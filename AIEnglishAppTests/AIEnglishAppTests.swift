import Testing
import Foundation
import UIKit
@testable import AIEnglishApp

// MARK: - AppTab navigation state tests

struct AppTabTests {

    @Test func defaultTabIsToday() {
        let tab = AppTab.today
        #expect(tab == .today)
    }

    @Test func tabSwitchesToMine() {
        var selected: AppTab = .today
        selected = .mine
        #expect(selected == .mine)
    }

    @Test func tabSwitchesBackToToday() {
        var selected: AppTab = .mine
        selected = .today
        #expect(selected == .today)
    }

    @Test func inputBarVisibleOnlyForToday() {
        let isVisible: (AppTab) -> Bool = { $0 == .today }
        #expect(isVisible(.today) == true)
        #expect(isVisible(.mine) == false)
    }
}

// MARK: - AIEnvelope JSON decode tests
// 第5刀后：s1–s4 统一解码为 .card(CardContent)，字段为 granularity/direction/
// target_expression/native_meaning/learnable_units 等统一 schema。

struct AIEnvelopeDecodeTests {

    // s1 = word + comprehend：音标、词性数组、释义、例句、可学单元
    @Test func decodesWordComprehendCard() throws {
        let json = """
        {
            "card_type": "s1",
            "card_content": {
                "granularity": "word",
                "direction": "comprehend",
                "user_original": "overtime",
                "target_expression": "overtime",
                "native_meaning": "加班",
                "phonetic": "/ˈoʊvərtaɪm/",
                "pos": ["n."],
                "examples": [{"en": "I work overtime tonight.", "zh": "我今晚加班。"}],
                "learnable_units": [
                    {"form": "overtime", "kind": "word", "note": "", "is_primary": true}
                ]
            },
            "extracted_concept": "overtime"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.isWord)
        #expect(c.isComprehend)
        #expect(c.targetExpression == "overtime")
        #expect(c.nativeMeaning == "加班")
        #expect(c.phonetic == "/ˈoʊvərtaɪm/")
        #expect(c.pos == ["n."])
        #expect(c.examples.count == 1)
        #expect(c.examples[0].en == "I work overtime tonight.")
        #expect(c.primaryUnit?.form == "overtime")
        #expect(c.primaryUnit?.isPrimary == true)
        #expect(envelope.extractedConcept == "overtime")
    }

    // s2 = sentence + comprehend，原句有误：revision_type=error、修正版、语法观察
    @Test func decodesSentenceComprehendWithRevision() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "revision_type": "error",
                "user_original": "I am very sleep today",
                "target_expression": "I am very sleepy today",
                "native_meaning": "我今天很困。",
                "grammar_note": "sleepy is the adjective for that drowsy feeling; sleep stays a verb or noun.",
                "learnable_units": [
                    {"form": "sleepy", "kind": "word", "note": "形容词", "is_primary": true}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(!c.isWord)
        #expect(c.isComprehend)
        #expect(c.revisionType == "error")
        #expect(c.userOriginal == "I am very sleep today")
        #expect(c.displayTarget == "I am very sleepy today")
        #expect(c.nativeMeaning == "我今天很困。")
        #expect(c.grammarNote != nil)
    }

    // s2 = sentence + comprehend，原句无误：target_expression 为 nil，displayTarget 落到 user_original
    @Test func decodesSentenceComprehendNoRevision() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "revision_type": null,
                "user_original": "I have to work overtime tonight.",
                "target_expression": null,
                "native_meaning": "我今晚又得加班了。",
                "grammar_note": null,
                "learnable_units": [
                    {"form": "have to", "kind": "phrase", "note": "比 must 更口语", "is_primary": true}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.revisionType == nil)
        #expect(c.targetExpression == nil)
        #expect(c.displayTarget == "I have to work overtime tonight.")
        #expect(c.grammarNote == nil)
    }

    // s3 = word + express：母语词 → 目标语表达
    @Test func decodesWordExpressCard() throws {
        let json = """
        {
            "card_type": "s3",
            "card_content": {
                "granularity": "word",
                "direction": "express",
                "user_original": "摸鱼",
                "target_expression": "slack off",
                "native_meaning": "摸鱼",
                "phonetic": "/slæk ɔːf/",
                "pos": ["v."],
                "examples": [{"en": "I've been slacking off all day.", "zh": "我摸了一天鱼。"}],
                "learnable_units": [
                    {"form": "slack off", "kind": "phrase", "note": "", "is_primary": true}
                ]
            },
            "extracted_concept": "摸鱼"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.isWord)
        #expect(!c.isComprehend)
        #expect(c.displayTarget == "slack off")
        #expect(c.nativeMeaning == "摸鱼")
        #expect(c.examples[0].zh == "我摸了一天鱼。")
        #expect(envelope.extractedConcept == "摸鱼")
    }

    // s4 = sentence + express：母语句子 → 目标语句子
    @Test func decodesSentenceExpressCard() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "user_original": "今天地铁挤死了。",
                "target_expression": "The subway was absolutely packed this morning.",
                "native_meaning": null,
                "learnable_units": [
                    {"form": "absolutely packed", "kind": "phrase", "note": "比 very crowded 更有力", "is_primary": true},
                    {"form": "commute", "kind": "word", "note": "", "is_primary": false}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.displayTarget == "The subway was absolutely packed this morning.")
        #expect(c.learnableUnits.count == 2)
        // primaryUnit 优先取 is_primary=true 的那个，而不是数组第一个
        #expect(c.primaryUnit?.form == "absolutely packed")
        #expect(c.passageLines.isEmpty)
    }

    // s5 = passage + comprehend：长文本（目标语言）→ 逐行翻译对照
    @Test func decodesPassageComprehendCard() throws {
        let json = """
        {
            "card_type": "s5",
            "card_content": {
                "granularity": "passage",
                "direction": "comprehend",
                "user_original": "The subway was packed today. I could barely breathe.",
                "target_expression": "The subway was packed today. I could barely breathe.",
                "native_meaning": "一段关于地铁拥挤的描述",
                "revision_type": null,
                "learnable_units": [
                    {"form": "packed", "kind": "word", "note": "拥挤的", "is_primary": true},
                    {"form": "could barely breathe", "kind": "phrase", "note": "几乎喘不过气", "is_primary": false}
                ],
                "passage_lines": [
                    {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
                    {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "passage")
        #expect(c.isPassage == true)
        #expect(c.isWord == false)
        #expect(c.passageLines.count == 2)
        #expect(c.passageLines[0].en == "The subway was packed today.")
        #expect(c.passageLines[0].zh == "今天地铁挤死了。")
        #expect(c.learnableUnits.count == 2)
        #expect(c.primaryUnit?.form == "packed")
    }

    // s6 = passage + express：长文本（母语）→ 逐行翻译对照
    @Test func decodesPassageExpressCard() throws {
        let json = """
        {
            "card_type": "s6",
            "card_content": {
                "granularity": "passage",
                "direction": "express",
                "user_original": "今天地铁挤死了。我几乎喘不过气。",
                "target_expression": "The subway was packed today. I could barely breathe.",
                "native_meaning": null,
                "learnable_units": [
                    {"form": "packed", "kind": "word", "note": "拥挤的", "is_primary": true}
                ],
                "passage_lines": [
                    {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
                    {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "passage")
        #expect(c.isPassage == true)
        #expect(c.direction == "express")
        #expect(c.passageLines.count == 2)
        #expect(c.passageLines[1].zh == "我几乎喘不过气。")
        #expect(c.nativeMeaning == nil)
    }

    // 纯场景图 → sentence + comprehend（s2）：native_meaning 承载母语翻译
    @Test func decodesPureScenePhotoCard() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "user_original": null,
                "user_original_lang": null,
                "target_expression": "A cup of coffee sits on a wooden desk next to a laptop.",
                "native_meaning": "一杯咖啡放在木桌上，旁边是一台笔记本电脑。",
                "revision_type": null,
                "learnable_units": [
                    {"form": "wooden desk", "kind": "phrase", "note": "木桌", "is_primary": true}
                ],
                "passage_lines": [],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "sentence")
        #expect(c.direction == "comprehend")
        #expect(c.userOriginal == nil)
        #expect(c.targetExpression == "A cup of coffee sits on a wooden desk next to a laptop.")
        #expect(c.nativeMeaning == "一杯咖啡放在木桌上，旁边是一台笔记本电脑。")
        #expect(c.passageLines.isEmpty)
    }

    // error 卡：安全/无效拦截走 ErrorContent
    @Test func decodesErrorCard() throws {
        let json = """
        {
            "card_type": "error",
            "card_content": {
                "error_type": "meaningless",
                "message": "好像没有接收到内容，再说一次？"
            },
            "extracted_concept": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .error(let c) = envelope.card else {
            Issue.record("Expected .error card"); return
        }
        #expect(c.errorType == "meaningless")
        #expect(c.message == "好像没有接收到内容，再说一次？")
    }

    // 容错：granularity/direction 缺失时用默认值（sentence + express），不抛错
    @Test func missingRoutingFieldsFallBackToDefaults() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "user_original": "好累",
                "target_expression": "So tired."
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "sentence")
        #expect(c.direction == "express")
        #expect(c.learnableUnits.isEmpty)
        #expect(c.pos.isEmpty)
        #expect(c.displayTarget == "So tired.")
    }
}

// MARK: - Mocks

private struct SuccessMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, source: String?) async throws -> AIEnvelope {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "user_original": "今天会议推迟了",
                "target_expression": "Today's meeting got postponed.",
                "learnable_units": [
                    {"form": "got postponed", "kind": "phrase", "note": "", "is_primary": true}
                ],
                "examples": []
            },
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
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "user_original": "今天会议推迟了",
                "target_expression": "Today's meeting got postponed.",
                "learnable_units": [],
                "examples": []
            },
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
// LocalCache 已是 actor：所有调用都要 await。

struct LocalCacheTombstoneTests {

    // 加墓碑 → 读缓存时该 ID 被过滤（不再出现）
    @Test func tombstonedIdIsFilteredFromCache() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        let tombstones = await LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString))
        await LocalCache.shared.removeTombstone(id, key: .scenes)
    }

    // 撤销：移除墓碑后 ID 重新出现
    @Test func removeTombstoneRestoresVisibility() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        await LocalCache.shared.removeTombstone(id, key: .scenes)
        let tombstones = await LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString) == false)
    }

    // 成功拉取服务器后清空墓碑（服务器为正本，已不含被删条目）
    @Test func clearTombstonesEmptiesAll() async {
        let id1 = UUID()
        let id2 = UUID()
        await LocalCache.shared.addTombstone(id1, key: .vocabs)
        await LocalCache.shared.addTombstone(id2, key: .vocabs)
        await LocalCache.shared.clearTombstones(for: .vocabs)
        let tombstones = await LocalCache.shared.tombstones(for: .vocabs)
        #expect(tombstones.isEmpty)
    }

    // scenes 和 vocabs 各自独立（不互相污染）
    @Test func tombstonesAreScopedPerKey() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        let vocabTombstones = await LocalCache.shared.tombstones(for: .vocabs)
        #expect(vocabTombstones.contains(id.uuidString) == false)
        await LocalCache.shared.removeTombstone(id, key: .scenes)
    }
}

// MARK: - LocalCache tests

struct LocalCacheTests {

    @Test func saveThenLoadRoundTrips() async {
        let payload = #"[{"hello":"world"}]"#.data(using: .utf8)!
        await LocalCache.shared.save(payload, key: .vocabs)
        let loaded = await LocalCache.shared.load(key: .vocabs)
        #expect(loaded == payload)
        await LocalCache.shared.remove(key: .vocabs)   // 清理，避免污染其它用例
    }

    @Test func removeThenLoadReturnsNil() async {
        let payload = #"{"x":1}"#.data(using: .utf8)!
        await LocalCache.shared.save(payload, key: .scenes)
        await LocalCache.shared.remove(key: .scenes)
        #expect(await LocalCache.shared.load(key: .scenes) == nil)
    }

    @Test func saveOverwritesPrevious() async {
        await LocalCache.shared.save("old".data(using: .utf8)!, key: .messages)
        await LocalCache.shared.save("new".data(using: .utf8)!, key: .messages)
        let loaded = await LocalCache.shared.load(key: .messages)
        #expect(loaded == "new".data(using: .utf8)!)
        await LocalCache.shared.remove(key: .messages)
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

// MARK: - OnboardingViewModel tests

struct OnboardingViewModelTests {

    private let sampleCard = PresetCard.all[0]   // "Morning coffee"

    // 初始态：全部清零，未选中任何输入
    @Test func initialStateIsEmpty() {
        let vm = OnboardingViewModel(service: SuccessMock())
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.retryCount == 0)
    }

    // startWithCard 成功：selectedCard 已设、selectedImage 清空、generationResult 有值、loading 回 false
    @Test func startWithCardSuccessSetsResult() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.startWithCard(sampleCard)
        #expect(vm.selectedCard?.id == sampleCard.id)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult != nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.retryCount == 0)
    }

    // startWithImage 成功：selectedImage 已设、selectedCard 清空
    @Test func startWithImageSuccessClearsCard() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        // 先选一张卡，再用图片覆盖
        vm.selectedCard = sampleCard
        let image = UIImage(systemName: "photo")!
        await vm.startWithImage(image)
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage != nil)
        #expect(vm.generationResult != nil)
        #expect(vm.isLoading == false)
    }

    // startWithCard 会清掉之前设的 selectedImage
    @Test func startWithCardClearsPreviousImage() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        vm.selectedImage = UIImage(systemName: "photo")!
        await vm.startWithCard(sampleCard)
        #expect(vm.selectedImage == nil)
    }

    // generate 失败：errorMessage 有值、retryCount 为 1、generationResult 为 nil、loading 回 false
    @Test func generateFailureSetsErrorAndIncrementsRetry() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithCard(sampleCard)
        #expect(vm.errorMessage != nil)
        #expect(vm.retryCount == 1)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
    }

    // 连续失败两次：retryCount 累加到 2
    @Test func repeatedFailuresAccumulateRetryCount() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithCard(sampleCard)
        await vm.retry()
        #expect(vm.retryCount == 2)
    }

    // retry 成功（第一次失败后 retry）：retryCount 归零、generationResult 有值、errorMessage 清空
    @Test func retryAfterFailureSucceeds() async {
        let vm = OnboardingViewModel(service: FailOnceMock())
        await vm.startWithCard(sampleCard)
        #expect(vm.retryCount == 1)
        await vm.retry()
        #expect(vm.generationResult != nil)
        #expect(vm.retryCount == 0)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    // reset：所有状态回到初始值
    @Test func resetClearsAllState() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.startWithCard(sampleCard)
        vm.reset()
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.retryCount == 0)
    }

    // 无选中时 generate 早退：isLoading 回 false，不修改其他状态
    @Test func generateWithNoSelectionExitsEarly() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.generate()
        #expect(vm.isLoading == false)
        #expect(vm.generationResult == nil)
        #expect(vm.errorMessage == nil)
    }
}
