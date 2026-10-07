import SwiftUI

private enum MineRoute: Hashable {
    case conversation(sceneCategory: String)
}

struct MineView: View {
    var listResetToken: UUID = UUID()      // kept for RootTabContainer compat
    @Binding var swipeActionOpen: Bool
    @Binding var detailActive: Bool
    var topInset: CGFloat = 0
    var isActive: Bool = true
    /// Called when user taps "Capture something" in locked state — switches to Tab1
    var onSwitchToToday: (() -> Void)? = nil

    @State private var vm = Tab2HomeViewModel()
    @State private var path: [MineRoute] = []
    @State private var comingSoonToast: String? = nil
    @State private var milestoneToast: String? = nil
    /// 刀 4b：Hero 进入页面时求值一次并持有，一次浏览之内不因数据刷新而换。
    @State private var heroSelection: Tab2CategoryData? = nil
    @State private var isRadiantAscentActive: Bool = false
    @State private var lockedBottomBarHeight: CGFloat = 0
    /// 离开 Tab2（切到 Today）时换新值 → 竖向滚动回顶、More topics 横滑归位。
    /// 在「离开」而非「回来」时归位：此时页面已不可见，用户回来看到的就是初始状态，
    /// 不会撞见一次跳动。进对话页再返回、App 退后台都不触发（isActive 不变），保持原位。
    @State private var leaveResetToken = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 解锁前有沉底操作栏时，Toast 自动上浮避让按钮高度与呼吸间距；解锁后沉底栏销毁，自然归零
    private var toastExtraBottomOffset: CGFloat {
        lockedBottomBarHeight > 0 ? lockedBottomBarHeight + AppTheme.Space.paddingM : 0
    }

    /// 解锁揭幕转场：参考 main 基线从底部优雅生长舒展，配合温润微上浮与消融淡入
    private var unlockRevealTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity
                    .combined(with: .scale(scale: 0.84, anchor: .bottom))
                    .combined(with: .offset(y: 16)),
                removal: .opacity
            )
    }

    init(
        listResetToken: UUID = UUID(),
        swipeActionOpen: Binding<Bool> = .constant(false),
        detailActive: Binding<Bool> = .constant(false),
        topInset: CGFloat = 0,
        isActive: Bool = true,
        onSwitchToToday: (() -> Void)? = nil
    ) {
        self.listResetToken = listResetToken
        self._swipeActionOpen = swipeActionOpen
        self._detailActive = detailActive
        self.topInset = topInset
        self.isActive = isActive
        self.onSwitchToToday = onSwitchToToday
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                mainContent
                    // 挂在 mainContent 上而非 body 修饰链末尾：body 链已长到编译器类型推断超时。
                    .onChange(of: isActive) { _, nowActive in
                        if !nowActive { leaveResetToken = UUID() }
                    }

                // 品牌色温润升腾柔光：跨越 Locked → Unlocked 转场全生命周期
                if isRadiantAscentActive && !reduceMotion {
                    BrandRadiantAscentOverlay()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await vm.load() }
            .onChange(of: listResetToken) { _, _ in
                #if DEBUG
                if ProcessInfo.processInfo.environment["TAB2_MILESTONE_DEMO"] == "1" {
                    vm.prepareDebugMilestoneDemoFromCurrentData()
                }
                #endif
                // 刀 4b：切回 Tab2 = 新一次浏览，Hero 在此刻重求值。
                refreshHeroSelectionIfNeeded()
                Task { await vm.load() }
            }
            .onChange(of: path) { _, newPath in
                detailActive = !newPath.isEmpty
            }
            .onChange(of: vm.isPermanentlyUnlocked) { _, newValue in
                if newValue {
                    lockedBottomBarHeight = 0
                    withAnimation(AppTheme.Motion.tabSelection) {}
                    refreshHeroSelectionIfNeeded()
                }
            }
            // 首载数据到位（nil → 有数据）时求值一次；后续刷新 categories id 不变、
            // 不触发 → Hero 在一次浏览之内保持冻结。
            .onChange(of: vm.data?.categories.map(\.id) ?? []) { _, _ in
                refreshHeroSelectionIfNeeded()
            }
            // 里程碑排除集变化（弹出/播完）时重求值，与旧动态排除行为对齐。
            .onChange(of: visibleMilestonePresentations) { _, _ in
                refreshHeroSelectionIfNeeded()
            }
            .task(id: visibleMilestonePresentations) {
                let presentations = visibleMilestonePresentations
                guard !presentations.isEmpty else { return }
                milestoneToast = vm.milestoneToastMessage(for: presentations)
                let revealDuration = reduceMotion
                    ? AppTheme.Motion.categoryMilestoneReducedReveal
                    : AppTheme.Motion.categoryMilestoneReveal
                try? await Task.sleep(for: revealDuration)
                guard !Task.isCancelled, isActive else { return }
                try? await Task.sleep(for: AppTheme.Motion.categoryMilestoneResultHold)
                guard !Task.isCancelled, isActive else { return }
                vm.finishMilestonePresentations(presentations)
            }
            .appToast(
                message: Binding(get: { vm.toastMessage }, set: { vm.toastMessage = $0 }),
                systemImage: vm.toastIcon,
                semantic: .blocked,
                extraBottomOffset: toastExtraBottomOffset
            )
            .appToast(
                message: $comingSoonToast,
                systemImage: "clock",
                semantic: .blocked,
                extraBottomOffset: toastExtraBottomOffset
            )
            .appToast(
                message: $milestoneToast,
                systemImage: "sparkles",
                semantic: .positive,
                lifetime: AppTheme.Motion.milestoneToastLifetime,
                extraBottomOffset: toastExtraBottomOffset
            )
#if DEBUG
            // 【toast-probe · 常备验收手段】真机曾现「toast 常驻不消失」
            // （2026-09-15，结论：rebase 前旧包，当前代码无法复现）。三条 toast
            // （comingSoon / vm.toastMessage / milestone）共用 AppToast 消失链路，
            // 每次值变化都打 [toast-probe] NSLog——写入 N 秒后必须跟一条 nil，
            // 否则自动消失链路坏。触发方式与验收标准见 CLAUDE.md「Debug Probes」。
            // 设备 console 是管道、stdout 全缓冲，必须走 NSLog（os_log 通道）才即时可见。
            .onChange(of: comingSoonToast) { _, newValue in
                NSLog("[toast-probe] comingSoonToast -> %@", String(describing: newValue))
            }
            .onChange(of: vm.toastMessage) { _, newValue in
                NSLog("[toast-probe] vm.toastMessage -> %@", String(describing: newValue))
            }
            .onChange(of: milestoneToast) { _, newValue in
                NSLog("[toast-probe] milestoneToast -> %@", String(describing: newValue))
            }
            .task {
                guard ProcessInfo.processInfo.environment["TOAST_PROBE"] == "1" else { return }
                try? await Task.sleep(for: .seconds(2))
                NSLog("[toast-probe] firing")
                comingSoonToast = "Speaking mode will be available soon."
            }
#endif
            .onPreferenceChange(Tab2LockedBottomBarHeightKey.self) { height in
                lockedBottomBarHeight = height
            }
            .navigationDestination(for: MineRoute.self) { route in
                switch route {
                case .conversation(let cat):
                    ConversationView(sceneCategory: cat, onDismiss: { path.removeLast() })
                }
            }
        }
    }

    private var visibleMilestonePresentations: [CategoryMilestonePresentation] {
        isActive ? vm.milestonePresentations : []
    }

    /// 刀 4b：Hero 在「进入页面」时求值一次并持有，一次浏览之内不随数据
    /// 刷新换。重算触发器只有三个：切回 Tab2（新一次浏览）、解锁转场、
    /// 里程碑排除集变化（与旧 heroCategory 的动态排除行为对齐）。
    private func refreshHeroSelectionIfNeeded() {
        guard vm.isPermanentlyUnlocked, vm.data != nil else { return }
        let milestoneIDs = Set(visibleMilestonePresentations.map(\.categoryID))
        heroSelection = vm.selectHero(excluding: milestoneIDs)
    }

    // MARK: - State machine

    @ViewBuilder
    private var mainContent: some View {
        if vm.data == nil {
            if vm.errorMessage != nil {
                Tab2LoadErrorView(
                    topInset: topInset,
                    isRetrying: vm.isLoading
                ) {
                    await vm.retryInitialLoad()
                }
            } else {
                // 首载任务真正启动前、缓存读取期间或生命周期取消后，都不能
                // 落入一个没有 loading / error / content 的空白页面。
                skeletonView
            }
        } else if vm.isPermanentlyUnlocked {
            unlockedView
                .transition(unlockRevealTransition)
        } else {
            lockedView
                .transition(.opacity)
        }
    }

    private var unlockedView: some View {
        Tab2UnlockedView(
            vm: vm,
            hero: heroSelection,
            topInset: topInset,
            listResetToken: listResetToken,
            leaveResetToken: leaveResetToken,
            milestonePresentations: visibleMilestonePresentations,
            onTalk: { cat in
                if FeatureFlags.conversationEnabled {
                    path.append(.conversation(sceneCategory: cat))
                } else {
                    comingSoonToast = "Speaking mode will be available soon."
                }
            }
        )
    }

    private var lockedView: some View {
        Tab2LockedView(
            vm: vm,
            topInset: topInset,
            listResetToken: listResetToken,
            leaveResetToken: leaveResetToken,
            milestonePresentations: visibleMilestonePresentations,
            onCapture: { onSwitchToToday?() },
            onStartAscent: { triggerRadiantAscent() }
        )
    }

    private func triggerRadiantAscent() {
        isRadiantAscentActive = true
        Task {
            try? await Task.sleep(for: AppTheme.Motion.radiantAscentLifetime)
            isRadiantAscentActive = false
        }
    }

    private var skeletonView: some View {
        List {
            ForEach(0..<4, id: \.self) { _ in SkeletonCardRow() }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Space.paddingCard / 2,
                    leading: AppTheme.Space.paddingPage,
                    bottom: AppTheme.Space.paddingCard / 2,
                    trailing: AppTheme.Space.paddingPage
                ))
        }
        .listStyle(.plain)
    }
}

// MARK: - Locked bottom bar height preference

private struct Tab2LockedBottomBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Locked view

private enum UnlockState {
    case idle
    case charging   // 蓄力：压实下沉，阴影收拢，图标微调
    case releasing  // 舒张释放：蓬勃膨胀至1.14，光晕绽放，图标旋转放大
}

/// Tab2 竖向滚动的回顶锚点（挂在 ScrollView 首个 0 高子视图上）。
private enum Tab2ScrollAnchor {
    static let top = "tab2ScrollTop"
}

private struct Tab2LockedView: View {
    let vm: Tab2HomeViewModel
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    var leaveResetToken: UUID? = nil
    var milestonePresentations: [CategoryMilestonePresentation] = []
    let onCapture: () -> Void
    var onStartAscent: (() -> Void)? = nil

    private let wordTarget  = 20

    @State private var unlockState: UnlockState = .idle
    @State private var measuredBottomBarHeight: CGFloat = 0
    // 单开手风琴：同时只展开一个主题；切回 Mine（listResetToken 变化）时回收起。
    @State private var expandedCategoryId: String?
    // 空状态/非空状态两个 ScrollView 互斥渲染，共用同一个触感实例。
    @State private var refreshHaptics = PullToRefreshHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            if categoriesWithWords.isEmpty {
                GeometryReader { geo in
                    let reservedTop = max(topInset, 56)

                    ScrollView {
                        WarmRefreshControlHelper(haptics: refreshHaptics)
                            .frame(width: 0, height: 0)
                        emptyStateView
                            // safeAreaInset 会从实际滚动视口中扣除 reservedTop 与 bottomBar。
                            // 内容高度按同一个视口计算，居中负空间匀称舒展。
                            .frame(minHeight: max(geo.size.height - reservedTop, 400))
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: reservedTop)
                    }
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .refreshable {
                        refreshHaptics.fire()
                        await vm.load(showFailureHint: true)
                    }
                }
            } else {
                // 1. 待解锁页面内容（固定顶栏空间，卡片与 Header 独立协同避让）
                GeometryReader { geo in
                    let reservedTop = max(topInset, 56)
                    let availableHeight = max(geo.size.height - reservedTop, 400)

                    ScrollViewReader { proxy in
                        ScrollView {
                            WarmRefreshControlHelper(haptics: refreshHaptics)
                                .frame(width: 0, height: 0)
                                .id(Tab2ScrollAnchor.top)
                            // 2026-10-03：去掉「Not open yet」外壳，与解锁页同骨架——
                            // Topics in progress 与 More topics to explore 两个平级一级标题。
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                                VStack(alignment: .leading, spacing: AppTheme.Tab2ExploreTopics.Layout.tagsToFootnote) {
                                    topicsCard(proxy)

                                    Tab2Footnote(iconName: "lightbulb", text: "Any topic with \(wordTarget) words unlocks speaking.")
                                        .padding(.horizontal, AppTheme.Space.paddingPage)
                                }

                                let unstarted = SceneCategory.unstarted(given: vm.data?.categories ?? [])
                                if !unstarted.isEmpty {
                                    Tab2MoreTopicsSection(
                                        topics: unstarted,
                                        footnote: Tab2Footnote(
                                            iconName: "square.grid.2x2",
                                            text: "Moments you capture will automatically sort into these life themes."
                                        ),
                                        resetToken: leaveResetToken
                                    )
                                }
                            }
                            .padding(.top, AppTheme.Space.tab2ContentTop)     // 与解锁页同一标题起点
                            .padding(.bottom, AppTheme.Space.paddingPage)
                            .frame(minHeight: availableHeight, alignment: .top)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .safeAreaInset(edge: .top, spacing: 0) {
                            Color.clear.frame(height: reservedTop)
                        }
                        .scrollBounceBehavior(.always, axes: .vertical)
                        .refreshable {
                            refreshHaptics.fire()
                            await vm.load(showFailureHint: true)
                        }
                        .onChange(of: leaveResetToken) { _, _ in
                            proxy.scrollTo(Tab2ScrollAnchor.top, anchor: .top)
                        }
                    }
                }
            }

            // 释放时温润晨曦升腾：从底部向上如暖雾轻烟般舒展弥散
            LinearGradient(
                stops: [
                    .init(color: AppTheme.Color.brandTint.opacity(0.14), location: 0.0),
                    .init(color: AppTheme.Color.brandStrong.opacity(0.08), location: 0.5),
                    .init(color: .clear, location: 0.95)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .blur(radius: 40)
            .opacity(unlockState == .releasing ? 1.0 : 0.0)
            .offset(y: unlockState == .releasing ? -60 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(AppTheme.Motion.unlockDissolve, value: unlockState)
        }
        // 沉底操作栏通过 safeAreaInset 统一挂载在容器最外层：
        // 自动扣减两套 ScrollView 的底部视口，滚条不穿帮，零一帧回环。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBarContainer
        }
        // ★ 解锁动效包含按钮：.blur 挂在 safeAreaInset 之后，保证 releasing 时按钮与正文一同被模糊消融
        .blur(radius: unlockState == .releasing ? 8 : 0)
        .opacity(unlockState == .releasing ? 0 : 1)
        .scaleEffect(unlockState == .releasing ? 0.98 : 1.0)
        .animation(AppTheme.Motion.unlockDissolve, value: unlockState)
        .onChange(of: listResetToken) { _, _ in
            expandedCategoryId = nil   // 切回 Mine：回到初始收起
        }
    }

    // ── 统一常驻沉底栏（承载纸色暖光背板 + CTA 按钮 + 真实高度测量）─────────────
    private var bottomBarContainer: some View {
        VStack(spacing: 0) {
            captureButton(showsCaptureIcon: categoriesWithWords.isEmpty)
                .padding(.bottom, AppTheme.Space.bottomBarActionBottom)
        }
        .padding(.top, AppTheme.Space.paddingS)
        .background {
            // 对齐 Tab1 既定分工：有常驻底栏的页面，承托暖光归控件背板承担，不另画椭圆。
            // 纯纸色非线性渐隐 + 5.5% 暖橙补充层，杜绝系统 material 冷灰发脏。
            VariableBlurBackdrop(extraExtend: 16)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        // 实测沉底栏真实高度（无障碍大字号下按钮自适应长高），仅服务 Toast 动态避让
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard newHeight > 0, abs(newHeight - measuredBottomBarHeight) > 0.5 else { return }
            measuredBottomBarHeight = newHeight
        }
        .preference(key: Tab2LockedBottomBarHeightKey.self, value: measuredBottomBarHeight)
    }

    // ── 无数据空状态（Warm Minimalism 减法设计）───────────────────────────
    // 按钮已提升至外层 safeAreaInset 统一沉底，此处专注纯净负空间居中
    private var emptyStateView: some View {
        EmptyStateView()
    }

    // ── TOPICS list ──────────────────────────────────────────────────────
    private func topicsCard(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Topics 保持页面级标题（与 Talk about today 同款 sectionTitleSerif）；
            // 刀 6 §六①只降档 More to talk about。
            Text("Topics in progress")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingM)

            let cats  = categoriesWithWords

            if cats.isEmpty {
                Text("Capture a moment to get started.")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            } else {
                // 卡片：进度条独自承担行间分隔（方案3），不再叠分割线
                VStack(spacing: 0) {
                    ForEach(Array(cats.enumerated()), id: \.element.id) { index, cat in
                        CategoryProgressRow(
                            category: cat,
                            isExpanded: expandedCategoryId == cat.id,
                            onToggle: { toggleExpand(cat.id, proxy) },
                            loadWords: { try await vm.loadCategoryWords(for: cat.sceneCategory) },
                            wordsRevision: vm.categoryWordsRevision,
                            milestonePresentations: milestonePresentations
                        )
                        .id(cat.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
    }

    // 单开手风琴 + 滚动锚定：展开时把点开的行滚到顶部对齐，收起上一个，视线始终锁在这一行。
    private func toggleExpand(_ id: String, _ proxy: ScrollViewProxy) {
        let willExpand = expandedCategoryId != id
        let animation = reduceMotion ? AppTheme.Motion.accordionReducedToggle : AppTheme.Motion.accordionToggle
        withAnimation(animation) {
            expandedCategoryId = willExpand ? id : nil
            if willExpand { proxy.scrollTo(id, anchor: .top) }
        }
    }

    // ── CTA ──────────────────────────────────────────────────────────────
    private func captureButton(showsCaptureIcon: Bool = false) -> some View {
        let isReady = vm.isReadyToUnlock
        return Button {
            if isReady {
                if reduceMotion {
                    // 减弱动态：跳过蓄力/升腾，单次轻震动 + 纯净淡入切换
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(AppTheme.Motion.unlockReducedFade) {
                        vm.confirmUnlock()
                    }
                } else {
                    // 1. 原点蓄力阶段 (Soft Medium Impact + 温润微下沉)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(AppTheme.Motion.unlockCharging) {
                        unlockState = .charging
                    }

                    Task {
                        // 蓄力停顿 360ms - 凝聚能量
                        try? await Task.sleep(nanoseconds: 360_000_000)

                        // 2. 从蓄力原点升腾释放 (Medium Impact + 品牌柔光升腾与旧页消融)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onStartAscent?()
                        withAnimation(AppTheme.Motion.unlockDissolve) {
                            unlockState = .releasing
                        }

                        // 3. 顺势在晨曦中揭开新世界
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        withAnimation(AppTheme.Motion.unlockReveal) {
                            vm.confirmUnlock()
                        }
                    }
                }
            } else {
                onCapture()
            }
        } label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                // 无障碍字号下**隐藏图标**，把宽度整个让给文字。
                // 只允许换行是不够的：`something` 这种单个长词本身就可能比
                // 「胶囊宽度 − 图标 − 间距」还宽，换行救不了单词内部，
                // 结果是字画到胶囊外面去（AX5 实测）。图标是装饰性的，
                // 让位给唯一的操作指引是划算的。
                if !dynamicTypeSize.isAccessibilitySize {
                    if isReady {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .scaleEffect(sparkleScale)
                            .rotationEffect(.degrees(sparkleRotation))
                    } else if showsCaptureIcon {
                        Image(systemName: "camera")
                            .font(.system(size: AppTheme.Size.emptyStateCaptureIconGlyph, weight: .regular))
                    }
                }
                Text(isReady ? "You're all set" : "Capture something")
                    .multilineTextAlignment(.center)
                    // 让出图标后仍可能有更长的本地化文案或更大的屏幕缩放，
                    // 留一档缩放兜底——宁可小一点，也不能画到按钮外面。
                    .minimumScaleFactor(0.75)
            }
            .font(AppTheme.Font.ctaLabel)
            .foregroundStyle(AppTheme.Color.cardBg)
            .frame(maxWidth: .infinity)
            // 与 Tab1 InputBar 胶囊同高。用 minHeight 而非固定 height：
            // 固定高度会把放大后的文字锁死在 52pt 里，只能截断。
            .padding(.vertical, AppTheme.Space.paddingS)
            .frame(minHeight: AppTheme.Size.inputBarMinHeight)
            .background(AppTheme.Color.interactive)   // 保持染色黑（点击变橙显得怪，去掉）
            .clipShape(Capsule())
            .background {
                ZStack {
                    // 蓄力光晕层：charging 时在按钮周围轻柔收拢凝聚
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .blur(radius: 14)
                        .scaleEffect(unlockState == .charging ? 1.10 : 0.9)
                        .opacity(unlockState == .charging ? 0.24 : 0.0)
                        .animation(AppTheme.Motion.unlockCharging, value: unlockState)

                    // 释放时光晕温和漫散
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .blur(radius: unlockState == .releasing ? 24 : 8)
                        .scaleEffect(unlockState == .releasing ? 1.25 : 0.9)
                        .opacity(unlockState == .releasing ? 0.14 : 0.0)
                        .animation(.easeOut(duration: 0.3), value: unlockState)
                }
            }
            .shadow(
                color: AppTheme.Color.interactive.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)      // 释放时溶解淡出（虚化由外层统一施加，避免双重模糊）
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingS)
    }

    private var buttonScale: CGFloat {
        switch unlockState {
        case .idle: return 1.0
        case .charging: return 0.95   // 温润微下沉
        case .releasing: return 0.98   // 原地温润消融
        }
    }

    // 释放时按钮原地淡出（虚化由外层统一施加，避免双重模糊）
    private var buttonOpacity: Double { unlockState == .releasing ? 0 : 1 }

    private var shadowRadius: CGFloat {
        switch unlockState {
        case .idle: return 10
        case .charging: return 4
        case .releasing: return 12
        }
    }

    private var shadowY: CGFloat {
        switch unlockState {
        case .idle: return 4
        case .charging: return 2
        case .releasing: return 5
        }
    }

    private var shadowOpacity: Double {
        switch unlockState {
        case .idle: return 0.3
        case .charging: return 0.15
        case .releasing: return 0.20
        }
    }

    private var sparkleScale: CGFloat {
        switch unlockState {
        case .idle: return 1.0
        case .charging: return 0.9
        case .releasing: return 1.15
        }
    }

    private var sparkleRotation: Double {
        switch unlockState {
        case .idle: return 0
        case .charging: return -12
        case .releasing: return 20
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private var categoriesWithWords: [Tab2CategoryData] {
        #if DEBUG
        // 长期保留的走查开关：`TAB2_EMPTY=1` 强制空状态。
        // 空状态在真实账号里几乎不可复现（有数据就再也回不去），没有它就只能靠清库来看一眼。
        // 只读环境变量、不写任何持久化状态——进程退出即失效，不会像早先那批
        // `debug_*` UserDefaults 键那样把设备锁死在假数据上。
        if ProcessInfo.processInfo.environment["TAB2_EMPTY"] == "1" {
            return []
        }
        #endif
        return (vm.data?.categories ?? []).filter { $0.wordCount >= 1 }
    }

    private func sectionHeader(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
            Text(title)
                .font(AppTheme.Font.sectionLabel)
                .foregroundStyle(AppTheme.Color.textMuted)
            Spacer()
            Text(note)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }
}

/// Tab2 解锁页区块显隐决策（刀 6a）——纯函数，视图与单测共用。
/// 标题属于区块，不属于页面：
///  · 规则 1：0 个解锁类目 → Talk about today + Hero + More 整块不渲染（标题一起）。
///  · 规则 2：只有 1 个解锁类目 → 有 Hero、无 More。More 的含义是「除了 Hero
///    还有别的」——唯一那件事被 Hero 占掉，不存在「别的」。
///  · 规则 4：三块全空 → EmptyStateView（规则 5 的页脚随 Hero 在视图层同进同出）。
struct Tab2UnlockedVisibility {
    let showsTalk: Bool
    let showsMore: Bool
    let showsTopics: Bool
    let showsEmptyState: Bool
    /// Topics 渲染输入（与 showsTopics 同源推导，视图直接消费，不重算）。
    let stillFilling: [Tab2CategoryData]
    /// More 渲染输入（同上）。
    let moreRows: [Tab2CategoryData]

    static func compute(
        categories: [Tab2CategoryData],
        hero: Tab2CategoryData?,
        milestoneIDs: Set<String>,
        moreRows: [Tab2CategoryData]
    ) -> Tab2UnlockedVisibility {
        let stillFilling = categories.filter {
            (!$0.unlocked && $0.wordCount >= 1) || milestoneIDs.contains($0.id)
        }
        let showsTalk = hero != nil
        let showsMore = !moreRows.isEmpty
        let showsTopics = !stillFilling.isEmpty
        return Tab2UnlockedVisibility(
            showsTalk: showsTalk,
            showsMore: showsMore,
            showsTopics: showsTopics,
            showsEmptyState: !showsTalk && !showsMore && !showsTopics,
            stillFilling: stillFilling,
            moreRows: moreRows
        )
    }
}

private struct Tab2UnlockedView: View {
    let vm: Tab2HomeViewModel
    /// 刀 4b：Hero 由 MineView 进入页面时求值一次并传入，本视图内只读不重算。
    var hero: Tab2CategoryData? = nil
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    var leaveResetToken: UUID? = nil
    var milestonePresentations: [CategoryMilestonePresentation] = []
    let onTalk: (String) -> Void
    var footerTopSpace: CGFloat = AppTheme.Space.tab2FooterTop
    var footerBottomSpace: CGFloat = AppTheme.Space.tab2FooterBottom
    /// 预览直达（刀 6 截图验收用）：进入页面后自动滚到指定分类行。生产调用恒 nil，无行为变化。
    var initialScrollTarget: String? = nil

    // 单开手风琴：同时只展开一个 Topics-in-Progress 主题；切回 Mine 时回收起。
    @State private var expandedCategoryId: String?
    @State private var refreshHaptics = PullToRefreshHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 刀 6a：区块显隐的单源决策。
    /// 数据未就绪（vm.data == nil）时返回 nil → body 里 `if let visibility` 整块
    /// 不渲染：加载态只显示页面底色，**不会**落进空态分支。规则 4 的
    /// EmptyStateView 只可能出现在「已加载且三块全空」——loading 与 empty
    /// 是两个互斥分支（CLAUDE.md 三态规矩：不允许共用一个分支）。
    private var visibility: Tab2UnlockedVisibility? {
        guard let data = vm.data else { return nil }
        let milestoneIDs = Set(milestonePresentations.map(\.categoryID))
        return Tab2UnlockedVisibility.compute(
            categories: data.categories,
            hero: hero,
            milestoneIDs: milestoneIDs,
            moreRows: vm.moreCategories(excluding: milestoneIDs, hero: hero)
        )
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            GeometryReader { geo in
                let reservedTop = max(topInset, 56)
                let availableHeight = max(geo.size.height - reservedTop, 400)

                ScrollViewReader { proxy in
                    ScrollView {
                        WarmRefreshControlHelper(haptics: refreshHaptics)
                            .frame(width: 0, height: 0)
                            .id(Tab2ScrollAnchor.top)
                        VStack(alignment: .leading, spacing: 0) {
                            // visibility == nil ⟺ vm.data == nil（未加载）：整块不渲染，
                            // 不会闪空态。见 visibility 属性的注释。
                            if let visibility {
                                // 规则 4（刀 6a）：三块全空 → 空态。组件现成，解锁页首次
                                // 接线；minHeight 与锁定页同款——把视图高度提案给组件
                                // 内部 Spacer 均分，内容垂直居中。
                                if visibility.showsEmptyState {
                                    EmptyStateView()
                                        .frame(minHeight: availableHeight)
                                } else {
                                    // 只作用于已解锁页面：最后一个可见卡片（Hero 或 Topics）
                                    contentSections(proxy, visibility: visibility)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                // 规则 5（刀 6a）：页脚宣言与 Hero 区块同进同出。
                                // Spacer 与宣言是一对——负责把短内容的宣言推到底部
                                // 贴暖光，两个必须一起在 Hero 分支里；只挪宣言会在
                                // 空态页面底部多出一段撑开的空白。
                                if visibility.showsTalk {
                                    Spacer(minLength: footerTopSpace)

                                    footerSignoff
                                        .padding(.bottom, footerBottomSpace)
                                }
                            }
                        }
                        .frame(minHeight: availableHeight, alignment: .top)
                        .background(alignment: .bottom) {
                            BottomAuraFooter()
                        }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: reservedTop)
                    }
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .refreshable {
                        refreshHaptics.fire()
                        await vm.load(showFailureHint: true)
                    }
                    .onChange(of: leaveResetToken) { _, _ in
                        proxy.scrollTo(Tab2ScrollAnchor.top, anchor: .top)
                    }
                    .task {
                        // 刀 6 截图验收：预览直达 Topics 行（initialScrollTarget 生产恒 nil，不触发）。
                        guard let target = initialScrollTarget else { return }
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
            }
        }
        .onAppear {
            if vm.isFirstUnlock {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    vm.markFirstUnlockShown()
                }
            }
        }
        .onChange(of: listResetToken) { _, _ in
            expandedCategoryId = nil   // 切回 Mine：回到初始收起
        }
    }

    // 单开手风琴 + 滚动锚定（同 Tab2LockedView）
    private func toggleExpand(_ id: String, _ proxy: ScrollViewProxy) {
        let willExpand = expandedCategoryId != id
        let animation = reduceMotion ? AppTheme.Motion.accordionReducedToggle : AppTheme.Motion.accordionToggle
        withAnimation(animation) {
            expandedCategoryId = willExpand ? id : nil
            if willExpand { proxy.scrollTo(id, anchor: .top) }
        }
    }

    @ViewBuilder
    private func contentSections(_ proxy: ScrollViewProxy, visibility: Tab2UnlockedVisibility) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // ── Talk about today（规则 1/2/5，刀 6a）──
            // 标题属于本区块，不属于页面：有 Hero 才整块渲染，标题一起。
            if let hero {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Talk about today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    Tab2HeroCard(
                        category: hero,
                        onTalk: { onTalk(hero.sceneCategory) }
                    )
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── More to talk about（规则 2 明写，刀 6a）──
            // More 的含义是「除了 Hero 还有别的」：只有 1 个解锁类目时它恰被
            // Hero 占掉、moreRows 自然为空。这是规则，不是副作用——只有一件事
            // 可聊时不存在「别的」，整块（含标题）不渲染。
            if visibility.showsMore {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    // 规则 3（刀 6a）：三标题同档 sectionTitleSerif
                    // （刀 6 §六①曾把 More 降为眉题，本刀改回）。
                    Text("More to talk about")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                        ForEach(visibility.moreRows) { category in
                            Tab2ActivityRow(
                                category: category,
                                onTap: { onTalk(category.sceneCategory) }
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── Topics in Progress——页面级标题 + 磨砂玻璃列表容器 ──
            // 规则 3（刀 6a）：标题同档 sectionTitleSerif（Talk / More / Topics 一致）。
            if visibility.showsTopics {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(spacing: 0) {
                        ForEach(Array(visibility.stillFilling.enumerated()), id: \.element.id) { index, cat in
                            CategoryProgressRow(
                                category: cat,
                                isExpanded: expandedCategoryId == cat.id,
                                onToggle: { toggleExpand(cat.id, proxy) },
                                loadWords: { try await vm.loadCategoryWords(for: cat.sceneCategory) },
                                wordsRevision: vm.categoryWordsRevision,
                                milestonePresentations: milestonePresentations
                            )
                            .id(cat.id)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── More topics to explore（2026-10-03）──
            // 与待解锁页同一组件，贯穿解锁前后；解锁后不带注脚（规则用户已知）。
            let unstarted = SceneCategory.unstarted(given: vm.data?.categories ?? [])
            if !unstarted.isEmpty {
                Tab2MoreTopicsSection(topics: unstarted, resetToken: leaveResetToken)
            }
        }
        // 首个标题（Talk about today 或 Topics in progress）统一落在同一高度，与待解锁页一致。
        .padding(.top, AppTheme.Space.tab2ContentTop)
    }

    private var footerSignoff: some View {
        // 方案 3D（定稿）：【低调静音收束 · 暖灰弱化】
        // 弱化暖灰调，不喧宾夺主，极度安静克制，退后两步不抢上方卡片视线
        VStack(spacing: 6) {
            PoplexWordmark(
                capHeight: 12.5,
                style: .mono(AppTheme.Color.textMuted),
                showsPeriod: true
            )

            Text(Self.footerTagline())
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    /// 目标语言动态解耦（MVP 默认 English，未来支持多语种无缝扩展）
    static func footerTagline(targetLanguage: String = "English") -> String {
        "\(targetLanguage) from your everyday life."
    }
}

// MARK: - Conversation stub (E1 placeholder — replaced when voice dialogue is built)

private struct ConversationStubView: View {
    let sceneCategory: String
    @Environment(\.dismiss) private var dismiss

    private var englishLabel: String {
        SceneCategory(rawValue: sceneCategory)?.englishLabel ?? sceneCategory
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingCard) {
                Spacer()

                Image(systemName: "waveform.circle")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AppTheme.Color.brandStrong.opacity(0.4))

                VStack(spacing: AppTheme.Space.paddingS) {
                    Text(englishLabel)
                        .font(AppTheme.Font.screenTitle)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("Voice practice is coming soon.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Close button — top-left, always reachable
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(Circle())
                    .shadow(
                        color: AppTheme.Shadow.cardColor,
                        radius: AppTheme.Shadow.cardRadius / 2,
                        x: AppTheme.Shadow.cardX,
                        y: AppTheme.Shadow.cardY
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingCard)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 品牌色温润升腾柔光层 (Brand Radiant Ascent Overlay)
// 跨越从待解锁页(消融)到已解锁页(揭开)的全生命周期，提供轻柔通透、袅袅升腾的晨曦微光

private struct BrandRadiantAscentOverlay: View {
    @State private var ascentOffsetY: CGFloat = 40
    @State private var ascentScaleX: CGFloat = 0.95
    @State private var ascentScaleY: CGFloat = 0.90
    @State private var ascentOpacity: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottom) {
                // 1. 轻柔升腾暖幕（自底部向上舒展漫散、轻盈通透的品牌晨光）
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AppTheme.Color.brandTint.opacity(0.16), location: 0.30),
                        .init(color: AppTheme.Color.brandStrong.opacity(0.12), location: 0.60),
                        .init(color: AppTheme.Color.brandStrong.opacity(0.15), location: 0.85),
                        .init(color: AppTheme.Color.brandTint.opacity(0.07), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: w * 1.5, height: h * 0.82)
                .blur(radius: 52)
                .offset(y: ascentOffsetY)
                .scaleEffect(x: ascentScaleX, y: ascentScaleY, anchor: .bottom)
                .opacity(ascentOpacity)

                // 2. 底部原点发光核心（伴随按钮消融升腾的轻柔微光核）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.Color.brandStrong.opacity(0.18),
                                AppTheme.Color.brandTint.opacity(0.10),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 200
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 40)
                    .offset(y: ascentOffsetY * 0.75)
                    .opacity(ascentOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            ascentOffsetY = 40
            ascentScaleX = 0.95
            ascentScaleY = 0.90
            ascentOpacity = 0.0

            // 1. 轻柔淡入
            withAnimation(.easeIn(duration: 0.20)) {
                ascentOpacity = 1.0
            }
            // 2. 向上升腾舒展（垂直方向自然拉伸向上拔起）
            withAnimation(.easeOut(duration: 0.82)) {
                ascentOffsetY = -300
                ascentScaleX = 1.18
                ascentScaleY = 1.45
            }
            // 3. 伴随新页面展开温润消融进背景
            Task {
                try? await Task.sleep(nanoseconds: 480_000_000)
                withAnimation(.easeOut(duration: 0.38)) {
                    ascentOpacity = 0.0
                }
            }
        }
    }
}

#Preview("Tab2 Empty State") {
    Tab2LockedView(vm: Tab2HomeViewModel(), onCapture: {})
        .environment(\.colorScheme, .light)
}

#Preview("Tab2 Load Error") {
    Tab2LoadErrorView { }
}

#Preview("Unlock Radiant Ascent · Replay") {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        BrandRadiantAscentOverlay()
    }
}

#Preview("Tab2 Unlocked") {
    let vm = Tab2HomeViewModel()
    vm.data = Tab2HomeData(
        unlocked: true,
        inputCount: 24,
        categories: [
            Tab2CategoryData(
                sceneCategory: "工作与学业",
                wordCount: 24,
                unlocked: true,
                activityCount: 5
            ),
            Tab2CategoryData(
                sceneCategory: "饮食",
                wordCount: 12,
                unlocked: false,
                activityCount: 3
            )
        ]
    )
    return Tab2UnlockedView(vm: vm, onTalk: { _ in })
        .environment(\.colorScheme, .light)
}

// MARK: - Xcode Canvas 专属对比预览（方案3：晨曦托底 · 字立光上）

#if DEBUG

/// Tab2 底部品牌与收尾视觉探索变体（仅供 Canvas / Debug 预览对比，不进入 Release）
enum Tab2FooterStyle: String, CaseIterable, Identifiable {
    case scheme3Classic    = "方案3A: 经典书刊双行 (深暖墨字 · 晨曦地平光)"
    case scheme3Inline     = "方案3B: 极简单行横排 (空灵通透 · 纤薄晨曦)"
    case scheme3Crest      = "方案3C: 晨曦徽标仪式 (日出P标 · 品牌印记)"
    case scheme3Quiet      = "方案3D: 低调静音收束 (暖灰弱化 · 纯净退后)"
    case currentWatermark  = "对照组: 现状硬叠水印 (旧版对照)"
    case pureAmbient       = "对照组: 纯暖光留白 (无文字对照)"
    case editorialBadge    = "对照组: 杂志微胶囊 (浮雕印章对照)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .scheme3Classic: return "3A 经典双行"
        case .scheme3Inline: return "3B 极简单行"
        case .scheme3Crest: return "3C 晨曦微标"
        case .scheme3Quiet: return "🌟 3D 低调静音 (当前真机方案)"
        case .currentWatermark: return "旧版硬叠"
        case .pureAmbient: return "纯光留白"
        case .editorialBadge: return "微胶囊"
        }
    }
}

#Preview("🌟 方案 3D 页面全览 (当前定稿)") {
    Tab2FullPagePreviewView()
}

#Preview("🌟 方案3 变体交互切换器 (Canvas 可点选切换)") {
    Tab2FooterInteractivePreviewView()
}

#Preview("📐 方案3 变体局部对比矩阵 (同屏一览)") {
    Tab2FooterMatrixPreviewView()
}

// 供 Canvas 交互点击切换的专用容器
private struct Tab2FooterInteractivePreviewView: View {
    @State private var selectedStyle: Tab2FooterStyle = .scheme3Quiet

    var body: some View {
        VStack(spacing: 0) {
            Picker("Footer Style", selection: $selectedStyle) {
                ForEach(Tab2FooterStyle.allCases) { style in
                    Text(style.shortTitle).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) {
                Divider()
            }

            ZStack(alignment: .bottom) {
                AppTheme.Color.pageBg.ignoresSafeArea()
                VStack {
                    Spacer()
                    Tab2FooterSignoffSample(style: selectedStyle)
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                }
                .background(alignment: .bottom) {
                    sampleAura(for: selectedStyle)
                }
            }
        }
    }

    @ViewBuilder
    private func sampleAura(for style: Tab2FooterStyle) -> some View {
        switch style {
        case .scheme3Classic:
            WarmAuraGlow(width: 340, height: 340 * 0.36, peakOpacity: 0.17, offsetY: 68, blurRadius: 20)
        case .scheme3Inline:
            WarmAuraGlow(width: 360, height: 360 * 0.28, peakOpacity: 0.15, offsetY: 55, blurRadius: 20)
        case .scheme3Crest:
            WarmAuraGlow(width: 340, height: 340 * 0.38, peakOpacity: 0.18, offsetY: 70, blurRadius: 20)
        case .scheme3Quiet:
            WarmAuraGlow(width: 320, height: 102, peakOpacity: 0.11, offsetY: 60, blurRadius: 20)
        case .pureAmbient:
            WarmAuraGlow(width: 320, height: 320 * 0.42, peakOpacity: 0.18, offsetY: 35, blurRadius: 20)
        case .currentWatermark, .editorialBadge:
            BottomAuraFooter()
        }
    }
}

// 底部局部对比视口（同屏一览）
private struct Tab2FooterMatrixPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(Tab2FooterStyle.allCases) { style in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(style.rawValue)
                            .font(AppTheme.Font.sectionLabel)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        ZStack(alignment: .bottom) {
                            AppTheme.Color.pageBg

                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "tram.fill")
                                        .foregroundStyle(AppTheme.Color.textSecondary)
                                    Text("Getting around")
                                        .font(AppTheme.Font.englishBody)
                                        .foregroundStyle(AppTheme.Color.textPrimary)
                                    Spacer()
                                    Text("3 words ▾")
                                        .font(AppTheme.Font.pos)
                                        .foregroundStyle(AppTheme.Color.textMuted)
                                }
                                .padding()
                                .surfaceCard()
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                                .padding(.top, 16)

                                Tab2FooterSignoffSample(style: style)
                                    .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                            }
                        }
                        .frame(height: 220)
                        .background(alignment: .bottom) {
                            sampleAura(for: style)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    @ViewBuilder
    private func sampleAura(for style: Tab2FooterStyle) -> some View {
        switch style {
        case .scheme3Classic:
            WarmAuraGlow(width: 340, height: 340 * 0.36, peakOpacity: 0.17, offsetY: 68, blurRadius: 20)
        case .scheme3Inline:
            WarmAuraGlow(width: 360, height: 360 * 0.28, peakOpacity: 0.15, offsetY: 55, blurRadius: 20)
        case .scheme3Crest:
            WarmAuraGlow(width: 340, height: 340 * 0.38, peakOpacity: 0.18, offsetY: 70, blurRadius: 20)
        case .scheme3Quiet:
            WarmAuraGlow(width: 320, height: 102, peakOpacity: 0.11, offsetY: 60, blurRadius: 20)
        case .pureAmbient:
            WarmAuraGlow(width: 320, height: 320 * 0.42, peakOpacity: 0.18, offsetY: 35, blurRadius: 20)
        case .currentWatermark, .editorialBadge:
            BottomAuraFooter()
        }
    }
}

private struct Tab2FooterSignoffSample: View {
    let style: Tab2FooterStyle

    var body: some View {
        switch style {
        case .scheme3Classic:
            VStack(spacing: 7) {
                PoplexWordmark(
                    capHeight: 13.5,
                    style: .mono(AppTheme.Color.textPrimary),
                    showsPeriod: true
                )
                Text(Tab2UnlockedView.footerTagline())
                    .font(AppTheme.Font.libraryFooterTagline)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.top, AppTheme.Space.tab2FooterTop)

        case .scheme3Inline:
            HStack(spacing: 6) {
                Text("Poplex")
                    .font(AppTheme.Font.tab2HeroWord)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text("·")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(Tab2UnlockedView.footerTagline())
                    .font(AppTheme.Font.libraryFooterTagline)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.top, AppTheme.Space.tab2FooterTop + 6)

        case .scheme3Crest:
            VStack(spacing: 5) {
                PoplexPShape()
                    .frame(width: 10 * PoplexPShape.aspect, height: 10)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                PoplexWordmark(
                    capHeight: 12.5,
                    style: .mono(AppTheme.Color.textPrimary),
                    showsPeriod: true
                )
                Text(Tab2UnlockedView.footerTagline())
                    .font(AppTheme.Font.libraryFooterTagline)
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .padding(.top, 1)
            }
            .padding(.top, AppTheme.Space.tab2FooterTop - 4)

        case .scheme3Quiet:
            VStack(spacing: 6) {
                PoplexWordmark(
                    capHeight: 12.5,
                    style: .mono(AppTheme.Color.textMuted),
                    showsPeriod: true
                )
                Text(Tab2UnlockedView.footerTagline())
                    .font(AppTheme.Font.libraryFooterTagline)
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
            }
            .padding(.top, AppTheme.Space.tab2FooterTop)

        case .pureAmbient:
            Color.clear.frame(height: 56)

        case .editorialBadge:
            HStack(spacing: 7) {
                PoplexPShape()
                    .frame(width: 9 * PoplexPShape.aspect, height: 9)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Text("Poplex · English from everyday life")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppTheme.Color.cardBg.opacity(0.88))
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 4, x: 0, y: 2)
            .padding(.top, 36)

        case .currentWatermark:
            VStack(spacing: 9) {
                PoplexWordmark(
                    capHeight: 13,
                    style: .mono(AppTheme.Color.footerSignoffPrimary),
                    showsPeriod: true
                )
                Text(Tab2UnlockedView.footerTagline())
                    .font(AppTheme.Font.libraryFooterTagline)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Color.footerSignoffSecondary)
            }
            .padding(.top, AppTheme.Space.tab2FooterTop)
        }
    }
}

private struct Tab2FullPagePreviewView: View {
    var topSpace: CGFloat = AppTheme.Space.tab2FooterTop
    var bottomSpace: CGFloat = AppTheme.Space.tab2FooterBottom

    private var previewVM: Tab2HomeViewModel {
        let vm = Tab2HomeViewModel()
        vm.data = Tab2HomeData(
            unlocked: true,
            inputCount: 28,
            categories: [
                Tab2CategoryData(
                    sceneCategory: "Work & Study",
                    wordCount: 24,
                    unlocked: true,
                    activityCount: 5
                ),
                Tab2CategoryData(
                    sceneCategory: "Food & Drink",
                    wordCount: 12,
                    unlocked: false,
                    activityCount: 3
                ),
                Tab2CategoryData(
                    sceneCategory: "Social & Feelings",
                    wordCount: 8,
                    unlocked: false,
                    activityCount: 4
                )
            ]
        )
        return vm
    }

    var body: some View {
        Tab2UnlockedView(
            vm: previewVM,
            hero: previewVM.data?.categories.first,
            onTalk: { _ in },
            footerTopSpace: topSpace,
            footerBottomSpace: bottomSpace
        )
        .environment(\.colorScheme, .light)
    }
}

/// 刀 6 验收预览宿主（DEBUG 启动参数 `-tab2Preview`）：一片页面上集齐刀 6 全部
/// 视觉形态——Hero（照片标签 chip / hot 理由胶囊 / 活动块上标与 +N 让位 / 预设底图）、
/// More 行（层级反转 / 时间帽 / 词数行 / 预设图标缩略图）、Topics in progress
/// （words 胶囊 + 恒中性进度）。刀 6a 起加 `-tab2PreviewState 1|2|3|4` 切换
/// 状态矩阵四行（默认 4 = 全形态）。2026-10-03 加 20–24 = 待解锁页 More topics 五档。刀 6b 加 6–16：一页一格、逐格截图——
/// 6–9 = 胶囊溢出四连拍（More 行，与 v12「两行，装得下几个就几个」demo 同名
/// 同数据），10–12 = Hero 理由胶囊三档文案，13–15 = 空态 v1 三连拍
/// （Hero 空态 / More 空态 / 四行混排），16 = hot-onlight 组合（空态 +
/// 今天有新词，设计稿未画的组合，供 PM 复核对比度）。不进 Release。
struct Tab2Knife6PreviewView: View {
    /// 状态矩阵行号（1–4 刀 6a 矩阵；6–16 刀 6b 逐格夹具），默认 4 = 全形态。
    /// 经启动参数 `-tab2PreviewState` 传入。
    private var stateRow: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tab2PreviewState"),
              i + 1 < args.count,
              let row = Int(args[i + 1]) else { return 4 }
        return row
    }

    private var previewVM: Tab2HomeViewModel {
        let vm = Tab2HomeViewModel()
        if stateRow == 1 {
            // 状态矩阵行 ①：0 解锁 + 有在攒 → 只剩 Topics in progress
            // （Talk/More 整块与页脚都不渲染）。
            vm.data = Tab2HomeData(unlocked: true, inputCount: 12, categories: [
                Tab2CategoryData(sceneCategory: "出行交通", wordCount: 7, unlocked: false),
                Tab2CategoryData(sceneCategory: "Social & Feelings", wordCount: 3, unlocked: false),
            ])
            return vm
        }
        if stateRow == 2 {
            // 状态矩阵行 ②：三块全空 → EmptyStateView（解锁页首次接线的空态）。
            vm.data = Tab2HomeData(unlocked: true, inputCount: 0, categories: [])
            return vm
        }
        if stateRow == 3 {
            // 状态矩阵行 ③：仅 1 个解锁 → 有 Hero、无 More（规则 2 明写）。
            vm.data = Tab2HomeData(unlocked: true, inputCount: 8, categories: [
                Tab2CategoryData(
                    sceneCategory: "日常起居",
                    wordCount: 21,
                    unlocked: true,
                    lastMaterialAt: Date(),
                    newMaterialCount: 1,
                    activityCount: 4,
                    activities: [
                        Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 3),
                        Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                    ]
                ),
                Tab2CategoryData(sceneCategory: "出行交通", wordCount: 7, unlocked: false),
            ])
            return vm
        }
        // 状态矩阵行 ⑤（截图辅助，无需专属 fixture）：与 ④ 同数据，只是
        // initialScrollTarget 不滚动——拍页面顶部全景（④ 会在 0.6s 后自动滚到
        // Topics，顶部全景拍不到）。stateRow 取 4 以外任何值且不走 ①②③ 即落到此处。
        // 状态矩阵行 ④（默认）：≥2 解锁 → Talk + Hero + More + Topics 全齐
        // （刀 6 全形态原 fixture，未改动）。
        vm.data = Tab2HomeData(
            unlocked: true,
            inputCount: 28,
            categories: [
                // Hero：今天有新材料 → hot 胶囊「Added something new today」；
                // 无封面 → 预设平底图 + 照片标签；5 条活动（含上标次数、+N 让位）
                Tab2CategoryData(
                    sceneCategory: "日常起居",
                    wordCount: 47,
                    unlocked: true,
                    lastMaterialAt: Date(),
                    newMaterialCount: 1,
                    activityCount: 7,
                    activities: [
                        Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 3),
                        Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                        Tab2Activity(sceneDetail: "Watering plants", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Walking the dog", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Weekend cleaning", occurrenceCount: 1),
                    ]
                ),
                // More 行 A：长活动名挤两行 → 让位 + 上标次数；时间帽 3 天前
                Tab2CategoryData(
                    sceneCategory: "工作与学业",
                    wordCount: 24,
                    unlocked: true,
                    lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                    activityCount: 4,
                    activities: [
                        Tab2Activity(sceneDetail: "Coordinating the quarterly budget review", occurrenceCount: 4),
                        Tab2Activity(sceneDetail: "Preparing slides for the investor update", occurrenceCount: 2),
                        Tab2Activity(sceneDetail: "One-on-ones", occurrenceCount: 1),
                    ]
                ),
                // More 行 B：次数全是 1 → 无上标数字；短名多条排满两行；时间帽 9 天前
                Tab2CategoryData(
                    sceneCategory: "Food & Drink",
                    wordCount: 12,
                    unlocked: true,
                    lastMaterialAt: Calendar.current.date(byAdding: .day, value: -9, to: Date()),
                    activityCount: 5,
                    activities: [
                        Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Cooking dinner", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Grocery shopping", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Baking bread", occurrenceCount: 1),
                        Tab2Activity(sceneDetail: "Trying a new café", occurrenceCount: 1),
                    ]
                ),
                // Topics in progress：锁定且有词 → 页面级标题 + 7 words / 3 words 胶囊
                Tab2CategoryData(
                    sceneCategory: "出行交通",
                    wordCount: 7,
                    unlocked: false
                ),
                Tab2CategoryData(
                    sceneCategory: "Social & Feelings",
                    wordCount: 3,
                    unlocked: false
                ),
            ]
        )
        return vm
    }

    /// 2026-10-03 More topics to explore 验收夹具（20–24 = 待解锁页）：
    /// 已开始主题数 1 / 8 / 9 / 11 / 12 → 剩 11（两排）/ 4（3+1）/ 3 / 1（单排）/ 0（隐藏）。
    private var lockedPreviewVM: Tab2HomeViewModel {
        let startedCount: Int
        switch stateRow {
        case 20: startedCount = 1
        case 21: startedCount = 8
        case 22: startedCount = 9
        case 23: startedCount = 11
        default: startedCount = 12
        }
        let vm = Tab2HomeViewModel()
        // 先从 Digital & Tech 往前开始，Other 最后才开始——让「Other 恒在末尾」在各档夹具里都看得见。
        let startOrder: [SceneCategory] = [.tech, .social, .weather, .leisure, .healthFitness, .gettingAround,
                                           .shopping, .food, .dailyRoutines, .workStudy, .homeFamily, .other]
        let started = startOrder.prefix(startedCount)
        vm.data = Tab2HomeData(unlocked: false, inputCount: startedCount, categories: started.enumerated().map { index, cat in
            Tab2CategoryData(sceneCategory: cat.rawValue, wordCount: index == 0 ? 5 : 1, unlocked: false)
        })
        return vm
    }

    var body: some View {
        if stateRow >= 20 {
            Tab2LockedView(vm: lockedPreviewVM, onCapture: {})
                .environment(\.colorScheme, .light)
        } else if (6...16).contains(stateRow) {
            knife6bFixture
                .environment(\.colorScheme, .light)
        } else {
            Tab2UnlockedView(
                vm: previewVM,
                // 行 ①②：0 解锁 → hero 必须传 nil（hero 语义是「首个解锁类目」，
                // 无条件取首条会让 0 解锁行凭空出现 Hero）。
                hero: (stateRow == 1 || stateRow == 2) ? nil : previewVM.data?.categories.first,
                onTalk: { _ in },
                footerTopSpace: AppTheme.Space.tab2FooterTop,
                footerBottomSpace: AppTheme.Space.tab2FooterBottom,
                // 刀 6 截图验收：行 ④ 直达 Topics 首行（出行交通）；
                // 行 ①②③ 停在页面顶部拍显隐。
                initialScrollTarget: (stateRow == 4) ? "出行交通" : nil
            )
            .environment(\.colorScheme, .light)
        }
    }

    // MARK: - 刀 6b 逐格截图夹具（stateRow 6–16）

    /// 一页一格：6–9 单条 More 行、10–13/16 单张 Hero 卡，都停在页面顶部同一位置，
    /// 逐格截图后四连拍行高可直接比对。15 = 空态混排四行（有内容两行与空态
    /// 两行同屏，验证两种行高混排不乱）。More 行无封面 → 预设缩略图（离线安全）。
    @ViewBuilder
    private var knife6bFixture: some View {
        ScrollView {
            if stateRow == 15 {
                VStack(spacing: AppTheme.Space.paddingM) {
                    ForEach(0..<knife6bMixedCategories.count, id: \.self) { i in
                        Tab2ActivityRow(category: knife6bMixedCategories[i], onTap: {})
                    }
                }
                .padding(.top, AppTheme.Space.paddingSection)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            } else {
                VStack(spacing: 0) {
                    if (10...13).contains(stateRow) || stateRow == 16 {
                        Tab2HeroCard(category: knife6bCategory, onTalk: {})
                    } else {
                        Tab2ActivityRow(category: knife6bCategory, onTap: {})
                    }
                }
                .padding(.top, AppTheme.Space.paddingSection)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
        .background(AppTheme.Color.pageBg)
    }

    /// 空态③混排夹具（stateRow 15，与空态 v1 设计稿同数据）：
    /// Work & Study（Working / Studying / Meetings / Quarterly budget review
    /// +1 more，两条长名让位）→ Digital & Tech（空）→ Shopping（空）→
    /// Social & Feelings（+9 more）。空态行矮、有内容行高，两种行高交错同屏。
    private var knife6bMixedCategories: [Tab2CategoryData] {
        let today = Date()
        let cal = Calendar.current
        func ago(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: today)! }
        return [
            Tab2CategoryData(
                sceneCategory: "Work & Study", wordCount: 53, unlocked: true,
                lastMaterialAt: ago(1), activityCount: 5,
                activities: [
                    Tab2Activity(sceneDetail: "Working", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Studying", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Meetings", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Quarterly budget review", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Investor update meeting", occurrenceCount: 1),
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Digital & Tech", wordCount: 31, unlocked: true,
                lastMaterialAt: ago(2), activityCount: 0,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "Shopping", wordCount: 24, unlocked: true,
                lastMaterialAt: ago(4), activityCount: 0,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "Social & Feelings", wordCount: 27, unlocked: true,
                lastMaterialAt: ago(3), activityCount: 12,
                activities: [
                    Tab2Activity(sceneDetail: "Sharing thoughts", occurrenceCount: 3),
                    Tab2Activity(sceneDetail: "Catching up", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Texting", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Quarterly budget review", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Investor update meeting", occurrenceCount: 1),
                ]
            ),
        ]
    }

    /// 刀 6b 夹具数据——溢出四连拍与 v12 demo 同名同量（“Working / Studying /
    /// Meetings / Emails / Reading” 等），三档文案取 §二② 的 N=3 / N=1 / quiet。
    /// 例外：demo 的超长名（28/40/38 字符）超出 Tab2SceneDetailValidation 的
    /// ≤24 字符上限、线上永不渲染，②③ 两格取上限内最长名复现让位形状。
    private var knife6bCategory: Tab2CategoryData {
        let today = Date()
        let cal = Calendar.current
        func ago(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: today)! }
        switch stateRow {
        case 6:
            // 溢出①：5 条短名全排下（两行），+N 为 0 不渲染
            return Tab2CategoryData(
                sceneCategory: "工作与学业", wordCount: 53, unlocked: true,
                lastMaterialAt: ago(1), activityCount: 5,
                activities: [
                    Tab2Activity(sceneDetail: "Working", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Studying", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Meetings", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Emails", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Reading", occurrenceCount: 1),
                ]
            )
        case 7:
            // 溢出②：24 字符长名（校验上限内最长）→ 完整无省略号、让位 +N
            // 注：v12 demo 原用 28 字符名，超出 Tab2SceneDetailValidation 的
            // ≤24 字符上限，线上永不出现——fixture 取上限内最长名。
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: today, activityCount: 6,
                activities: [
                    Tab2Activity(sceneDetail: "Organizing daily routine", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Getting up", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Making coffee", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Watering plants", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Walking the dog", occurrenceCount: 1),
                ]
            )
        case 8:
            // 溢出③：12 个活动 → 3 显示 + “+9 more”（后两条长名让位）
            // 注：v12 demo 原用 40/38 字符长名，同样超 24 字符上限——换成上限内
            // 最长的两条，让位形状不变、blocked 归零、+N 与 demo 同为 +9。
            return Tab2CategoryData(
                sceneCategory: "Social & Feelings", wordCount: 27, unlocked: true,
                lastMaterialAt: ago(3), activityCount: 12,
                activities: [
                    Tab2Activity(sceneDetail: "Sharing thoughts", occurrenceCount: 3),
                    Tab2Activity(sceneDetail: "Catching up", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Texting", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Quarterly budget review", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Investor update meeting", occurrenceCount: 1),
                ]
            )
        case 9:
            // 溢出④：只有 1 颗、第二行空着高度照占
            return Tab2CategoryData(
                sceneCategory: "出行交通", wordCount: 22, unlocked: true,
                lastMaterialAt: ago(4), activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Waiting for the bus", occurrenceCount: 1),
                ]
            )
        case 10:
            // 理由胶囊 hot 复数：Added 3 times today
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: today, newMaterialCount: 3, activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Cooking dinner", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Walking the dog", occurrenceCount: 1),
                ]
            )
        case 11:
            // 理由胶囊 hot 单数：Added something today
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: today, newMaterialCount: 1, activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Cooking dinner", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Walking the dog", occurrenceCount: 1),
                ]
            )
        case 13:
            // 空态①：Hero 无 activity → 预设浅底 + onlight 标签（quiet
            // Nothing new in 5 days，与空态 v1 设计稿 Hero 示例同数据）+
            // 标题保留 + 一行 Only words so far + 脚行
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: ago(5), activityCount: 0,
                activities: []
            )
        case 14:
            // 空态②：More 无 activity → 帽行 + 一行 Only words so far +
            // 词数行（tight 上距），行高下限收掉——行就是矮的（同设计稿示例）
            return Tab2CategoryData(
                sceneCategory: "Digital & Tech", wordCount: 31, unlocked: true,
                lastMaterialAt: ago(2), activityCount: 0,
                activities: []
            )
        case 16:
            // 空态③ hot-onlight：空态 + 今天有新词（hot 橙点 + primaryDeep
            // 文字出现在浅底上——设计稿未画的组合，PM 复核点：对比度）。
            // hot 判定 = newMaterialCount ≥ 1 且 lastMaterialAt 为今天。
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: today, newMaterialCount: 2, activityCount: 0,
                activities: []
            )
        default: // 12
            // 理由胶囊 quiet：Nothing new in 4 days
            return Tab2CategoryData(
                sceneCategory: "日常起居", wordCount: 47, unlocked: true,
                lastMaterialAt: ago(4), activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Cooking dinner", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Walking the dog", occurrenceCount: 1),
                ]
            )
        }
    }
}

#endif

