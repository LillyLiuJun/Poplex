import Foundation
import UIKit

// DB 消息记录——从 get-messages 解码，用于重建历史时间线
// 纯数据 + 纯转换（asTimelineEntry 等），显式 nonisolated：TodayViewModel.buildEntries
// 本身标了 nonisolated 以便随处调用，调用这里的方法不该因为模块默认主线程隔离被拦下来。
nonisolated struct MessageRecord: Decodable, Identifiable {
    let id: UUID
    let role: String
    let inputType: String?
    let userContent: String?
    let signedImageUrl: String?  // 1h 访问 URL，随 session 变化
    let imagePath: String?       // Storage 路径（稳定 key，用于磁盘缓存）
    let requestId: UUID?         // 幂等键（老行可能为 NULL）；用于「持久化失败行 / seed」与服务端记录去重
    let card: AICard?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case inputType      = "input_type"
        case userContent    = "user_content"
        case signedImageUrl = "signed_image_url"
        case imagePath      = "image_url"
        case requestId      = "request_id"
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
        requestId      = try c.decodeIfPresent(UUID.self, forKey: .requestId)
        createdAt      = try c.decode(Date.self,   forKey: .createdAt)

        // s1–s6 与新写入的 "card" 统一解码为 .card；其余（含历史 chat）不渲染。
        let cardType = try c.decodeIfPresent(String.self, forKey: .cardType)
        switch cardType {
        case "s1", "s2", "s3", "s4", "s5", "s6", "card":
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
            // 预设卡图片是 App 内置素材：image_url 存 "asset:<imageName>" 标记，
            // 直接取本地素材渲染（storage 签名对 asset 前缀无意义）。
            if let assetName = Self.assetImageName(fromPath: imagePath) {
                return TimelineEntry(id: id, createdAt: createdAt,
                                     content: .userBubble(text: displayText, image: UIImage(named: assetName), imageUrl: nil, imageStableKey: nil))
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

    /// image_url 里的本地素材引用："asset:<imageName>" → 返回素材名；否则 nil（storage 路径）。
    static func assetImageName(fromPath path: String?) -> String? {
        guard let path, path.hasPrefix("asset:"), path.count > "asset:".count else { return nil }
        return String(path.dropFirst("asset:".count))
    }
}
