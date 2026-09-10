import Foundation
import UIKit
import CryptoKit

/// 统一时间线滚动请求模型（单一真实源）
struct TimelineScrollRequest: Equatable, Sendable {
    enum Anchor: Equatable, Sendable {
        case top
        case center
        case bottom
    }

    enum AnimationMode: Equatable, Sendable {
        case instant
        case animated
    }

    enum Reason: Equatable, Sendable {
        case initialEntry        // 冷启动/首次进入页面对齐
        case tabReturn           // 从 Tab2 切回 Tab1 对齐
        case send                // 用户主动发消息
        case retry               // 用户重试
        case finalCardLayout     // loading 替换为卡片/失败行（高度落位）
    }

    let id: UUID
    let targetEntryId: UUID
    let anchor: Anchor
    let animation: AnimationMode
    let reason: Reason
    let entrySessionId: UUID?

    init(
        id: UUID = UUID(),
        targetEntryId: UUID,
        anchor: Anchor,
        animation: AnimationMode,
        reason: Reason,
        entrySessionId: UUID? = nil
    ) {
        self.id = id
        self.targetEntryId = targetEntryId
        self.anchor = anchor
        self.animation = animation
        self.reason = reason
        self.entrySessionId = entrySessionId
    }
}

@Observable
/// @MainActor（审查发现 #5）：SwiftUI 只在主线程渲染 @Observable 状态，而 loadHistory /
/// runGeneration 是非隔离 async——await 之后的续体默认跑在全局执行器上，后台线程改
/// entries 会与渲染竞争（丢更新、闪帧、偶发崩溃）。标 @MainActor 后编译器强制所有
/// 续体跳回主线程。纯静态函数（buildEntries 等）标 nonisolated，保持可随处调用。
@MainActor
final class TodayViewModel {
    enum HistoryLoadError: Error, Equatable {
        case timedOut
    }

    var entries: [TimelineEntry] = []
    var isLoading = false
    var isLoadingHistory = false
    var pendingImage: UIImage?
    /// 输入框草稿文本（双向绑定到 InputBar，由 ViewModel 统一管控生命周期）。
    var inputText: String = ""
    /// 待重试记录存储（可注入，便于单测）；loadHistory 时把记录注入时间线。
    var pendingRetryStore = PendingRetryStore.shared
    /// 本地成功增量存储（可注入，便于单测）：生成成功的「气泡 + 卡片」底稿，
    /// 冷启动先展示、网络全量对齐后按幂等键清除。
    var successStore = LocalSuccessStore.shared
    /// 预设卡落库（可注入，便于单测 presetCard Retry 分支）。
    var presetCardSaver: PresetCardSaving = LivePresetCardSaver()
    /// 无网点 Retry 等场景的轻提示（视图挂 toast，自动消失）。
    var offlineHint: String?
    /// 生成次数额度的共享展示状态：成功响应的 usage 字段、429 裁决都写这里，
    /// Sheet / InputBar 达标态从这读。可注入（单测隔离，不污染全局 shared）。
    var quotaStore = UsageQuotaStore.shared
    /// 最近一次 loadHistory 是否以失败告终（离线/超时/解码失败）。
    /// 只在 entries 仍为空时被视图读取：冷启动无缓存又断网时，时间线会永远空着，
    /// 用户既看不到内容也没有任何重试入口（审查发现）。成功（哪怕解出 0 条记录，
    /// 那是真实的「新账号还没内容」，不是失败）会清掉这个标记。
    var historyLoadFailed = false

    /// 统一滚动请求：单一真实源驱动 TodayView 滚动容器执行确定性定位。
    var pendingScrollRequest: TimelineScrollRequest?

    /// 当前活动的进入首页对齐会话 ID。冷启动或切回 Tab1 时开启；服务器历史对齐完成或用户主动交互后失效。
    private(set) var activeEntrySessionId: UUID?
    /// 用户是否已在当前会话中主动滚动（主动翻看历史）。若为 true，后续服务器异步历史到达时不强拉到底部。
    private(set) var hasUserScrolledInCurrentSession: Bool = false

    let session = ConversationSession()

    private let service: AIServicing
    private let historyDataLoader: (@Sendable () async throws -> Data)?
    private let historyTimeout: Duration
    private let isConnected: () -> Bool
    private let localCache: LocalCache
    private var historyLoadCompletionWaiters: [CheckedContinuation<Void, Never>] = []
    private var inFlightHistoryShowsFailureHint = false
    private var hasLiveActivity = false   // 本次会话是否已产生实时对话（发过消息）
    /// 本会话已展示成功增量的幂等键集合：生成成功时标记 + 注入时标记。
    /// 注入前查重——卡片已在时间线里，再注入会重复（会话内回前台刷新时防重；
    /// onboarding 记录没有服务端消息行 ID 可查，这个集合就是它们唯一的去重钥匙）。
    private var displayedSuccessRequestIds: Set<UUID> = []

    /// AI 数据同意闸门。生产默认读 UserDefaults（AIConsentView 同意后写入的标记）；
    /// 抽成闭包是为了让 send() 的门控可在单元测试里注入，而不依赖全局 UserDefaults。
    private let isConsentGranted: () -> Bool

    // service/isConnected 的默认值改成在 init 体内构造，不写在参数默认值位置：
    // 参数默认值表达式不继承 init 本身的 @MainActor 隔离（即便类型标了 @MainActor 也一样，
    // 这是 Swift 的既有行为），LiveAIService.init() / NetworkMonitor.shared 都是主线程
    // 隔离的，写在参数默认值里会被当成「非隔离上下文里调用主线程隔离 API」报警；
    // init 方法体本身确定跑在 MainActor 上，挪进来就没有这个问题。
    init(service: AIServicing? = nil,
         historyDataLoader: (@Sendable () async throws -> Data)? = nil,
         historyTimeout: Duration = .seconds(8),
         isConnected: (() -> Bool)? = nil,
         isConsentGranted: @escaping () -> Bool = {
             UserDefaults.standard.double(forKey: "ai_consent_accepted_at") > 0
         },
         localCache: LocalCache? = nil) {
        self.service = service ?? LiveAIService()
        self.historyDataLoader = historyDataLoader
        self.historyTimeout = historyTimeout
        self.isConnected = isConnected ?? { NetworkMonitor.shared.isConnected }
        self.isConsentGranted = isConsentGranted
        self.localCache = localCache ?? .shared
        startEntryAlignmentSession(reason: .initialEntry)
    }

    // MARK: - Entry Alignment Session & Scroll Requests

    /// 开启进入首页对齐窗口（冷启动/切回 Tab1 调用）
    func startEntryAlignmentSession(reason: TimelineScrollRequest.Reason = .initialEntry) {
        let sessionId = UUID()
        activeEntrySessionId = sessionId
        hasUserScrolledInCurrentSession = false
        if let last = entries.last {
            postScrollRequest(TimelineScrollRequest(
                targetEntryId: last.id,
                anchor: .bottom,
                animation: .instant,
                reason: reason,
                entrySessionId: sessionId
            ))
        }
    }

    /// 进入对齐会话检查并发送滚动定位（若会话仍有效、用户未滚动，且有 entries）
    func postSessionFinalScrollIfEligible(reason: TimelineScrollRequest.Reason = .initialEntry, closeSession: Bool = false) {
        guard let sessionId = activeEntrySessionId, !hasUserScrolledInCurrentSession, let last = entries.last else {
            if closeSession { activeEntrySessionId = nil }
            return
        }
        postScrollRequest(TimelineScrollRequest(
            targetEntryId: last.id,
            anchor: .bottom,
            animation: .instant,
            reason: reason,
            entrySessionId: sessionId
        ))
        if closeSession {
            activeEntrySessionId = nil
        }
    }

    /// 用户主动垂直滚动或手势交互：立即取消当前进入对齐窗口，防止后续异步数据到达时强拉到底部。
    func userDidScroll() {
        hasUserScrolledInCurrentSession = true
        activeEntrySessionId = nil
    }

    /// 用户点击/切回 Tab1 激活通知
    func activateTab(token: UUID) {
        startEntryAlignmentSession(reason: .tabReturn)
    }

    /// 发布统一滚动请求（新请求自然覆盖尚未执行的旧请求）
    func postScrollRequest(_ request: TimelineScrollRequest) {
        pendingScrollRequest = request
    }

    /// 视图消费/标记完成该滚动请求
    func consumeScrollRequest(id: UUID) {
        if pendingScrollRequest?.id == id {
            pendingScrollRequest = nil
        }
    }

    /// 取消进入对齐窗口（用户主动发消息、主动重试等场景）
    private func cancelEntryAlignmentSession() {
        activeEntrySessionId = nil
    }

    // MARK: - History

    func loadHistory(showFailureHint: Bool = false) async {
        // 新一轮加载已经开始，上一轮失败提示不再代表当前状态。
        // 若本次仍失败，后续分支会写入本次对应的新提示。
        offlineHint = nil

        if isLoadingHistory {
            guard showFailureHint else { return }
            // 手动刷新加入当前历史请求：不重复发请求，但等待同一结果，并将失败反馈
            // 提升为手动刷新语义，避免刷新控件立即收起却什么都没发生。
            inFlightHistoryShowsFailureHint = true
            await waitForCurrentHistoryLoad()
            return
        }

        isLoadingHistory = true
        inFlightHistoryShowsFailureHint = showFailureHint
        // 解码出的服务端记录幂等键集合：供 seed 去重（D）与失败行/成功增量注入去重用。
        // defer 在函数任意出口执行，这里声明、成功解码后填充。
        var decodedRequestIds: Set<UUID> = []
        // seed 一次性取走（保持 store 的一次性语义）；本次函数内可能注入两轮：
        // 网络前先展示，网络对齐整列替换后由 defer 兜底重新评估。
        let seed = OnboardingSeedStore.shared.entries
        let seedRequestId = OnboardingSeedStore.shared.requestId
        OnboardingSeedStore.shared.entries = []
        OnboardingSeedStore.shared.requestId = nil
        var seedAlreadyShown = false
        defer {
            // 网络对齐若整列替换过时间线（entries = buildEntries），此前注入的本地内容
            // 已被冲掉 → 按服务器幂等键去重后兜底重注入。
            // First launch after onboarding: inject seed entries if Tab1 is still empty.
            // Own-photo path: server already has the record, entries won't be empty.
            // Preset-card path — only when the server save FAILED at onboarding (the seed
            // is written solely in that case): server has nothing, so seed = [userBubble +
            // aiCard] fills the gap. Save SUCCEEDED: the pair's message rows ARE in server
            // history under this request_id; Tab1 shows them from the server and the S1
            // record is stale-cleared on the first alignment — no seed involved.
            if !seedAlreadyShown,
               Self.shouldInjectSeed(
                seedEntries: seed,
                seedRequestId: seedRequestId,
                serverRequestIds: decodedRequestIds
            ) {
                entries = entries + seed
            }
            // 断网待重试记录 + Tab1 持久化失败行：本地「未成功内容」始终展示（杀 app 不丢）；
            // 幂等键已出现在服务端历史的记录跳过（重试成功但清理未跑完的竞态）。
            injectPendingRetry(serverRequestIds: decodedRequestIds)
            // 本地成功增量：对齐已带回的清除；未被对齐冲掉的按幂等去重后不重复注入。
            injectLocalSuccesses(serverRequestIds: decodedRequestIds)
            // 最终结算：时间线全貌（服务端历史 + 本地重试与增量）全部注入落定后，
            // 若对齐会话仍有效且用户未主动翻看历史，无动画定位到最终的 entries.last 并关闭会话。
            postSessionFinalScrollIfEligible(reason: .initialEntry, closeSession: true)
            finishCurrentHistoryLoad()
        }

        // 1) 先读本地缓存并立即渲染——仅当时间线还空着、且本次会话未产生实时对话。
        //    有缓存 → 用户瞬间看到历史，不再是空白/骨架。
        if entries.isEmpty, !hasLiveActivity,
           let cached = await localCache.load(key: .messages),
           let records = try? Self.decodeRecords(from: cached) {
            entries = Self.buildEntries(from: records)
            // 缓存同样填充幂等键集合：离线首启时也按「服务端正本」去重
            // （缓存即上次成功同步的服务端历史）。
            decodedRequestIds = Set(records.compactMap(\.requestId))
            postSessionFinalScrollIfEligible(reason: .initialEntry, closeSession: false)
        }

        // 2) S2 本地内容先拿出来：seed + 失败行 + 成功增量一律在缓存渲染后、
        //    网络请求前注入——「手里有的立刻看，没有的才打电话」。
        if Self.shouldInjectSeed(
            seedEntries: seed,
            seedRequestId: seedRequestId,
            serverRequestIds: decodedRequestIds
        ) {
            entries = entries + seed
            seedAlreadyShown = true
        }
        injectPendingRetry(serverRequestIds: decodedRequestIds)
        injectLocalSuccesses(serverRequestIds: decodedRequestIds)
        // 无论步骤 1 是否已用缓存渲染过 entries：本步注入的 seed / 失败行 / 本地
        // 成功增量若按写作时刻排在原 entries.last 之后（如上次杀 app 前刚生成成功
        // 但缓存文件还没来得及写入新内容），会成为新的真实底部——必须在这里重新
        // 对齐一次，否则用户会先看到缓存渲染时的旧底部，要等网络请求返回、defer
        // 兜底纠正才跳到真正的最新内容（表现为「刚进 App 不是最新内容，要等一下」）。
        // postSessionFinalScrollIfEligible 内部已做全部必要 guard（会话仍开启、
        // 用户未主动滚动、entries 非空）。即使目标未变也会发布一个新请求并覆盖尚未
        // 消费的旧请求；这是为了让本步注入后的最终目标成为唯一待执行请求，并非 no-op。
        postSessionFinalScrollIfEligible(reason: .initialEntry, closeSession: false)

        // 3) 后台向服务器请求最新数据，对齐正本（查新增/删除）
        if !isConnected() {
            historyLoadFailed = true
            activeEntrySessionId = nil
            if inFlightHistoryShowsFailureHint {
                offlineHint = Self.historyRefreshFailureMessage(isConnected: false)
            }
            return
        }

        let data: Data
        do {
            let loader = historyDataLoader
            let timeout = historyTimeout
            data = try await Self.withTimeout(timeout) {
                if let loader {
                    return try await loader()
                }
                return try await Self.fetchMessageData()
            }
        } catch is CancellationError {
            // 生命周期取消（例如视图重建）不是请求失败，不向用户展示错误。
            return
        } catch {
            // 静默降级：拉历史失败就继续显示本地缓存，不弹任何提示。
            // 是否「离线」由 NetworkMonitor 的真实网络状态决定，不再把「这一次请求失败」
            // 误判成离线——后端报错 / 超时时用户网络可能完全正常（例如刚成功生成过内容）。
            print("[TodayVM] loadHistory error (keeping cache):", error)
            historyLoadFailed = true
            activeEntrySessionId = nil
            if inFlightHistoryShowsFailureHint {
                offlineHint = Self.historyRefreshFailureMessage(isConnected: isConnected())
            }
            return
        }

        let records: [MessageRecord]
        do {
            records = try Self.decodeRecords(from: data)
        } catch {
            // 手动刷新拿到无法解析的数据，也属于本次刷新失败；后台加载仍保持静默。
            historyLoadFailed = true
            activeEntrySessionId = nil
            if inFlightHistoryShowsFailureHint {
                offlineHint = Self.historyRefreshFailureMessage(isConnected: isConnected())
            }
            return
        }

        // 解码成功——哪怕这批是 0 条记录，那也是「新账号还没内容」的真实状态，不是失败。
        historyLoadFailed = false
        if records.isEmpty {
            activeEntrySessionId = nil
        }

        // 解码成功才更新缓存——防止服务器偶发坏数据污染本地缓存导致下次启动空屏
        await localCache.save(data, key: .messages)
        decodedRequestIds = Set(records.compactMap(\.requestId))

        // 本地成功副本会在下方历史确认时清理（含 Documents 中的原图），而服务器回放
        // 只有远程签名 URL。先按服务器的稳定 Storage 路径把本地原图交接给图片缓存，
        // 历史替换后 CachedRemoteImage 会在首帧命中它，不出现「照片 → 加载块 → 照片」。
        promoteConfirmedLocalPhotosToImageCache(records)

        // 放行判定见 shouldReplaceHistory（审查发现 #12）：生成在途 / 本会话已有实时
        // 对话 / 服务端快照缺了会话已展示的幂等键，三者任一命中都不整列替换。
        guard Self.shouldReplaceHistory(
            isLoading: isLoading,
            hasLiveActivity: hasLiveActivity,
            displayedSuccessRequestIds: displayedSuccessRequestIds,
            serverRequestIds: decodedRequestIds
        ) else { return }

        entries = Self.buildEntries(from: records)
        seedAlreadyShown = false   // 整列替换过：defer 兜底需重新评估本地注入

        print("[TodayVM] loaded \(records.count) records → \(entries.count) entries")
        preloadRecentImages(records)
    }

    private func waitForCurrentHistoryLoad() async {
        await withCheckedContinuation { continuation in
            guard isLoadingHistory else {
                continuation.resume()
                return
            }
            historyLoadCompletionWaiters.append(continuation)
        }
    }

    private func finishCurrentHistoryLoad() {
        isLoadingHistory = false
        inFlightHistoryShowsFailureHint = false
        let waiters = historyLoadCompletionWaiters
        historyLoadCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }



    /// 把历史记录重建为时间线（含按天插入日期分隔符）。
    /// 分组按含年份的 dayKey（跨年同 "MMM d" 文案不会误并成一组）；分隔符 ID 由
    /// dayKey 确定性派生——缓存渲染与网络正本两次重建产出相同 ID，SwiftUI diff
    /// 视其为同一节点，不再「删旧插新」引发整列重排抖动。
    nonisolated static func buildEntries(from records: [MessageRecord]) -> [TimelineEntry] {
        var result: [TimelineEntry] = []
        var lastDayKey: String?
        for record in records {
            let key = dayKey(for: record.createdAt)
            if key != lastDayKey {
                result.append(TimelineEntry(
                    id: deterministicSeparatorId(for: key), createdAt: record.createdAt,
                    content: .dateSeparator(dayLabel(for: record.createdAt))
                ))
                lastDayKey = key
            }
            if let entry = record.asTimelineEntry() {
                result.append(entry)
            }
        }
        return result
    }

    /// 背景预载最新 15 张图片，新→旧顺序；命中即跳过，失败安全。
    /// 这一步让联网时看过的图片进入磁盘缓存，之后离线也能显示。
    private func preloadRecentImages(_ records: [MessageRecord]) {
        Task(priority: .background) {
            let recent = records.suffix(15).reversed()
            for record in recent {
                guard let signed = record.signedImageUrl,
                      let path = record.imagePath,
                      ImageCache.shared.get(path) == nil,
                      let url = URL(string: signed),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let img = UIImage(data: data)
                else { continue }
                ImageCache.shared.set(img, forKey: path)
            }
        }
    }

    /// 将刚生成成功的本地照片移交给稳定图片缓存。服务端的 storage path 是跨重签 URL
    /// 不变的身份；以它为键后，后续历史回放、下拉刷新和冷启动均可复用同一张本地图。
    private func promoteConfirmedLocalPhotosToImageCache(_ records: [MessageRecord]) {
        let localRecords = successStore.load()
        for message in records {
            guard message.role == "user",
                  let stableKey = message.imagePath,
                  !stableKey.isEmpty,
                  let localRecord = localRecords.first(where: { local in
                      local.userMessageId == message.id
                          || (message.requestId != nil && local.requestId == message.requestId)
                  }),
                  let image = successStore.bubbleImage(for: localRecord)
            else { continue }

            ImageCache.shared.set(image, forKey: stableKey)
        }
    }

    // MARK: - Send

    /// 同意页弹出前的暂存：用户点了发送但 AI 同意未签，弹出 AIConsentView；
    /// 同意后自动重发，不清空输入框以避免用户重新输入。
    var showAIConsent = false
    private var pendingSendText: String?
    private var pendingSendIsDraft = false

    func send(_ text: String? = nil) async {
        let rawText = text ?? inputText
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        guard !trimmed.isEmpty || image != nil else { return }

        // 未同意 AI 数据处理 → 暂存输入、弹出同意页，不修改任何 UI 状态。
        // 同意后 onConsentAgreed() 自动重发；拒绝则清空暂存，用户可再次尝试。
        guard isConsentGranted() else {
            pendingSendText = rawText
            pendingSendIsDraft = (text == nil)
            showAIConsent = true
            return
        }
        // 同意页关闭后若用户未同意，showAIConsent=false 但 pendingSendText 还在；
        // 下次 send 走到这里时清理掉残留。
        pendingSendText = nil
        pendingSendIsDraft = false
        // 只有发送输入框自身草稿（text == nil）时才清空草稿，
        // 避免外部显式传参（如快捷卡片、推荐词条）误清用户正在输入的文字。
        if text == nil {
            inputText = ""
        }

        hasLiveActivity = true   // 本次会话已有实时对话，后台历史刷新不得覆盖
        cancelEntryAlignmentSession()

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed

        ensureTodaySeparator()

        let bubbleText = textToSend ?? (image != nil ? "Describe this image" : nil)
        let bubbleEntry = TimelineEntry.userBubble(text: bubbleText, image: image)
        entries.append(bubbleEntry)
        pendingImage = nil

        postScrollRequest(TimelineScrollRequest(
            targetEntryId: bubbleEntry.id,
            anchor: .bottom,
            animation: .animated,
            reason: .send
        ))

        // 本次尝试的幂等键：失败后重试复用同一个，服务端按 request_id 去重——
        // 超时重试只会拿回第一次已落库的内容，不会生成第二组（修复重复卡）。
        let requestId = UUID()
        await runGeneration(text: textToSend, image: image, userBubbleEntryId: bubbleEntry.id, requestId: requestId)
    }

    /// 用户在 AIConsentView 点击"同意"后调用：清暂存、自动重发。
    func onConsentAgreed() {
        showAIConsent = false
        guard let text = pendingSendText else { return }
        let isDraft = pendingSendIsDraft
        pendingSendText = nil
        pendingSendIsDraft = false
        // 只有当暂存的请求来源于输入框草稿时，才在放行时清空草稿；
        // 若来源于外部显式传参（如快捷卡片推荐词条），则绝不误清输入框内的用户草稿。
        if isDraft {
            inputText = ""
        }
        Task { await send(text) }
    }

    /// 用户点击"重试"：复用原请求的幂等键重新发起生成——服务端同 request_id 不会重复
    /// 落库，超时重试只会拿回第一次已落库的内容（修复重复卡）。
    /// 摆放统一为「原位」（方案丙 · 微信式写作时刻语义）：客户端把气泡的原始发送时刻
    /// 一并发给服务器，服务器按该时刻落库（user 行 = 写作时刻，assistant 行 = +1ms），
    /// 因此卡片放回气泡原位与服务器时间线一致——回放与全新落库行为相同，刷新永不跳。
    func retrySend(text: String?, image: UIImage?, failedEntryId: UUID, requestId: UUID?, bubbleEntryId: UUID?) async {
        // 防重入：生成期间（isLoading）连点 Retry 只发起一次，避免双 loading / 双卡。
        // InputBar 发送按钮同样被 isLoading 禁用，send 与 retry 也互斥。
        guard !isLoading else { return }
        cancelEntryAlignmentSession()
        entries.removeAll { $0.id == failedEntryId }

        // 重试期间把视图锚在原地：生成动画也放在气泡正下方
        if let bubbleId = bubbleEntryId {
            postScrollRequest(TimelineScrollRequest(
                targetEntryId: bubbleId,
                anchor: .center,
                animation: .animated,
                reason: .retry
            ))
        }

        let bubble = bubbleEntryId.flatMap { id in entries.first(where: { $0.id == id }) }
        let card = await runGeneration(
            text: text,
            image: image,
            userBubbleEntryId: bubbleEntryId,   // 被拒时气泡就地转 userRejected；失败时新 sendFailed 行沿用
            failureMode: .sendFailed,
            insertCard: false,                   // 成功只移除 loading，卡片由本方法统一布置
            requestId: requestId,                // 复用原幂等键；不传 requiredDurableRequestId（那是断网待重试记录的持久化校验，Tab1 路径不需要）
            originalCreatedAt: bubble?.createdAt,  // 写作时刻：服务器按它落库，原位稳定
            loadingAnchorId: bubbleEntryId,      // 生成中动画出现在气泡正下方（原地），不是屏幕底部
            finalAnchor: .center,
            finalReason: .retry
        )
        guard let card else { return }

        // 重试成功：清除该幂等键的持久化失败行（含照片文件）。
        // 服务器已落库，重启后从历史回放，无需再注入失败行。
        if let requestId {
            pendingRetryStore.removeTab1ByRequestId(requestId)
        }

        let cardEntry = TimelineEntry.aiCard(card)
        if let bubbleId = bubbleEntryId,
           let idx = entries.firstIndex(where: { $0.id == bubbleId }) {
            entries.insert(cardEntry, at: idx + 1)
        } else {
            entries.append(cardEntry)
        }
        postScrollRequest(TimelineScrollRequest(
            targetEntryId: cardEntry.id,
            anchor: .center,
            animation: .animated,
            reason: .retry
        ))
    }

    /// 把持久化记录注入时间线：
    /// - D 去重（统一规则）：幂等键已出现在服务端历史的记录 → 服务端已原子落库完整内容
    ///   （onboarding 响应迟到误判失败 / Tab1 重试成功但本地清理未跑完），本地副本不再
    ///   注入并清除（含照片文件），否则与服务端回放重复。
    /// - onboarding（photo/presetCard）：追加到最新端（幂等：已有同 id 条目则跳过）。
    ///   服务端历史按 created_at 升序返回，视图自动滚到末尾，必须追加在末尾才在视口内。
    /// - Tab1 失败行：按写作时刻归位为「气泡 + sendFailed 行」对（杀 app 重启不丢）。
    ///   插入点 = 第一条 created_at 晚于写作时刻的条目之前；正撞上同一天的日期标题
    ///   时插到标题之下；插入点前不是该日的标题则补一个，保持按天分组。
    func injectPendingRetry(serverRequestIds: Set<UUID> = []) {
        // 审查发现 #13（失败行整会话残留）：服务端其实已落库（超时误判失败/他处重试
        // 成功）时，hasLiveActivity 会挡住本会话的整列替换，屏幕上的失败行永不消失。
        // 失败行携带 requestId：服务器历史里已有它 → 这条失败信息是错的，移除。
        // 气泡保留——消息确实发出去了；卡片内容在下次冷启动随正本回放出现（会话内
        // 点 Retry 依旧可原位换回卡片）。
        if !serverRequestIds.isEmpty {
            entries.removeAll { entry in
                if case .sendFailed(_, _, let requestId, _) = entry.content {
                    return requestId.map(serverRequestIds.contains) ?? false
                }
                return false
            }
        }
        let all = pendingRetryStore.load()
        let stale = all.filter { record in
            record.requestId.map(serverRequestIds.contains) ?? false
        }
        for record in stale {
            pendingRetryStore.remove(id: record.id)   // 服务端已有正本；本地副本（含照片文件）清除
        }
        // 跨 store 去重（审查发现 #2）：同 requestId 已有本地成功记录 → 成功侧才是真相
        // （重试成功与失败记录清除之间的杀进程窗口，两个 store 各留一条）。失败侧不注入，
        // 记录保留在 store，下次联网后由 stale 检查自然清除（服务端历史已含该幂等键）。
        let successRequestIds = Set(successStore.load().compactMap(\.requestId))
        let pending = all.filter { record in
            !stale.contains { $0.id == record.id }
                && !(record.requestId.map(successRequestIds.contains) ?? false)
        }
        for record in pending where record.source != .tab1 && !entries.contains(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) {
            entries.append(TimelineEntry.pendingRetry(record))
        }
        // 生成在途（isLoading）跳过 tab1 注入：重试已把失败行临时移除、由本次尝试
        // 负责结局——此刻注入会凭空多出一对「气泡 + 失败行」幽灵（成功路径只清
        // 本地记录、不清幽灵行，它会永远留在屏上）。跳过是安全的：本次尝试成功会
        // 清除持久化记录，失败会自行重建失败行。
        // 注意：非 tab1 的 pendingRetry 行在生成期间仍保留在时间线（幂等守卫按行 id
        // 跳过），不受此窗口影响。
        guard !isLoading else { return }
        // 幂等保护：entries 里已有同 requestId 的 sendFailed 行 → 这对「气泡 + 失败行」
        // 已注入过（本会话内二次 loadHistory，如回前台刷新；或发送失败当场生成的行）→
        // 跳过，避免同一失败消息重复展示、出现两个可点的 Retry 入口。
        // .tab1 记录恒带 requestId（saveTab1 必填），无键的旧式记录照旧注入。
        let injectedRequestIds = Set(entries.compactMap { entry -> UUID? in
            if case .sendFailed(_, _, let requestId, _) = entry.content {
                return requestId
            }
            return nil
        })
        let tab1Records = pending.filter { $0.source == .tab1 }
            .filter { record in
                guard let requestId = record.requestId else { return true }
                return !injectedRequestIds.contains(requestId)
            }
            .sorted { $0.createdAt < $1.createdAt }
        for record in tab1Records {
            let image = pendingRetryStore.photoImage(for: record)
            let bubbleId = UUID()
            let bubble = TimelineEntry(
                id: bubbleId, createdAt: record.createdAt,
                content: .userBubble(
                    text: record.text ?? "Describe this image", image: image,
                    imageUrl: nil, imageStableKey: nil
                )
            )
            let failed = TimelineEntry(
                id: UUID(), createdAt: record.createdAt,
                content: .sendFailed(
                    text: record.text, image: image,
                    requestId: record.requestId, bubbleEntryId: bubbleId
                )
            )
            insertChronologically(bubble: bubble, companion: failed, at: record.createdAt)
        }
    }

    /// 本地成功增量注入（S1 读侧）：与失败行同构的「气泡 + 卡片」对，按写作时刻归位。
    /// 三重去重：
    /// - 幂等键已在服务端历史 → 服务器正本已带回（或即将带回），本地副本清除；
    /// - 气泡 id（=服务端消息行 id，Tab1 路径才有）已在时间线 → 已展示，跳过；
    /// - requestId 在本会话已生成成功（displayedSuccessRequestIds）→ 卡片已在时间线，跳过。
    func injectLocalSuccesses(serverRequestIds: Set<UUID> = []) {
        let all = successStore.load()
        let stale = all.filter { serverRequestIds.contains($0.requestId) }
        for record in stale {
            successStore.remove(id: record.id)
        }
        let records = all.filter { record in
            !stale.contains { $0.id == record.id }
        }
        .sorted { $0.createdAt < $1.createdAt }
        for record in records {
            if let userMessageId = record.userMessageId,
               entries.contains(where: { $0.id == userMessageId }) {
                continue   // 服务端回放/本会话生成已在时间线
            }
            if displayedSuccessRequestIds.contains(record.requestId) {
                continue   // 本会话刚生成成功，卡片已在时间线
            }
            guard let card = successStore.card(for: record) else {
                // 坏记录（防御，审查发现 #7）：跳过注入但保留本地副本——服务端是正本，
                // 联网对齐后由 stale 检查清除；删除则会不可逆地毁掉「服务端行缺失」
                // 异常场景（如 App 升级 schema 变化）下用户唯一的本地底稿。
                continue
            }
            // 注入即标记：无 userMessageId 的记录（onboarding 照片/预设卡）此前没有
            // 去重钥匙——同一次 loadHistory 的「网络前注入 + defer 兜底」会注入两遍、
            // 每次回前台再翻倍。标记后本会话内每条记录只注入一次（杀 app 重开集合清空，
            // 未获服务端确认的记录下次启动照常注入一次，内容不丢）。
            displayedSuccessRequestIds.insert(record.requestId)
            let bubble = TimelineEntry(
                id: record.userMessageId ?? UUID(), createdAt: record.createdAt,
                content: .userBubble(
                    text: record.text ?? "Describe this image",
                    image: successStore.bubbleImage(for: record),
                    imageUrl: nil, imageStableKey: record.presetImageName
                )
            )
            let cardEntry = TimelineEntry(
                id: record.assistantMessageId ?? UUID(), createdAt: record.createdAt,
                content: .aiCard(card)
            )
            insertChronologically(bubble: bubble, companion: cardEntry, at: record.createdAt)
        }
    }

    /// 把「气泡 + 伴生行」对按写作时刻插入时间线（失败行/成功卡共用）：
    /// 插入点 = 第一条 createdAt 晚于写作时刻的条目之前；正撞上同一天的日期标题时
    /// 插到标题之下；插入点前没有该日标题则补一个（确定性 ID），保持按天分组。
    private func insertChronologically(bubble: TimelineEntry, companion: TimelineEntry, at date: Date) {
        let key = Self.dayKey(for: date)
        var insertAt = entries.firstIndex(where: { $0.createdAt > date }) ?? entries.count
        if insertAt < entries.count,
           case .dateSeparator = entries[insertAt].content,
           Self.dayKey(for: entries[insertAt].createdAt) == key {
            insertAt += 1
        }
        // 该日的标题已存在于插入点之前 → 不重复补；否则补一个（保持按天分组）。
        // 日期标题按天唯一且按时间序排列，「前面是否存在」即等价于「这一天有没有标题」。
        // 按 dayKey（含年份）判断：跨年同文案（"Aug 22"）不误判为同一天。
        let hasDaySeparator = entries[..<insertAt].contains {
            if case .dateSeparator = $0.content { return Self.dayKey(for: $0.createdAt) == key }
            return false
        }
        var toInsert: [TimelineEntry] = []
        if !hasDaySeparator {
            // 与 buildEntries 同源的确定性 ID：下次刷新重建后是同一节点，无重排
            toInsert.append(TimelineEntry(
                id: Self.deterministicSeparatorId(for: key), createdAt: date,
                content: .dateSeparator(Self.dayLabel(for: date))
            ))
        }
        toInsert.append(contentsOf: [bubble, companion])
        entries.insert(contentsOf: toInsert, at: insertAt)
    }

    /// 待重试记录 Retry：photo 走 AI 生成；presetCard 走静态卡 + 落库。
    /// 防重入（isLoading 全程占用，刷新不在此期间替换时间线）；成功后把记录就地替换为
    /// 「图片气泡 + 卡片」（与 Tab1 正常输入输出一致，图片不消失）；失败保留记录（用户可再试）。
    func retryPending(record: PendingRetryRecord) async {
        guard !isLoading else { return }
        cancelEntryAlignmentSession()
        switch record.source {
        case .tab1:
            return   // 构造上不可达：tab1 记录以「气泡 + 失败行」注入，重试走 retrySend
        case .photo:
            guard let image = pendingRetryStore.photoImage(for: record) else { return }
            let retryRecord: PendingRetryRecord
            do {
                retryRecord = try pendingRetryStore.ensureRequestId(for: record.id)
            } catch {
                return
            }
            guard let requestId = retryRecord.requestId else { return }
            // runGeneration 自行管理 isLoading（期间刷新被 guard 挡住，不替换时间线）
            let card = await runGeneration(
                text: nil,
                image: image,
                userBubbleEntryId: nil,
                failureMode: .silent,
                insertCard: false,
                requestId: requestId,
                requiredDurableRequestId: requestId
            )
            if let card {
                // S1 成功增量由 runGeneration 统一写入（requestId 非空即写，本路径已带），
                // 此处无需重复——与 presetCard 分支不同，后者不走 runGeneration 才需单独写。
                pendingRetryStore.remove(id: record.id)
                replacePendingRetryWithBubbleAndCard(record: record, image: image, card: card)
            }
        case .presetCard:
            guard let card = PresetCard.all.first(where: { $0.id == record.presetCardId }) else { return }
            let retryRecord: PendingRetryRecord
            do {
                retryRecord = try pendingRetryStore.ensureRequestId(for: record.id)
            } catch {
                return
            }
            guard let requestId = retryRecord.requestId else { return }
            // 预设卡分支显式占用 isLoading：落库期间回前台刷新不会替换时间线，
            // 避免「记录已删、卡片未插」的两头落空竞态（生产验证）。
            isLoading = true
            let saved = await presetCardSaver.save(card: card, requestId: requestId)
            isLoading = false
            if saved {
                pendingRetryStore.remove(id: record.id)
                // S1 生成即落本地：预设卡落库成功 → 成功增量（asset 图 + 静态卡），
                // 冷启动无需等网络全量拉取。
                successStore.saveOnboardingPreset(
                    imageName: card.imageName, requestId: requestId,
                    createdAt: record.createdAt, card: card.staticCard
                )
                displayedSuccessRequestIds.insert(requestId)
                replacePendingRetryWithBubbleAndCard(record: record, image: UIImage(named: card.imageName), card: card.staticCard)
            }
        }
    }

    /// 把待重试记录就地替换为「图片气泡 + 卡片」——图片不再消失，形态与正常输入一致。
    /// 若时间线已找不到记录行（如刷新重建过），兜底追加到末尾——待重试记录本就
    /// 注入在最新端（视图停在底部），插 index 0 会让结果出现在历史最顶、与「原位」语义相反。
    private func replacePendingRetryWithBubbleAndCard(record: PendingRetryRecord, image: UIImage?, card: AICard) {
        guard let idx = entries.firstIndex(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) else {
            entries.append(TimelineEntry.userBubble(text: "Describe this image", image: image))
            let cardEntry = TimelineEntry.aiCard(card)
            entries.append(cardEntry)
            postScrollRequest(TimelineScrollRequest(
                targetEntryId: cardEntry.id,
                anchor: .bottom,
                animation: .animated,
                reason: .finalCardLayout
            ))
            return
        }
        let entryId = entries[idx].id
        let createdAt = entries[idx].createdAt
        entries[idx] = TimelineEntry(
            id: entryId, createdAt: createdAt,
            content: .userBubble(text: "Describe this image", image: image, imageUrl: nil, imageStableKey: nil)
        )
        let cardEntry = TimelineEntry(id: UUID(), createdAt: createdAt, content: .aiCard(card))
        entries.insert(cardEntry, at: idx + 1)
        postScrollRequest(TimelineScrollRequest(
            targetEntryId: cardEntry.id,
            anchor: .bottom,
            animation: .animated,
            reason: .finalCardLayout
        ))
    }

    /// 生成失败时 loading 条目的处置方式。
    /// - sendFailed：换成可点击重试的 sendFailed 行（Tab1 常规发送路径）
    /// - silent：直接移除（待重试记录路径——pendingRetry 行保持唯一重试入口，不出现双入口）
    enum RunGenerationFailure {
        case sendFailed
        case silent
    }

    /// 发起一次 AI 生成：追加 loading → 成功换成卡片 / 失败按 failureMode 处置。
    /// 用户气泡由调用方负责，这里只管"生成"这一步，故 send 与 retry 可复用。
    /// 返回生成的卡片（nil = 失败）：调用方据此判定「本次生成」成败，
    /// 不能靠数时间线里的 aiCard 数量——并发 loadHistory 会污染计数。
    /// `insertCard: false` 时成功只移除 loading 并返回卡片，由调用方就地插入
    /// （重试与待重试记录路径：气泡与卡片就地落到原记录位置）。
    /// `loadingAnchorId` 非空时 loading 插到该条目之后（重试原地），否则追加末尾。
    @discardableResult
    private func runGeneration(
        text: String?,
        image: UIImage?,
        userBubbleEntryId: UUID?,
        failureMode: RunGenerationFailure = .sendFailed,
        insertCard: Bool = true,
        requestId: UUID? = nil,
        requiredDurableRequestId: UUID? = nil,
        originalCreatedAt: Date? = nil,
        loadingAnchorId: UUID? = nil,
        finalAnchor: TimelineScrollRequest.Anchor = .bottom,
        finalReason: TimelineScrollRequest.Reason = .finalCardLayout
    ) async -> AICard? {
        let loadingEntry = TimelineEntry.aiLoading()
        if let anchorId = loadingAnchorId,
           let anchorIdx = entries.firstIndex(where: { $0.id == anchorId }) {
            entries.insert(loadingEntry, at: anchorIdx + 1)
        } else {
            entries.append(loadingEntry)
            // 普通发送路径（在末尾追加 loading）：立即将滚动目标推进到 loadingEntry，
            // 确保生成中呼吸动画立刻进入视口，不被气泡挤出屏幕或被输入框遮挡。
            postScrollRequest(TimelineScrollRequest(
                targetEntryId: loadingEntry.id,
                anchor: .bottom,
                animation: .animated,
                reason: .send
            ))
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let envelope = try await service.generate(
                text: text,
                image: image,
                context: session.currentContext,
                presetCardId: nil,
                requestId: requestId,
                source: "tab1",
                originalCreatedAt: originalCreatedAt
            )
            if let requiredDurableRequestId,
               (envelope.requestId != requiredDurableRequestId
                || envelope.userMessageId == nil
                || envelope.assistantMessageId == nil
                || envelope.materialId == nil) {
                entries.removeAll { $0.id == loadingEntry.id }
                return nil
            }
            if insertCard {
                replace(loadingEntry.id, with: .aiCard(envelope.card))
                postScrollRequest(TimelineScrollRequest(
                    targetEntryId: loadingEntry.id,
                    anchor: finalAnchor,
                    animation: .animated,
                    reason: finalReason
                ))
            } else {
                entries.removeAll { $0.id == loadingEntry.id }
            }
            // S1 生成即落本地：成功增量持久化（文字/照片 + 卡片 + 服务端消息行 ID），
            // 冷启动在服务器全量拉回前即可展示。持久化失败静默——不打断成功体验。
            if let requestId {
                let bubbleCreatedAt = userBubbleEntryId.flatMap { id in
                    entries.first(where: { $0.id == id })?.createdAt
                } ?? originalCreatedAt ?? loadingEntry.createdAt
                try? successStore.saveTab1(
                    text: text, image: image, requestId: requestId,
                    userMessageId: envelope.userMessageId,
                    assistantMessageId: envelope.assistantMessageId,
                    createdAt: bubbleCreatedAt, card: envelope.card
                )
                displayedSuccessRequestIds.insert(requestId)
            }
            let userContent = text ?? (image != nil ? "[photo]" : nil)
            if let userContent {
                session.onAIResponseReceived(
                    userContent: userContent,
                    cardType: envelope.card.cardTypeName,
                    cardContent: envelope.card.contextRepresentation,
                    image: image
                )
            }
            // 服务器报告的最新用量（含本次生成）与落账后裁决（方案 B）：直接进
            // 共享额度状态——Sheet 打开时无需等一次网络往返就能看到最新数字；
            // allowed=false 时额度在本次生成用尽，输入栏立即锁定。
            if let usage = envelope.usage {
                quotaStore.apply(usage: usage)
            }
            return envelope.card
        } catch let AIServiceError.dailyLimitReached(used, limit, _) {
            // 服务端额度裁决：移除 loading，不产生 sendFailed 行（今天重试只会再撞
            // 429），把裁决接进共享额度状态——InputBar 转为达标态（banner + 锁定）。
            // 用户气泡保留：那是用户说过的话，只是服务器拒绝了这次生成。
            entries.removeAll { $0.id == loadingEntry.id }
            quotaStore.applyServerVerdict(used: used, limit: limit, allowed: false)
            return nil
        } catch AIServiceError.contentBlocked {
            // 内容被安全过滤拦截：移除 loading，按 id 定位对应的用户气泡就地转为「被拒」形态
            // （图片 → 占位块；文本 → 原样），不再弹窗、不保留原图。
            entries.removeAll { $0.id == loadingEntry.id }
            if let bubbleId = userBubbleEntryId,
               let idx = entries.firstIndex(where: { $0.id == bubbleId }),
               case .userBubble(let bubbleText, let bubbleImage, let bubbleImageUrl, _) = entries[idx].content {
                entries[idx] = TimelineEntry(
                    id: entries[idx].id,
                    createdAt: entries[idx].createdAt,
                    content: .userRejected(
                        text: bubbleText,
                        wasImage: bubbleImage != nil || bubbleImageUrl != nil
                    )
                )
            } else {
                // 兜底：按 id 找不到气泡（异常路径）时补一条被拒条目
                entries.append(TimelineEntry.userRejected(text: text, wasImage: image != nil))
            }
            return nil
        } catch {
            // 失败（含断网）：常规发送路径保留用户气泡、换成可点击重试的提示，原始输入随 entry 带着以便重发；
            // 待重试记录路径静默移除 loading——pendingRetry 行保持唯一重试入口，不出现第二个入口。
            switch failureMode {
            case .sendFailed:
                // 统一 attempt 持久化：本次失败（文字或照片 + 写作时刻 + 幂等键）写入 store，
                // 杀 app 重启后以「气泡 + 失败行」按写作时刻归位——Tab1 与 onboarding 行为对齐。
                // try? 静默：持久化失败不影响「失败行 + 可重试」的既有 UI 体验。
                if let requestId {
                    // 与成功路径同构的回退链（审查发现 #9）：当前两处调用方气泡必在时间线里、
                    // 按 id 总能查到；未来若出现「无气泡条目的重试入口」（语音/批量补发），
                    // originalCreatedAt 是写作时刻的最后防线。
                    let bubbleCreatedAt = userBubbleEntryId.flatMap { id in
                        entries.first(where: { $0.id == id })?.createdAt
                    } ?? originalCreatedAt ?? loadingEntry.createdAt
                    try? pendingRetryStore.saveTab1(
                        text: text, image: image,
                        requestId: requestId, createdAt: bubbleCreatedAt
                    )
                }
                // 失败行携带本次尝试的幂等键与气泡引用：重试复用同一 requestId，
                // 且成功后能按 bubbleEntryId 把卡片放回气泡原位。
                replace(loadingEntry.id, with: .sendFailed(text: text, image: image, requestId: requestId, bubbleEntryId: userBubbleEntryId))
                postScrollRequest(TimelineScrollRequest(
                    targetEntryId: loadingEntry.id,
                    anchor: finalAnchor,
                    animation: .animated,
                    reason: finalReason
                ))
            case .silent:
                entries.removeAll { $0.id == loadingEntry.id }
            }
            return nil
        }
    }

    // MARK: - Private

    /// 若时间线最后一条日期分隔符不是 "Today"，追加今天的分隔符（仅 send 用；
    /// 重试成功是原位摆放，不产生新的一天）。
    private func ensureTodaySeparator() {
        let today = Self.dayLabel(for: .now)
        let lastSeparator = entries.last(where: {
            if case .dateSeparator = $0.content { return true }
            return false
        })
        // 按 dayKey 判断而非展示文案（审查发现 #3）：跨零点后昨天的分隔符文案同样是
        // "Today"，凭 label 相等会把今天的消息并进昨天的分组。
        if !Self.hasTodaySeparator(lastSeparator: lastSeparator, todayKey: Self.dayKey(for: .now)) {
            // 与 buildEntries 同源的确定性 ID：刷新重建后今天是同一节点，无重排
            entries.append(TimelineEntry(
                id: Self.deterministicSeparatorId(for: Self.dayKey(for: .now)), createdAt: .now,
                content: .dateSeparator(today)
            ))
        }
    }

    private func replace(_ id: UUID, with content: TimelineEntry.Content) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx] = TimelineEntry(id: id, createdAt: entries[idx].createdAt, content: content)
    }

    /// 只取原始响应字节——成功后既用于解码、也用于落盘缓存（两者同一份 Data）
    nonisolated static func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw HistoryLoadError.timedOut
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func fetchMessageData() async throws -> Data {
        var request = URLRequest(url: SupabaseConfig.messagesFunctionURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        try await SupabaseManager.setAuthHeaders(on: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[TodayVM] HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// 把原始字节解码成记录——网络回来的和缓存读出来的走完全相同的这条路径
    nonisolated static func historyRefreshFailureMessage(isConnected: Bool) -> String {
        isConnected
            ? "Unable to sync right now. Pull to try again."
            : "You're offline. Check your connection and try again."
    }

    private nonisolated static func decodeRecords(from data: Data) throws -> [MessageRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return try decoder.decode([MessageRecord].self, from: data)
    }

    /// 历史整列替换的放行判定（纯函数便于单测，审查发现 #12）：三关全过才放行——
    /// 生成在途不放（不打断本次生成）、本会话已有实时对话不放（不覆盖会话内容）、
    /// 服务器快照缺了本会话已展示过的幂等键不放（服务端丢行/快照竞态时替换会把
    /// 会话内已展示的内容冲掉）。注意：删除功能上线后「服务器合法删行」也会触发
    /// 第三关——届时由删除切片统一处理（见 D1-2）。
    nonisolated static func shouldReplaceHistory(
        isLoading: Bool,
        hasLiveActivity: Bool,
        displayedSuccessRequestIds: Set<UUID>,
        serverRequestIds: Set<UUID>
    ) -> Bool {
        !isLoading
            && !hasLiveActivity
            && displayedSuccessRequestIds.isSubset(of: serverRequestIds)
    }

    /// D 去重决策（纯函数便于单测）：seed 的幂等键已出现在服务端历史
    /// → 说明落库其实成功过（1.5s 竞速误判失败），跳过注入避免首屏重复卡。
    /// 无幂等键（旧流程）时照旧注入——宁可重复一次也不吞掉内容。
    nonisolated static func shouldInjectSeed(
        seedEntries: [TimelineEntry],
        seedRequestId: UUID?,
        serverRequestIds: Set<UUID>
    ) -> Bool {
        guard !seedEntries.isEmpty else { return false }
        guard let seedRequestId else { return true }
        return !serverRequestIds.contains(seedRequestId)
    }

    private nonisolated static func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// 含年份的日历日键（"yyyy-MM-dd"）：用于按天分组与日期分隔符的确定性 ID。
    /// 与 dayLabel 分开：label 是无年份的展示文案（"Aug 22"），跨年会重名，
    /// 不能拿来做分组比较或 ID 种子。
    private nonisolated static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 是否已含「今天」的分隔符：按 dayKey 判断而非展示文案（审查发现 #3）——
    /// 跨零点后昨天的分隔符文案同样是 "Today"，凭 label 会把今天的消息并进昨天的
    /// 分组。纯函数便于单测跨零点场景。
    nonisolated static func hasTodaySeparator(lastSeparator: TimelineEntry?, todayKey: String) -> Bool {
        guard let last = lastSeparator else { return false }
        return dayKey(for: last.createdAt) == todayKey
    }

    /// 由 dayKey 确定性派生 UUID：同一日历日永远得到同一个 ID。
    /// 缓存渲染与网络正本两次重建产出相同分隔符 ID，SwiftUI diff 视其为同一节点
    /// （身份证不变），不再「删旧插新」引发整列重排；SHA256 截 16 字节 = 128 位，
    /// 碰撞概率可忽略。
    nonisolated static func deterministicSeparatorId(for dayKey: String) -> UUID {
        let hash = SHA256.hash(data: Data("date_sep_\(dayKey)".utf8))
        let b = Array(hash.prefix(16))
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
