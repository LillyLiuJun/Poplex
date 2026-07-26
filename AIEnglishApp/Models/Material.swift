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

// 第5刀：raw_content 已统一为一套字段。Tab2 仍按 material_type 分 scene/vocabulary 两类展示，
// 故这里保留两个视图模型，但都从【统一字段】解码，并保持原有的公开属性名，Tab2 视图几乎不动。
// （Tab2 的词本位重构是后续独立工作，不在本刀范围。）

// material_type = "scene"（sentence 素材）
struct SceneMaterial: Decodable {
    let nativeEnglish: String        // 目标语言表达 = target_expression ?? user_original
    let chineseOriginal: String      // 母语侧 = native_meaning ?? user_original
    let keyPhrases: [KeyPhraseMaterial]  // 由 learnable_units 映射而来
    let sourceImagePath: String?     // DB 存的稳定路径（用作图片缓存 key）
    let sourceImageUrl: String?      // get-materials 现签的 1h 签名 URL（用于实际下载）
    // NOTE(Realtime): Realtime 推送来的素材只有 sourceImagePath，无 sourceImageUrl。
    //   实现 Realtime 时需单独为带路径的素材请求签名 URL。

    enum CodingKeys: String, CodingKey {
        case targetExpression = "target_expression"
        case userOriginal     = "user_original"
        case nativeMeaning    = "native_meaning"
        case learnableUnits   = "learnable_units"
        case sourceImagePath  = "source_image_path"
        case sourceImageUrl   = "source_image_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let target   = try c.decodeIfPresent(String.self, forKey: .targetExpression)
        let original = try c.decodeIfPresent(String.self, forKey: .userOriginal)
        let meaning  = try c.decodeIfPresent(String.self, forKey: .nativeMeaning)
        nativeEnglish   = target ?? original ?? ""
        chineseOriginal = meaning ?? original ?? ""
        let units = (try? c.decode([LearnableUnit].self, forKey: .learnableUnits)) ?? []
        keyPhrases = units.map { KeyPhraseMaterial(phrase: $0.form, note: $0.note) }
        sourceImagePath = try c.decodeIfPresent(String.self, forKey: .sourceImagePath)
        sourceImageUrl  = try c.decodeIfPresent(String.self, forKey: .sourceImageUrl)
    }
}

struct KeyPhraseMaterial {
    let phrase: String
    let note: String
}

// material_type = "vocabulary"（word 素材）
struct VocabMaterial: Decodable {
    let word: String                 // = target_expression ?? user_original
    let phonetic: String
    let pos: String                  // 统一字段是数组，这里 join 成 " / " 供现有行视图直接用
    let definition: String           // = native_meaning
    let exampleEn: String
    let exampleZh: String

    enum CodingKeys: String, CodingKey {
        case targetExpression = "target_expression"
        case userOriginal     = "user_original"
        case nativeMeaning    = "native_meaning"
        case phonetic, pos, examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let target   = try c.decodeIfPresent(String.self, forKey: .targetExpression)
        let original = try c.decodeIfPresent(String.self, forKey: .userOriginal)
        word       = target ?? original ?? ""
        phonetic   = (try? c.decode(String.self, forKey: .phonetic)) ?? ""
        let posArr = (try? c.decode([String].self, forKey: .pos)) ?? []
        pos        = posArr.joined(separator: " / ")
        // try? 与同函数其他字段保持一致：后端脏数据（非 String）不至于炸掉整个词表数组解码
        definition = (try? c.decode(String.self, forKey: .nativeMeaning)) ?? ""
        let examples = (try? c.decode([BilingualExample].self, forKey: .examples)) ?? []
        exampleEn  = examples.first?.en ?? ""
        exampleZh  = examples.first?.zh ?? ""
    }
}
