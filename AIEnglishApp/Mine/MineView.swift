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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                systemImage: "exclamationmark.triangle"
            )
            .toast(message: $comingSoonToast, systemImage: "clock")
            .toast(
                message: $milestoneToast,
                systemImage: "sparkles",
                lifetime: AppTheme.Motion.milestoneToastLifetime
            )
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
    // 单开手风琴：同时只展开一个主题；切回 Mine（listResetToken 变化）时回收起。
    @State private var expandedCategoryId: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            if categoriesWithWords.isEmpty {
                GeometryReader { geo in
                    let reservedTop = max(topInset, 56)

                    ScrollView {
                        WarmRefreshControlHelper()
                            .frame(width: 0, height: 0)
                        emptyStateView
                            // safeAreaInset 会从实际滚动视口中扣除 reservedTop。
                            // 内容高度也必须按同一个视口计算，否则空状态会比视口高一截，
                            // 导致首次布局与刷新回弹落在不同的滚动锚点。
                            .frame(minHeight: max(geo.size.height - reservedTop, 400))
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: reservedTop)
                    }
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .refreshable {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        await vm.load(showFailureHint: true)
                    }
                }
            } else {
                // 1. 待解锁页面内容（固定顶栏空间，卡片与 Header 独立协同避让）
                ScrollViewReader { proxy in
                    ScrollView {
                        WarmRefreshControlHelper()
                            .frame(width: 0, height: 0)
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                            headerSection

                            VStack(spacing: AppTheme.Space.paddingPage) {
                                topicsCard(proxy)
                            }

                            captureButton()
                        }
                        .padding(.top, AppTheme.Space.paddingSection)     // 顶部呼吸
                        .padding(.bottom, AppTheme.Space.paddingPage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: max(topInset, 56))
                    }
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .refreshable {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        await vm.load(showFailureHint: true)
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
        .blur(radius: unlockState == .releasing ? 8 : 0)
        .opacity(unlockState == .releasing ? 0 : 1)
        .scaleEffect(unlockState == .releasing ? 0.98 : 1.0)
        .animation(AppTheme.Motion.unlockDissolve, value: unlockState)
        .onChange(of: listResetToken) { _, _ in
            expandedCategoryId = nil   // 切回 Mine：回到初始收起
        }
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
    // 采用通用 EmptyStateView，以叠纸插画 + 优雅 Typography 构建舒展居中负空间。
    // 底部 CTA 沉底作为唯一操作焦点。
    private var emptyStateView: some View {
        // CTA 必须与文案同处一个 VStack、真正参与布局，不能用 overlay 浮在上面。
        // overlay 不占布局位置：CTA 一旦因大字号换行长高，就会直接压住正文
        // （实测 AX5 下「your day.」被盖掉）。EmptyStateView 自身吃满剩余高度，
        // CTA 自然沉底，两者从此互相知道对方多高。
        VStack(spacing: 0) {
            EmptyStateView()

            captureButton(showsCaptureIcon: true)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingSection)
        }
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
            .opacity(buttonOpacity)      // 释放时溶解：淡出
            .blur(radius: buttonBlur)     // + 虚化，溶入升腾光晕
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

    // 释放时按钮原地淡出 + 柔和虚化
    private var buttonOpacity: Double { unlockState == .releasing ? 0 : 1 }
    private var buttonBlur: CGFloat { unlockState == .releasing ? 8 : 0 }

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

// MARK: - Unlocked view


private struct Tab2UnlockedView: View {
    let vm: Tab2HomeViewModel
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    var milestonePresentations: [CategoryMilestonePresentation] = []
    let onTalk: (String) -> Void

    // 单开手风琴：同时只展开一个 Topics-in-Progress 主题；切回 Mine 时回收起。
    @State private var expandedCategoryId: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    WarmRefreshControlHelper()
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
                        // 与底部安全区之间保留明确的收尾空间。
                        contentSections(proxy)
                            .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: max(topInset, 56))
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .refreshable {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    await vm.load(showFailureHint: true)
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

#Preview {
    MineView()
}
