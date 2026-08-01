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

    // Session state (Step 5)
    var sessionId: String? = nil

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

    // MARK: - ASR (Step 4)

    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var liveLineIndex: Int?

    func startListening() {
        guard micState == .idle else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            pageState = .failed
            return
        }

        // Append a live placeholder user line; updated in-place as transcription arrives.
        let liveLine = DialogueLine(role: .user, text: "")
        liveLineIndex = lines.count
        lines.append(liveLine)
        micState = .listening

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

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
                if let error {
                    let nsError = error as NSError
                    // kLSRErrorDomain / code 216 = expected cancellation or no-speech
                    let isExpected = nsError.domain == "kLSRErrorDomain" || nsError.code == 216
                    if !isExpected {
                        Task { @MainActor [weak self] in self?.cancelListening() }
                    }
                }
            }

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
                request.append(buf)
            }
            engine.prepare()
            try engine.start()

        } catch {
            cancelListening()
            pageState = .failed
        }
    }

    func stopListening() {
        guard micState == .listening else { return }
        tearDownAudio()
        finalizeSpeech()
    }

    func cancelListening() {
        guard micState == .listening else { return }
        tearDownAudio()
        if let idx = liveLineIndex, idx < lines.count {
            lines.remove(at: idx)
        }
        liveLineIndex = nil
        micState = .idle
    }

    /// Called when user taps mic during `.aiSpeaking` to interrupt.
    func interruptAI() {
        guard micState == .aiSpeaking else { return }
        micState = .idle
        // finalizeSpeech's Task checks micState == .aiSpeaking before appending, so it bails cleanly.
    }

    private func tearDownAudio() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finalizeSpeech() {
        guard micState == .listening else { return }  // re-entry guard
        micState = .aiSpeaking                         // block concurrent calls immediately

        // Extract and clean up the live placeholder line
        var userText = ""
        if let idx = liveLineIndex, idx < lines.count {
            userText = lines[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if userText.isEmpty { lines.remove(at: idx) }
        }
        liveLineIndex = nil

        // Nothing was transcribed — release mic without calling the backend
        guard !userText.isEmpty else {
            micState = .idle
            return
        }

        let sid = sessionId
        let turnId = UUID().uuidString

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let sid else { throw DialogueError.notAuthenticated }
                let response = try await DialogueService.turn(
                    sessionId: sid,
                    turnId: turnId,
                    text: userText
                )
                guard self.micState == .aiSpeaking else { return }  // interrupt guard
                self.lines.append(DialogueLine(role: .ai, text: response.reply))
                self.suggestions = response.suggestions.map {
                    DialogueSuggestion(lemma: $0.lemma, hint: $0.hint)
                }
                if let detail = response.sceneDetail, !detail.isEmpty {
                    self.sceneDetail = detail
                }
                self.micState = .idle
            } catch {
                guard self.micState == .aiSpeaking else { return }
                print("[ConversationViewModel] turn failed:", error)
                // Show the error banner but keep the conversation alive
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
