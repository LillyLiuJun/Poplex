import Foundation
import UIKit

/// Tab2 解锁状态的 UserDefaults 键名——单一真源。
///
/// 键名散落成字面量时，改名只会有一处被改到，其余静默失效
/// （清不掉 = 用户以为重置了、其实没有），故收在这里。
/// 注：Settings 页已退回 main 基线，那边仍是字面量；两处保持同名即可。
enum Tab2Defaults {
    static let permanentlyUnlocked = "tab2_permanently_unlocked"
    static let firstUnlockShown    = "tab2_first_unlock_shown"
    /// 刀 4b：轮换记账 = [类别ID: 上次被选中日(yyyy-MM-dd 本地自然日)]。
    /// 没有记录 = 从未被选中 = 最久（§12 补充规则）。旧键 heroMaterialID /
    /// heroKnownMoments 随刀 3 过渡态语义一并退役。
    static let heroLastSelectedDays = "tab2_hero_last_selected_days"
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
    var toastIcon: String = "wifi"
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
    private let defaults: UserDefaults
    private let now: () -> Date
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
        isConnected: @escaping () -> Bool = { NetworkMonitor.shared.isConnected },
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.milestoneTracker = milestoneTracker
        self.homeDataLoader = homeDataLoader
        self.homeCacheLoader = homeCacheLoader
        self.homeLoadTimeout = homeLoadTimeout
        self.isConnected = isConnected
        self.defaults = defaults
        self.now = now
        isPermanentlyUnlocked = defaults.bool(forKey: kUnlockedKey)
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
            // 刀 6 §六：pops → words 文案（PopsLabel 随全局改名退役，复用 words()）。
            // 引号/句号来自 main 的 toast 重设计 #64（rebase 合并时保留，分支无此改动）。
            return "\(presentations.count) topics reached \(Tab2CardLabels.words(20))."
        }
        let label = data?.categories.first {
            $0.id == presentation.categoryID
        }?.englishLabel ?? SceneCategory.from(presentation.categoryID).englishLabel
        // 引号/句号来自 main 的 toast 重设计 #64（rebase 合并时保留，分支无此改动）。
        return "'\(label)' reached \(Tab2CardLabels.words(20))."
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

    // MARK: - Hero 选取（刀 4b · §10.5 ①②③）

    /// 每次「进入页面」求值一次并由 MineView 持有结果（@State），
    /// 一次浏览之内不因数据刷新换 Hero。三条规则，①优先于②优先于③：
    /// ① 今天已确定过 → 冻结，即使期间有分类冒出新素材也不重新判定②/③
    ///    （必须在②③分支之外、对全体候选统一检查一次，否则冻结形同虚设）
    /// ② newMaterialCount ≥ 1 的类中取 lastMaterialAt 最新；平局三级键：
    ///    newMaterialCount 降序 → activityCount 降序 → id 升序（§12 拍板）
    /// ③ 全为 0 → 按自然日轮换：持久化 类别ID → 上次选中日 字典。
    ///    没有记录 = 从未被选中 = 最久，排在所有有记录的类前面（§12 补充）；
    ///    同久组内按 §10.5 排序取第一个。确定后写一次当天日期。
    /// word_count 不参与 Hero 选取（只在 lastMaterialAt = null 组的组内排序里出现）。
    func selectHero(
        excluding excludedCategoryIDs: Set<String> = [],
        now: Date? = nil,
        calendar: Calendar = .current
    ) -> Tab2CategoryData? {
        guard let cats = data?.categories else { return nil }
        let candidates = cats.filter {
            $0.unlocked && !excludedCategoryIDs.contains($0.id)
        }
        guard !candidates.isEmpty else { return nil }

        let referenceDate = now ?? self.now()
        let todayKey = Self.dayKey(for: referenceDate, calendar: calendar)
        let records = lastSelectedDays()
        let selected: Tab2CategoryData?

        // ① 今天已有记录且该类别仍是候选 → 冻结，不进②③重新判定
        if let todaysPick = candidates.first(where: { records[$0.id] == todayKey }) {
            selected = todaysPick
        } else {
            let fresh = candidates.filter { $0.newMaterialCount >= 1 }
            if !fresh.isEmpty {
                // ② 今天有新素材的类：lastMaterialAt 最新优先
                //    （fresh 内 lastMaterialAt 恒非空——new_material_count ≥ 1 必产生
                //      MAX(created_at)，.distantPast 仅为防御性兜底）
                selected = fresh.sorted {
                    if $0.lastMaterialAt != $1.lastMaterialAt {
                        return ($0.lastMaterialAt ?? .distantPast) > ($1.lastMaterialAt ?? .distantPast)
                    }
                    if $0.newMaterialCount != $1.newMaterialCount {
                        return $0.newMaterialCount > $1.newMaterialCount
                    }
                    if $0.activityCount != $1.activityCount {
                        return $0.activityCount > $1.activityCount
                    }
                    return $0.id < $1.id
                }.first
            } else {
                // ③ 轮换（到这里已确定今天无人被冻结，无需再查 records[id] == todayKey）
                selected = candidates.sorted { lhs, rhs in
                    switch (records[lhs.id], records[rhs.id]) {
                    case (nil, _?): return true        // 从未被选中 = 最久
                    case (_?, nil): return false
                    case let (l?, r?) where l != r: return l < r  // 选中日更旧排前
                    default: break
                    }
                    // 同为从未选中 / 同日被选 → 按 §10.5 列表排序
                    return Self.isEarlierInRecencyOrder(lhs, rhs)
                }.first
            }
        }

        if let selected {
            setLastSelectedDay(todayKey, for: selected.id)
        }
        return selected
    }

    /// 刀 4b（§10.5）：候选集统一排序——lastMaterialAt 降序；null 排最后、
    /// 组内按 wordCount 降序；最后 id 升序兜底保证稳定可复现。
    static func recencySorted(_ categories: [Tab2CategoryData]) -> [Tab2CategoryData] {
        categories.sorted(by: isEarlierInRecencyOrder)
    }

    private static func isEarlierInRecencyOrder(
        _ lhs: Tab2CategoryData,
        _ rhs: Tab2CategoryData
    ) -> Bool {
        switch (lhs.lastMaterialAt, rhs.lastMaterialAt) {
        case let (l?, r?):
            if l != r { return l > r }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            if lhs.wordCount != rhs.wordCount { return lhs.wordCount > rhs.wordCount }
        }
        return lhs.id < rhs.id
    }

    /// 本地自然日键（yyyy-MM-dd）——轮换记账的「同一天」判定单位。
    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 0, comps.month ?? 0, comps.day ?? 0
        )
    }

    private func lastSelectedDays() -> [String: String] {
        defaults.dictionary(forKey: Tab2Defaults.heroLastSelectedDays) as? [String: String] ?? [:]
    }

    private func setLastSelectedDay(_ day: String, for categoryID: String) {
        var records = lastSelectedDays()
        records[categoryID] = day
        defaults.set(records, forKey: Tab2Defaults.heroLastSelectedDays)
    }

    // MARK: - More 选取（刀 4b · §10.5）

    /// 候选集 = 已解锁 − 排除集 − hero，保持 §10.5 排序
    /// （lastMaterialAt 降序，null 最后内部 wordCount 降序）。
    func moreCategories(
        excluding excludedCategoryIDs: Set<String> = [],
        hero: Tab2CategoryData?
    ) -> [Tab2CategoryData] {
        guard let cats = data?.categories else { return [] }
        let candidates = cats.filter {
            $0.unlocked
                && !excludedCategoryIDs.contains($0.id)
                && $0.id != hero?.id
        }
        return Self.recencySorted(candidates)
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
        defaults.set(true, forKey: kUnlockedKey)
        if !defaults.bool(forKey: kFirstUnlockShownKey) {
            isFirstUnlock = true
        }
    }

    func markFirstUnlockShown() {
        isFirstUnlock = false
        defaults.set(true, forKey: kFirstUnlockShownKey)
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

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-screenshotStore05") ||
           ProcessInfo.processInfo.environment["SCREENSHOT_STORE05"] == "1" {
            self.isPermanentlyUnlocked = true
            if let dogImg = UIImage(named: "card_scene_1") {
                ImageCache.shared.set(dogImg, forKey: "card_scene_1")
            }
            self.data = Tab2HomeData(
                unlocked: true,
                inputCount: 24,
                categories: [
                    Tab2CategoryData(
                        sceneCategory: "Hobbies & Leisure",
                        wordCount: 46,
                        unlocked: true,
                        lastMaterialAt: Date(),
                        newMaterialCount: 2,
                        activityCount: 6,
                        activities: [
                            Tab2Activity(
                                sceneDetail: "Playing with pets",
                                occurrenceCount: 3,
                                cover: Tab2Activity.Cover(materialId: "card_scene_1", imageUrl: "card_scene_1")
                            ),
                            Tab2Activity(sceneDetail: "Weekend hiking", occurrenceCount: 2),
                            Tab2Activity(sceneDetail: "Learning guitar", occurrenceCount: 1),
                            Tab2Activity(sceneDetail: "Camping trip", occurrenceCount: 1),
                            Tab2Activity(sceneDetail: "Cooking new recipe", occurrenceCount: 1),
                            Tab2Activity(sceneDetail: "Photography walk", occurrenceCount: 1)
                        ]
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Work & Study",
                        wordCount: 38,
                        unlocked: true,
                        lastMaterialAt: Date().addingTimeInterval(-86400),
                        newMaterialCount: 0,
                        activityCount: 5,
                        activities: [
                            Tab2Activity(sceneDetail: "Team meetings", occurrenceCount: 4),
                            Tab2Activity(sceneDetail: "Code reviews", occurrenceCount: 3),
                            Tab2Activity(sceneDetail: "Weekly report", occurrenceCount: 2),
                            Tab2Activity(sceneDetail: "Job interview", occurrenceCount: 1),
                            Tab2Activity(sceneDetail: "Online course", occurrenceCount: 1)
                        ]
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Travel & Commute",
                        wordCount: 26,
                        unlocked: true,
                        lastMaterialAt: Date().addingTimeInterval(-3 * 86400),
                        newMaterialCount: 0,
                        activityCount: 4,
                        activities: [
                            Tab2Activity(sceneDetail: "Running late", occurrenceCount: 3),
                            Tab2Activity(sceneDetail: "Taking the subway", occurrenceCount: 2),
                            Tab2Activity(sceneDetail: "Airport check-in", occurrenceCount: 1),
                            Tab2Activity(sceneDetail: "Asking for directions", occurrenceCount: 1)
                        ]
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Home & Family",
                        wordCount: 21,
                        unlocked: true,
                        lastMaterialAt: Date().addingTimeInterval(-8 * 86400),
                        newMaterialCount: 0,
                        activityCount: 2,
                        activities: [
                            Tab2Activity(sceneDetail: "Fixing the water heater", occurrenceCount: 2),
                            Tab2Activity(sceneDetail: "Weekend cleaning", occurrenceCount: 1)
                        ]
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Food & Drink",
                        wordCount: 24,
                        unlocked: true,
                        lastMaterialAt: Date().addingTimeInterval(-9 * 86400),
                        newMaterialCount: 0,
                        activityCount: 3,
                        activities: [
                            Tab2Activity(sceneDetail: "Ordering coffee", occurrenceCount: 3),
                            Tab2Activity(sceneDetail: "Cooking dinner", occurrenceCount: 2),
                            Tab2Activity(sceneDetail: "Grocery run", occurrenceCount: 1)
                        ]
                    )
                ]
            )
            self.errorMessage = nil
            self.isLoading = false
            return
        } else {
            // 商店图截图分支：DEBUG 模式下默认直接提供 store04 完整数据，无论如何启动均有内容
            self.isPermanentlyUnlocked = true
            let store04Words = [
                Tab2WordEntry(
                    lemma: "Boston Terrier",
                    entryKind: "phrase",
                    granularity: "phrase",
                    sourceType: "material",
                    nativeMeaning: "波士顿梗犬",
                    imageUrl: "card_scene_1"
                ),
                Tab2WordEntry(
                    lemma: "plaid",
                    entryKind: "word",
                    granularity: "word",
                    sourceType: "material",
                    nativeMeaning: "苏格兰格子",
                    imageUrl: "card_scene_1"
                ),
                Tab2WordEntry(
                    lemma: "harness",
                    entryKind: "word",
                    granularity: "word",
                    sourceType: "material",
                    nativeMeaning: "胸背带",
                    imageUrl: "card_scene_1"
                ),
                Tab2WordEntry(
                    lemma: "grassy field",
                    entryKind: "phrase",
                    granularity: "phrase",
                    sourceType: "material",
                    nativeMeaning: "草地",
                    imageUrl: "card_scene_1"
                )
            ]
            self.wordCache["Hobbies & Leisure"] = store04Words
            self.data = Tab2HomeData(
                unlocked: true,
                inputCount: 24,
                categories: [
                    Tab2CategoryData(
                        sceneCategory: "Hobbies & Leisure",
                        wordCount: 14,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Daily Routine",
                        wordCount: 16,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Work & Study",
                        wordCount: 12,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Home & Family",
                        wordCount: 9,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Food & Drink",
                        wordCount: 7,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Travel & Commute",
                        wordCount: 5,
                        unlocked: false
                    ),
                    Tab2CategoryData(
                        sceneCategory: "Social & Feelings",
                        wordCount: 4,
                        unlocked: false
                    )
                ]
            )
            self.errorMessage = nil
            self.isLoading = false
            return
        }
        #endif

        // 同步 UserDefaults → 支持 debug reset（清除 UserDefaults 后 load 能感知）
        if !defaults.bool(forKey: kUnlockedKey) && isPermanentlyUnlocked {
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
            toastIcon = "wifi"
            if data == nil {
                errorMessage = "Failed to load"
                if preservesInitialError {
                    toastMessage = "You're offline. Check your connection."
                }
            } else if showFailureHint {
                toastMessage = "You're offline. Check your connection."
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
            #if DEBUG
            // 【toast-probe】TOAST_PROBE_BLOCKED=1：load 成功后触发一次 vm.toastMessage
            // 的 blocked toast（"You're offline. Check your connection." 正是其正常文案），
            // 供 toast 全链路时序验收。用法见 CLAUDE.md「Debug Probes」。
            if ProcessInfo.processInfo.environment["TOAST_PROBE_BLOCKED"] == "1" {
                toastMessage = "You're offline. Check your connection."
            }
            #endif
            // isReadyToUnlock is computed — no manual trigger needed
        } catch is CancellationError {
            // `.refreshable` 随所属视图生命周期取消属于正常控制流，不代表网络失败。
            // 保留现有内容且不弹 Toast；真正的超时由 HomeLoadError.timedOut 进入下方分支。
        } catch {
            print("[Tab2HomeVM] load error (keeping cache):", error)
            toastIcon = isConnected() ? "arrow.clockwise" : "wifi"
            if data == nil {
                errorMessage = "Failed to load"
                if preservesInitialError {
                    toastMessage = isConnected()
                        ? "Couldn't refresh. Try again in a moment."
                        : "You're offline. Check your connection."
                }
            } else if inFlightShowsFailureHint {
                toastMessage = isConnected()
                    ? "Couldn't refresh. Try again in a moment."
                    : "You're offline. Check your connection."
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

    /// 刀 4a：Tab2 首页请求 URL——追加 day_start = 本地当日 00:00 对应的 UTC 时刻
    /// （§10.6 方案 B：传时刻，不传偏移；存偏移数字的方案每年夏令时会错两次）。
    /// ISO8601DateFormatter 默认按 UTC 输出，故「本地零点」这个 Date 瞬间
    /// 序列化出来天然就是对应的 UTC 时刻。抽成纯函数供单测锁定换算行为。
    static func tab2HomeRequestURL(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> URL? {
        var components = URLComponents(
            url: SupabaseConfig.getTab2HomeFunctionURL,
            resolvingAgainstBaseURL: false
        )
        let dayStart = calendar.startOfDay(for: now)
        components?.queryItems = [
            URLQueryItem(
                name: "day_start",
                value: ISO8601DateFormatter().string(from: dayStart)
            )
        ]
        return components?.url
    }

    private static func fetchHomeData() async throws -> Data {
        guard let url = tab2HomeRequestURL() else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
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
