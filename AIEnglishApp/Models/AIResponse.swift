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

        switch type_ {
        case "s1":   card = .s1(try c.decode(VocabContent.self, forKey: .cardContent))
        case "s2":   card = .s2(try c.decode(GrammarContent.self, forKey: .cardContent))
        case "s3":   card = .s3(try c.decode(TranslationContent.self, forKey: .cardContent))
        case "s4":   card = .s4(try c.decode(SceneContent.self, forKey: .cardContent))
        case "chat": card = .chat(try c.decode(ChatContent.self, forKey: .cardContent))
        default:     card = .error(try c.decode(ErrorContent.self, forKey: .cardContent))
        }
    }
}

// MARK: - Card type discriminator
enum AICard {
    case s1(VocabContent)
    case s2(GrammarContent)
    case s3(TranslationContent)
    case s4(SceneContent)
    case chat(ChatContent)
    case error(ErrorContent)
}

// MARK: - s1 轻词典（英文单词/短语）
struct VocabContent: Decodable {
    let word: String
    let phonetic: String
    let pos: String
    let definition: String
    let examples: [BilingualExample]
    let sceneTrigger: String

    enum CodingKeys: String, CodingKey {
        case word, phonetic, pos, definition, examples
        case sceneTrigger = "scene_trigger"
    }
}

// MARK: - s2 句子分析（英文句子）
struct GrammarContent: Decodable {
    let chineseTranslation: String
    let grammarAnalysis: String?
    let nativePolish: String?
    let keyPhrase: KeyPhrase?
    let sceneTrigger: String

    enum CodingKeys: String, CodingKey {
        case chineseTranslation = "chinese_translation"
        case grammarAnalysis    = "grammar_analysis"
        case nativePolish       = "native_polish"
        case keyPhrase          = "key_phrase"
        case sceneTrigger       = "scene_trigger"
    }
}

// MARK: - s3 地道翻译（中文词/短语）
struct TranslationContent: Decodable {
    let chineseConcept: String
    let englishTranslation: String
    let phonetic: String
    let pos: String
    let example: BilingualExample
    let sceneTrigger: String

    enum CodingKeys: String, CodingKey {
        case chineseConcept      = "chinese_concept"
        case englishTranslation  = "english_translation"
        case phonetic, pos, example
        case sceneTrigger        = "scene_trigger"
    }
}

// MARK: - s4 场景手帐（中文句子）
struct SceneContent: Decodable {
    let chineseOriginal: String
    let nativeTranslation: String
    let keyPhrase: KeyPhrase?
    let sceneTrigger: String

    enum CodingKeys: String, CodingKey {
        case chineseOriginal   = "chinese_original"
        case nativeTranslation = "native_translation"
        case keyPhrase         = "key_phrase"
        case sceneTrigger      = "scene_trigger"
    }
}

// MARK: - chat 对话气泡
struct ChatContent: Decodable {
    let text: String
    let sceneConnection: String?

    enum CodingKeys: String, CodingKey {
        case text
        case sceneConnection = "scene_connection"
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

// MARK: - Shared sub-types
struct BilingualExample: Decodable {
    let en: String
    let zh: String
}

struct KeyPhrase: Decodable {
    let phrase: String
    let note: String
}
