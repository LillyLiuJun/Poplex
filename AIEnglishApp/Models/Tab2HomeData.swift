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

/// 单个分类的数据，含活动清单。
struct Tab2CategoryData: Decodable, Identifiable {
    let sceneCategory: String   // 数据库枚举值（英文 key，同 SceneCategory rawValue；旧中文值由 SceneCategory.from(_:) 兼容映射）
    let wordCount: Int
    let unlocked: Bool
    let notSpokenCount: Int     // 没说过（spoken_count = 0）的词条数
    let lastTalkedAt: Date?     // 最后一次用户开口时间；null = 从未开口
    let lastMaterialAt: Date?   // 最后一次存入素材的时间；null = 从未存入（刀 4b）
    let newMaterialCount: Int   // 本地「今天」新存的不同素材数，服务端按客户端日界计算（刀 4b）
    let activityCount: Int      // 全量活动数（不受 activities 截断影响）
    let activities: [Tab2Activity]

    var id: String { sceneCategory }

    /// 英文 UI 标签（通过 SceneCategoryMap 转换）
    var englishLabel: String {
        SceneCategory.from(sceneCategory).englishLabel
    }

    enum CodingKeys: String, CodingKey {
        case sceneCategory  = "scene_category"
        case wordCount      = "word_count"
        case unlocked
        case notSpokenCount = "not_spoken_count"
        case lastTalkedAt   = "last_talked_at"
        case lastMaterialAt = "last_material_at"
        case newMaterialCount = "new_material_count"
        case activityCount  = "activity_count"
        case activities
    }

    init(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        notSpokenCount: Int = 0,
        lastTalkedAt: Date? = nil,
        lastMaterialAt: Date? = nil,
        newMaterialCount: Int = 0,
        activityCount: Int = 0,
        activities: [Tab2Activity] = []
    ) {
        self.sceneCategory = sceneCategory
        self.wordCount = wordCount
        self.unlocked = unlocked
        self.notSpokenCount = notSpokenCount
        self.lastTalkedAt = lastTalkedAt
        self.lastMaterialAt = lastMaterialAt
        self.newMaterialCount = newMaterialCount
        self.activityCount = activityCount
        self.activities = activities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sceneCategory  = try c.decode(String.self, forKey: .sceneCategory)
        wordCount      = try c.decode(Int.self,    forKey: .wordCount)
        unlocked       = try c.decode(Bool.self,   forKey: .unlocked)
        notSpokenCount = try c.decodeIfPresent(Int.self,        forKey: .notSpokenCount) ?? 0
        activityCount  = try c.decodeIfPresent(Int.self,        forKey: .activityCount)  ?? 0
        activities     = try c.decodeIfPresent([Tab2Activity].self, forKey: .activities) ?? []

        // 后端时间字段带毫秒小数（如 "2026-07-25T10:00:00.000Z"），
        // 标准 ISO8601DateFormatter 默认不认 → 走共享的双格式解析（Tab2ISO8601）。
        if let raw = try c.decodeIfPresent(String.self, forKey: .lastTalkedAt) {
            lastTalkedAt = Tab2ISO8601.parse(raw)
        } else {
            lastTalkedAt = nil
        }

        if let raw = try c.decodeIfPresent(String.self, forKey: .lastMaterialAt) {
            lastMaterialAt = Tab2ISO8601.parse(raw)
        } else {
            lastMaterialAt = nil
        }
        newMaterialCount = try c.decodeIfPresent(Int.self, forKey: .newMaterialCount) ?? 0
    }
}

// MARK: - 共享时间解析

/// 双格式 ISO8601 解析：先按带毫秒格式解析，失败再退回无毫秒格式。
enum Tab2ISO8601 {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}

// MARK: - 活动（旧称 sub_scene）

/// 活动——一个反复出现的日常场景。
struct Tab2Activity: Decodable, Identifiable {
    let sceneDetail: String
    let occurrenceCount: Int
    let cover: Cover?            // 该活动最新一张带图素材；无图素材为 null（客户端走预设图）

    var id: String { sceneDetail }

    /// 活动封面——对应后端 cover 对象。
    /// Equatable：给 Tab2ActivityCapsuleGroup 的 .equatable() 用，判断 activities
    /// 真的没变时跳过重渲染（跳过 Tab2CapsuleFit.fit 的 CoreText 测量）。
    struct Cover: Decodable, Equatable {
        let materialId: String
        // Storage 签名失败时 get-tab2-home 会把这个字段单独置 null（cover 对象本身仍存在，
        // 详见该函数 signImagePaths 的注释）；必须是可选，否则那一条签名失败会让整页解码失败。
        let imageUrl: String?

        enum CodingKeys: String, CodingKey {
            case materialId = "material_id"
            case imageUrl   = "image_url"
        }

        // 剥掉签名参数，取路径部分作缓存 key（签名 URL 每次重签会变，路径不变）
        var stableImageKey: String? {
            guard let imageUrl, !imageUrl.isEmpty else { return nil }
            return imageUrl.components(separatedBy: "?").first
        }

        init(materialId: String, imageUrl: String?) {
            self.materialId = materialId
            self.imageUrl = imageUrl
        }
    }

    enum CodingKeys: String, CodingKey {
        case sceneDetail      = "scene_detail"
        case occurrenceCount  = "occurrence_count"
        case cover
    }

    init(sceneDetail: String, occurrenceCount: Int, cover: Cover? = nil) {
        self.sceneDetail = sceneDetail
        self.occurrenceCount = occurrenceCount
        self.cover = cover
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

enum Tab2BadgeGlyph: Equatable, Hashable {
    case symbol(String)       // SF Symbol 描边图标
    case quoteBlock           // 地道引语垂直树线 (专供习语/俚语)
}

// MARK: - Badge & image helpers (internal for testability)

extension Tab2WordEntry {
    /// 图片缓存 key：去掉签名 URL 的查询参数，路径不变，磁盘缓存跨 session 可命中。
    var stableImageKey: String? {
        guard let urlStr = imageUrl, !urlStr.isEmpty else { return nil }
        return urlStr.components(separatedBy: "?").first
    }

    /// 词条类型图标（统一细线家族）。按捕获方式优先，再按表达类型细分：
    ///   · 查词（.word）→ magnifyingglass 放大镜；对话（.dialogue，未上线）→ waveform 声波
    ///   · 句子/段落里的单词 → book.closed 纯净极简小书本
    ///   · 习语/俚语 → quoteBlock 垂直引语线
    ///   · 短语/搭配/句型 → link 词语双环搭扣
    /// 图片走 imageUrl，不经此。
    var badgeGlyph: Tab2BadgeGlyph {
        switch sourceTag {
        case .word:     return .symbol("magnifyingglass")
        case .dialogue: return .symbol("waveform")
        case .sentence, .passage:
            switch entryKind {
            case "word":            return .symbol("book.closed")
            case "idiom", "slang":  return .quoteBlock
            default:                return .symbol("link")
            }
        }
    }
}
