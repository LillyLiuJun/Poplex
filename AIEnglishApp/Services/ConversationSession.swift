import Foundation
import UIKit

struct ContextTurn {
    let userContent: String
    let cardType: String
    let cardContent: [String: Any]
    let image: UIImage?   // 上一轮的图片，follow-up 时重发给 AI，让模型真正"看"到上轮图片
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

    func onAIResponseReceived(userContent: String, cardType: String, cardContent: [String: Any], image: UIImage? = nil) {
        currentContext = ContextTurn(userContent: userContent, cardType: cardType, cardContent: cardContent, image: image)
    }
}
