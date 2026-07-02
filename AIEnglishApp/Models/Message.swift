import Foundation

struct TimelineEntry: Identifiable {
    let id: UUID
    let createdAt: Date
    let content: Content

    enum Content {
        case userBubble(text: String)
        case aiCard(AICard)
        case aiError(message: String)
    }

    static func userBubble(text: String) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .userBubble(text: text))
    }

    static func aiCard(_ card: AICard) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .aiCard(card))
    }

    static func aiError(_ message: String) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .aiError(message: message))
    }
}
