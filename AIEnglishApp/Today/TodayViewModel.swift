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
        defer {
            isLoadingHistory = false
            // First launch after onboarding: inject seed entries if Tab1 is still empty.
            // Own-photo path: server already has the record, entries won't be empty.
            // Preset-card path: server has nothing; seed = [userBubble + aiCard] fills the gap.
            let seed = OnboardingSeedStore.shared.entries
            OnboardingSeedStore.shared.entries = []
            if !seed.isEmpty {
                entries = entries + seed
            }
            // 断网待重试记录：本地持久化的「未生成内容」始终展示（杀 app 不丢）。
            injectPendingRetry()
        }

        // 1) 先读本地缓存并立即渲染——仅当时间线还空着、且本次会话未产生实时对话。
        //    有缓存 → 用户瞬间看到历史，不再是空白/骨架。
        if entries.isEmpty, !hasLiveActivity,
           let cached = await LocalCache.shared.load(key: .messages),
           let records = try? Self.decodeRecords(from: cached) {
            entries = Self.buildEntries(from: records)
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

        // 用户已在本次会话产生实时对话 → 不用历史覆盖，避免打断
        guard !isLoading, !hasLiveActivity else { return }
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

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed

        // 若最后一条分隔符不是 "Today"，插入今天的分隔符
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

        let bubbleText = textToSend ?? (image != nil ? "Describe this image" : nil)
        let bubbleEntry = TimelineEntry.userBubble(text: bubbleText, image: image)
        entries.append(bubbleEntry)
        pendingImage = nil

        await runGeneration(text: textToSend, image: image, userBubbleEntryId: bubbleEntry.id)
    }

    /// 用户在 AIConsentView 点击"同意"后调用：清暂存、自动重发。
    func onConsentAgreed() {
        showAIConsent = false
        guard let text = pendingSendText else { return }
        pendingSendText = nil
        Task { await send(text) }
    }

    /// 用户点击"重试"：不重复生成用户气泡（它已在上方保留），仅移除失败提示后重新发起生成。
    func retrySend(text: String?, image: UIImage?, failedEntryId: UUID) async {
        entries.removeAll { $0.id == failedEntryId }
        await runGeneration(text: text, image: image, userBubbleEntryId: nil)
    }

    /// 把持久化的待重试记录注入时间线最新端（幂等：已有同 id 条目则跳过）。
    /// 服务端历史按 created_at 升序返回，视图也会自动滚到末尾；
    /// 因此待重试记录必须追加在末尾，否则刷新后会留在视口外。
    func injectPendingRetry() {
        let pending = pendingRetryStore.load()
        for record in pending where !entries.contains(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) {
            entries.append(TimelineEntry.pendingRetry(record))
        }
    }

    /// 待重试记录 Retry：photo 走 AI 生成；presetCard 走静态卡 + 落库。
    /// 防重入（isLoading 全程占用，刷新不在此期间替换时间线）；成功后把记录就地替换为
    /// 「图片气泡 + 卡片」（与 Tab1 正常输入输出一致，图片不消失）；失败保留记录（用户可再试）。
    func retryPending(record: PendingRetryRecord) async {
        guard !isLoading else { return }
        switch record.source {
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
            // 预设卡分支显式占用 isLoading：落库期间回前台刷新不会替换时间线，
            // 避免「记录已删、卡片未插」的两头落空竞态（生产验证）。
            isLoading = true
            let saved = await presetCardSaver.save(card: card)
            isLoading = false
            if saved {
                pendingRetryStore.remove(id: record.id)
                replacePendingRetryWithBubbleAndCard(record: record, image: UIImage(named: card.imageName), card: card.staticCard)
            }
        }
    }

    /// 把待重试记录就地替换为「图片气泡 + 卡片」——图片不再消失，形态与正常输入一致。
    /// 若时间线已找不到记录行（如刷新重建过），兜底把卡片直接插入顶部，不丢内容。
    private func replacePendingRetryWithBubbleAndCard(record: PendingRetryRecord, image: UIImage?, card: AICard) {
        guard let idx = entries.firstIndex(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) else {
            entries.insert(TimelineEntry.userBubble(text: "Describe this image", image: image), at: 0)
            entries.insert(TimelineEntry.aiCard(card), at: 1)
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
    /// （待重试记录路径：气泡与卡片就地落到原记录位置）。
    @discardableResult
    private func runGeneration(
        text: String?,
        image: UIImage?,
        userBubbleEntryId: UUID?,
        failureMode: RunGenerationFailure = .sendFailed,
        insertCard: Bool = true,
        requestId: UUID? = nil,
        requiredDurableRequestId: UUID? = nil
    ) async -> AICard? {
        let loadingEntry = TimelineEntry.aiLoading()
        entries.append(loadingEntry)
        isLoading = true
        defer { isLoading = false }

        do {
            let envelope = try await service.generate(
                text: text,
                image: image,
                context: session.currentContext,
                presetCardId: nil,
                requestId: requestId,
                source: "tab1"
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
                replace(loadingEntry.id, with: .sendFailed(text: text, image: image))
            case .silent:
                entries.removeAll { $0.id == loadingEntry.id }
            }
            return nil
        }
    }

    // MARK: - Private

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

    private static func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
