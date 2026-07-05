import Foundation

// DB 消息记录——从 get-messages 解码，用于重建历史时间线
struct MessageRecord: Decodable, Identifiable {
    let id: UUID
    let role: String           // "user" | "assistant"
    let inputType: String?     // "text" | "image"
    let userContent: String?   // 用户原文（role=user 时有值）
    let card: AICard?          // 从 card_type + card_content 重建（role=assistant 时有值）
    let imageUrl: String?      // Storage 路径（图片消息时有值）
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case inputType   = "input_type"
        case userContent = "user_content"
        case cardType    = "card_type"
        case cardContent = "card_content"
        case imageUrl    = "image_url"
        case createdAt   = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        role        = try c.decode(String.self, forKey: .role)
        inputType   = try c.decodeIfPresent(String.self, forKey: .inputType)
        userContent = try c.decodeIfPresent(String.self, forKey: .userContent)
        imageUrl    = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        createdAt   = try c.decode(Date.self,   forKey: .createdAt)

        // 用已有的各卡片 Decodable 直接从 card_content 字段解码，复用现有解码逻辑
        let cardType = try c.decodeIfPresent(String.self, forKey: .cardType)
        switch cardType {
        case "s1":   card = try .s1(c.decode(VocabContent.self,       forKey: .cardContent))
        case "s2":   card = try .s2(c.decode(GrammarContent.self,     forKey: .cardContent))
        case "s3":   card = try .s3(c.decode(TranslationContent.self, forKey: .cardContent))
        case "s4":   card = try .s4(c.decode(SceneContent.self,       forKey: .cardContent))
        case "chat": card = try .chat(c.decode(ChatContent.self,      forKey: .cardContent))
        default:     card = nil
        }
    }

    // 转换为 UI 用的 TimelineEntry（图片消息历史里无法恢复 UIImage，显示为纯文字气泡）
    func asTimelineEntry() -> TimelineEntry? {
        switch role {
        case "user":
            let displayText: String?
            if inputType == "image" {
                // "[photo] 文字" → 只显示附带的文字（如果有），否则显示 nil
                let stripped = userContent?.replacingOccurrences(of: "[photo] ", with: "")
                                          .replacingOccurrences(of: "[photo]", with: "")
                displayText = stripped?.isEmpty == false ? stripped : nil
            } else {
                displayText = userContent
            }
            return TimelineEntry(id: id, createdAt: createdAt,
                                 content: .userBubble(text: displayText, image: nil))
        case "assistant":
            guard let card else { return nil }
            return TimelineEntry(id: id, createdAt: createdAt, content: .aiCard(card))
        default:
            return nil
        }
    }
}
