import SwiftUI

private enum MineRoute: Hashable {
    case conversation(sceneCategory: String)
}

struct MineView: View {
    var listResetToken: UUID = UUID()      // kept for RootTabContainer compat
    @Binding var swipeActionOpen: Bool
    @Binding var detailActive: Bool
    var topInset: CGFloat = 0
    /// Called when user taps "Capture something" in locked state — switches to Tab1
    var onSwitchToToday: (() -> Void)? = nil

    @State private var vm = Tab2HomeViewModel()
    @State private var path: [MineRoute] = []
    @State private var comingSoonToast: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 解锁揭幕转场：减弱动态时只淡入（不做从底部缩放生长）
    private var unlockRevealTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.82, anchor: .bottom))
    }

    init(
        listResetToken: UUID = UUID(),
        swipeActionOpen: Binding<Bool> = .constant(false),
        detailActive: Binding<Bool> = .constant(false),
        topInset: CGFloat = 0,
        onSwitchToToday: (() -> Void)? = nil
    ) {
        self.listResetToken = listResetToken
        self._swipeActionOpen = swipeActionOpen
        self._detailActive = detailActive
        self.topInset = topInset
        self.onSwitchToToday = onSwitchToToday
    }

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
                .toolbar(.hidden, for: .navigationBar)
                .task { await vm.load() }
                .onChange(of: listResetToken) { _, _ in
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
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: topInset)
                }
                .toast(
                    message: Binding(get: { vm.toastMessage }, set: { vm.toastMessage = $0 }),
                    systemImage: "exclamationmark.triangle"
                )
                .toast(message: $comingSoonToast, systemImage: "clock")
                .navigationDestination(for: MineRoute.self) { route in
                    switch route {
                    case .conversation(let cat):
                        ConversationView(sceneCategory: cat, onDismiss: { path.removeLast() })
                    }
                }
        }
    }

    // MARK: - State machine

    @ViewBuilder
    private var mainContent: some View {
        if vm.isLoading && vm.data == nil {
            skeletonView
        } else if vm.errorMessage != nil && vm.data == nil {
            ConnectionRetryView { Task { await vm.load() } }
        } else if vm.isPermanentlyUnlocked {
            Tab2UnlockedView(
                vm: vm,
                onTalk: { cat in
                    if FeatureFlags.conversationEnabled {
                        path.append(.conversation(sceneCategory: cat))
                    } else {
                        comingSoonToast = "Coming soon"
                    }
                }
            )
            // 从橙波原点（底部按钮处）向上"揭幕"生长浮现 + 淡入（减弱动态时只淡入）
            .transition(unlockRevealTransition)
        } else {
            Tab2LockedView(
                vm: vm,
                onCapture: { onSwitchToToday?() }
            )
            // 锁定页（含全屏橙波）淡出，露出下面的解锁页
            .transition(.opacity)
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
    let onCapture: () -> Void

    private let wordTarget  = 20

    @State private var unlockState: UnlockState = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()
            
            // 1. 待解锁页面内容（固定顶栏空间，卡片与 Header 独立协同避让）
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                    headerSection
                    
                    VStack(spacing: AppTheme.Space.paddingPage) {
                        topicsCard
                    }
                    // 不再压缩/下沉当前页——解锁重点是"呈现新内容"，旧页保持不动、随整页转场离场

                    captureButton
                }
                .padding(.top, AppTheme.Space.paddingSection)     // 顶部呼吸
                .padding(.bottom, AppTheme.Space.paddingPage)
                // 锁回屏宽、左对齐
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 释放时暖橙"洗版"：从按钮位置(底部)向上的渐变，下浓上淡——能量从按钮升腾、呈现新内容
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: AppTheme.Color.brandStrong, location: 0.0),
                            .init(color: AppTheme.Color.brandStrong.opacity(0), location: 0.78)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .opacity(unlockState == .releasing ? 0.9 : 0.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeIn(duration: 0.4), value: unlockState)
        }
    }

    // ── 待解锁 header ────────────────────────────────────────────────────
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Not open yet")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            
            hintText
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.bottom, AppTheme.Space.paddingS)
        // 顶部 Header 动效处理：蓄力时平稳贴合(y:+3)，释放时向上顺畅离场(y:-28, opacity:0)
        // header 不随蓄力下压/变暗，保持不动——解锁重点是呈现新内容，不是压旧页
    }

    private var hintText: some View {
        Text("Reach 20 words in any topic to start practicing.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    // ── TOPICS list ──────────────────────────────────────────────────────
    private var topicsCard: some View {
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
                // 卡片：话题行装回白卡（与解锁态 Topics in progress 卡同款；标题在卡外）
                // 行间不叠额外 spacing——由行内 .padding(.vertical,12) 统一决定间距，避免 12+8+12 的叠加乱节奏
                VStack(spacing: 0) {
                    ForEach(cats) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isHighlighted: cat.id == topId,
                            loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                        )
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
    }

    // ── CTA ──────────────────────────────────────────────────────────────
    private var captureButton: some View {
        let isReady = vm.isReadyToUnlock
        return Button {
            if isReady {
                if reduceMotion {
                    // 减弱动态：跳过蓄力/爆发/全屏橙波，单次轻震动 + 简单淡入切换
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.confirmUnlock()
                    }
                } else {
                    // 1. 蓄力阶段 (Heavy Impact + 深入压实下沉)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        unlockState = .charging
                    }

                    Task {
                        // 延长蓄力停顿到 450ms - 增强蓄势凝结感
                        try? await Task.sleep(nanoseconds: 450_000_000)

                        // 2. 舒张全屏释放阶段 (Heavy Impact + 能量波扫过全屏)
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                            unlockState = .releasing
                        }

                        // 3. 能量波覆盖全屏后，橙波淡出、解锁页揭幕淡入（用 withAnimation 驱动分支转场）
                        try? await Task.sleep(nanoseconds: 480_000_000)
                        withAnimation(.spring(response: 0.58, dampingFraction: 0.8)) {
                            vm.confirmUnlock()
                        }
                    }
                }
            } else {
                onCapture()
            }
        } label: {
            ZStack {
                // 蓄力光晕层：charging 时橙光在 0.45s 内 easeIn 由弱到强、由小到大地"攒劲"，
                // 把这半秒的等待变成看得见的"正在充能"，再爆发（releasing 时交给 bloom/shockwave）
                Capsule()
                    .fill(AppTheme.Color.brandStrong)
                    .blur(radius: 16)
                    .scaleEffect(unlockState == .charging ? 1.22 : 0.85)
                    .opacity(unlockState == .charging ? 0.5 : 0.0)
                    .animation(.easeIn(duration: 0.45), value: unlockState)

                // 舒张发光的背影光晕层 (Bloom Glow Layer)——释放时铺得更大更软，橙色散开
                Capsule()
                    .fill(AppTheme.Color.brandStrong)
                    .blur(radius: unlockState == .releasing ? 56 : 0)
                    .scaleEffect(unlockState == .releasing ? 4.5 : 0.8)
                    .opacity(unlockState == .releasing ? 0.72 : 0.0)

                HStack(spacing: AppTheme.Space.paddingS) {
                    if isReady {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .scaleEffect(sparkleScale)
                            .rotationEffect(.degrees(sparkleRotation))
                    }
                    Text(isReady ? "You're all set" : "Capture something")
                }
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.cardBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Color.interactive)   // 保持染色黑（点击变橙显得怪，去掉）
                .clipShape(Capsule())
                .shadow(
                    color: AppTheme.Color.interactive.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
                .scaleEffect(buttonScale)
                .opacity(buttonOpacity)      // 释放时溶解：淡出
                .blur(radius: buttonBlur)     // + 虚化，溶进能量爆发
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingS)
    }

    private var buttonScale: CGFloat {
        switch unlockState {
        case .idle: return 1.0
        case .charging: return 0.84   // 蓄力压实下沉
        case .releasing: return 1.0   // 不放大——纯淡出+虚化原地消散
        }
    }

    // 释放时按钮"溶解"：原地淡出 + 虚化，安静化掉（散开交给橙色 bloom）
    private var buttonOpacity: Double { unlockState == .releasing ? 0 : 1 }
    private var buttonBlur: CGFloat { unlockState == .releasing ? 16 : 0 }

    private var shadowRadius: CGFloat {
        switch unlockState {
        case .idle: return 10
        case .charging: return 2
        case .releasing: return 24
        }
    }

    private var shadowY: CGFloat {
        switch unlockState {
        case .idle: return 4
        case .charging: return 1
        case .releasing: return 10
        }
    }

    private var shadowOpacity: Double {
        switch unlockState {
        case .idle: return 0.3
        case .charging: return 0.1
        case .releasing: return 0.6
        }
    }

    private var sparkleScale: CGFloat {
        switch unlockState {
        case .idle: return 1.0
        case .charging: return 0.7
        case .releasing: return 1.6
        }
    }

    private var sparkleRotation: Double {
        switch unlockState {
        case .idle: return 0
        case .charging: return -30
        case .releasing: return 60
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private var categoriesWithWords: [Tab2CategoryData] {
        (vm.data?.categories ?? []).filter { $0.wordCount >= 1 }
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
    let onTalk: (String) -> Void

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Talk about something")
                            .font(AppTheme.Font.pageTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Text("Scenarios built from your daily moments.")
                            .font(AppTheme.Font.englishBody)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Space.paddingPage)

                    contentSections
                }
                .padding(.bottom, AppTheme.Space.paddingPage * 2)
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
    }

    @ViewBuilder
    private var contentSections: some View {
        if let data = vm.data {
            let hero   = vm.heroCategory()
            let heroId = hero?.id
            let otherUnlocked = data.categories.filter { $0.unlocked && $0.id != heroId }

            // 已解锁分类：独立 Serif 标题 "Materials Yours" + 横向 Peek 轮播卡片
            if hero != nil || !otherUnlocked.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Materials Yours")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            if let hero {
                                Tab2HeroCard(
                                    category: hero,
                                    isFirstUnlock: vm.isFirstUnlock,
                                    onTalk: { onTalk(hero.sceneCategory) }
                                )
                                .frame(width: 335)
                            }

                            ForEach(otherUnlocked) { cat in
                                Tab2CategoryRow(
                                    category: cat,
                                    onTalk: { onTalk(cat.sceneCategory) }
                                )
                                .frame(width: 335)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(AppTheme.Color.brandSubtleBg.opacity(0.4))
                    )
                    .padding(.horizontal, AppTheme.Space.paddingS)
                }
            }

            // Topics in Progress——独立 Serif 标题 "Topics in Progress" + 纯列表圆角白卡容器
            let stillFilling = data.categories.filter { !$0.unlocked && $0.wordCount >= 1 }
            if !stillFilling.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Topics in Progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(spacing: 4) {
                        ForEach(stillFilling) { cat in
                            CategoryProgressRow(
                                category: cat,
                                isHighlighted: false,
                                loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    .shadow(
                        color: Color.black.opacity(0.04),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                    .padding(.horizontal, AppTheme.Space.paddingPage)
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

#Preview {
    MineView()
}
