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

// MARK: - Suggestion (stub, expanded in E1b)

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
    var sceneDetail: String = "Mornings at the office"
    var lines: [DialogueLine] = []
    var micState: MicState = .idle
    var isSuggestionsExpanded: Bool = false
    var suggestions: [DialogueSuggestion] = []

    init(sceneCategory: String) {
        self.sceneCategory = sceneCategory
        lines = ConversationViewModel.fakeLinesForActive()
        suggestions = ConversationViewModel.fakeSuggestions()
    }

    // MARK: - Permission (Step 2)

    /// Called on view appear and on every return from background.
    /// • Already granted → stay in .preparing (Step 5 starts the session).
    /// • Undetermined    → request; denied result → .permissionNeeded.
    /// • Denied          → .permissionNeeded immediately.
    func checkPermissions() async {
        // Only act when the page is in a state where permission matters.
        guard pageState == .preparing || pageState == .permissionNeeded else { return }

        if PermissionService.areBothGranted {
            if pageState == .permissionNeeded {
                pageState = .preparing   // user just granted in Settings, unblock
            }
            return
        }

        // One or both are denied → show gate immediately, no dialog.
        if PermissionService.micStatus == .denied || PermissionService.speechStatus == .denied {
            pageState = .permissionNeeded
            return
        }

        // Undetermined → request (system dialogs appear here).
        let granted = await PermissionService.requestNeeded()
        pageState = granted ? .preparing : .permissionNeeded
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
        // The stub Task in finalizeSpeech checks micState == .aiSpeaking before appending,
        // so it will silently bail out without adding the fake response.
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

        // Remove the placeholder if user said nothing recognizable
        if let idx = liveLineIndex, idx < lines.count,
           lines[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.remove(at: idx)
        }
        liveLineIndex = nil

        // Stub: fake AI reply after a short pause — Step 5 replaces this with the real backend call.
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard self.micState == .aiSpeaking else { return }  // interrupt guard
            let stubs = [
                "That's a good point. Can you say more about that?",
                "Right. And how did you feel about that?",
                "I see. What happened next?",
                "Interesting. Would you do anything differently?",
                "Good. Can you give me an example?",
            ]
            self.lines.append(DialogueLine(role: .ai, text: stubs[self.lines.count % stubs.count]))
            self.micState = .idle
        }
    }

    // MARK: Fake data (step 1 skeleton — replaced by real data in E1b)

    static func fakeLinesForActive() -> [DialogueLine] {
        [
            DialogueLine(role: .ai,   text: "You've got mornings at the office and client calls in here. Which one's on your mind?"),
            DialogueLine(role: .user, text: "I set up the room but the projector no work"),
            DialogueLine(role: .ai,   text: "So you were troubleshooting before the day even started. Did you manage to sort it out before the meeting began?"),
            DialogueLine(role: .user, text: "Yes we run late about ten minute"),
            DialogueLine(role: .ai,   text: "That kind of slow start before a big presentation is rough. What happened with the projector?"),
            DialogueLine(role: .user, text: "The cable was wrong type, our IT guy bring adapter"),
            DialogueLine(role: .ai,   text: "So the IT team came through in the end. How did the client react when you finally got connected?"),
            DialogueLine(role: .user, text: "They were okay, the manager explain the delay"),
            DialogueLine(role: .ai,   text: "Your manager helped smooth it over — that's good support. Did you get through the whole presentation?"),
            DialogueLine(role: .user, text: "Yes we finish all the slide but I very nervous the whole time"),
            DialogueLine(role: .ai,   text: "First time presenting with tech issues is tough. What would you do differently next time?"),
        ]
    }

    // Cycles through extra lines so the debug "+ Line" button always adds something new.
    private static let debugLineCycle: [(DialogueRole, String)] = [
        (.user, "Maybe check equipment one day before"),
        (.ai,   "That's a smart habit — arriving early to test everything. Have you had any tricky presentations since then?"),
        (.user, "Not yet but I will be more prepare"),
        (.ai,   "Good mindset. Being prepared takes the anxiety out of it. Anything else from that morning you want to talk through?"),
        (.user, "No I think that is all, thank you"),
        (.ai,   "You covered it well. 'Run late,' 'sort it out,' 'set up the room' — those came up a lot today. Nice work."),
    ]

    func debugAddLine() {
        let idx = lines.count % Self.debugLineCycle.count
        let (role, text) = Self.debugLineCycle[idx]
        lines.append(DialogueLine(role: role, text: text))
    }

    static func fakeSuggestions() -> [DialogueSuggestion] {
        [
            DialogueSuggestion(lemma: "run late",    hint: "if things ran behind"),
            DialogueSuggestion(lemma: "set up",      hint: "when preparing the room"),
            DialogueSuggestion(lemma: "sort it out", hint: "to fix the problem"),
        ]
    }
}
