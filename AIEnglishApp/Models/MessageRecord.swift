import Foundation

// DB 消息记录——从 get-messages 解码，用于重建历史时间线
struct MessageRecord: Decodable, Identifiable {
    let id: UUID
    let role: String
    let inputType: String?
    let userContent: String?
    let signedImageUrl: String?  // get-messages 为 image 消息签发的 1h Storage URL
    let card: AICard?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case inputType      = "input_type"
        case userContent    = "user_content"
        case signedImageUrl = "signed_image_url"
        case cardType       = "card_type"
        case cardContent    = "card_content"
        case createdAt      = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,   forKey: .id)
        role           = try c.decode(String.self, forKey: .role)
        inputType      = try c.decodeIfPresent(String.self, forKey: .inputType)
        userContent    = try c.decodeIfPresent(String.self, forKey: .userContent)
        signedImageUrl = try c.decodeIfPresent(String.self, forKey: .signedImageUrl)
        createdAt      = try c.decode(Date.self,   forKey: .createdAt)

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

    func asTimelineEntry() -> TimelineEntry? {
        switch role {
        case "user":
            let displayText: String?
            if inputType == "image" || inputType == "preset_card" {
                let stripped = userContent?.replacingOccurrences(of: "[photo] ", with: "")
                                          .replacingOccurrences(of: "[photo]", with: "")
                displayText = stripped?.isEmpty == false ? stripped : "Describe this image"
            } else {
                displayText = userContent
            }
            return TimelineEntry(id: id, createdAt: createdAt,
                                 content: .userBubble(text: displayText, image: nil, imageUrl: signedImageUrl))
        case "assistant":
            guard let card else { return nil }
            return TimelineEntry(id: id, createdAt: createdAt, content: .aiCard(card))
        default:
            return nil
        }
    }
}
