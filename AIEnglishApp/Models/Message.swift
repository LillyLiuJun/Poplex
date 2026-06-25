import Foundation

// 时间线里的一条记录：用户说的，或 AI 回的
enum MessageRole {
    case user
    case ai
}

struct Message: Identifiable {
    let id: UUID
    let role: MessageRole
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: MessageRole, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
