import Foundation

struct ContextTurn {
    let userContent: String
    let cardType: String
    let cardContent: [String: Any]
}

@Observable
final class ConversationSession {
    private(set) var currentContext: ContextTurn?
    private var backgroundedAt: Date?

    func didEnterBackground() {
        backgroundedAt = Date()
    }

    func didBecomeActive() {
        guard let t = backgroundedAt else { return }
        if Date().timeIntervalSince(t) > 30 * 60 {
            currentContext = nil
        }
        backgroundedAt = nil
    }

    func onAIResponseReceived(userContent: String, cardType: String, cardContent: [String: Any]) {
        currentContext = ContextTurn(userContent: userContent, cardType: cardType, cardContent: cardContent)
    }
}
