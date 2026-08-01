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
        ]
    }

    static func fakeSuggestions() -> [DialogueSuggestion] {
        [
            DialogueSuggestion(lemma: "run late",    hint: "if things ran behind"),
            DialogueSuggestion(lemma: "set up",      hint: "when preparing the room"),
            DialogueSuggestion(lemma: "sort it out", hint: "to fix the problem"),
        ]
    }
}
