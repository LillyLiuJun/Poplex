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

    // error 卡缺 message（模型漂移）：解码不失败，message 为 nil，渲染层用兜底文案
    @Test func decodesErrorCardWithoutMessage() throws {
        let json = """
        {
            "card_type": "error",
            "card_content": {
                "error_type": "unsafe"
            },
            "extracted_concept": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .error(let c) = envelope.card else {
            Issue.record("Expected .error card"); return
        }
        #expect(c.errorType == "unsafe")
        #expect(c.message == nil)
        #expect(envelope.card.primaryEnglish == "This content can't be processed. Try another one.")
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

// MARK: - Reliable generation service contract tests

struct AIServiceContractTests {

    // Catches a client that accepts a stable request ID but silently omits it
    // from the actual HTTP JSON contract.
    @Test func requestBodyEncodesRequestIDAsSnakeCase() throws {
        let requestID = UUID(uuidString: "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001")!

        let data = try LiveAIService.requestBody(
            text: "A photo from my commute",
            image: nil,
            context: nil,
            presetCardId: nil,
            requestId: requestID,
            source: "onboarding"
        )
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(body["request_id"] as? String == "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001")
    }

    // Catches a client that loses the server proof required for durable success.
    @Test func decodesDurableResponseMetadataFromSnakeCase() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            },
            "request_id": "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001",
            "user_message_id": "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002",
            "assistant_message_id": "C7B5C2D0-5B2A-4C5B-A60D-7C901B303003",
            "material_id": "D6A4B1CF-4C1B-4B4C-950E-6B801A404004"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.requestId == UUID(uuidString: "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001"))
        #expect(envelope.userMessageId == UUID(uuidString: "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002"))
        #expect(envelope.assistantMessageId == UUID(uuidString: "C7B5C2D0-5B2A-4C5B-A60D-7C901B303003"))
        #expect(envelope.materialId == UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404004"))
    }

    // Catches an additive response change that would break existing callers and mocks.
    @Test func cardOnlyResponseStillDecodesWithoutDurableMetadata() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.requestId == nil)
        #expect(envelope.userMessageId == nil)
        #expect(envelope.assistantMessageId == nil)
        #expect(envelope.materialId == nil)
        guard case .card = envelope.card else {
            Issue.record("Expected legacy card to decode"); return
        }
    }
}

// MARK: - Mocks

private struct SuccessMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

private func makeSuccessEnvelope(
    requestId: UUID? = nil,
    userMessageId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404002"),
    assistantMessageId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404003"),
    materialId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404004")
) throws -> AIEnvelope {
    var payload: [String: Any] = [
        "card_type": "s4",
        "card_content": [
            "granularity": "sentence",
            "direction": "express",
            "user_original": "今天会议推迟了",
            "target_expression": "Today's meeting got postponed.",
            "learnable_units": [
                ["form": "got postponed", "kind": "phrase", "note": "", "is_primary": true]
            ],
            "examples": []
        ],
        "extracted_concept": NSNull()
    ]
    if let requestId { payload["request_id"] = requestId.uuidString }
    if let userMessageId { payload["user_message_id"] = userMessageId.uuidString }
    if let assistantMessageId { payload["assistant_message_id"] = assistantMessageId.uuidString }
    if let materialId { payload["material_id"] = materialId.uuidString }
    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder().decode(AIEnvelope.self, from: data)
}

private final class RecordingResponseMock: AIServicing, @unchecked Sendable {
    enum Response: String, Sendable {
        case matchingDurable
        case mismatchedDurable
        case absentRequestDurable
        case missingUserMessage
        case missingAssistantMessage
        case missingMaterial
    }

    private(set) var requestIds: [UUID?] = []
    let response: Response

    init(response: Response = .matchingDurable) {
        self.response = response
    }

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        switch response {
        case .matchingDurable:
            return try makeSuccessEnvelope(requestId: requestId)
        case .mismatchedDurable:
            return try makeSuccessEnvelope(
                requestId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            )
        case .absentRequestDurable:
            return try makeSuccessEnvelope(requestId: nil)
        case .missingUserMessage:
            return try makeSuccessEnvelope(requestId: requestId, userMessageId: nil)
        case .missingAssistantMessage:
            return try makeSuccessEnvelope(requestId: requestId, assistantMessageId: nil)
        case .missingMaterial:
            return try makeSuccessEnvelope(requestId: requestId, materialId: nil)
        }
    }
}

private final class FailOnceRecordingMock: AIServicing, @unchecked Sendable {
    private(set) var requestIds: [UUID?] = []

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        if requestIds.count == 1 { throw URLError(.notConnectedToInternet) }
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

/// 把外部生成请求悬停到测试主动释放，用于稳定复现 A/B 逆序完成。
private actor ControllableGenerationMock: AIServicing {
    private var continuations: [UUID: CheckedContinuation<AIEnvelope, any Error>] = [:]
    private var startedRequestIds: [UUID] = []

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        guard let requestId else { throw AIServiceError.requestFailed }
        return try await withCheckedThrowingContinuation { continuation in
            startedRequestIds.append(requestId)
            continuations[requestId] = continuation
        }
    }

    func waitForStartedRequests(_ count: Int) async -> [UUID] {
        while startedRequestIds.count < count {
            await Task.yield()
        }
        return startedRequestIds
    }

    func succeed(_ requestId: UUID) {
        guard let continuation = continuations.removeValue(forKey: requestId) else { return }
        do {
            continuation.resume(returning: try makeSuccessEnvelope(requestId: requestId))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    func fail(_ requestId: UUID, with error: AIServiceError) {
        continuations.removeValue(forKey: requestId)?.resume(throwing: error)
    }
}

private struct FailingMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        throw URLError(.badServerResponse)
    }
}

/// 预设卡落库 mock：按配置返回成功/失败。
private struct PresetCardSavingMock: PresetCardSaving {
    let succeeds: Bool
    func save(card: PresetCard) async -> Bool { succeeds }
}

/// 计数 saver：记录被调用次数，可配置成败——供断网跳过落库断言用。
private final class CountingPresetCardSaver: PresetCardSaving, @unchecked Sendable {
    private(set) var callCount = 0
    private let succeeds: Bool
    init(succeeds: Bool = true) { self.succeeds = succeeds }
    func save(card: PresetCard) async -> Bool {
        callCount += 1
        return succeeds
    }
}

/// 第一次抛错、之后成功——模拟"断网发送失败 → 恢复网络后重试成功"。
/// 用 class（引用语义）才能在多次 generate 调用间共享计数。
private final class FailOnceMock: AIServicing {
    private var callCount = 0
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        callCount += 1
        if callCount == 1 { throw URLError(.notConnectedToInternet) }
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

/// 总是抛断网错误的 mock。
private struct OfflineMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        throw URLError(.notConnectedToInternet)
    }
}

/// 生成时被服务端安全过滤拦截（Edge Function 返回 422 content_blocked，
/// AIService 解析后抛 AIServiceError.contentBlocked）。
private struct ContentBlockedMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope {
        throw AIServiceError.contentBlocked
    }
}

// MARK: - TodayViewModel tests

struct TodayViewModelTests {

    @Test func sendAppendsUserBubbleAndAICard() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
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
        let vm = TodayViewModel(service: FailingMock(), isConsentGranted: { true })
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
        let vm = TodayViewModel(service: FailOnceMock(), isConsentGranted: { true })
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

    private func makePendingRetryStore(suite: String) -> PendingRetryStore {
        makePendingRetryStoreComponents(suite: suite).store
    }

    private func makePendingRetryStoreComponents(
        suite: String
    ) -> (store: PendingRetryStore, directory: URL, defaults: UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func removeRequestIdFromStoredMetadata(_ defaults: UserDefaults) throws {
        let data = try #require(defaults.data(forKey: "pending_retry_records"))
        var records = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        records[0].removeValue(forKey: "requestId")
        defaults.set(
            try JSONSerialization.data(withJSONObject: records),
            forKey: "pending_retry_records"
        )
    }

    private func hasSendFailed(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .sendFailed = $0.content { return true }; return false }
    }

    // retryPending（photo）失败：记录与照片文件保留（不误删唯一副本）
    @Test func retryPendingPhotoFailureKeepsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo-fail")
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555551")!
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
        let record = store.load()[0]

        let service = FailOnceRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().count == 1)             // 记录保留
        #expect(store.photoImage(for: record) != nil) // 照片文件仍在
        #expect(vm.entries.contains { if case .pendingRetry(let r) = $0.content { return r.id == record.id }; return false })
        #expect(hasSendFailed(vm) == false)   // 单入口语义：失败不产生 sendFailed 行
        #expect(service.requestIds == [requestId])
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
    }

    // 同 request 且三项 durable ID 齐全，才可删除本地唯一副本并展示成功结果。
    @Test func retryPendingPhotoMatchingDurableSuccessClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo-matching-durable")
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555552")!
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
        let record = store.load()[0]
        let service = RecordingResponseMock(response: .matchingDurable)
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(service.requestIds == [requestId])
        #expect(store.load().isEmpty)
        #expect(store.photoImage(for: record) == nil)
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
        #expect(vm.entries.contains { if case .userBubble = $0.content { return true }; return false })
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false })
    }

    // 不同或缺失 request ID 的成功响应不能认领当前 pending 照片。
    @Test func retryPendingPhotoMismatchedRequestKeepsUniqueCopy() async throws {
        let responses: [RecordingResponseMock.Response] = [
            .mismatchedDurable,
            .absentRequestDurable
        ]

        for response in responses {
            let store = makePendingRetryStore(suite: "retry-photo-\(response.rawValue)")
            let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555553")!
            try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
            let record = store.load()[0]
            let service = RecordingResponseMock(response: response)
            let vm = TodayViewModel(service: service, isConsentGranted: { true })
            vm.pendingRetryStore = store
            vm.entries = [TimelineEntry.pendingRetry(record)]

            await vm.retryPending(record: record)

            #expect(service.requestIds == [requestId])
            #expect(store.load().map(\.id) == [record.id])
            #expect(store.photoImage(for: record) != nil)
            #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == record.id }; return false })
            #expect(vm.entries.contains { if case .userBubble = $0.content { return true }; return false } == false)
            #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
        }
    }

    // 任一 durable ID 缺失都不是已提交成功；三种字段分别防回归。
    @Test func retryPendingPhotoMissingAnyDurableIDKeepsUniqueCopy() async throws {
        let responses: [RecordingResponseMock.Response] = [
            .missingUserMessage,
            .missingAssistantMessage,
            .missingMaterial
        ]

        for (index, response) in responses.enumerated() {
            let store = makePendingRetryStore(suite: "retry-photo-\(response.rawValue)-\(index)")
            let requestId = UUID()
            try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
            let record = store.load()[0]
            let service = RecordingResponseMock(response: response)
            let vm = TodayViewModel(service: service, isConsentGranted: { true })
            vm.pendingRetryStore = store
            vm.entries = [TimelineEntry.pendingRetry(record)]

            await vm.retryPending(record: record)

            #expect(service.requestIds == [requestId])
            #expect(store.load().map(\.id) == [record.id])
            #expect(store.photoImage(for: record) != nil)
            #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == record.id }; return false })
            #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
        }
    }

    // 旧记录首次 Retry 先持久升级 request ID；失败与 app 重启后仍复用同一 ID。
    @Test func retryPendingLegacyPhotoPersistsAndReusesRequestIDAcrossRestart() async throws {
        let components = makePendingRetryStoreComponents(suite: "retry-photo-legacy-round-trip")
        try components.store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        try removeRequestIdFromStoredMetadata(components.defaults)
        let legacyRecord = try #require(components.store.load().first)
        #expect(legacyRecord.requestId == nil)

        let service = FailOnceRecordingMock()
        let firstVM = TodayViewModel(service: service, isConsentGranted: { true })
        firstVM.pendingRetryStore = components.store
        firstVM.entries = [TimelineEntry.pendingRetry(legacyRecord)]
        await firstVM.retryPending(record: legacyRecord)

        let reloadedStore = PendingRetryStore(
            defaults: components.defaults,
            documentsDir: components.directory
        )
        let upgradedRecord = try #require(reloadedStore.load().first)
        let persistedRequestId = try #require(upgradedRecord.requestId)
        #expect(service.requestIds == [persistedRequestId])
        #expect(reloadedStore.photoImage(for: upgradedRecord) != nil)

        let restartedVM = TodayViewModel(service: service, isConsentGranted: { true })
        restartedVM.pendingRetryStore = reloadedStore
        restartedVM.entries = [TimelineEntry.pendingRetry(upgradedRecord)]
        await restartedVM.retryPending(record: upgradedRecord)

        #expect(service.requestIds == [persistedRequestId, persistedRequestId])
        #expect(reloadedStore.load().isEmpty)
        #expect(reloadedStore.photoImage(for: upgradedRecord) == nil)
        #expect(restartedVM.entries.contains { if case .aiCard = $0.content { return true }; return false })
    }

    // legacy metadata 升级写失败时，不能发 AI 请求，也不能覆盖记录或删除 JPEG。
    @Test func retryPendingLegacyPhotoUpgradePersistFailureStopsBeforeGeneration() async throws {
        let components = makePendingRetryStoreComponents(suite: "retry-photo-legacy-persist-failure")
        try components.store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        try removeRequestIdFromStoredMetadata(components.defaults)
        let legacyRecord = try #require(components.store.load().first)
        let failingStore = PendingRetryStore(
            defaults: components.defaults,
            documentsDir: components.directory,
            metadataWriter: { _ in
                throw NSError(domain: "test", code: 1)
            }
        )
        let service = RecordingResponseMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = failingStore
        vm.entries = [TimelineEntry.pendingRetry(legacyRecord)]

        await vm.retryPending(record: legacyRecord)

        #expect(service.requestIds.isEmpty)
        #expect(failingStore.load().map(\.id) == [legacyRecord.id])
        #expect(failingStore.load().first?.requestId == nil)
        #expect(failingStore.photoImage(for: legacyRecord) != nil)
        #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == legacyRecord.id }; return false })
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
    }
}

// MARK: - AI consent gate + content-blocked tests (App Store 合规切片)
//
// 门控行为：未同意 AI 数据处理时 send() 只暂存输入 + 弹同意页，绝不发起任何
// generate 请求（合规硬要求："同意前零请求"）。同意后放行照常生成。
// 内容被服务端安全过滤拦截时，展示友好提示、不产出卡片、不残留 loading。
//
// consent 通过注入闭包驱动（生产读 UserDefaults），因此无需触碰全局状态、可并行安全。

struct AIConsentGateTests {

    private func hasBubble(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .userBubble = $0.content { return true }; return false }
    }
    private func hasCard(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .aiCard = $0.content { return true }; return false }
    }
    private func hasLoading(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .aiLoading = $0.content { return true }; return false }
    }

    private func makePendingRetryStore(suite: String) -> PendingRetryStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRetryStore(defaults: defaults, documentsDir: dir)
    }

    // 待重试记录注入：injectPendingRetry 后时间线顶部有 pendingRetry 条目（不重复注入）
    @Test func pendingRetryRecordInjectedOnce() {
        let store = makePendingRetryStore(suite: "inject")
        store.savePreset(cardId: "1", imageName: "card_scene_1")

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.injectPendingRetry()
        vm.injectPendingRetry()

        let count = vm.entries.filter { if case .pendingRetry = $0.content { return true }; return false }.count
        #expect(count == 1)
    }

    // 自动刷新用服务器历史重建时间线后，待重试记录仍应位于最新端；
    // 否则页面的自动滚底会把它留在视口外，看起来像刷新后消失。
    @Test func pendingRetryRemainsVisibleAtLatestEndAfterHistoryReplacement() {
        let store = makePendingRetryStore(suite: "inject-after-refresh")
        store.savePreset(cardId: "1", imageName: "card_scene_1")

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.userBubble(text: "Older server history", image: nil)]

        vm.injectPendingRetry()

        guard let last = vm.entries.last else {
            Issue.record("Expected a pending retry entry after refresh replacement")
            return
        }
        guard case .pendingRetry = last.content else {
            Issue.record("Pending retry must stay at the latest end of the timeline")
            return
        }
    }

    // retryPending（photo）：成功后生成卡片、记录被移除
    @Test func retryPendingPhotoGeneratesAndClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo")
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        let record = store.load()[0]

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().isEmpty)
        #expect(hasCard(vm) == true)
        #expect(hasBubble(vm) == true)   // 就地替换为「气泡 + 卡片」——图片不再消失
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
    }

    // 预设卡 Retry：落库成功 → 记录移除、就地变「气泡 + 卡片」（静态卡内容）
    @Test func retryPendingPresetCardGeneratesAndClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-preset")
        store.savePreset(cardId: "2", imageName: "card_scene_2")
        let record = store.load()[0]

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.presetCardSaver = PresetCardSavingMock(succeeds: true)
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().isEmpty)
        #expect(hasCard(vm) == true)
        #expect(hasBubble(vm) == true)
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
    }
    private func rejectedEntry(_ vm: TodayViewModel) -> (text: String?, wasImage: Bool)? {
        for e in vm.entries {
            if case .userRejected(let t, let w) = e.content { return (t, w) }
        }
        return nil
    }

    // 未同意：只弹同意页 + 暂存输入，不追加气泡 / 卡片 / loading，不触发生成
    @Test func sendWithoutConsentShowsSheetAndSkipsGeneration() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { false })
        await vm.send("今天会议推迟了")

        #expect(vm.showAIConsent == true)
        #expect(hasBubble(vm) == false)
        #expect(hasCard(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 已同意：门控放行，send() 照常走生成 → 气泡 + 卡片，同意页不弹
    @Test func sendWithConsentProceedsToGeneration() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        #expect(vm.showAIConsent == false)
        #expect(hasBubble(vm) == true)
        #expect(hasCard(vm) == true)
        #expect(vm.isLoading == false)
    }

    // onConsentAgreed 同步关闭同意页（无暂存输入时不生成任何内容）
    @Test func consentAgreedClosesSheet() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.showAIConsent = true
        vm.onConsentAgreed()
        #expect(vm.showAIConsent == false)
    }

    // 图片被拒：userBubble 就地转 userRejected(wasImage: true)、loading 移除、不再有弹窗字段
    @Test func contentBlockedImageConvertsBubbleToRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == true)
        #expect(r?.text == "Describe this image")
        #expect(hasBubble(vm) == false)     // 原气泡已转换，时间线不再有 userBubble
        #expect(hasCard(vm) == false)       // 回归护栏：被拒路径不应产生卡片
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 文本被拒：气泡文本原样保留、wasImage == false
    @Test func contentBlockedTextKeepsBubbleTextAsRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        await vm.send("something the filter rejects")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == false)
        #expect(r?.text == "something the filter rejects")
        #expect(hasBubble(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 图文混合被拒：文本原样 + wasImage == true
    @Test func contentBlockedMixedKeepsTextAndMarksImage() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("check this photo")

        let r = rejectedEntry(vm)
        #expect(r?.wasImage == true)
        #expect(r?.text == "check this photo")
        #expect(hasBubble(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }
}

// MARK: - AIService HTTP response classification tests (App Store 合规切片)
//
// LiveAIService.decodeResponse 把服务端响应映射为解码结果或 AIServiceError。
// 这是「服务端安全过滤 → 客户端友好提示」链路的客户端解析半边（Step 5）。
// 用 do/catch 断言具体 case，不依赖 AIServiceError 的 Equatable 合成。

struct AIServiceResponseTests {

    private let validEnvelopeJSON = """
    {
        "card_type": "s4",
        "card_content": {
            "granularity": "sentence",
            "direction": "express",
            "user_original": "今天会议推迟了",
            "target_expression": "Today's meeting got postponed.",
            "learnable_units": [],
            "examples": []
        }
    }
    """.data(using: .utf8)!

    // 422 + {"error":"content_blocked"} → .contentBlocked（安全过滤命中）
    @Test func status422ContentBlockedThrowsContentBlocked() {
        let data = #"{"error":"content_blocked","blockReason":"OUTPUT_SAFETY"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 422, data: data)
            Issue.record("Expected contentBlocked to be thrown")
        } catch AIServiceError.contentBlocked {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 422 但不是 content_blocked → 落到非 2xx 分支 → .requestFailed（不误报被拦）
    @Test func status422OtherErrorThrowsRequestFailed() {
        let data = #"{"error":"rate_limited"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 422, data: data)
            Issue.record("Expected requestFailed to be thrown")
        } catch AIServiceError.contentBlocked {
            Issue.record("Must NOT classify a non-content_blocked 422 as contentBlocked")
        } catch AIServiceError.requestFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 非 2xx（如 500）→ .requestFailed
    @Test func status500ThrowsRequestFailed() {
        let data = Data("Internal Server Error".utf8)
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 500, data: data)
            Issue.record("Expected requestFailed to be thrown")
        } catch AIServiceError.requestFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 2xx + 合法 JSON → 正常返回 AIEnvelope
    @Test func status200ValidJSONReturnsEnvelope() throws {
        let envelope = try LiveAIService.decodeResponse(statusCode: 200, data: validEnvelopeJSON)
        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.displayTarget == "Today's meeting got postponed.")
    }

    // 2xx + 坏 JSON → .decodingFailed
    @Test func status200GarbageThrowsDecodingFailed() {
        let data = Data("not json at all".utf8)
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 200, data: data)
            Issue.record("Expected decodingFailed to be thrown")
        } catch AIServiceError.decodingFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
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

// MARK: - PendingRetryStore tests

struct PendingRetryStoreTests {

    private func makeStore(suite: String) -> (PendingRetryStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-retry-tests-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    // 预设卡记录：写入 → 新实例读取（杀 app 语义）→ 字段完整
    @Test func presetRecordSurvivesReload() {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-preset")
        store.savePreset(cardId: "2", imageName: "card_scene_2")

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .presetCard)
        #expect(records[0].presetCardId == "2")
        #expect(records[0].presetImageName == "card_scene_2")
    }

    // 照片记录：照片落盘 → 新实例读取 → 图片往返一致
    @Test func photoRecordSurvivesReloadWithImage() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-photo")
        let image = UIImage(systemName: "photo")!
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        try store.savePhoto(image, requestId: requestId)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .photo)
        #expect(records[0].requestId == requestId)
        let restored = reloaded.photoImage(for: records[0])
        #expect(restored != nil)
        // SF Symbol 原图的 point 尺寸与 JPEG 重解码后的像素尺寸不同，只断言图回来了且非空
        #expect(restored?.size != .zero)
    }

    // remove：删除后 load 为空，且照片文件被清理
    @Test func removeClearsRecordAndFile() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-remove")
        let image = UIImage(systemName: "photo")!
        try store.savePhoto(image, requestId: UUID())
        let record = store.load()[0]

        store.remove(id: record.id)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        #expect(reloaded.load().isEmpty)
        #expect(reloaded.photoImage(for: record) == nil)
    }

    // 旧版本 JSON 没有 requestId：升级后仍能读取，身份留空等待后续 Retry 升级。
    @Test func legacyRecordWithoutRequestIdStillDecodes() {
        let (store, _, defaults) = makeStore(suite: "pending-retry-legacy")
        let legacyJSON = """
        [{
          "id":"11111111-2222-3333-4444-555555555555",
          "source":"photo",
          "presetCardId":null,
          "presetImageName":null,
          "photoFileName":"legacy.jpg",
          "createdAt":0
        }]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "pending_retry_records")

        let records = store.load()

        #expect(records.count == 1)
        #expect(records[0].requestId == nil)
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

// MARK: - OnboardingErrorKind classify tests

struct OnboardingErrorKindTests {

    // contentBlocked 优先于一切：即使网络正常也判被拒
    @Test func contentBlockedWinsEvenWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.contentBlocked, isConnected: true) == .contentBlocked)
    }

    // 断网类 URLError 码逐个归 offline
    @Test func offlineURLErrorCodesMapToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.notConnectedToInternet), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.networkConnectionLost), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.dataNotAllowed), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.internationalRoamingOff), isConnected: true) == .offline)
    }

    // NetworkMonitor 兜底：非断网码但设备无网 → offline
    @Test func disconnectedFallbackMapsToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: false) == .offline)
    }

    // 有网时的超时 / 服务器错误 → generic
    @Test func serverAndTimeoutMapToGenericWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: URLError(.badServerResponse), isConnected: true) == .generic)
    }

    // 服务层其它错误与未知错误 → generic
    @Test func otherErrorsMapToGeneric() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.decodingFailed, isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: NSError(domain: "test", code: 1), isConnected: true) == .generic)
    }

    // 状态条文案映射：断网/其它有文案且常驻；被拒不映射（走 toast）
    @Test func failureBarCopyMapping() {
        #expect(OnboardingErrorKind.offline.failureBarCopy == "Network unavailable. Check your network and try again.")
        #expect(OnboardingErrorKind.generic.failureBarCopy == "Something went wrong. Please try again.")
        #expect(OnboardingErrorKind.contentBlocked.failureBarCopy == nil)
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
        #expect(vm.errorKind == nil)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // 同一张照片第一次生成分配一个 request ID；失败后的 Retry 必须复用它。
    @Test func retryReusesRequestIdForCurrentPhoto() async {
        let service = FailOnceRecordingMock()
        let vm = OnboardingViewModel(service: service, isConnected: { false })

        await vm.startWithImage(UIImage(systemName: "photo")!)
        let firstId = vm.currentRequestId
        await vm.retry()

        #expect(firstId != nil)
        #expect(service.requestIds.count == 2)
        #expect(service.requestIds[0] == firstId)
        #expect(service.requestIds[1] == firstId)
        #expect(vm.currentRequestId == firstId)
    }

    // 换一张图就是新的用户动作，不能复用上一张图的幂等键。
    @Test func replacementPhotoCreatesDifferentRequestId() async {
        let service = RecordingResponseMock()
        let vm = OnboardingViewModel(service: service)

        await vm.startWithImage(UIImage(systemName: "photo")!)
        let firstId = vm.currentRequestId
        await vm.startWithImage(UIImage(systemName: "camera")!)

        #expect(firstId != nil)
        #expect(vm.currentRequestId != nil)
        #expect(vm.currentRequestId != firstId)
        #expect(service.requestIds == [firstId, vm.currentRequestId])
    }

    // generic/解码/401 等失败仍保留当前照片，Continue 时必须可进入 pending。
    @Test func genericFailureLeavesPhotoUnconfirmed() async {
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(vm.currentRequestId != nil)
    }

    // 只有同 request ID 且三个 durable ID 齐全的响应，才是可展示的确认成功。
    @Test func matchingDurableResponseConfirmsPhoto() async {
        let vm = OnboardingViewModel(service: RecordingResponseMock(response: .matchingDurable))

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    @Test func mismatchedResponseRequestIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .mismatchedDurable),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func absentResponseRequestIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .absentRequestDurable),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingMaterialIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingMaterial),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingUserMessageIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingUserMessage),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingAssistantMessageIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingAssistantMessage),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    // A 成功晚于 B 启动时，A 不能把 B 的 loading 收掉，也不能写入 A 的结果/错误。
    @Test @MainActor func staleSuccessCannotMutateReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requests = await service.waitForStartedRequests(2)
        let requestB = requests[1]

        await service.succeed(requestA)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // A 的 contentBlocked 晚到时不能 reject/清空当前 B。
    @Test @MainActor func staleContentBlockedCannotRejectReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requestB = await service.waitForStartedRequests(2)[1]

        await service.fail(requestA, with: .contentBlocked)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // A 的普通失败晚到时不能覆盖 B 的错误态，也不能提前结束 B 的 loading。
    @Test @MainActor func staleGenericFailureCannotMutateReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service, isConnected: { true })

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requestB = await service.waitForStartedRequests(2)[1]

        await service.fail(requestA, with: .requestFailed)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // loading 期间重复选图必须在改 selection/request ID 前拒绝，不能让活跃请求失去所属输入。
    @Test @MainActor func reentrantImageSelectionDoesNotReplaceActiveAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]

        await vm.startWithImage(UIImage(systemName: "camera")!)

        #expect(vm.currentRequestId == requestA)
        #expect(vm.selectedCard == nil)
        #expect(vm.isLoading)

        await service.succeed(requestA)
        await taskA.value
        #expect(vm.currentRequestId == requestA)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // loading 期间切预设卡也必须在改 selection 前拒绝，旧照片请求仍拥有当前状态。
    @Test @MainActor func reentrantCardSelectionDoesNotReplaceActiveAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]

        await vm.startWithCard(sampleCard)

        #expect(vm.currentRequestId == requestA)
        #expect(vm.selectedImage != nil)
        #expect(vm.selectedCard == nil)
        #expect(vm.isLoading)

        await service.succeed(requestA)
        await taskA.value
        #expect(vm.currentRequestId == requestA)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // startWithCard 成功：selectedCard 已设、selectedImage 清空、generationResult 有值、loading 回 false
    @Test func startWithCardSuccessSetsResult() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: true)
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.selectedCard?.id == sampleCard.id)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult != nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorKind == nil)
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

    // generate 失败（服务器错误类）：errorKind == .generic、generationResult 为 nil、loading 回 false
    @Test func generateFailureSetsErrorKind() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .generic)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
    }

    // retry 成功（第一次断网失败后 retry）：generationResult 有值、errorKind 清空
    @Test func retryAfterFailureSucceeds() async {
        let vm = OnboardingViewModel(service: FailOnceMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        await vm.retry()
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // 预设卡落库成功：presetSavedToServer = true → completeOnboarding 不注入 seed
    // （服务端记录会被 loadHistory 拉到，再注入就重复了）
    @Test func startWithCardSaveSuccessMarksSaved() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: true)
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.generationResult != nil)
        #expect(vm.presetSavedToServer == true)
    }

    // 预设卡落库失败：与自选图「请求失败」同规则——断网档失败态，不展示完整卡片、
    // 粘性标记置位（离开写待重试记录）。不再信 NetworkMonitor（真机飞行模式可能误报有网）。
    @Test func startWithCardSaveFailureFallsToOfflineState() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: false),
            isConnected: { true }   // 监控说有网，但落库失败——以落库结果为真相
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.generationResult == nil)          // 不展示完整卡片
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)            // 断网档
        #expect(vm.offlineFailureOccurred == true)   // 写待重试记录
        #expect(vm.isLoading == false)
    }

    // 预设卡断网：始终真实尝试落库（不预判网络——真机监控不可靠），落库失败 → 不生成内容、
    // errorKind == .offline、粘性标记置位。与自选图断网完全同构。
    @Test func presetCardOfflineFailsSaveAndDoesNotGenerate() async {
        let saver = CountingPresetCardSaver(succeeds: false)   // 模拟断网时落库失败
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { false }
        )
        await vm.startWithCard(PresetCard.all[0])
        #expect(vm.generationResult == nil)          // 落库失败不生成内容
        #expect(saver.callCount == 1)                // 始终真实尝试（不预判）
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
        #expect(vm.isLoading == false)
    }

    // 预设卡有网：落库照常（回归 #28 语义）
    @Test func presetCardOnlineStillSaves() async {
        let saver = CountingPresetCardSaver(succeeds: true)
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { true }
        )
        await vm.startWithCard(sampleCard)
        #expect(saver.callCount == 1)
        #expect(vm.presetSavedToServer == true)
        #expect(vm.errorKind == nil)
        #expect(vm.generationResult != nil)   // 有网生成静态卡内容（#28 显式守护）
    }

    // 断网：errorKind == .offline
    @Test func offlineFailureClassifiedAsOffline() async {
        let vm = OnboardingViewModel(service: OfflineMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
    }

    // 内容被拒：errorKind == .contentBlocked
    @Test func contentBlockedClassifiedAsBlocked() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
    }

    // 被拒：rejectSelection 清空选中（图片不上屏、回空上传区）、errorKind 保留驱动 toast、
    // 粘性标记不受影响
    @Test func contentBlockedRejectsSelectionAndKeepsErrorKind() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
        #expect(vm.selectedImage == nil)
        #expect(vm.selectedCard == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.offlineFailureOccurred == false)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // Try again 链路：断网失败 → 网络恢复 → retry() 原素材重新生成成功
    @Test func retryWhileOfflineFailsSafely() async {
        let vm = OnboardingViewModel(service: OfflineMock(), isConnected: { false })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.generationResult == nil)

        // 模拟网络恢复后的重试：同 VM 不可换 mock——改用「恢复后重新生成」语义：
        // retry() 仍走同一个 OfflineMock 会再失败，因此这里验证 retry 入口存在且再次落 offline。
        await vm.retry()
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
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
        #expect(vm.errorKind == nil)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // 无选中时 generate 早退：isLoading 回 false，不修改其他状态
    @Test func generateWithNoSelectionExitsEarly() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.generate()
        #expect(vm.isLoading == false)
        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == nil)
    }

    // 断网失败的粘性标记：状态条不随恢复消失（errorKind 保留到用户行动），
    // 粘性标记只在 reset() 时抹掉——离开时仍写待重试记录（防内容丢失窗口）
    @Test func offlineFailureFlagIsStickyUntilReset() async {
        let vm = OnboardingViewModel(service: OfflineMock(), isConnected: { false })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)

        // 失败态保留：不自动清除（重试入口稳定）
        #expect(vm.errorKind == .offline)

        vm.reset()
        #expect(vm.errorKind == nil)
        #expect(vm.offlineFailureOccurred == false)
    }
}

// MARK: - Onboarding completion ordering tests

struct OnboardingCompletionCoordinatorTests {

    private func makeStore(suite: String) -> (PendingRetryStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-completion-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    // pending 照片必须先落盘，之后才能写本地完成/同步标记并离开 onboarding。
    @Test func unconfirmedPhotoPersistsBeforeCompletionMarkersAndExit() async {
        let (store, _, defaults) = makeStore(suite: "completion-order")
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        let requestId = vm.currentRequestId
        var events: [String] = []
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            defaults: defaults,
            setSyncPending: {
                #expect(store.load().first?.requestId == requestId)
                #expect(defaults.double(forKey: "onboarding_completed_at") > 0)
                events.append("sync-pending")
            },
            startRemoteSync: {
                #expect(store.load().first?.requestId == requestId)
                events.append("remote-sync")
            }
        )

        let completed = coordinator.complete(viewModel: vm) {
            #expect(store.load().first?.requestId == requestId)
            #expect(defaults.double(forKey: "onboarding_completed_at") > 0)
            events.append("complete")
        }

        #expect(completed)
        #expect(events == ["sync-pending", "remote-sync", "complete"])
        #expect(store.load().count == 1)
    }

    // JPEG 写失败时必须留在 onboarding；完成标记、同步和退出都不可发生。
    @Test func jpegPersistenceFailureKeepsOnboardingOpen() async {
        let suite = "completion-jpeg-failure"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let missingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        let store = PendingRetryStore(defaults: defaults, documentsDir: missingDir)
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var sideEffectCount = 0
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            defaults: defaults,
            setSyncPending: { sideEffectCount += 1 },
            startRemoteSync: { sideEffectCount += 1 }
        )

        let completed = coordinator.complete(viewModel: vm) { sideEffectCount += 1 }

        #expect(completed == false)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(defaults.double(forKey: "onboarding_completed_at") == 0)
        #expect(sideEffectCount == 0)
    }

    // 元数据写失败与 JPEG 失败同等处理，不能只保住文件却误报 onboarding 已完成。
    @Test func metadataPersistenceFailureKeepsOnboardingOpen() async {
        let (_, dir, defaults) = makeStore(suite: "completion-metadata-failure")
        let store = PendingRetryStore(
            defaults: defaults,
            documentsDir: dir,
            metadataWriter: { _ in throw NSError(domain: "test", code: 9) }
        )
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var sideEffectCount = 0
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            defaults: defaults,
            setSyncPending: { sideEffectCount += 1 },
            startRemoteSync: { sideEffectCount += 1 }
        )

        let completed = coordinator.complete(viewModel: vm) { sideEffectCount += 1 }

        #expect(completed == false)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(defaults.double(forKey: "onboarding_completed_at") == 0)
        #expect(store.load().isEmpty)
        #expect(sideEffectCount == 0)
    }

    // 已由匹配 durable 响应确认的照片不需要 pending 副本。
    @Test func confirmedPhotoCompletesWithoutPendingRecord() async {
        let (store, _, defaults) = makeStore(suite: "completion-confirmed")
        let vm = OnboardingViewModel(service: RecordingResponseMock(response: .matchingDurable))
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var didComplete = false
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            defaults: defaults,
            setSyncPending: {},
            startRemoteSync: {}
        )

        let completed = coordinator.complete(viewModel: vm) { didComplete = true }

        #expect(completed)
        #expect(didComplete)
        #expect(store.load().isEmpty)
    }
}

// MARK: - ProfileService pending sync tests

struct ProfileServicePendingSyncTests {

    // 待办标记的生命周期：默认无 → 置位 → 清除。用独立 suite 隔离 .standard。
    @Test func pendingSyncLifecycle() {
        let suite = "profile-service-pending-tests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == false)

        ProfileService.setOnboardingSyncPending(true, defaults: defaults)
        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == true)

        ProfileService.setOnboardingSyncPending(false, defaults: defaults)
        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == false)
    }
}

// MARK: - MessageRecord asset 前缀解析

struct MessageRecordAssetPathTests {

    // "asset:<imageName>" 是预设卡图片的本地素材引用（storage 签名对其无意义）
    @Test func assetPrefixExtractsImageName() {
        #expect(MessageRecord.assetImageName(fromPath: "asset:card_scene_1") == "card_scene_1")
    }

    // storage 路径与空值不误判为素材引用
    @Test func nonAssetPathsReturnNil() {
        #expect(MessageRecord.assetImageName(fromPath: nil) == nil)
        #expect(MessageRecord.assetImageName(fromPath: "materials/abc.jpg") == nil)
        #expect(MessageRecord.assetImageName(fromPath: "asset:") == nil)
        #expect(MessageRecord.assetImageName(fromPath: "asset") == nil)
    }
}

// MARK: - Tab2WordEntry decode tests

struct Tab2WordEntryDecodeTests {

    // 辅助：从字段字典构造 Tab2WordEntry
    private func entry(
        lemma: String = "blanch",
        entryKind: String? = nil,
        granularity: String? = "sentence",
        sourceType: String? = "material",
        nativeMeaning: String? = nil,
        imageUrl: String? = nil
    ) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": lemma]
        if let v = entryKind    { fields["entry_kind"]     = v }
        if let v = granularity  { fields["granularity"]    = v }
        if let v = sourceType   { fields["source_type"]    = v }
        if let v = nativeMeaning { fields["native_meaning"] = v }
        if let v = imageUrl     { fields["image_url"]      = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // native_meaning 有值时正确解码
    @Test func nativeMeaningDecoded() throws {
        let e = try entry(nativeMeaning: "焯水")
        #expect(e.nativeMeaning == "焯水")
    }

    // native_meaning 缺失时为 nil，不抛错
    @Test func nativeMeaningMissingIsNil() throws {
        let e = try entry()
        #expect(e.nativeMeaning == nil)
    }

    // granularity=word → sourceTag=.word
    @Test func sourceTagWordForWordGranularity() throws {
        let e = try entry(granularity: "word", sourceType: "material")
        #expect(e.sourceTag == .word)
    }

    // granularity=passage → sourceTag=.passage
    @Test func sourceTagPassageForPassageGranularity() throws {
        let e = try entry(granularity: "passage", sourceType: "material")
        #expect(e.sourceTag == .passage)
    }

    // sourceType=dialogue 优先级高于 granularity
    @Test func sourceTagDialogueTakesPriority() throws {
        let e = try entry(granularity: "sentence", sourceType: "dialogue")
        #expect(e.sourceTag == .dialogue)
    }

    // 默认（granularity=sentence）→ sourceTag=.sentence
    @Test func sourceTagDefaultIsSentence() throws {
        let e = try entry(granularity: "sentence", sourceType: "material")
        #expect(e.sourceTag == .sentence)
    }

    // granularity=nil → 默认 .sentence（不崩溃）
    @Test func sourceTagFallsBackToSentenceWhenNil() throws {
        let e = try entry(granularity: nil)
        #expect(e.sourceTag == .sentence)
    }
}

// MARK: - Tab2WordEntry badge icon tests

struct Tab2WordEntryBadgeTests {

    private func entry(
        granularity: String? = "sentence",
        sourceType: String? = "material",
        entryKind: String? = nil
    ) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": "test"]
        if let v = granularity  { fields["granularity"] = v }
        if let v = sourceType   { fields["source_type"] = v }
        if let v = entryKind    { fields["entry_kind"]  = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // 分类型图标家族：查词→放大镜；句中单词→衬线 A；短语→text.quote；习语/俚语→bubble.left。

    // 主动查词 (.word sourceTag) → 放大镜
    @Test func lookupWordUsesMagnifier() throws {
        let e = try entry(granularity: "word", sourceType: "material")
        #expect(e.badgeGlyph == .symbol("magnifyingglass"))
    }

    // 对话来源 (.dialogue) → 声波（未上线，保留）
    @Test func dialogueUsesWaveform() throws {
        let e = try entry(granularity: "sentence", sourceType: "dialogue")
        #expect(e.badgeGlyph == .symbol("waveform"))
    }

    // 句子/段落里的单词 → 衬线字母 A
    @Test func sentenceWordUsesSerifLetter() throws {
        #expect(try entry(granularity: "sentence", entryKind: "word").badgeGlyph == .serifLetter("A"))
        #expect(try entry(granularity: "passage", entryKind: "word").badgeGlyph == .serifLetter("A"))
    }

    // 短语 / 搭配 / 句型 → text.quote
    @Test func phraseKindUsesTextQuote() throws {
        for kind in ["phrase", "collocation", "pattern"] {
            #expect(try entry(entryKind: kind).badgeGlyph == .symbol("text.quote"))
        }
    }

    // 习语 / 俚语 → bubble.left
    @Test func idiomSlangUsesBubble() throws {
        for kind in ["idiom", "slang"] {
            #expect(try entry(entryKind: kind).badgeGlyph == .symbol("bubble.left"))
        }
    }

    // 未知 entryKind / nil → 默认 text.quote（当短语处理）
    @Test func unknownOrNilKindDefaultsTextQuote() throws {
        #expect(try entry(entryKind: "unknown_future_kind").badgeGlyph == .symbol("text.quote"))
        #expect(try entry(entryKind: nil).badgeGlyph == .symbol("text.quote"))
    }
}

// MARK: - SceneCategoryMap tests

struct SceneCategoryMapTests {

    @Test func knownCategoryMapsToCorrectCase() {
        #expect(SceneCategory.from("工作与学业") == .workStudy)
        #expect(SceneCategory.from("饮食") == .food)
        #expect(SceneCategory.from("家庭与人际") == .homeFamily)
        #expect(SceneCategory.from("休闲娱乐") == .leisure)
    }

    @Test func nilRawValueFallsToOther() {
        #expect(SceneCategory.from(nil) == .other)
    }

    @Test func unknownRawValueFallsToOther() {
        #expect(SceneCategory.from("不存在的分类") == .other)
    }

    @Test func englishLabelsMatchExpected() {
        #expect(SceneCategory.workStudy.englishLabel == "Work & study")
        #expect(SceneCategory.food.englishLabel == "Food")
        #expect(SceneCategory.homeFamily.englishLabel == "Home & people")
        #expect(SceneCategory.other.englishLabel == "Other")
        #expect(SceneCategory.leisure.englishLabel == "Leisure")
    }
}

// MARK: - Tab2HomeData JSON decode tests

struct Tab2HomeDataDecodeTests {

    private let decoder = JSONDecoder()

    @Test func decodesFullPayloadWithSubScenesAndDate() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 12,
            "categories": [
                {
                    "scene_category": "工作与学业",
                    "word_count": 8,
                    "unlocked": true,
                    "last_material_at": "2026-07-25T10:00:00.000Z",
                    "sub_scenes": [
                        {
                            "scene_detail": "Team meeting",
                            "occurrence_count": 3,
                            "quote": "We had a long meeting",
                            "image_url": null
                        }
                    ],
                    "preview_words": ["overtime", "deadline"]
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.unlocked == true)
        #expect(home.inputCount == 12)
        #expect(home.categories.count == 1)

        let cat = home.categories[0]
        #expect(cat.sceneCategory == "工作与学业")
        #expect(cat.wordCount == 8)
        #expect(cat.unlocked == true)
        #expect(cat.lastMaterialAt != nil)
        #expect(cat.englishLabel == "Work & study")
        #expect(cat.previewWords == ["overtime", "deadline"])

        let scene = cat.subScenes[0]
        #expect(scene.sceneDetail == "Team meeting")
        #expect(scene.occurrenceCount == 3)
        #expect(scene.quote == "We had a long meeting")
        #expect(scene.imageUrl == nil)
    }

    @Test func missingOptionalFieldsDefaultToEmpty() throws {
        let json = """
        {
            "unlocked": false,
            "input_count": 3,
            "categories": [
                {
                    "scene_category": "饮食",
                    "word_count": 2,
                    "unlocked": false
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        let cat = home.categories[0]
        #expect(cat.subScenes.isEmpty)
        #expect(cat.previewWords.isEmpty)
        #expect(cat.lastMaterialAt == nil)
    }

    @Test func lastMaterialAtParsesISO8601() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 5,
            "categories": [
                {
                    "scene_category": "其他",
                    "word_count": 1,
                    "unlocked": true,
                    "last_material_at": "2026-07-20T08:30:00.000Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        let date = home.categories[0].lastMaterialAt
        #expect(date != nil)
        let after = ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z")!
        #expect(date! > after)
    }

    @Test func emptyCategoriesArray() throws {
        let json = """
        {"unlocked": false, "input_count": 0, "categories": []}
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.categories.isEmpty)
    }

    @Test func unknownSceneCategoryFallsToOtherLabel() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 1,
            "categories": [
                {"scene_category": "未知分类", "word_count": 1, "unlocked": true}
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.categories[0].englishLabel == "Other")
    }
}

// MARK: - Tab2HomeViewModel.heroCategory() tests

struct Tab2HeroCategoryTests {

    private func makeCategory(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        lastMaterialAt: Date? = nil,
        hasFeatured: Bool = false
    ) -> Tab2CategoryData {
        // 第 3 刀后 heroCategory() 改读 featured（不再看 subScenes.quote）
        let featured: Tab2FeaturedMoment? = hasFeatured ? Tab2FeaturedMoment(
            sceneDetail: "Scene", occurrenceCount: 1, materialId: "m",
            userOriginal: "some original", targetExpression: "some target",
            nativeMeaning: nil, imageUrl: nil, inputLang: "native",
            sourceDirection: "express", sourceGranularity: "sentence",
            createdAt: lastMaterialAt, spokenCount: 0
        ) : nil
        return Tab2CategoryData(
            sceneCategory: sceneCategory,
            wordCount: wordCount,
            unlocked: unlocked,
            lastMaterialAt: lastMaterialAt,
            featured: featured
        )
    }

    @Test func nilDataReturnsNil() {
        let vm = Tab2HomeViewModel()
        vm.data = nil
        #expect(vm.heroCategory() == nil)
    }

    @Test func noUnlockedCategoriesReturnsNil() {
        let vm = Tab2HomeViewModel()
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [
            makeCategory(sceneCategory: "工作与学业", wordCount: 5, unlocked: false),
            makeCategory(sceneCategory: "饮食", wordCount: 3, unlocked: false)
        ])
        #expect(vm.heroCategory() == nil)
    }

    // 无任何 featured → 降级到词数最多的已解锁分类
    @Test func noFeaturedFallsBackToHighestWordCount() {
        let vm = Tab2HomeViewModel()
        let low  = makeCategory(sceneCategory: "工作与学业", wordCount: 10, unlocked: true)
        let high = makeCategory(sceneCategory: "饮食", wordCount: 20, unlocked: true)
        vm.data = Tab2HomeData(unlocked: true, inputCount: 5, categories: [low, high])
        let hero = vm.heroCategory()
        #expect(hero?.sceneCategory == "饮食")
        #expect(hero?.wordCount == 20)
    }

    // 有 featured 的分类优先于无 featured（即使后者词数更多）
    @Test func prefersCategoryWithFeaturedOverHigherWordCount() {
        let vm = Tab2HomeViewModel()
        let featuredCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 5, unlocked: true,
            lastMaterialAt: Date(), hasFeatured: true
        )
        let wordRichCat = makeCategory(
            sceneCategory: "饮食", wordCount: 50, unlocked: true, hasFeatured: false
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 8, categories: [wordRichCat, featuredCat])
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")
    }

    // 多个有 featured：lastMaterialAt 最新的赢
    @Test func mostRecentFeaturedWins() {
        let vm = Tab2HomeViewModel()
        let older = Date(timeIntervalSince1970: 1_750_000_000)
        let newer = Date(timeIntervalSince1970: 1_760_000_000)
        let oldCat = makeCategory(
            sceneCategory: "家庭与人际", wordCount: 15, unlocked: true,
            lastMaterialAt: older, hasFeatured: true
        )
        let newCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            lastMaterialAt: newer, hasFeatured: true
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 10, categories: [oldCat, newCat])
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")
    }
}

// MARK: - Tab2HeroCard 模式判据 tests（§4.2）

struct Tab2HeroCardModeTests {

    // 英文输入（input_lang=target）→ 模式 A（引号）
    @Test func targetInputIsModeA() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "I'm exhausted.", inputLang: "target", hasFeatured: true) == .a)
    }

    // 母语输入（native）→ 模式 B（无引号 + 注脚）
    @Test func nativeInputIsModeB() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "太累了", inputLang: "native", hasFeatured: true) == .b)
    }

    // 第三语言（other）按非目标语言 → 模式 B（不加引号）
    @Test func otherLangIsModeB() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "疲れた", inputLang: "other", hasFeatured: true) == .b)
    }

    // user_original 为空（纯图片）→ 模式 C
    @Test func nilUserOriginalIsModeC() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: nil, inputLang: nil, hasFeatured: true) == .c)
    }

    // user_original 空字符串也当纯图片 → 模式 C
    @Test func emptyUserOriginalIsModeC() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "", inputLang: nil, hasFeatured: true) == .c)
    }

    // 无 featured（分类全查词）→ 模式 D
    @Test func noFeaturedIsModeD() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "x", inputLang: "target", hasFeatured: false) == .d)
    }
}

// MARK: - Tab2HeroCard 相对时间粒度 tests（§5.4）

struct Tab2HeroCardRelativeTimeTests {

    private let cal = Calendar.current
    private func daysAgo(_ n: Int, from now: Date) -> Date {
        cal.date(byAdding: .day, value: -n, to: now)!
    }

    @Test func zeroDaysIsToday() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(now, now: now) == "today")
    }

    @Test func oneDayIsYesterday() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(daysAgo(1, from: now), now: now) == "yesterday")
    }

    @Test func fourDaysIsNDaysAgo() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(daysAgo(4, from: now), now: now) == "4 days ago")
    }

    // 上边界：27 天仍是 "N days ago"
    @Test func twentySevenDaysIsDaysAgo() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(daysAgo(27, from: now), now: now) == "27 days ago")
    }

    // 28 天进入 "last month"
    @Test func twentyEightDaysIsLastMonth() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(daysAgo(28, from: now), now: now) == "last month")
    }

    // 90 天 → "earlier"
    @Test func ninetyDaysIsEarlier() {
        let now = Date()
        #expect(Tab2HeroCard.relativeTime(daysAgo(90, from: now), now: now) == "earlier")
    }
}

// MARK: - Tab2WordEntry stableImageKey tests

struct Tab2WordEntryStableImageKeyTests {

    private func entry(imageUrl: String?) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": "test"]
        if let v = imageUrl { fields["image_url"] = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // 有签名 token 的 URL → 截掉查询参数，只保留路径
    @Test func stripsTokenQueryParam() throws {
        let e = try entry(imageUrl: "https://example.com/storage/img.jpg?token=abc123")
        #expect(e.stableImageKey == "https://example.com/storage/img.jpg")
    }

    // 多个查询参数也一并截掉
    @Test func stripsMultipleQueryParams() throws {
        let e = try entry(imageUrl: "https://example.com/img.jpg?token=x&t=1234")
        #expect(e.stableImageKey == "https://example.com/img.jpg")
    }

    // 没有查询参数的 URL → 原样返回
    @Test func noQueryParamReturnsOriginal() throws {
        let e = try entry(imageUrl: "https://example.com/storage/img.jpg")
        #expect(e.stableImageKey == "https://example.com/storage/img.jpg")
    }

    // imageUrl=nil → stableImageKey=nil
    @Test func nilImageUrlReturnsNil() throws {
        let e = try entry(imageUrl: nil)
        #expect(e.stableImageKey == nil)
    }

    // imageUrl="" → stableImageKey=nil
    @Test func emptyImageUrlReturnsNil() throws {
        let e = try entry(imageUrl: "")
        #expect(e.stableImageKey == nil)
    }
}

// MARK: - CJK detection tests (finalizeFallbackSpeech language routing)

struct CJKDetectionTests {
    // Mirrors the predicate in ConversationViewModel.finalizeFallbackSpeech
    private func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    @Test func detectsChineseCharacters() {
        #expect(hasCJK("你好") == true)
    }

    @Test func detectsMixedChineseEnglish() {
        #expect(hasCJK("I'm 很累 today") == true)
    }

    @Test func ignoresPureLatin() {
        #expect(hasCJK("Hello world") == false)
    }

    @Test func ignoresEmptyString() {
        #expect(hasCJK("") == false)
    }

    @Test func ignoresPunctuation() {
        #expect(hasCJK("!@#$%") == false)
    }

    @Test func detectsRangeLowerBound() {
        // U+4E00 = 一 (first CJK Unified Ideograph)
        #expect(hasCJK("一") == true)
    }

    @Test func detectsRangeUpperBound() {
        let ch = String(UnicodeScalar(0x9FFF)!)
        #expect(hasCJK(ch) == true)
    }

    @Test func ignoresJapaneseKatakana() {
        // Katakana is U+30A0–U+30FF, outside the CJK block
        #expect(hasCJK("アイウエオ") == false)
    }

    @Test func ignoresKoreanHangul() {
        // Hangul is U+AC00–U+D7A3, outside the CJK block
        #expect(hasCJK("안녕") == false)
    }

    @Test func detectsKanjiInJapaneseSentence() {
        // Japanese sentences often mix kanji (CJK) with kana — should still detect
        #expect(hasCJK("今日はいい天気ですね") == true)
    }
}

// MARK: - DialogueService DTO decode tests

struct DialogueDTODecodeTests {

    @Test func decodesStartResponse() throws {
        let json = """
        {"session_id": "abc-123", "reply": "Hello!", "suggestions": []}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueStartResponse.self, from: json)
        #expect(r.sessionId == "abc-123")
        #expect(r.reply == "Hello!")
        #expect(r.suggestions.isEmpty)
    }

    @Test func decodesStartResponseWithSuggestions() throws {
        let json = """
        {
            "session_id": "s1",
            "reply": "What happened?",
            "suggestions": [{"lemma": "burnout", "hint": "extreme exhaustion"}]
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueStartResponse.self, from: json)
        #expect(r.suggestions.count == 1)
        #expect(r.suggestions[0].lemma == "burnout")
        #expect(r.suggestions[0].hint == "extreme exhaustion")
    }

    @Test func decodesTurnResponseNullSceneDetail() throws {
        let json = """
        {"reply": "That sounds tough.", "suggestions": [], "scene_detail": null}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueTurnResponse.self, from: json)
        #expect(r.reply == "That sounds tough.")
        #expect(r.sceneDetail == nil)
    }

    @Test func decodesTurnResponseWithSceneDetail() throws {
        let json = """
        {
            "reply": "Tell me more.",
            "suggestions": [
                {"lemma": "deadline", "hint": "due date"},
                {"lemma": "overtime", "hint": "extra hours"}
            ],
            "scene_detail": "Work stress meeting"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueTurnResponse.self, from: json)
        #expect(r.suggestions.count == 2)
        #expect(r.sceneDetail == "Work stress meeting")
    }

    @Test func decodesFallbackResponse() throws {
        let json = """
        {
            "translation": "I stayed late at work.",
            "key_words": [{"word": "stayed", "phonetic": "/steɪd/"}],
            "hint": "Try using 'stayed late'"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.translation == "I stayed late at work.")
        #expect(r.keyWords.count == 1)
        #expect(r.keyWords[0].word == "stayed")
        #expect(r.keyWords[0].phonetic == "/steɪd/")
        #expect(r.hint == "Try using 'stayed late'")
    }

    @Test func decodesFallbackResponseEmptyKeyWords() throws {
        let json = """
        {"translation": "Let's go.", "key_words": [], "hint": "Say it!"}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.keyWords.isEmpty)
    }

    @Test func decodesFallbackResponseMultipleKeyWords() throws {
        let json = """
        {
            "translation": "The projector wasn't working.",
            "key_words": [
                {"word": "projector", "phonetic": "/prəˈdʒektər/"},
                {"word": "working",   "phonetic": "/ˈwɜːrkɪŋ/"}
            ],
            "hint": "Focus on 'projector'"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.keyWords.count == 2)
        #expect(r.keyWords[1].phonetic == "/ˈwɜːrkɪŋ/")
    }

    @Test func decodesSuggestionDTO() throws {
        let json = "{\"lemma\": \"overtime\", \"hint\": \"extra hours beyond schedule\"}".data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueSuggestionDTO.self, from: json)
        #expect(r.lemma == "overtime")
        #expect(r.hint == "extra hours beyond schedule")
    }

    @Test func decodesFallbackKeyWordDTO() throws {
        let json = "{\"word\": \"projector\", \"phonetic\": \"/pr\u{0259}\u{02C8}d\u{0292}ekt\u{0259}r/\"}".data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackKeyWordDTO.self, from: json)
        #expect(r.word == "projector")
        #expect(r.phonetic == "/prəˈdʒektər/")
    }
}

// MARK: - ConversationViewModel state machine tests

@MainActor
struct ConversationViewModelStateTests {

    @Test func initialPageStateIsPreparing() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.pageState == .preparing)
    }

    @Test func initialMicStateIsIdle() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.micState == .idle)
    }

    @Test func initialSessionIdIsNil() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.sessionId == nil)
    }

    @Test func initialFallbackListeningIsFalse() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.isFallbackListening == false)
    }

    @Test func retryWithNoSessionReEntersPreparing() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.pageState = .failed
        vm.sessionId = nil
        vm.retry()
        #expect(vm.pageState == .preparing)
    }

    @Test func retryWithExistingSessionBecomesActive() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.pageState = .failed
        vm.sessionId = "existing-session-id"
        vm.retry()
        #expect(vm.pageState == .active)
    }

    @Test func dismissFallbackClearsFallbackResult() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.fallbackResult = FallbackResult(
            translation: "I'm tired.",
            keyWords: [],
            hint: "Try saying it."
        )
        vm.dismissFallback()
        #expect(vm.fallbackResult == nil)
    }

    // 停用原因：interruptAI() 会串接 startListening()，其最终 micState 取决于设备
    // 麦克风权限状态（授权环境下会推进到 .listening 而非 .idle）——期望值与权限耦合，
    // 是先于合规切片就存在的 flaky 老用例。待语音对话切片锁定时再修正期望并重新启用。
    @Test(.disabled("Voice-dialogue: interruptAI chains into startListening; final micState is coupled to mic-permission state. Revisit with the dialogue slice."))
    func interruptAISetsIdleWhenAISpeaking() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .aiSpeaking
        vm.interruptAI()
        #expect(vm.micState == .idle)
    }

    @Test func interruptAIDoesNothingWhenIdle() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .idle
        vm.interruptAI()
        #expect(vm.micState == .idle)
    }

    // startFallbackListening guard: already in fallback mode → early return, no state change
    @Test func startFallbackListeningNoOpWhenAlreadyFallback() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .idle
        vm.isFallbackListening = true
        vm.startFallbackListening()
        // guard !isFallbackListening fires — micState must remain idle, not change to .listening
        #expect(vm.micState == .idle)
        #expect(vm.isFallbackListening == true)
    }

    // startFallbackListening guard: aiSpeaking → early return
    @Test func startFallbackListeningNoOpWhenAISpeaking() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .aiSpeaking
        vm.startFallbackListening()
        // guard micState == .idle || .listening fails for .aiSpeaking
        #expect(vm.isFallbackListening == false)
        #expect(vm.micState == .aiSpeaking)
    }

    // NativeFallbackButton.isDisabled logic: only aiSpeaking disables the button
    @Test func fallbackButtonDisabledOnlyWhenAISpeaking() {
        let isDisabled: (MicState) -> Bool = { $0 == .aiSpeaking }
        #expect(isDisabled(.idle) == false)
        #expect(isDisabled(.listening) == false)
        #expect(isDisabled(.aiSpeaking) == true)
        #expect(isDisabled(.disabled) == false)
    }
}

// MARK: - PopsLabel formatting tests
// 锁定 pops 计数单位的复数处理（0/1/N），供 Topics 进度行胶囊与 Hero 卡共用。

struct PopsLabelTests {

    @Test func zeroUsesPlural() {
        #expect(PopsLabel.format(0) == "0 pops")
    }

    @Test func oneUsesSingular() {
        #expect(PopsLabel.format(1) == "1 pop")
    }

    @Test func manyUsePlural() {
        #expect(PopsLabel.format(2) == "2 pops")
        #expect(PopsLabel.format(18) == "18 pops")
    }
}

// MARK: - Category milestone crossing tests

struct CategoryMilestoneTrackerTests {

    @Test func existingAchievementsBecomeBaselineWithoutReplaying() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        let first = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        let later = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 21)],
            userID: "user-a"
        )

        #expect(first.isEmpty)
        #expect(later.isEmpty)
    }

    @Test func crossingFromNineteenToTwentyCreatesPresentation() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        let presentations = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        #expect(presentations == [CategoryMilestonePresentation(
            categoryID: "work",
            previousCount: 19,
            currentCount: 20
        )])
    }

    @Test func achievedCategoryNeverReplaysAfterCountRegression() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 8)],
            userID: "user-a"
        )
        let replay = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        #expect(replay.isEmpty)
    }

    @Test func simultaneousCrossingsReturnEveryPresentationAndPersistAll() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 19),
            CategoryMilestoneSnapshot(categoryID: "food", count: 18)
        ], userID: "user-a")

        let presentations = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 20),
            CategoryMilestoneSnapshot(categoryID: "food", count: 23)
        ], userID: "user-a")

        _ = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 10),
            CategoryMilestoneSnapshot(categoryID: "food", count: 10)
        ], userID: "user-a")
        let replay = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 20),
            CategoryMilestoneSnapshot(categoryID: "food", count: 23)
        ], userID: "user-a")

        #expect(presentations == [
            CategoryMilestonePresentation(
                categoryID: "work",
                previousCount: 19,
                currentCount: 20
            ),
            CategoryMilestonePresentation(
                categoryID: "food",
                previousCount: 18,
                currentCount: 23
            )
        ])
        #expect(replay.isEmpty)
    }

    @Test func baselinesAreIsolatedPerUser() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        let userACrossing = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        let userBFirstObservation = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-b"
        )

        #expect(!userACrossing.isEmpty)
        #expect(userBFirstObservation.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CategoryMilestoneTrackerTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }
}

struct Tab2MilestoneLifecycleTests {

    @Test func milestoneEmphasisScalesOnlyDuringStandardMotionPresentation() {
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: true,
            isEmphasized: true,
            reduceMotion: false
        ) == 1.08)
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: true,
            isEmphasized: true,
            reduceMotion: true
        ) == 1.0)
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: false,
            isEmphasized: true,
            reduceMotion: false
        ) == 1.0)
    }

    @Test func milestoneToastLifetimeIsShorterThanReadingToastLifetime() {
        #expect(AppTheme.Motion.milestoneToastLifetime < AppTheme.Motion.toastLifetime)
    }

    @Test func onboardingPhotoToastLifetimeSitsBetweenMilestoneAndReadingFeedback() {
        #expect(
            AppTheme.Motion.milestoneToastLifetime
                < AppTheme.Motion.onboardingPhotoToastLifetime
        )
        #expect(
            AppTheme.Motion.onboardingPhotoToastLifetime
                < AppTheme.Motion.toastLifetime
        )
    }

    @Test func milestoneToastDescribesReachedCategory() {
        let vm = Tab2HomeViewModel()
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 20,
                unlocked: true
            )
        ])

        let message = vm.milestoneToastMessage(for: [CategoryMilestonePresentation(
            categoryID: "出行交通",
            previousCount: 19,
            currentCount: 20
        )])

        #expect(message == "Getting around reached 20 pops")
    }

    @Test func milestoneToastAggregatesSimultaneousTopicsAtThreshold() {
        let vm = Tab2HomeViewModel()
        let message = vm.milestoneToastMessage(for: [
            CategoryMilestonePresentation(
                categoryID: "出行交通",
                previousCount: 19,
                currentCount: 23
            ),
            CategoryMilestonePresentation(
                categoryID: "饮食",
                previousCount: 18,
                currentCount: 21
            )
        ])

        #expect(message == "2 topics reached 20 pops")
    }

    @Test func pendingPresentationRemainsUntilMatchingPresentationFinishes() {
        let defaults = UserDefaults(suiteName: "Tab2MilestoneLifecycleTests.\(UUID().uuidString)")!
        defer { defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:)) }
        let vm = Tab2HomeViewModel(
            milestoneTracker: CategoryMilestoneTracker(defaults: defaults)
        )

        vm.registerMilestones(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        vm.registerMilestones(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        let expected = [CategoryMilestonePresentation(
            categoryID: "work",
            previousCount: 19,
            currentCount: 20
        )]
        #expect(vm.milestonePresentations == expected)

        vm.finishMilestonePresentations([CategoryMilestonePresentation(
            categoryID: "food",
            previousCount: 19,
            currentCount: 20
        )])
        #expect(vm.milestonePresentations == expected)

        vm.finishMilestonePresentations(expected)
        #expect(vm.milestonePresentations.isEmpty)
    }

    #if DEBUG
    @Test func debugDemoUsesTwoUnlockedCategoriesClosestToThreshold() {
        let categories = [
            Tab2CategoryData(sceneCategory: "工作与学业", wordCount: 12, unlocked: false),
            Tab2CategoryData(sceneCategory: "饮食", wordCount: 34, unlocked: true),
            Tab2CategoryData(sceneCategory: "出行交通", wordCount: 22, unlocked: true)
        ]

        let presentations = Tab2HomeViewModel.debugMilestoneDemoPresentations(
            in: categories
        )

        #expect(presentations == [
            CategoryMilestonePresentation(
                categoryID: "出行交通",
                previousCount: 19,
                currentCount: 20
            ),
            CategoryMilestonePresentation(
                categoryID: "饮食",
                previousCount: 19,
                currentCount: 20
            )
        ])
    }

    @Test func debugDemoCanStartFromAlreadyLoadedData() {
        let vm = Tab2HomeViewModel()
        let categories = [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 22,
                unlocked: true
            )
        ]
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: categories)

        vm.prepareDebugMilestoneDemoFromCurrentData()

        #expect(vm.milestonePresentations == [CategoryMilestonePresentation(
            categoryID: "出行交通",
            previousCount: 19,
            currentCount: 20
        )])
    }

    @Test func freshResponseDoesNotReplayDemoAlreadyStartedFromLoadedData() {
        let vm = Tab2HomeViewModel()
        let categories = [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 22,
                unlocked: true
            )
        ]
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: categories)

        vm.prepareDebugMilestoneDemoFromCurrentData()
        let presentations = vm.milestonePresentations
        vm.finishMilestonePresentations(presentations)
        vm.prepareDebugMilestoneDemoAfterRefresh(categories)

        #expect(vm.milestonePresentations.isEmpty)
    }
    #endif
}
