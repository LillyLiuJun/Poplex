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
    let text: String
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
