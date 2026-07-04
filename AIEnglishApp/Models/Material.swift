import Foundation

// Tab2 素材：从 Supabase materials 表读取
struct Material: Identifiable, Decodable {
    let id: UUID
    let materialType: String      // "scene" | "vocabulary"
    let status: String            // "pending" | "categorized"
    let sceneCategory: String?
    let rawContent: MaterialContent
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case materialType  = "material_type"
        case status
        case sceneCategory = "scene_category"
        case rawContent    = "raw_content"
        case createdAt     = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        materialType  = try c.decode(String.self, forKey: .materialType)
        status        = try c.decode(String.self, forKey: .status)
        sceneCategory = try c.decodeIfPresent(String.self, forKey: .sceneCategory)
        createdAt     = try c.decode(Date.self,   forKey: .createdAt)

        switch materialType {
        case "scene":
            rawContent = .scene(try c.decode(SceneMaterial.self, forKey: .rawContent))
        case "vocabulary":
            rawContent = .vocabulary(try c.decode(VocabMaterial.self, forKey: .rawContent))
        default:
            rawContent = .unknown
        }
    }
}

enum MaterialContent {
    case scene(SceneMaterial)
    case vocabulary(VocabMaterial)
    case unknown
}

// raw_content schema for material_type = "scene" (extracted from s2 or s4 cards)
struct SceneMaterial: Decodable {
    let nativeEnglish: String        // s4: native_translation; s2: native_polish ?? user sentence
    let chineseOriginal: String      // s4: chinese_original; s2: chinese_translation
    let keyPhrases: [KeyPhraseMaterial]
    let sourceImagePath: String?     // DB 存的稳定路径（用作图片缓存 key）
    let sourceImageUrl: String?      // get-materials 现签的 1h 签名 URL（用于实际下载）
    // NOTE(Realtime): Realtime 推送来的素材只有 sourceImagePath，无 sourceImageUrl。
    //   实现 Realtime 时需单独为带路径的素材请求签名 URL。

    enum CodingKeys: String, CodingKey {
        case nativeEnglish   = "native_english"
        case chineseOriginal = "chinese_original"
        case keyPhrases      = "key_phrases"
        case sourceImagePath = "source_image_path"
        case sourceImageUrl  = "source_image_url"
    }
}

struct KeyPhraseMaterial: Decodable {
    let phrase: String
    let note: String
}

// raw_content schema for material_type = "vocabulary" (extracted from s1 or s3 cards)
struct VocabMaterial: Decodable {
    let word: String
    let phonetic: String
    let pos: String
    let definition: String
    let exampleEn: String
    let exampleZh: String

    enum CodingKeys: String, CodingKey {
        case word, phonetic, pos, definition
        case exampleEn = "example_en"
        case exampleZh = "example_zh"
    }
}
