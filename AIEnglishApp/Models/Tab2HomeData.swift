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
    let previewWords: [Tab2PreviewWord]
    // 第 2 刀新增字段（§9.2）；旧客户端收不到时退化为 nil/0
    let momentCount: Int
    let featured: Tab2FeaturedMoment?
    let heroPhotos: [Tab2HeroPhoto]

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
        case momentCount    = "moment_count"
        case featured
        case heroPhotos     = "hero_photos"
    }

    init(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        lastMaterialAt: Date? = nil,
        subScenes: [Tab2SubScene] = [],
        previewWords: [Tab2PreviewWord] = [],
        momentCount: Int = 0,
        featured: Tab2FeaturedMoment? = nil,
        heroPhotos: [Tab2HeroPhoto] = []
    ) {
        self.sceneCategory = sceneCategory
        self.wordCount = wordCount
        self.unlocked = unlocked
        self.lastMaterialAt = lastMaterialAt
        self.subScenes = subScenes
        self.previewWords = previewWords
        self.momentCount = momentCount
        self.featured = featured
        self.heroPhotos = heroPhotos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sceneCategory  = try c.decode(String.self,   forKey: .sceneCategory)
        wordCount      = try c.decode(Int.self,       forKey: .wordCount)
        unlocked       = try c.decode(Bool.self,      forKey: .unlocked)
        subScenes      = try c.decodeIfPresent([Tab2SubScene].self,      forKey: .subScenes)   ?? []
        if let words = try? c.decode([Tab2PreviewWord].self, forKey: .previewWords) {
            previewWords = words
        } else if let legacyWords = try? c.decode([String].self, forKey: .previewWords) {
            previewWords = legacyWords.map { Tab2PreviewWord(lemma: $0) }
        } else {
            previewWords = []
        }
        momentCount    = try c.decodeIfPresent(Int.self,                 forKey: .momentCount)  ?? 0
        featured       = try c.decodeIfPresent(Tab2FeaturedMoment.self,  forKey: .featured)
        heroPhotos     = try c.decodeIfPresent([Tab2HeroPhoto].self,     forKey: .heroPhotos)   ?? []

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

/// Hero 卡预览词——对应 get_tab2_home 的 preview_words 行。
struct Tab2PreviewWord: Decodable {
    let lemma: String
    let displayForm: String?
    let pos: String?
    let nativeMeaning: String?

    enum CodingKeys: String, CodingKey {
        case lemma
        case displayForm = "display_form"
        case pos
        case nativeMeaning = "native_meaning"
    }

    init(
        lemma: String,
        displayForm: String? = nil,
        pos: String? = nil,
        nativeMeaning: String? = nil
    ) {
        self.lemma = lemma
        self.displayForm = displayForm
        self.pos = pos
        self.nativeMeaning = nativeMeaning
    }
}

// MARK: - 第 2 刀新增模型（§9.2）

/// 被选中展示在底部的 featured moment（§3、§9.1）。
struct Tab2FeaturedMoment: Decodable {
    let sceneDetail: String
    let occurrenceCount: Int
    let materialId: String
    let userOriginal: String?
    let targetExpression: String?
    let nativeMeaning: String?
    let imageUrl: String?
    let inputLang: String?
    let sourceDirection: String?
    let sourceGranularity: String?
    let createdAt: Date?
    let spokenCount: Int

    // 剥掉签名参数，取路径部分作缓存 key
    var stableImageKey: String? {
        guard let url = imageUrl, !url.isEmpty else { return nil }
        return url.components(separatedBy: "?").first
    }

    enum CodingKeys: String, CodingKey {
        case sceneDetail       = "scene_detail"
        case occurrenceCount   = "occurrence_count"
        case materialId        = "material_id"
        case userOriginal      = "user_original"
        case targetExpression  = "target_expression"
        case nativeMeaning     = "native_meaning"
        case imageUrl          = "image_url"
        case inputLang         = "input_lang"
        case sourceDirection   = "source_direction"
        case sourceGranularity = "source_granularity"
        case createdAt         = "created_at"
        case spokenCount       = "spoken_count"
    }

    init(
        sceneDetail: String, occurrenceCount: Int, materialId: String,
        userOriginal: String?, targetExpression: String?, nativeMeaning: String?,
        imageUrl: String?, inputLang: String?, sourceDirection: String?,
        sourceGranularity: String?, createdAt: Date?, spokenCount: Int
    ) {
        self.sceneDetail = sceneDetail
        self.occurrenceCount = occurrenceCount
        self.materialId = materialId
        self.userOriginal = userOriginal
        self.targetExpression = targetExpression
        self.nativeMeaning = nativeMeaning
        self.imageUrl = imageUrl
        self.inputLang = inputLang
        self.sourceDirection = sourceDirection
        self.sourceGranularity = sourceGranularity
        self.createdAt = createdAt
        self.spokenCount = spokenCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sceneDetail       = try c.decode(String.self, forKey: .sceneDetail)
        occurrenceCount   = try c.decode(Int.self,    forKey: .occurrenceCount)
        materialId        = try c.decode(String.self, forKey: .materialId)
        userOriginal      = try c.decodeIfPresent(String.self, forKey: .userOriginal)
        targetExpression  = try c.decodeIfPresent(String.self, forKey: .targetExpression)
        nativeMeaning     = try c.decodeIfPresent(String.self, forKey: .nativeMeaning)
        imageUrl          = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        inputLang         = try c.decodeIfPresent(String.self, forKey: .inputLang)
        sourceDirection   = try c.decodeIfPresent(String.self, forKey: .sourceDirection)
        sourceGranularity = try c.decodeIfPresent(String.self, forKey: .sourceGranularity)
        spokenCount       = try c.decodeIfPresent(Int.self,    forKey: .spokenCount) ?? 0
        // fractional-seconds 双格式兜底（同 Tab2CategoryData.lastMaterialAt）
        if let raw = try c.decodeIfPresent(String.self, forKey: .createdAt) {
            let fmtMs = ISO8601DateFormatter()
            fmtMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = fmtMs.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        } else {
            createdAt = nil
        }
    }
}

/// 顶部拼图照片中的单张（§6.2）。
struct Tab2HeroPhoto: Decodable, Identifiable {
    let materialId: String
    let imageUrl: String
    let isFeatured: Bool

    var id: String { materialId }

    var stableImageKey: String? {
        imageUrl.components(separatedBy: "?").first
    }

    enum CodingKeys: String, CodingKey {
        case materialId  = "material_id"
        case imageUrl    = "image_url"
        case isFeatured  = "is_featured"
    }
}

// MARK: -

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
