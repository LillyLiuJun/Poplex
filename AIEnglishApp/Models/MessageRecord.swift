import Foundation

// DB 消息记录——从 get-messages 解码，用于重建历史时间线
struct MessageRecord: Decodable, Identifiable {
    let id: UUID
    let role: String
    let inputType: String?
    let userContent: String?
    let signedImageUrl: String?  // 1h 访问 URL，随 session 变化
    let imagePath: String?       // Storage 路径（稳定 key，用于磁盘缓存）
    let card: AICard?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case inputType      = "input_type"
        case userContent    = "user_content"
        case signedImageUrl = "signed_image_url"
        case imagePath      = "image_url"
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
        imagePath      = try c.decodeIfPresent(String.self, forKey: .imagePath)
        createdAt      = try c.decode(Date.self,   forKey: .createdAt)

        // s1–s4 与新写入的 "card" 统一解码为 .card；其余（含历史 chat）不渲染。
        let cardType = try c.decodeIfPresent(String.self, forKey: .cardType)
        switch cardType {
        case "s1", "s2", "s3", "s4", "card":
            // try? so a single bad card_content (null or malformed) silently becomes nil
            // instead of throwing and aborting the entire [MessageRecord] array decode.
            card = (try? c.decode(CardContent.self, forKey: .cardContent)).map { .card($0) }
        default:
            card = nil
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
                                 content: .userBubble(text: displayText, image: nil, imageUrl: signedImageUrl, imageStableKey: imagePath))
        case "assistant":
            guard let card else { return nil }
            return TimelineEntry(id: id, createdAt: createdAt, content: .aiCard(card))
        default:
            return nil
        }
    }
}
