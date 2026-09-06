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
    @State private var isRadiantAscentActive: Bool = false
    @State private var lockedBottomBarHeight: CGFloat = 0
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
                Task { await vm.load() }
            }
            .onChange(of: path) { _, newPath in
                detailActive = !newPath.isEmpty
            }
            .onChange(of: vm.isPermanentlyUnlocked) { _, newValue in
                if newValue {
                    lockedBottomBarHeight = 0
                    withAnimation(AppTheme.Motion.tabSelection) {}
                }
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
            .toast(
                message: Binding(get: { vm.toastMessage }, set: { vm.toastMessage = $0 }),
                systemImage: "exclamationmark.triangle",
                extraBottomOffset: toastExtraBottomOffset
            )
            .toast(
                message: $comingSoonToast,
                systemImage: "clock",
                extraBottomOffset: toastExtraBottomOffset
            )
            .toast(
                message: $milestoneToast,
                systemImage: "sparkles",
                lifetime: AppTheme.Motion.milestoneToastLifetime,
                extraBottomOffset: toastExtraBottomOffset
            )
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
            topInset: topInset,
            listResetToken: listResetToken,
            milestonePresentations: visibleMilestonePresentations,
            onTalk: { cat in
                if FeatureFlags.conversationEnabled {
                    path.append(.conversation(sceneCategory: cat))
                } else {
                    comingSoonToast = "Coming soon"
                }
            }
        )
    }

    private var lockedView: some View {
        Tab2LockedView(
            vm: vm,
            topInset: topInset,
            listResetToken: listResetToken,
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

private struct Tab2LockedView: View {
    let vm: Tab2HomeViewModel
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
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
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                                headerSection

                                VStack(spacing: AppTheme.Space.paddingPage) {
                                    topicsCard(proxy)
                                }
                            }
                            .padding(.top, AppTheme.Space.paddingSection)     // 顶部呼吸
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

    // ── 待解锁 header ────────────────────────────────────────────────────
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
            Text("Not open yet")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
            
            hintText
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.bottom, AppTheme.Space.paddingS)
    }

    private var hintText: some View {
        Text("Reach 20 pops in any topic to start talking.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
            .lineSpacing(AppTheme.Typography.lineBody)
    }

    // ── 无数据空状态（Warm Minimalism 减法设计）───────────────────────────
    // 按钮已提升至外层 safeAreaInset 统一沉底，此处专注纯净负空间居中
    private var emptyStateView: some View {
        EmptyStateView()
    }

    // ── TOPICS list ──────────────────────────────────────────────────────
    private func topicsCard(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Topics in progress")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingM)

            let cats  = categoriesWithWords
            let topId = closestCategory?.id

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
                            isHighlighted: cat.id == topId,
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
                .surfaceCard()
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

    private var closestCategory: Tab2CategoryData? {
        categoriesWithWords.max(by: { $0.wordCount < $1.wordCount })
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

private struct Tab2UnlockedView: View {
    let vm: Tab2HomeViewModel
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    var milestonePresentations: [CategoryMilestonePresentation] = []
    let onTalk: (String) -> Void
    var footerTopSpace: CGFloat = AppTheme.Space.tab2FooterTop
    var footerBottomSpace: CGFloat = AppTheme.Space.tab2FooterBottom

    // 单开手风琴：同时只展开一个 Topics-in-Progress 主题；切回 Mine 时回收起。
    @State private var expandedCategoryId: String?
    @State private var refreshHaptics = PullToRefreshHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Talk about today")
                                .font(AppTheme.Font.sectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.top, AppTheme.Space.paddingPage)
                            // 与「Topics in progress → 卡片」保持同一标题到内容节奏。
                            .padding(.bottom, AppTheme.Space.paddingCard)

                            // 只作用于已解锁页面：最后一个可见卡片（Hero 或 Topics）
                            contentSections(proxy)

                            // 页面底部收尾宣言
                            footerSignoff
                                .padding(.bottom, footerBottomSpace)
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
    private func contentSections(_ proxy: ScrollViewProxy) -> some View {
        if let data = vm.data {
            let milestoneIDs = Set(milestonePresentations.map(\.categoryID))
            let hero   = vm.heroCategory(excluding: milestoneIDs)
            let stillFilling = data.categories.filter {
                (!$0.unlocked && $0.wordCount >= 1) || milestoneIDs.contains($0.id)
            }

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                if let hero {
                    Tab2HeroCard(
                        category: hero,
                        onTalk: { onTalk(hero.sceneCategory) }
                    )
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // More to talk about——hero 之后的推荐行（§3/§4）。行状态由行组件
                // 按 featured 有无自行判定，不再跟踪「聊过」。空列表时标题与列表
                // 整块不渲染（§6）：只有一件事可聊，不假装有选择。
                let moreRows = vm.moreCategories(excluding: milestoneIDs, hero: hero)
                if !moreRows.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        Text("More to talk about")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                            ForEach(moreRows) { category in
                                Tab2MomentRow(
                                    category: category,
                                    onTap: { onTalk(category.sceneCategory) }
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }

                // Topics in Progress——独立 Serif 标题 + 磨砂玻璃列表容器
                if !stillFilling.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        VStack(spacing: 0) {
                            ForEach(Array(stillFilling.enumerated()), id: \.element.id) { index, cat in
                                CategoryProgressRow(
                                    category: cat,
                                    isHighlighted: false,
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
                        .surfaceCard()
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }
            }
        }
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
        .padding(.top, footerTopSpace)
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
                momentCount: 5
            ),
            Tab2CategoryData(
                sceneCategory: "饮食",
                wordCount: 12,
                unlocked: false,
                previewWords: [
                    Tab2PreviewWord(lemma: "comfort food"),
                    Tab2PreviewWord(lemma: "grab a bite")
                ],
                momentCount: 3
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
                                    Text("3 pops ▾")
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
                    sceneCategory: "工作与学业",
                    wordCount: 24,
                    unlocked: true,
                    momentCount: 5
                ),
                Tab2CategoryData(
                    sceneCategory: "饮食与生活",
                    wordCount: 12,
                    unlocked: false,
                    previewWords: [
                        Tab2PreviewWord(lemma: "comfort food"),
                        Tab2PreviewWord(lemma: "grab a bite")
                    ],
                    momentCount: 3
                ),
                Tab2CategoryData(
                    sceneCategory: "日常社交",
                    wordCount: 8,
                    unlocked: false,
                    previewWords: [
                        Tab2PreviewWord(lemma: "catch up"),
                        Tab2PreviewWord(lemma: "take it easy")
                    ],
                    momentCount: 4
                )
            ]
        )
        return vm
    }

    var body: some View {
        Tab2UnlockedView(
            vm: previewVM,
            onTalk: { _ in },
            footerTopSpace: topSpace,
            footerBottomSpace: bottomSpace
        )
        .environment(\.colorScheme, .light)
    }
}

#endif

