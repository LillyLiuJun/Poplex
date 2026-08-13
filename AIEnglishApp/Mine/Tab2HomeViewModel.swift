import Foundation

private let kUnlockedKey         = "tab2_permanently_unlocked"
private let kFirstUnlockShownKey = "tab2_first_unlock_shown"

@Observable
final class Tab2HomeViewModel {
    var data: Tab2HomeData?
    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?
    var milestonePresentations: [CategoryMilestonePresentation] = []

    /// 首次解锁时为 true，用于触发动效和专属 hero 文案；动效结束后置 false。
    var isFirstUnlock = false

    /// 永久解锁标记（UserDefaults），一旦 true 永不回退。
    private(set) var isPermanentlyUnlocked: Bool

    private var lastLoadedAt: Date = .distantPast
    private let milestoneTracker: CategoryMilestoneTracker
    #if DEBUG
    private var debugDemoStartedBeforeRefresh = false
    #endif

    init(milestoneTracker: CategoryMilestoneTracker = CategoryMilestoneTracker()) {
        self.milestoneTracker = milestoneTracker
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

    func load() async {
        // 同步 UserDefaults → 支持 debug reset（清除 UserDefaults 后 load 能感知）
        if !UserDefaults.standard.bool(forKey: kUnlockedKey) && isPermanentlyUnlocked {
            isPermanentlyUnlocked = false
            isFirstUnlock = false
        }

        // 1. 先读缓存立即渲染（离线或刷新前不显示骨架）
        if data == nil,
           let cached = await LocalCache.shared.load(key: .tab2Home) {
            data = try? JSONDecoder().decode(Tab2HomeData.self, from: cached)
            // isReadyToUnlock is computed — no manual trigger needed
        }

        isLoading = true
        errorMessage = nil

        do {
            let fresh = try await fetchHomeData()
            await LocalCache.shared.save(fresh, key: .tab2Home)
            let decoded = try JSONDecoder().decode(Tab2HomeData.self, from: fresh)
            data = decoded
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
            lastLoadedAt = Date()
            toastMessage = nil
            // isReadyToUnlock is computed — no manual trigger needed
        } catch {
            if data == nil {
                errorMessage = "Failed to load"
            } else {
                toastMessage = "Couldn't update — showing saved content"
            }
        }
        isLoading = false
    }

    // MARK: - 按需拉词（分类展开）

    // 内存缓存：同一 session 内折叠再展开同一分类无需重新请求。
    // load() 刷新首页数据时清空，保证词数变化后下次展开能拿到最新词条。
    private var wordCache: [String: [Tab2WordEntry]] = [:]

    func loadCategoryWords(for sceneCategory: String) async -> [Tab2WordEntry] {
        if let cached = wordCache[sceneCategory] { return cached }

        do {
            var req = URLRequest(url: SupabaseConfig.getCategoryWordsFunctionURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try await SupabaseManager.setAuthHeaders(on: &req)
            req.httpBody = try JSONEncoder().encode(["scene_category": sceneCategory])

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let words = (try? JSONDecoder().decode([Tab2WordEntry].self, from: data)) ?? []
            wordCache[sceneCategory] = words
            return words
        } catch {
            return []
        }
    }

    // MARK: - Private helpers

    private func fetchHomeData() async throws -> Data {
        var req = URLRequest(url: SupabaseConfig.getTab2HomeFunctionURL)
        req.httpMethod = "GET"
        try await SupabaseManager.setAuthHeaders(on: &req)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
