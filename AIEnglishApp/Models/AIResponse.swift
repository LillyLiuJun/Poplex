import Foundation

// MARK: - Top-level envelope from Edge Function
struct AIEnvelope: Decodable {
    let card: AICard
    let extractedConcept: String?

    enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
        case cardContent = "card_content"
        case extractedConcept = "extracted_concept"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try c.decode(String.self, forKey: .cardType)
        extractedConcept = try c.decodeIfPresent(String.self, forKey: .extractedConcept)

        // s1–s6 六种卡型统一解码为一个 CardContent（由 granularity/direction 驱动显隐）。
        // card_type 仍作 error 判别符保留。
        switch type_ {
        case "s1", "s2", "s3", "s4", "s5", "s6", "card":
            card = .card(try c.decode(CardContent.self, forKey: .cardContent))
        default:
            card = .error(try c.decode(ErrorContent.self, forKey: .cardContent))
        }
    }
}

// MARK: - Card type discriminator
enum AICard {
    case card(CardContent)      // 统一学习卡（word/sentence × comprehend/express）
    case error(ErrorContent)
}

// MARK: - 统一学习卡内容（一套字段，按两个维度取用）
struct CardContent: Decodable {
    let granularity: String          // "word" | "sentence" | "passage"
    let direction: String            // "comprehend" | "express"
    let revisionType: String?        // "error" | "polish" | nil（仅 sentence+comprehend 有意义）
    let learnableUnits: [LearnableUnit]

    let userOriginal: String?        // 用户原样输入；纯场景图为 nil
    let userOriginalLang: String?    // "target" | 具体语言码
    let targetExpression: String?    // AI 产出的目标语言表达；sentence+comp 原句无误时为 nil
    let nativeMeaning: String?       // 对 (targetExpression ?? userOriginal) 的母语释义/译文
    let phonetic: String?            // 仅 word
    let pos: [String]                // 仅 word，最多 3
    let examples: [BilingualExample]
    let grammarNote: String?         // word 讲形式 / sentence 讲语法 / passage 可选
    let passageLines: [PassageLine]  // 仅 passage (s5/s6)，逐行双语对照

    enum CodingKeys: String, CodingKey {
        case granularity, direction, phonetic, pos, examples
        case revisionType      = "revision_type"
        case learnableUnits    = "learnable_units"
        case userOriginal      = "user_original"
        case userOriginalLang  = "user_original_lang"
        case targetExpression  = "target_expression"
        case nativeMeaning     = "native_meaning"
        case grammarNote       = "grammar_note"
        case passageLines      = "passage_lines"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        granularity      = (try? c.decode(String.self, forKey: .granularity)) ?? "sentence"
        direction        = (try? c.decode(String.self, forKey: .direction)) ?? "express"
        revisionType     = try c.decodeIfPresent(String.self, forKey: .revisionType)
        learnableUnits   = (try? c.decode([LearnableUnit].self, forKey: .learnableUnits)) ?? []
        userOriginal     = try c.decodeIfPresent(String.self, forKey: .userOriginal)
        userOriginalLang = try c.decodeIfPresent(String.self, forKey: .userOriginalLang)
        targetExpression = try c.decodeIfPresent(String.self, forKey: .targetExpression)
        nativeMeaning    = try c.decodeIfPresent(String.self, forKey: .nativeMeaning)
        phonetic         = try c.decodeIfPresent(String.self, forKey: .phonetic)
        pos              = (try? c.decode([String].self, forKey: .pos)) ?? []
        examples         = (try? c.decode([BilingualExample].self, forKey: .examples)) ?? []
        grammarNote      = try c.decodeIfPresent(String.self, forKey: .grammarNote)
        passageLines     = (try? c.decode([PassageLine].self, forKey: .passageLines)) ?? []
    }

    init(
        granularity: String = "sentence",
        direction: String = "express",
        revisionType: String? = nil,
        learnableUnits: [LearnableUnit] = [],
        userOriginal: String? = nil,
        userOriginalLang: String? = nil,
        targetExpression: String? = nil,
        nativeMeaning: String? = nil,
        phonetic: String? = nil,
        pos: [String] = [],
        examples: [BilingualExample] = [],
        grammarNote: String? = nil,
        passageLines: [PassageLine] = []
    ) {
        self.granularity = granularity
        self.direction = direction
        self.revisionType = revisionType
        self.learnableUnits = learnableUnits
        self.userOriginal = userOriginal
        self.userOriginalLang = userOriginalLang
        self.targetExpression = targetExpression
        self.nativeMeaning = nativeMeaning
        self.phonetic = phonetic
        self.pos = pos
        self.examples = examples
        self.grammarNote = grammarNote
        self.passageLines = passageLines
    }

    // MARK: Derived
    var isWord: Bool { granularity == "word" }
    var isPassage: Bool { granularity == "passage" }
    var isComprehend: Bool { direction == "comprehend" }

    /// 卡片主推的目标语言表达（下游统一用这条规则，不分卡型）。
    var displayTarget: String { targetExpression ?? userOriginal ?? "" }

    /// 卡片主推的可学单元（高亮那个）。
    var primaryUnit: LearnableUnit? {
        learnableUnits.first(where: { $0.isPrimary }) ?? learnableUnits.first
    }
}

// MARK: - error 安全/无效拦截
struct ErrorContent: Decodable {
    let errorType: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case errorType = "error_type"
        case message
    }
}

// MARK: - AICard helpers
extension AICard {
    var cardTypeName: String {
        switch self {
        case .card:  return "card"
        case .error: return "error"
        }
    }

    // Re-encodes the typed card back to [String: Any] so it can be sent as
    // raw JSON context in the next generate request (multi-turn design).
    var contextRepresentation: [String: Any] {
        switch self {
        case .card(let c):
            var d: [String: Any] = [
                "granularity": c.granularity,
                "direction": c.direction,
                "learnable_units": c.learnableUnits.map {
                    ["form": $0.form, "kind": $0.kind, "note": $0.note, "is_primary": $0.isPrimary]
                },
                "examples": c.examples.map { ["en": $0.en, "zh": $0.zh] },
                "pos": c.pos,
            ]
            if let v = c.revisionType     { d["revision_type"] = v }
            if let v = c.userOriginal     { d["user_original"] = v }
            if let v = c.userOriginalLang { d["user_original_lang"] = v }
            if let v = c.targetExpression { d["target_expression"] = v }
            if let v = c.nativeMeaning    { d["native_meaning"] = v }
            if let v = c.phonetic         { d["phonetic"] = v }
            if let v = c.grammarNote      { d["grammar_note"] = v }
            if !c.passageLines.isEmpty {
                d["passage_lines"] = c.passageLines.map { ["en": $0.en, "zh": $0.zh] }
            }
            return d
        case .error(let c):
            return ["error_type": c.errorType, "message": c.message]
        }
    }

    /// The primary target-language expression to display (e.g. on Screen 5 or TTS).
    var primaryEnglish: String {
        switch self {
        case .card(let c):  return c.displayTarget
        case .error(let c): return c.message
        }
    }

    /// The native-language translation to display if available.
    var nativeMeaning: String? {
        switch self {
        case .card(let c):  return c.nativeMeaning
        case .error:        return nil
        }
    }
}

// MARK: - Shared sub-types
struct BilingualExample: Decodable {
    let en: String
    let zh: String
}

struct PassageLine: Decodable {
    let en: String
    let zh: String
}

struct LearnableUnit: Decodable {
    let form: String
    let kind: String
    let note: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case form, kind, note
        case isPrimary = "is_primary"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        form      = (try? c.decode(String.self, forKey: .form)) ?? ""
        kind      = (try? c.decode(String.self, forKey: .kind)) ?? "word"
        note      = (try? c.decode(String.self, forKey: .note)) ?? ""
        isPrimary = (try? c.decode(Bool.self, forKey: .isPrimary)) ?? false
    }
}
