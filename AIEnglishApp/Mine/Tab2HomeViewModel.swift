import Foundation

/// Tab2 解锁状态的 UserDefaults 键名——单一真源。
///
/// 键名散落成字面量时，改名只会有一处被改到，其余静默失效
/// （清不掉 = 用户以为重置了、其实没有），故收在这里。
/// 注：Settings 页已退回 main 基线，那边仍是字面量；两处保持同名即可。
enum Tab2Defaults {
    static let permanentlyUnlocked = "tab2_permanently_unlocked"
    static let firstUnlockShown    = "tab2_first_unlock_shown"
}

private let kUnlockedKey         = Tab2Defaults.permanentlyUnlocked
private let kFirstUnlockShownKey = Tab2Defaults.firstUnlockShown

@Observable
final class Tab2HomeViewModel {
    enum HomeLoadError: Error, Equatable {
        case timedOut
        case httpStatus(Int)
    }

    var data: Tab2HomeData?
    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?
    var milestonePresentations: [CategoryMilestonePresentation] = []
    /// 每次首页正本刷新成功后递增；手风琴用它淘汰刷新前的行内词条与在途请求。
    private(set) var categoryWordsRevision = 0

    /// 首次解锁时为 true，用于触发动效和专属 hero 文案；动效结束后置 false。
    var isFirstUnlock = false

    /// 永久解锁标记（UserDefaults），一旦 true 永不回退。
    private(set) var isPermanentlyUnlocked: Bool

    private var lastLoadedAt: Date = .distantPast
    private let milestoneTracker: CategoryMilestoneTracker
    private let homeDataLoader: (@Sendable () async throws -> Data)?
    private let homeCacheLoader: @Sendable () async -> Data?
    private let homeLoadTimeout: Duration
    private let isConnected: () -> Bool
    private var inFlightShowsFailureHint = false
    private var loadCompletionWaiters: [CheckedContinuation<Void, Never>] = []
    #if DEBUG
    private var debugDemoStartedBeforeRefresh = false
    #endif

    init(
        milestoneTracker: CategoryMilestoneTracker = CategoryMilestoneTracker(),
        homeDataLoader: (@Sendable () async throws -> Data)? = nil,
        homeCacheLoader: @escaping @Sendable () async -> Data? = {
            LocalCache.shared.load(key: .tab2Home)
        },
        homeLoadTimeout: Duration = .seconds(8),
        isConnected: @escaping () -> Bool = { NetworkMonitor.shared.isConnected }
    ) {
        self.milestoneTracker = milestoneTracker
        self.homeDataLoader = homeDataLoader
        self.homeCacheLoader = homeCacheLoader
        self.homeLoadTimeout = homeLoadTimeout
        self.isConnected = isConnected
        isPermanentlyUnlocked = UserDefaults.standard.bool(forKey: kUnlockedKey)
    }

    // MARK: - Category milestone presentation

    func registerMilestones(
        _ snapshots: [CategoryMilestoneSnapshot],
        userID: String
    ) {
        let detected = milestoneTracker.observeBatch(snapshots, userID: userID)
        guard milestonePresentations.isEmpty, !detected.isEmpty else { return }
        milestonePresentations = detected
    }

    func finishMilestonePresentations(_ presentations: [CategoryMilestonePresentation]) {
        guard milestonePresentations == presentations else { return }
        milestonePresentations = []
    }

    func milestoneToastMessage(
        for presentations: [CategoryMilestonePresentation]
    ) -> String {
        guard presentations.count == 1, let presentation = presentations.first else {
            return "\(presentations.count) topics reached \(PopsLabel.format(20))"
        }
        let label = data?.categories.first {
            $0.id == presentation.categoryID
        }?.englishLabel ?? SceneCategory.from(presentation.categoryID).englishLabel
        return "\(label) reached \(PopsLabel.format(20))"
    }

    #if DEBUG
    /// Repeatable visual walkthrough. It never touches milestone persistence;
    /// launch with `TAB2_MILESTONE_DEMO=1` and refresh Tab2 to replay.
    static func debugMilestoneDemoPresentations(
        in categories: [Tab2CategoryData]
    ) -> [CategoryMilestonePresentation] {
        let unlocked = categories.filter(\.unlocked).sorted {
            if $0.wordCount == $1.wordCount { return $0.id < $1.id }
            return $0.wordCount < $1.wordCount
        }
        let candidates = Array(unlocked.prefix(2))
        let selected = candidates.isEmpty
            ? categories.filter { $0.wordCount > 0 }.max(by: { $0.wordCount < $1.wordCount }).map { [$0] } ?? []
            : candidates

        return selected.map { candidate in
            CategoryMilestonePresentation(
                categoryID: candidate.id,
                previousCount: 19,
                currentCount: 20
            )
        }
    }


    /// Starts the walkthrough from cached/on-screen data so switching to Tab2
    /// does not wait for the refresh. Only Debug callers invoke this helper.
    func prepareDebugMilestoneDemoFromCurrentData() {
        guard let categories = data?.categories else { return }
        debugDemoStartedBeforeRefresh = true
        guard milestonePresentations.isEmpty else { return }
        milestonePresentations = Self.debugMilestoneDemoPresentations(in: categories)
    }

    func prepareDebugMilestoneDemoAfterRefresh(_ categories: [Tab2CategoryData]) {
        defer { debugDemoStartedBeforeRefresh = false }
        guard !debugDemoStartedBeforeRefresh,
              milestonePresentations.isEmpty else { return }
        milestonePresentations = Self.debugMilestoneDemoPresentations(in: categories)
    }
    #endif

    // MARK: - Hero 选取

    /// 从 data.categories 里选出 hero 卡：
    /// 优先「有 featured moment 且最近有新素材的已解锁分类」；
    /// 次选「已解锁词数最多的分类」；未解锁时返回 nil。
    func heroCategory(excluding excludedCategoryIDs: Set<String> = []) -> Tab2CategoryData? {
        guard let cats = data?.categories else { return nil }
        let unlocked = cats.filter {
            $0.unlocked && !excludedCategoryIDs.contains($0.id)
        }
        guard !unlocked.isEmpty else { return nil }

        // 优先：有 featured moment（有可展示的场景）+ 最近有素材，按 lastMaterialAt 降序
        let preferred = unlocked
            .filter { $0.featured != nil }
            .sorted { ($0.lastMaterialAt ?? .distantPast) > ($1.lastMaterialAt ?? .distantPast) }
        if let best = preferred.first { return best }

        // 降级：词数最多的
        return unlocked.max(by: { $0.wordCount < $1.wordCount })
    }

    // MARK: - 解锁判定

    /// 数据显示已达标，但用户尚未主动点击"开门" CTA。
    /// 此时仍显示锁定页，但底部 CTA 变为"你已够了，点击开始"。
    var isReadyToUnlock: Bool {
        !isPermanentlyUnlocked && (data?.unlocked == true)
    }

    /// 用户主动点击解锁 CTA 后调用——写入 UserDefaults，触发首次解锁动效。
    func confirmUnlock() {
        guard isReadyToUnlock else { return }
        isPermanentlyUnlocked = true
        UserDefaults.standard.set(true, forKey: kUnlockedKey)
        if !UserDefaults.standard.bool(forKey: kFirstUnlockShownKey) {
            isFirstUnlock = true
        }
    }

    func markFirstUnlockShown() {
        isFirstUnlock = false
        UserDefaults.standard.set(true, forKey: kFirstUnlockShownKey)
    }

    // MARK: - 数据加载

    func loadIfStale() async {
        guard lastLoadedAt != .distantPast else { return }
        guard Date().timeIntervalSince(lastLoadedAt) > 30 else { return }
        await load()
    }

    func load(showFailureHint: Bool = false) async {
        await load(
            showFailureHint: showFailureHint,
            preservesInitialError: false
        )
    }

    /// 首次无缓存错误页的专用恢复动作。重试期间保留错误页和 Retry 入口，
    /// 失败时补充可见反馈；不复用普通下拉刷新“已有内容”的页面语义。
    func retryInitialLoad() async {
        await load(showFailureHint: true, preservesInitialError: true)
    }

    private func load(
        showFailureHint: Bool,
        preservesInitialError: Bool
    ) async {
        // 新一轮加载已经开始，上一轮失败提示不再代表当前状态。
        // 若本次手动刷新仍失败，catch 会写入本次对应的新提示。
        toastMessage = nil

        if isLoading {
            guard showFailureHint else { return }
            // 用户手动刷新加入当前请求：不重复发请求，但等待同一结果，并把失败反馈
            // 提升为手动刷新语义，避免刷新控件立即收起却什么都没发生。
            inFlightShowsFailureHint = true
            await waitForCurrentLoad()
            return
        }

        // 在第一次 await 之前占有加载权。否则缓存读取挂起期间，首载与手动刷新
        // 都可能穿过上方门控，随后各自发起一次网络请求。
        isLoading = true
        inFlightShowsFailureHint = showFailureHint
        if !preservesInitialError {
            errorMessage = nil
        }
        defer { finishCurrentLoad() }

        // 同步 UserDefaults → 支持 debug reset（清除 UserDefaults 后 load 能感知）
        if !UserDefaults.standard.bool(forKey: kUnlockedKey) && isPermanentlyUnlocked {
            isPermanentlyUnlocked = false
            isFirstUnlock = false
        }

        // 1. 先读缓存立即渲染（离线或刷新前不显示骨架）
        if data == nil,
           let cached = await homeCacheLoader() {
            data = try? JSONDecoder().decode(Tab2HomeData.self, from: cached)
            // isReadyToUnlock is computed — no manual trigger needed
        }
        // 与 Tab1 一致：已明确离线时不启动一个注定失败的请求。
        // 手动刷新立即反馈；后台刷新有缓存则静默；首次无缓存则进入可重试错误态。
        guard isConnected() else {
            if data == nil {
                errorMessage = "Failed to load"
                if preservesInitialError {
                    toastMessage = "You're offline. Check your connection and try again."
                }
            } else if showFailureHint {
                toastMessage = "You're offline. Check your connection and try again."
            }
            return
        }

        do {
            let loader = homeDataLoader
            let timeout = homeLoadTimeout
            let fresh = try await Self.withTimeout(timeout) {
                if let loader {
                    return try await loader()
                }
                return try await Self.fetchHomeData()
            }
            await LocalCache.shared.save(fresh, key: .tab2Home)
            let decoded = try JSONDecoder().decode(Tab2HomeData.self, from: fresh)
            data = decoded
            errorMessage = nil
            #if DEBUG
            if ProcessInfo.processInfo.environment["TAB2_MILESTONE_DEMO"] == "1" {
                prepareDebugMilestoneDemoAfterRefresh(decoded.categories)
            } else if let userID = SupabaseManager.currentUserID {
                registerMilestones(
                    decoded.categories.map {
                        CategoryMilestoneSnapshot(categoryID: $0.id, count: $0.wordCount)
                    },
                    userID: userID
                )
            }
            #else
            if let userID = SupabaseManager.currentUserID {
                registerMilestones(
                    decoded.categories.map {
                        CategoryMilestoneSnapshot(categoryID: $0.id, count: $0.wordCount)
                    },
                    userID: userID
                )
            }
            #endif
            wordCache.removeAll()
            categoryWordsRevision &+= 1
            lastLoadedAt = Date()
            toastMessage = nil
            // isReadyToUnlock is computed — no manual trigger needed
        } catch is CancellationError {
            // `.refreshable` 随所属视图生命周期取消属于正常控制流，不代表网络失败。
            // 保留现有内容且不弹 Toast；真正的超时由 HomeLoadError.timedOut 进入下方分支。
        } catch {
            print("[Tab2HomeVM] load error (keeping cache):", error)
            if data == nil {
                errorMessage = "Failed to load"
                if preservesInitialError {
                    toastMessage = isConnected()
                        ? "Unable to sync right now. Try again in a moment."
                        : "You're offline. Check your connection and try again."
                }
            } else if inFlightShowsFailureHint {
                toastMessage = isConnected()
                    ? "Unable to sync right now. Pull to try again."
                    : "You're offline. Check your connection and try again."
            }
        }
    }

    // MARK: - 按需拉词（分类展开）

    // 内存缓存：同一 session 内折叠再展开同一分类无需重新请求。
    // load() 刷新首页数据时清空，保证词数变化后下次展开能拿到最新词条。
    private var wordCache: [String: [Tab2WordEntry]] = [:]

    func loadCategoryWords(for sceneCategory: String) async throws -> [Tab2WordEntry] {
        if let cached = wordCache[sceneCategory] { return cached }
        let requestedRevision = categoryWordsRevision

        do {
            var req = URLRequest(url: SupabaseConfig.getCategoryWordsFunctionURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 8.0
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try await SupabaseManager.setAuthHeaders(on: &req)
            req.httpBody = try JSONEncoder().encode(["scene_category": sceneCategory])

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw CategoryWordsLoadFailure.unavailable
            }
            let words = try JSONDecoder().decode([Tab2WordEntry].self, from: data)
            guard !words.isEmpty else {
                throw CategoryWordsLoadFailure.unavailable
            }
            try Task.checkCancellation()
            // 首页刷新已推进版本时，这份响应属于旧正本，不能重新写回刚清空的缓存。
            guard requestedRevision == categoryWordsRevision else {
                throw CancellationError()
            }
            wordCache[sceneCategory] = words
            return words
        } catch is CancellationError {
            // 折叠、切换分类、离开页面和首页刷新都属于正常生命周期取消。
            throw CancellationError()
        } catch {
            throw CategoryWordsLoadFailure.classify(
                error: error,
                isConnected: NetworkMonitor.shared.isConnected
            )
        }
    }

    // MARK: - Private helpers

    private func waitForCurrentLoad() async {
        await withCheckedContinuation { continuation in
            guard isLoading else {
                continuation.resume()
                return
            }
            loadCompletionWaiters.append(continuation)
        }
    }

    private func finishCurrentLoad() {
        isLoading = false
        inFlightShowsFailureHint = false
        let waiters = loadCompletionWaiters
        loadCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    nonisolated static func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw HomeLoadError.timedOut
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return first
        }
    }

    private static func fetchHomeData() async throws -> Data {
        var req = URLRequest(url: SupabaseConfig.getTab2HomeFunctionURL)
        req.httpMethod = "GET"
        req.timeoutInterval = 8.0
        try await SupabaseManager.setAuthHeaders(on: &req)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[Tab2HomeVM] HTTP \(http.statusCode): \(body)")
            throw HomeLoadError.httpStatus(http.statusCode)
        }
        return data
    }
}
