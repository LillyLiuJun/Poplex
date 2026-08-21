import Foundation
import UIKit

@Observable
final class TodayViewModel {
    var entries: [TimelineEntry] = []
    var isLoading = false
    var isLoadingHistory = false
    var pendingImage: UIImage?
    /// 待重试记录存储（可注入，便于单测）；loadHistory 时把记录注入时间线。
    var pendingRetryStore = PendingRetryStore.shared
    /// 预设卡落库（可注入，便于单测 presetCard Retry 分支）。
    var presetCardSaver: PresetCardSaving = LivePresetCardSaver()
    /// 无网点 Retry 等场景的轻提示（视图挂 toast，自动消失）。
    var offlineHint: String?
    /// 视图滚动锚点：非空时视图滚到对应条目，且跳过「条目变化自动滚到最后一条」。
    /// 重试期间置为气泡 id（留在原地），成功后置为卡片 id；下次 send / 历史替换时清空。
    var scrollTargetId: UUID?
    let session = ConversationSession()

    private let service: AIServicing
    private var hasLiveActivity = false   // 本次会话是否已产生实时对话（发过消息）

    /// AI 数据同意闸门。生产默认读 UserDefaults（AIConsentView 同意后写入的标记）；
    /// 抽成闭包是为了让 send() 的门控可在单元测试里注入，而不依赖全局 UserDefaults。
    private let isConsentGranted: () -> Bool

    init(service: AIServicing = LiveAIService(),
         isConsentGranted: @escaping () -> Bool = {
             UserDefaults.standard.double(forKey: "ai_consent_accepted_at") > 0
         }) {
        self.service = service
        self.isConsentGranted = isConsentGranted
    }

    // MARK: - History

    func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        // 解码出的服务端记录幂等键集合：供 seed 去重（D）与持久化失败行注入去重用。
        // defer 在函数任意出口执行，这里声明、成功解码后填充。
        var decodedRequestIds: Set<UUID> = []
        defer {
            isLoadingHistory = false
            // First launch after onboarding: inject seed entries if Tab1 is still empty.
            // Own-photo path: server already has the record, entries won't be empty.
            // Preset-card path: server has nothing; seed = [userBubble + aiCard] fills the gap.
            let seed = OnboardingSeedStore.shared.entries
            let seedRequestId = OnboardingSeedStore.shared.requestId
            OnboardingSeedStore.shared.entries = []
            OnboardingSeedStore.shared.requestId = nil
            // 弱网竞速去重（D）：seed 的幂等键已在服务端历史里 → 说明落库其实成功过
            // （客户端 1.5s 超时误判失败），注入 seed 会让首屏同一张卡出现两次——
            // 跳过注入，以服务端记录为准。
            if Self.shouldInjectSeed(
                seedEntries: seed,
                seedRequestId: seedRequestId,
                serverRequestIds: decodedRequestIds
            ) {
                entries = entries + seed
            }
            // 断网待重试记录 + Tab1 持久化失败行：本地「未成功内容」始终展示（杀 app 不丢）；
            // 幂等键已出现在服务端历史的记录跳过（重试成功但清理未跑完的竞态）。
            injectPendingRetry(serverRequestIds: decodedRequestIds)
        }

        // 1) 先读本地缓存并立即渲染——仅当时间线还空着、且本次会话未产生实时对话。
        //    有缓存 → 用户瞬间看到历史，不再是空白/骨架。
        if entries.isEmpty, !hasLiveActivity,
           let cached = await LocalCache.shared.load(key: .messages),
           let records = try? Self.decodeRecords(from: cached) {
            entries = Self.buildEntries(from: records)
            // 缓存同样填充幂等键集合：离线首启时也按「服务端正本」去重
            // （缓存即上次成功同步的服务端历史）。
            decodedRequestIds = Set(records.compactMap(\.requestId))
        }

        // 2) 后台向服务器请求最新数据，对齐正本（查新增/删除）
        let data: Data
        do {
            data = try await fetchMessageData()
        } catch {
            // 静默降级：拉历史失败就继续显示本地缓存，不弹任何提示。
            // 是否「离线」由 NetworkMonitor 的真实网络状态决定，不再把「这一次请求失败」
            // 误判成离线——后端报错 / 超时时用户网络可能完全正常（例如刚成功生成过内容）。
            print("[TodayVM] loadHistory error (keeping cache):", error)
            return
        }

        guard let records = try? Self.decodeRecords(from: data) else { return }

        // 解码成功才更新缓存——防止服务器偶发坏数据污染本地缓存导致下次启动空屏
        await LocalCache.shared.save(data, key: .messages)
        decodedRequestIds = Set(records.compactMap(\.requestId))

        // 用户已在本次会话产生实时对话 → 不用历史覆盖，避免打断
        guard !isLoading, !hasLiveActivity else { return }
        scrollTargetId = nil   // 历史重建后恢复默认的「自动滚到最后一条」
        entries = Self.buildEntries(from: records)

        print("[TodayVM] loaded \(records.count) records → \(entries.count) entries")
        preloadRecentImages(records)
    }

    /// 把历史记录重建为时间线（含按天插入日期分隔符）
    private static func buildEntries(from records: [MessageRecord]) -> [TimelineEntry] {
        var result: [TimelineEntry] = []
        var lastDayLabel: String?
        for record in records {
            let dayLabel = dayLabel(for: record.createdAt)
            if dayLabel != lastDayLabel {
                result.append(TimelineEntry(
                    id: UUID(), createdAt: record.createdAt,
                    content: .dateSeparator(dayLabel)
                ))
                lastDayLabel = dayLabel
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

    // MARK: - Send

    /// 同意页弹出前的暂存：用户点了发送但 AI 同意未签，弹出 AIConsentView；
    /// 同意后自动重发，不清空输入框以避免用户重新输入。
    var showAIConsent = false
    private var pendingSendText: String?

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        guard !trimmed.isEmpty || image != nil else { return }

        // 未同意 AI 数据处理 → 暂存输入、弹出同意页，不修改任何 UI 状态。
        // 同意后 onConsentAgreed() 自动重发；拒绝则清空暂存，用户可再次尝试。
        guard isConsentGranted() else {
            pendingSendText = text
            showAIConsent = true
            return
        }
        // 同意页关闭后若用户未同意，showAIConsent=false 但 pendingSendText 还在；
        // 下次 send 走到这里时清理掉残留。
        pendingSendText = nil

        hasLiveActivity = true   // 本次会话已有实时对话，后台历史刷新不得覆盖

        scrollTargetId = nil   // 正常发送恢复默认滚动（追加到末尾 → 自动滚到底）

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed

        ensureTodaySeparator()

        let bubbleText = textToSend ?? (image != nil ? "Describe this image" : nil)
        let bubbleEntry = TimelineEntry.userBubble(text: bubbleText, image: image)
        entries.append(bubbleEntry)
        pendingImage = nil

        // 本次尝试的幂等键：失败后重试复用同一个，服务端按 request_id 去重——
        // 超时重试只会拿回第一次已落库的内容，不会生成第二组（修复重复卡）。
        let requestId = UUID()
        await runGeneration(text: textToSend, image: image, userBubbleEntryId: bubbleEntry.id, requestId: requestId)
    }

    /// 用户在 AIConsentView 点击"同意"后调用：清暂存、自动重发。
    func onConsentAgreed() {
        showAIConsent = false
        guard let text = pendingSendText else { return }
        pendingSendText = nil
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
        entries.removeAll { $0.id == failedEntryId }

        // 重试期间把视图锚在原地：抑制「条目变化自动滚到最后」，生成动画也放在气泡正下方
        scrollTargetId = bubbleEntryId

        let bubble = bubbleEntryId.flatMap { id in entries.first(where: { $0.id == id }) }
        let card = await runGeneration(
            text: text,
            image: image,
            userBubbleEntryId: bubbleEntryId,   // 被拒时气泡就地转 userRejected；失败时新 sendFailed 行沿用
            failureMode: .sendFailed,
            insertCard: false,                   // 成功只移除 loading，卡片由本方法统一布置
            requestId: requestId,                // 复用原幂等键；不传 requiredDurableRequestId（那是断网待重试记录的持久化校验，Tab1 路径不需要）
            originalCreatedAt: bubble?.createdAt,  // 写作时刻：服务器按它落库，原位稳定
            loadingAnchorId: bubbleEntryId       // 生成中动画出现在气泡正下方（原地），不是屏幕底部
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
        scrollTargetId = cardEntry.id   // 结果出现在原位；视图滚到卡片处
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
        let all = pendingRetryStore.load()
        let stale = all.filter { record in
            record.requestId.map(serverRequestIds.contains) ?? false
        }
        for record in stale {
            pendingRetryStore.remove(id: record.id)   // 服务端已有正本；本地副本（含照片文件）清除
        }
        let pending = all.filter { record in
            !stale.contains { $0.id == record.id }
        }
        for record in pending where record.source != .tab1 && !entries.contains(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) {
            entries.append(TimelineEntry.pendingRetry(record))
        }
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
            let dayLabel = Self.dayLabel(for: record.createdAt)
            var insertAt = entries.firstIndex(where: { $0.createdAt > record.createdAt }) ?? entries.count
            if insertAt < entries.count,
               case .dateSeparator(let label) = entries[insertAt].content,
               label == dayLabel {
                insertAt += 1
            }
            // 该日的标题已存在于插入点之前 → 不重复补；否则补一个（保持按天分组）。
            // 日期标题按天唯一且按时间序排列，「前面是否存在」即等价于「这一天有没有标题」。
            let hasDaySeparator = entries[..<insertAt].contains {
                if case .dateSeparator(let label) = $0.content { return label == dayLabel }
                return false
            }
            var toInsert: [TimelineEntry] = []
            if !hasDaySeparator {
                toInsert.append(TimelineEntry(
                    id: UUID(), createdAt: record.createdAt,
                    content: .dateSeparator(dayLabel)
                ))
            }
            toInsert.append(contentsOf: [bubble, failed])
            entries.insert(contentsOf: toInsert, at: insertAt)
        }
    }

    /// 待重试记录 Retry：photo 走 AI 生成；presetCard 走静态卡 + 落库。
    /// 防重入（isLoading 全程占用，刷新不在此期间替换时间线）；成功后把记录就地替换为
    /// 「图片气泡 + 卡片」（与 Tab1 正常输入输出一致，图片不消失）；失败保留记录（用户可再试）。
    func retryPending(record: PendingRetryRecord) async {
        guard !isLoading else { return }
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
            entries.append(TimelineEntry.aiCard(card))
            return
        }
        let entryId = entries[idx].id
        let createdAt = entries[idx].createdAt
        entries[idx] = TimelineEntry(
            id: entryId, createdAt: createdAt,
            content: .userBubble(text: "Describe this image", image: image, imageUrl: nil, imageStableKey: nil)
        )
        entries.insert(TimelineEntry(id: UUID(), createdAt: createdAt, content: .aiCard(card)), at: idx + 1)
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
        loadingAnchorId: UUID? = nil
    ) async -> AICard? {
        let loadingEntry = TimelineEntry.aiLoading()
        if let anchorId = loadingAnchorId,
           let anchorIdx = entries.firstIndex(where: { $0.id == anchorId }) {
            entries.insert(loadingEntry, at: anchorIdx + 1)
        } else {
            entries.append(loadingEntry)
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
            } else {
                entries.removeAll { $0.id == loadingEntry.id }
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
            return envelope.card
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
                    let bubbleCreatedAt = userBubbleEntryId.flatMap { id in
                        entries.first(where: { $0.id == id })?.createdAt
                    } ?? loadingEntry.createdAt
                    try? pendingRetryStore.saveTab1(
                        text: text, image: image,
                        requestId: requestId, createdAt: bubbleCreatedAt
                    )
                }
                // 失败行携带本次尝试的幂等键与气泡引用：重试复用同一 requestId，
                // 且成功后能按 bubbleEntryId 把卡片放回气泡原位。
                replace(loadingEntry.id, with: .sendFailed(text: text, image: image, requestId: requestId, bubbleEntryId: userBubbleEntryId))
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
        let alreadyHasToday: Bool
        if case .dateSeparator(let label) = lastSeparator?.content {
            alreadyHasToday = (label == today)
        } else {
            alreadyHasToday = false
        }
        if !alreadyHasToday {
            entries.append(TimelineEntry(
                id: UUID(), createdAt: .now,
                content: .dateSeparator(today)
            ))
        }
    }

    private func replace(_ id: UUID, with content: TimelineEntry.Content) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx] = TimelineEntry(id: id, createdAt: entries[idx].createdAt, content: content)
    }

    /// 只取原始响应字节——成功后既用于解码、也用于落盘缓存（两者同一份 Data）
    private func fetchMessageData() async throws -> Data {
        var request = URLRequest(url: SupabaseConfig.messagesFunctionURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
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
    private static func decodeRecords(from data: Data) throws -> [MessageRecord] {
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

    /// D 去重决策（纯函数便于单测）：seed 的幂等键已出现在服务端历史
    /// → 说明落库其实成功过（1.5s 竞速误判失败），跳过注入避免首屏重复卡。
    /// 无幂等键（旧流程）时照旧注入——宁可重复一次也不吞掉内容。
    static func shouldInjectSeed(
        seedEntries: [TimelineEntry],
        seedRequestId: UUID?,
        serverRequestIds: Set<UUID>
    ) -> Bool {
        guard !seedEntries.isEmpty else { return false }
        guard let seedRequestId else { return true }
        return !serverRequestIds.contains(seedRequestId)
    }

    private static func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
