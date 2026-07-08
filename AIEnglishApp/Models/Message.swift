import Foundation
import UIKit

struct TimelineEntry: Identifiable {
    let id: UUID
    let createdAt: Date
    let content: Content

    enum Content {
        case userBubble(text: String?, image: UIImage?, imageUrl: String?, imageStableKey: String?)
        case aiLoading
        case aiCard(AICard)
        case aiError(message: String)
        case dateSeparator(String)   // "Today" / "Yesterday" / "Jul 3"
    }

    static func userBubble(text: String?, image: UIImage?, imageUrl: String? = nil, imageStableKey: String? = nil) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .userBubble(text: text, image: image, imageUrl: imageUrl, imageStableKey: imageStableKey))
    }

    static func aiLoading() -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .aiLoading)
    }

    static func aiCard(_ card: AICard) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .aiCard(card))
    }

    static func aiError(_ message: String) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .aiError(message: message))
    }
}
