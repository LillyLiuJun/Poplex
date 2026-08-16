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
        case sendFailed(text: String?, image: UIImage?)   // 生成请求失败（含断网）：可点击重试，携带原始输入以重发
        case userRejected(text: String?, wasImage: Bool)   // 安全拦截：文本原样展示、图片转占位块；不带原图数据（不渲染、不重试）
        case pendingRetry(PendingRetryRecord)   // 断网待重试记录：带图 + 文案 + Retry（不参与服务端历史）
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

    static func userRejected(text: String?, wasImage: Bool) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .userRejected(text: text, wasImage: wasImage))
    }

    static func pendingRetry(_ record: PendingRetryRecord) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .pendingRetry(record))
    }
}
