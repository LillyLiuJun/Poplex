import Foundation

/// Tab2 首页数据——对应 get_tab2_home RPC 返回的 JSON 结构。
struct Tab2HomeData: Decodable {
    let unlocked: Bool
    let inputCount: Int
    let categories: [Tab2CategoryData]

    enum CodingKeys: String, CodingKey {
        case unlocked
        case inputCount = "input_count"
        case categories
    }

    init(unlocked: Bool, inputCount: Int, categories: [Tab2CategoryData]) {
        self.unlocked = unlocked
        self.inputCount = inputCount
        self.categories = categories
    }
}

/// 单个分类的数据，含子场景和预览词。
struct Tab2CategoryData: Decodable, Identifiable {
    let sceneCategory: String   // 数据库枚举值（中文）
    let wordCount: Int
    let unlocked: Bool
    let lastMaterialAt: Date?
    let subScenes: [Tab2SubScene]
    let previewWords: [String]

    var id: String { sceneCategory }

    /// 英文 UI 标签（通过 SceneCategoryMap 转换）
    var englishLabel: String {
        SceneCategory.from(sceneCategory).englishLabel
    }

    enum CodingKeys: String, CodingKey {
        case sceneCategory  = "scene_category"
        case wordCount      = "word_count"
        case unlocked
        case lastMaterialAt = "last_material_at"
        case subScenes      = "sub_scenes"
        case previewWords   = "preview_words"
    }

    init(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        lastMaterialAt: Date? = nil,
        subScenes: [Tab2SubScene] = [],
        previewWords: [String] = []
    ) {
        self.sceneCategory = sceneCategory
        self.wordCount = wordCount
        self.unlocked = unlocked
        self.lastMaterialAt = lastMaterialAt
        self.subScenes = subScenes
        self.previewWords = previewWords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sceneCategory  = try c.decode(String.self,   forKey: .sceneCategory)
        wordCount      = try c.decode(Int.self,       forKey: .wordCount)
        unlocked       = try c.decode(Bool.self,      forKey: .unlocked)
        subScenes      = try c.decodeIfPresent([Tab2SubScene].self, forKey: .subScenes) ?? []
        previewWords   = try c.decodeIfPresent([String].self,       forKey: .previewWords) ?? []

        if let raw = try c.decodeIfPresent(String.self, forKey: .lastMaterialAt) {
            lastMaterialAt = ISO8601DateFormatter().date(from: raw)
        } else {
            lastMaterialAt = nil
        }
    }
}

/// 子场景——一个反复出现的日常活动。
struct Tab2SubScene: Decodable, Identifiable {
    let sceneDetail: String
    let occurrenceCount: Int
    let quote: String?      // 该子场景下最近一条用户原话（≥6 字；无则 nil）
    let imageUrl: String?   // 对应来源 message 的图片 URL（无则 nil）

    var id: String { sceneDetail }

    enum CodingKeys: String, CodingKey {
        case sceneDetail     = "scene_detail"
        case occurrenceCount = "occurrence_count"
        case quote
        case imageUrl        = "image_url"
    }

    init(sceneDetail: String, occurrenceCount: Int, quote: String? = nil, imageUrl: String? = nil) {
        self.sceneDetail = sceneDetail
        self.occurrenceCount = occurrenceCount
        self.quote = quote
        self.imageUrl = imageUrl
    }
}

/// 单个词条——get_category_words RPC 返回的行。
struct Tab2WordEntry: Decodable, Identifiable {
    let lemma: String
    let displayForm: String?
    let entryKind: String?
    let pos: String?
    let granularity: String?    // word | sentence | passage
    let sourceType: String?     // material | dialogue
    let sampleSentence: String?
    let nativeMeaning: String?
    let imageUrl: String?

    var id: String { lemma }

    /// 左槽显示用：区分来源类型
    var sourceTag: SourceTag {
        if sourceType == "dialogue" { return .dialogue }
        switch granularity {
        case "word":    return .word
        case "passage": return .passage
        default:        return .sentence
        }
    }

    /// 右侧说明文字（截断前原始值）
    var displaySample: String? {
        if granularity == "word" { return nil }  // 查词：显示 "looked up"
        return sampleSentence
    }

    enum CodingKeys: String, CodingKey {
        case lemma
        case displayForm    = "display_form"
        case entryKind      = "entry_kind"
        case pos
        case granularity
        case sourceType     = "source_type"
        case sampleSentence  = "sample_sentence"
        case nativeMeaning   = "native_meaning"
        case imageUrl        = "image_url"
    }

    enum SourceTag { case word, sentence, passage, dialogue }

    init(
        lemma: String,
        displayForm: String? = nil,
        entryKind: String? = nil,
        pos: String? = nil,
        granularity: String? = nil,
        sourceType: String? = nil,
        sampleSentence: String? = nil,
        nativeMeaning: String? = nil,
        imageUrl: String? = nil
    ) {
        self.lemma = lemma
        self.displayForm = displayForm
        self.entryKind = entryKind
        self.pos = pos
        self.granularity = granularity
        self.sourceType = sourceType
        self.sampleSentence = sampleSentence
        self.nativeMeaning = nativeMeaning
        self.imageUrl = imageUrl
    }
}

// MARK: - Badge & image helpers (internal for testability)

extension Tab2WordEntry {
    /// 图片缓存 key：去掉签名 URL 的查询参数，路径不变，磁盘缓存跨 session 可命中。
    var stableImageKey: String? {
        guard let urlStr = imageUrl, !urlStr.isEmpty else { return nil }
        return urlStr.components(separatedBy: "?").first
    }

    /// Badge 图标名称，按捕获方式（sourceTag）优先，再按表达类型（entryKind）细分。
    var badgeIconName: String {
        switch sourceTag {
        case .word:     return "text.magnifyingglass"
        case .dialogue: return "waveform"
        case .sentence, .passage:
            switch entryKind {
            case "word":                                return "character.textbox"
            case "phrase", "collocation", "pattern":    return "text.bubble.fill"
            case "idiom", "slang":                      return "quote.bubble.fill"
            default:                                    return "text.bubble.fill"
            }
        }
    }
}

