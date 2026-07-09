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

/// 第一次抛错、之后成功——模拟"断网发送失败 → 恢复网络后重试成功"。
/// 用 class（引用语义）才能在多次 generate 调用间共享计数。
private final class FailOnceMock: AIServicing {
    private var callCount = 0
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, source: String?) async throws -> AIEnvelope {
        callCount += 1
        if callCount == 1 { throw URLError(.notConnectedToInternet) }
        let json = """
        {
            "card_type": "chat",
            "card_content": {"text": "Recovered", "scene_connection": null},
            "extracted_concept": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(AIEnvelope.self, from: json)
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

    // 断网/失败：保留用户气泡 + 产生可重试的 sendFailed（携带原始输入），不再是 aiError
    @Test func sendFailureKeepsBubbleAndProducesRetryableEntry() async {
        let vm = TodayViewModel(service: FailingMock())
        await vm.send("今天会议推迟了")

        // 用户气泡仍在
        let hasBubble = vm.entries.contains {
            if case .userBubble = $0.content { return true }
            return false
        }
        #expect(hasBubble)

        // 失败态是 sendFailed，且带着原始文本以便重发
        let failed = vm.entries.first {
            if case .sendFailed = $0.content { return true }
            return false
        }
        guard let failed, case .sendFailed(let text, let image) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        #expect(text == "今天会议推迟了")
        #expect(image == nil)
        #expect(vm.isLoading == false)
    }

    // 重试：移除失败提示、不新增用户气泡、成功后出现卡片
    @Test func retryAfterFailureReplacesWithCard() async {
        let vm = TodayViewModel(service: FailOnceMock())
        await vm.send("今天会议推迟了")

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image) = failed.content else {
            Issue.record("Expected sendFailed entry after first send"); return
        }

        let bubbleCountBefore = vm.entries.filter {
            if case .userBubble = $0.content { return true }
            return false
        }.count

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id)

        // 失败提示已移除
        let stillFailed = vm.entries.contains {
            if case .sendFailed = $0.content { return true }
            return false
        }
        #expect(stillFailed == false)

        // 出现卡片
        let hasCard = vm.entries.contains {
            if case .aiCard = $0.content { return true }
            return false
        }
        #expect(hasCard)

        // 用户气泡数量不变（重试不重复气泡）
        let bubbleCountAfter = vm.entries.filter {
            if case .userBubble = $0.content { return true }
            return false
        }.count
        #expect(bubbleCountAfter == bubbleCountBefore)
    }

    @Test func sendIgnoresBlankInput() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("   ")
        #expect(vm.entries.isEmpty)
    }
}

// MARK: - Onboarding gate three-state parsing tests

struct OnboardingStateParsingTests {

    // 有行且有完成时间 → completed（同机重装的老用户直接进主界面）
    @Test func rowWithDateMeansCompleted() {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let state = ProfileService.parseOnboardingState(completedDates: [date])
        #expect(state == .completed(date))
    }

    // 有行但完成时间为空 → notCompleted（唯一允许进引导的情况）
    @Test func rowWithNilDateMeansNotCompleted() {
        let state = ProfileService.parseOnboardingState(completedDates: [nil])
        #expect(state == .notCompleted)
    }

    // 查不到行 → missingProfile（数据缺失 ≠ 没走过引导，与 notCompleted 严格区分）
    @Test func emptyRowsMeansMissingProfile() {
        let state = ProfileService.parseOnboardingState(completedDates: [])
        #expect(state == .missingProfile)
    }
}

// MARK: - LocalCache tombstone tests

struct LocalCacheTombstoneTests {

    // 加墓碑 → 读缓存时该 ID 被过滤（不再出现）
    @Test func tombstonedIdIsFilteredFromCache() {
        let id = UUID()
        LocalCache.shared.addTombstone(id, key: .scenes)
        let tombstones = LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString))
        LocalCache.shared.removeTombstone(id, key: .scenes)
    }

    // 撤销：移除墓碑后 ID 重新出现
    @Test func removeTombstoneRestoresVisibility() {
        let id = UUID()
        LocalCache.shared.addTombstone(id, key: .scenes)
        LocalCache.shared.removeTombstone(id, key: .scenes)
        let tombstones = LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString) == false)
    }

    // 成功拉取服务器后清空墓碑（服务器为正本，已不含被删条目）
    @Test func clearTombstonesEmptiesAll() {
        let id1 = UUID()
        let id2 = UUID()
        LocalCache.shared.addTombstone(id1, key: .vocabs)
        LocalCache.shared.addTombstone(id2, key: .vocabs)
        LocalCache.shared.clearTombstones(for: .vocabs)
        let tombstones = LocalCache.shared.tombstones(for: .vocabs)
        #expect(tombstones.isEmpty)
    }

    // scenes 和 vocabs 各自独立（不互相污染）
    @Test func tombstonesAreScopedPerKey() {
        let id = UUID()
        LocalCache.shared.addTombstone(id, key: .scenes)
        let vocabTombstones = LocalCache.shared.tombstones(for: .vocabs)
        #expect(vocabTombstones.contains(id.uuidString) == false)
        LocalCache.shared.removeTombstone(id, key: .scenes)
    }
}

// MARK: - LocalCache tests

struct LocalCacheTests {

    @Test func saveThenLoadRoundTrips() {
        let payload = #"[{"hello":"world"}]"#.data(using: .utf8)!
        LocalCache.shared.save(payload, key: .vocabs)
        let loaded = LocalCache.shared.load(key: .vocabs)
        #expect(loaded == payload)
        LocalCache.shared.remove(key: .vocabs)   // 清理，避免污染其它用例
    }

    @Test func removeThenLoadReturnsNil() {
        let payload = #"{"x":1}"#.data(using: .utf8)!
        LocalCache.shared.save(payload, key: .scenes)
        LocalCache.shared.remove(key: .scenes)
        #expect(LocalCache.shared.load(key: .scenes) == nil)
    }

    @Test func saveOverwritesPrevious() {
        LocalCache.shared.save("old".data(using: .utf8)!, key: .messages)
        LocalCache.shared.save("new".data(using: .utf8)!, key: .messages)
        let loaded = LocalCache.shared.load(key: .messages)
        #expect(loaded == "new".data(using: .utf8)!)
        LocalCache.shared.remove(key: .messages)
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
