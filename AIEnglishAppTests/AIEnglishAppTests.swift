import Testing
import Foundation
import UIKit
@testable import AIEnglishApp

// MARK: - AIEnvelope JSON decode tests

struct AIEnvelopeDecodeTests {

    @Test func decodesS1VocabCard() throws {
        let json = """
        {
            "card_type": "s1",
            "card_content": {
                "word": "overtime",
                "phonetic": "/ˈoʊvərtaɪm/",
                "pos": "n.",
                "definition": "加班",
                "examples": [{"en": "I work overtime tonight.", "zh": "我今晚加班。"}],
                "scene_trigger": "Does this happen often?"
            },
            "extracted_concept": "overtime"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .s1(let c) = envelope.card else {
            Issue.record("Expected .s1 card"); return
        }
        #expect(c.word == "overtime")
        #expect(c.phonetic == "/ˈoʊvərtaɪm/")
        #expect(c.pos == "n.")
        #expect(c.definition == "加班")
        #expect(c.examples.count == 1)
        #expect(c.examples[0].en == "I work overtime tonight.")
        #expect(c.sceneTrigger == "Does this happen often?")
        #expect(envelope.extractedConcept == "overtime")
    }

    @Test func decodesS2GrammarCard() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "chinese_translation": "我今晚又要加班了。",
                "grammar_analysis": "注意 have to 表示外力强迫。",
                "native_polish": null,
                "key_phrase": {"phrase": "have to", "note": "比 must 更口语"},
                "scene_trigger": "Is this a pattern?"
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .s2(let c) = envelope.card else {
            Issue.record("Expected .s2 card"); return
        }
        #expect(c.chineseTranslation == "我今晚又要加班了。")
        #expect(c.grammarAnalysis == "注意 have to 表示外力强迫。")
        #expect(c.nativePolish == nil)
        #expect(c.keyPhrase?.phrase == "have to")
        #expect(c.keyPhrase?.note == "比 must 更口语")
        #expect(envelope.extractedConcept == nil)
    }

    @Test func decodesS3TranslationCard() throws {
        let json = """
        {
            "card_type": "s3",
            "card_content": {
                "chinese_concept": "摸鱼",
                "english_translation": "slack off",
                "phonetic": "/slæk ɔːf/",
                "pos": "v.",
                "example": {"en": "I've been slacking off all day.", "zh": "我摸了一天鱼。"},
                "scene_trigger": "What were you supposed to be doing?"
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .s3(let c) = envelope.card else {
            Issue.record("Expected .s3 card"); return
        }
        #expect(c.chineseConcept == "摸鱼")
        #expect(c.englishTranslation == "slack off")
        #expect(c.example.en == "I've been slacking off all day.")
        #expect(c.example.zh == "我摸了一天鱼。")
    }

    @Test func decodesS4SceneCard() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "chinese_original": "今天地铁挤死了。",
                "native_translation": "The subway was absolutely packed this morning.",
                "key_phrase": {"phrase": "absolutely packed", "note": "比 very crowded 更有力"},
                "scene_trigger": "Is this your daily commute?"
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .s4(let c) = envelope.card else {
            Issue.record("Expected .s4 card"); return
        }
        #expect(c.chineseOriginal == "今天地铁挤死了。")
        #expect(c.nativeTranslation == "The subway was absolutely packed this morning.")
        #expect(c.keyPhrase?.phrase == "absolutely packed")
        #expect(c.keyPhrase?.note == "比 very crowded 更有力")
    }

    @Test func decodesChatCard() throws {
        let json = """
        {
            "card_type": "chat",
            "card_content": {
                "text": "Great question! Would and could are both modal verbs...",
                "scene_connection": null
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .chat(let c) = envelope.card else {
            Issue.record("Expected .chat card"); return
        }
        #expect(c.text == "Great question! Would and could are both modal verbs...")
        #expect(c.sceneConnection == nil)
    }

    @Test func decodesS2WithNullOptionals() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "chinese_translation": "她很开心。",
                "grammar_analysis": null,
                "native_polish": null,
                "key_phrase": null,
                "scene_trigger": "What made her happy?"
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .s2(let c) = envelope.card else {
            Issue.record("Expected .s2 card"); return
        }
        #expect(c.grammarAnalysis == nil)
        #expect(c.nativePolish == nil)
        #expect(c.keyPhrase == nil)
    }
}

// MARK: - Mocks

private struct SuccessMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, source: String?) async throws -> AIEnvelope {
        let json = """
        {
            "card_type": "chat",
            "card_content": {"text": "Test response", "scene_connection": null},
            "extracted_concept": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(AIEnvelope.self, from: json)
    }
}

private struct FailingMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, source: String?) async throws -> AIEnvelope {
        throw URLError(.badServerResponse)
    }
}

// MARK: - TodayViewModel tests

struct TodayViewModelTests {

    @Test func sendAppendsUserBubbleAndAICard() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("今天会议推迟了")

        let bubbleEntry = vm.entries.first {
            if case .userBubble = $0.content { return true }
            return false
        }
        guard let bubbleEntry,
              case .userBubble(let text, _, _, _) = bubbleEntry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "今天会议推迟了")

        let hasCard = vm.entries.contains {
            if case .aiCard = $0.content { return true }
            return false
        }
        #expect(hasCard)
        #expect(vm.isLoading == false)
    }

    @Test func sendAppendsErrorEntryOnFailure() async {
        let vm = TodayViewModel(service: FailingMock())
        await vm.send("今天会议推迟了")

        let hasError = vm.entries.contains {
            if case .aiError = $0.content { return true }
            return false
        }
        #expect(hasError)
        #expect(vm.isLoading == false)
    }

    @Test func sendIgnoresBlankInput() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("   ")
        #expect(vm.entries.isEmpty)
    }
}

// MARK: - ImageCache tests

struct ImageCacheTests {

    @Test func getUnknownKeyReturnsNil() {
        #expect(ImageCache.shared.get("no_such_key_\(UUID().uuidString)") == nil)
    }

    @Test func setThenGetHitsMemory() {
        let key = "mem_\(UUID().uuidString)"
        let image = UIImage(systemName: "star")!
        ImageCache.shared.set(image, forKey: key)
        #expect(ImageCache.shared.get(key) != nil)
    }

    @Test func setThenGetFromDiskAfterMemoryClear() {
        let key = "disk_\(UUID().uuidString)"
        let image = UIImage(systemName: "heart")!
        ImageCache.shared.set(image, forKey: key)
        ImageCache.shared.clearMemoryForTesting()
        // 内存已清，必须从磁盘读
        #expect(ImageCache.shared.get(key) != nil)
    }
}

// MARK: - MessageRecord image field propagation tests

struct MessageRecordImageFieldsTests {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let str = try c.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(str)")
        }
        return d
    }()

    @Test func imageRecordPassesBothUrlsToTimelineEntry() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "role": "user",
            "input_type": "image",
            "user_content": "[photo]",
            "signed_image_url": "https://example.com/signed?token=abc",
            "image_url": "user_images/uid123/photo.jpg",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        #expect(record.imagePath == "user_images/uid123/photo.jpg")
        #expect(record.signedImageUrl == "https://example.com/signed?token=abc")

        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, let imageUrl, let stableKey) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Describe this image")
        #expect(imageUrl == "https://example.com/signed?token=abc")
        #expect(stableKey == "user_images/uid123/photo.jpg")
    }

    @Test func textRecordHasNilImageFields() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "role": "user",
            "input_type": "text",
            "user_content": "Hello world",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        #expect(record.imagePath == nil)
        #expect(record.signedImageUrl == nil)

        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, let imageUrl, let stableKey) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Hello world")
        #expect(imageUrl == nil)
        #expect(stableKey == nil)
    }

    @Test func presetCardDefaultsToDescribeThisImage() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "role": "user",
            "input_type": "preset_card",
            "user_content": "[photo]",
            "signed_image_url": "https://example.com/signed?token=xyz",
            "image_url": "user_images/uid123/card.jpg",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, _, _) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Describe this image")
    }
}
