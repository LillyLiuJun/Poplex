import Foundation

// 对应 Edge Function 返回的 JSON 结构。
// Slice 1 界面只用到 reply；intent / material 现在就定好形状，供后续落库与 Tab2 分类使用，避免返工。
struct AIResponse: Codable {
    let reply: String
    let intent: Intent
    let material: Material

    struct Intent: Codable {
        let language: String        // zh / en / other
        let isMeaningful: Bool
        let isCompliant: Bool
        let hasClearScene: Bool

        enum CodingKeys: String, CodingKey {
            case language
            case isMeaningful = "is_meaningful"
            case isCompliant = "is_compliant"
            case hasClearScene = "has_clear_scene"
        }
    }

    struct Material: Codable {
        let sceneTag: String        // 场景标签，给 Tab2 分类用
        let level: String           // word / phrase / sentence / paragraph
        let english: String

        enum CodingKeys: String, CodingKey {
            case sceneTag = "scene_tag"
            case level
            case english
        }
    }
}
