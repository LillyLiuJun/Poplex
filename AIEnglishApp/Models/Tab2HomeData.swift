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
            // Backend returns fractional-seconds format (e.g. "2026-07-25T10:00:00.000Z");
            // the default ISO8601DateFormatter doesn't handle that, so try both.
            let fmtMs = ISO8601DateFormatter()
            fmtMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastMaterialAt = fmtMs.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        } else {
            lastMaterialAt = nil
        }
    }
}

/// 子场景——一个反复出现的日常活动。
struct Tab2SubScene: Decodable, Identifiable {
    let sceneDetail: String
    let occurrenceCount: Int
    let quote: String?            // 用户原话（≥6 字；无则 nil）
    let targetExpression: String? // AI 生成的目标语言句子（quote 为空时降级展示）
    let imageUrl: String?         // 对应来源 message 的图片 URL（无则 nil）

    var id: String { sceneDetail }

    var isPhotoMoment: Bool { imageUrl != nil }

    // 剥掉签名参数，取路径部分作缓存 key（签名 URL 每次重签会变，路径不变）
    var stableImageKey: String? {
        guard let url = imageUrl, !url.isEmpty else { return nil }
        return url.components(separatedBy: "?").first
    }

    enum CodingKeys: String, CodingKey {
        case sceneDetail       = "scene_detail"
        case occurrenceCount   = "occurrence_count"
        case quote
        case targetExpression  = "target_expression"
        case imageUrl          = "image_url"
    }

    init(sceneDetail: String, occurrenceCount: Int, quote: String? = nil, targetExpression: String? = nil, imageUrl: String? = nil) {
        self.sceneDetail = sceneDetail
        self.occurrenceCount = occurrenceCount
        self.quote = quote
        self.targetExpression = targetExpression
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

// MARK: - Badge glyph (类型图标：SF Symbol 描边 / 衬线字母 两种呈现)

enum Tab2BadgeGlyph: Equatable {
    case symbol(String)       // SF Symbol 描边图标
    case serifLetter(String)  // 衬线字母（句中单词，呼应品牌衬线）
}

// MARK: - Badge & image helpers (internal for testability)

extension Tab2WordEntry {
    /// 图片缓存 key：去掉签名 URL 的查询参数，路径不变，磁盘缓存跨 session 可命中。
    var stableImageKey: String? {
        guard let urlStr = imageUrl, !urlStr.isEmpty else { return nil }
        return urlStr.components(separatedBy: "?").first
    }

    /// 词条类型图标（统一细线家族）。按捕获方式优先，再按表达类型细分：
    ///   · 查词（.word）→ 放大镜；对话（.dialogue，未上线）→ 声波
    ///   · 句子/段落里的单词 → 衬线字母 A（呼应品牌衬线）
    ///   · 短语/搭配/句型 → text.quote 引用文本线；习语/俚语 → bubble.left 对话气泡
    /// 图片走 imageUrl，不经此。
    var badgeGlyph: Tab2BadgeGlyph {
        switch sourceTag {
        case .word:     return .symbol("magnifyingglass")
        case .dialogue: return .symbol("waveform")
        case .sentence, .passage:
            switch entryKind {
            case "word":            return .serifLetter("A")
            case "idiom", "slang":  return .symbol("bubble.left")
            default:                return .symbol("text.quote")  // phrase/collocation/pattern/未知
            }
        }
    }
}

