import SwiftUI
import AVFoundation
import Speech

// MARK: - Page state machine (§2)

enum ConversationPageState: CaseIterable {
    case permissionNeeded
    case preparing
    case active
    case failed
    case ended
}

// MARK: - Dialogue domain types

enum DialogueRole {
    case ai, user
}

struct DialogueLine: Identifiable {
    var id = UUID()
    let role: DialogueRole
    var text: String  // mutable — updated in-place during live ASR transcription
}

// MARK: - Mic states (§3.3)

enum MicState {
    case idle
    case listening
    case aiSpeaking
    case disabled
}

// MARK: - Suggestion

struct DialogueSuggestion: Identifiable {
    var id = UUID()
    let lemma: String
    let hint: String
}

// MARK: - Fallback result (shown inline after Chinese speech detected)

struct FallbackKeyWord {
    let word: String
    let phonetic: String
}

struct FallbackResult {
    let translation: String
    let keyWords: [FallbackKeyWord]
    let hint: String
}

// MARK: - ViewModel

@Observable
class ConversationViewModel {
    var pageState: ConversationPageState = .preparing
    var sceneCategory: String
    var sceneDetail: String = ""
    var lines: [DialogueLine] = []
    var micState: MicState = .idle
    var isSuggestionsExpanded: Bool = false
    var suggestions: [DialogueSuggestion] = []

    // Session state
    var sessionId: String? = nil
    // Fallback result — shown inline when Chinese speech is detected
    var fallbackResult: FallbackResult? = nil
    // Whether the current listening session was started by NativeFallbackButton
    var isFallbackListening: Bool = false

    init(sceneCategory: String) {
        self.sceneCategory = sceneCategory
    }

    // MARK: - Permission + Session start (Steps 2 & 5)

    /// Called on view appear and on every return from background.
    /// • Already granted  → start session if still in .preparing.
    /// • Undetermined     → request; then start session if granted.
    /// • Denied anywhere  → .permissionNeeded immediately.
    func checkPermissions() async {
        guard pageState == .preparing || pageState == .permissionNeeded else { return }

        if PermissionService.areBothGranted {
            if pageState == .permissionNeeded { pageState = .preparing }
            await beginSession()
            return
        }

        if PermissionService.micStatus == .denied || PermissionService.speechStatus == .denied {
            pageState = .permissionNeeded
            return
        }

        let granted = await PermissionService.requestNeeded()
        if granted {
            await beginSession()
        } else {
            pageState = .permissionNeeded
        }
    }

    // MARK: - Session start (Step 5)

    func beginSession() async {
        guard pageState == .preparing else { return }
        do {
            let response = try await DialogueService.start(sceneCategory: sceneCategory)
            sessionId = response.sessionId
            lines = [DialogueLine(role: .ai, text: response.reply)]
            suggestions = response.suggestions.map { DialogueSuggestion(lemma: $0.lemma, hint: $0.hint) }
            pageState = .active
        } catch {
            print("[ConversationViewModel] beginSession failed:", error)
            pageState = .failed
        }
    }

    @MainActor
    func openSettings() {
        PermissionService.openSettings()
    }

    // MARK: - ASR

    // en-US recognizer (primary — always running)
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var liveLineIndex: Int?
    // zh-CN recognizer (runs in parallel during fallback mode, same audio tap)
    @ObservationIgnored private var zhRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var zhRecognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var zhLiveText: String = ""

    // MARK: - Normal listening (en-US only)

    func startListening() {
        guard micState == .idle else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else { pageState = .failed; return }

        appendLiveLine()
        micState = .listening

        do {
            try startAudioSession()
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            audioEngine = engine
            recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let idx = self.liveLineIndex, idx < self.lines.count {
                            self.lines[idx].text = text
                        }
                        if isFinal { self.finalizeSpeech() }
                    }
                }
                if let error { self.handleASRError(error) }
            }

            attachTap(engine: engine) { [weak self] buf in
                self?.recognitionRequest?.append(buf)
            }
            try engine.start()
        } catch {
            cancelListening()
            pageState = .failed
        }
    }

    // MARK: - Fallback listening (en-US + zh-CN dual, same audio tap)

    func startFallbackListening() {
        guard micState == .idle else { return }
        guard let enRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              enRecognizer.isAvailable else { pageState = .failed; return }

        isFallbackListening = true
        appendLiveLine()
        micState = .listening

        do {
            try startAudioSession()
            let engine = AVAudioEngine()
            let enReq = SFSpeechAudioBufferRecognitionRequest()
            let zhReq = SFSpeechAudioBufferRecognitionRequest()
            enReq.shouldReportPartialResults = true
            zhReq.shouldReportPartialResults = true
            audioEngine = engine
            recognitionRequest = enReq
            zhRecognitionRequest = zhReq

            // en-US: update live line only when zh hasn't produced text
            recognitionTask = enRecognizer.recognitionTask(with: enReq) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    Task { @MainActor [weak self] in
                        guard let self, self.isFallbackListening, self.zhLiveText.isEmpty else { return }
                        if let idx = self.liveLineIndex, idx < self.lines.count { self.lines[idx].text = text }
                    }
                }
                if let error { self.handleASRError(error) }
            }

            // zh-CN: update live line with Chinese text (takes priority)
            let zhRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
            if let zhRecognizer, zhRecognizer.isAvailable {
                zhRecognitionTask = zhRecognizer.recognitionTask(with: zhReq) { [weak self] result, _ in
                    guard let self, let result else { return }
                    let text = result.bestTranscription.formattedString
                    Task { @MainActor [weak self] in
                        guard let self, self.isFallbackListening, !text.isEmpty else { return }
                        self.zhLiveText = text
                        if let idx = self.liveLineIndex, idx < self.lines.count { self.lines[idx].text = text }
                    }
                }
            }

            attachTap(engine: engine) { [weak self] buf in
                self?.recognitionRequest?.append(buf)
                self?.zhRecognitionRequest?.append(buf)
            }
            try engine.start()
        } catch {
            cancelListening()
            pageState = .failed
        }
    }

    // MARK: - Stop / cancel / interrupt

    func stopListening() {
        guard micState == .listening else { return }
        tearDownAudio()
        if isFallbackListening {
            finalizeFallbackSpeech()
        } else {
            finalizeSpeech()
        }
    }

    func cancelListening() {
        guard micState == .listening else { return }
        tearDownAudio()
        if let idx = liveLineIndex, idx < lines.count { lines.remove(at: idx) }
        liveLineIndex = nil
        zhLiveText = ""
        isFallbackListening = false
        micState = .idle
    }

    func interruptAI() {
        guard micState == .aiSpeaking else { return }
        micState = .idle
    }

    func dismissFallback() {
        fallbackResult = nil
    }

    // MARK: - Audio helpers

    private func appendLiveLine() {
        let liveLine = DialogueLine(role: .user, text: "")
        liveLineIndex = lines.count
        lines.append(liveLine)
    }

    private func startAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func attachTap(engine: AVAudioEngine, handler: @escaping (AVAudioPCMBuffer) -> Void) {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in handler(buf) }
        engine.prepare()
    }

    private func handleASRError(_ error: Error) {
        let nsError = error as NSError
        let isExpected = nsError.domain == "kLSRErrorDomain" || nsError.code == 216
        if !isExpected { Task { @MainActor [weak self] in self?.cancelListening() } }
    }

    private func tearDownAudio() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        zhRecognitionRequest?.endAudio()
        zhRecognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        zhRecognitionRequest = nil
        zhRecognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Finalize: normal turn

    private func finalizeSpeech() {
        guard micState == .listening else { return }

        var userText = ""
        if let idx = liveLineIndex, idx < lines.count {
            userText = lines[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if userText.isEmpty { lines.remove(at: idx) }
        }
        liveLineIndex = nil

        guard !userText.isEmpty else { micState = .idle; return }
        submitUserTurn(text: userText)
    }

    // MARK: - Finalize: fallback (detect language, route)

    private func finalizeFallbackSpeech() {
        let zhText = zhLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
        var enText = ""
        if let idx = liveLineIndex, idx < lines.count {
            enText = lines[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if zhText.isEmpty && enText.isEmpty { lines.remove(at: idx) }
        }
        liveLineIndex = nil
        zhLiveText = ""
        isFallbackListening = false

        // Chinese detected: any CJK character in zh transcript
        let hasChinese = zhText.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }

        if hasChinese {
            micState = .aiSpeaking
            submitFallback(text: zhText)
        } else if !enText.isEmpty {
            submitUserTurn(text: enText)
        } else {
            micState = .idle
        }
    }

    // MARK: - Backend calls

    private func submitUserTurn(text: String) {
        micState = .aiSpeaking
        let sid = sessionId
        let turnId = UUID().uuidString

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let sid else { throw DialogueError.notAuthenticated }
                let response = try await DialogueService.turn(sessionId: sid, turnId: turnId, text: text)
                guard self.micState == .aiSpeaking else { return }
                self.lines.append(DialogueLine(role: .ai, text: response.reply))
                self.suggestions = response.suggestions.map { DialogueSuggestion(lemma: $0.lemma, hint: $0.hint) }
                if let detail = response.sceneDetail, !detail.isEmpty { self.sceneDetail = detail }
                self.micState = .idle
            } catch {
                guard self.micState == .aiSpeaking else { return }
                print("[ConversationViewModel] turn failed:", error)
                self.pageState = .failed
                self.micState = .idle
            }
        }
    }

    private func submitFallback(text: String) {
        let sid = sessionId

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let sid else { throw DialogueError.notAuthenticated }
                let dto = try await DialogueService.fallback(sessionId: sid, text: text)
                guard self.micState == .aiSpeaking else { return }
                self.fallbackResult = FallbackResult(
                    translation: dto.translation,
                    keyWords: dto.keyWords.map { FallbackKeyWord(word: $0.word, phonetic: $0.phonetic) },
                    hint: dto.hint
                )
                self.micState = .idle
            } catch {
                guard self.micState == .aiSpeaking else { return }
                print("[ConversationViewModel] fallback failed:", error)
                self.pageState = .failed
                self.micState = .idle
            }
        }
    }

    // MARK: - Retry (error banner)

    func retry() {
        if sessionId == nil {
            pageState = .preparing
            Task { await beginSession() }
        } else {
            pageState = .active
        }
    }

    // MARK: - Debug helpers (debug picker only — not production paths)

    // Cycles through fake lines so the debug "+ Line" button always adds something new.
    private static let debugLineCycle: [(DialogueRole, String)] = [
        (.user, "I set up the room but the projector no work"),
        (.ai,   "So you were troubleshooting before the day even started."),
        (.user, "Yes we run late about ten minute"),
        (.ai,   "That kind of slow start is rough. What happened with the projector?"),
        (.user, "The cable was wrong type, our IT guy bring adapter"),
        (.ai,   "So the IT team came through in the end. How did the client react?"),
    ]

    func debugAddLine() {
        let idx = lines.count % Self.debugLineCycle.count
        let (role, text) = Self.debugLineCycle[idx]
        lines.append(DialogueLine(role: role, text: text))
    }
}
