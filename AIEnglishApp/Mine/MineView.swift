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
                topInset: topInset,
                listResetToken: listResetToken,
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
                topInset: topInset,
                listResetToken: listResetToken,
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
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    let onCapture: () -> Void

    private let wordTarget  = 20

    @State private var unlockState: UnlockState = .idle
    // 单开手风琴：同时只展开一个主题；切回 Mine（listResetToken 变化）时回收起。
    @State private var expandedCategoryId: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            if categoriesWithWords.isEmpty {
                // 无数据空状态（方案A · 极简居中）：整页垂直居中，CTA 沉底
                emptyStateView
            } else {
                // 1. 待解锁页面内容（固定顶栏空间，卡片与 Header 独立协同避让）
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                            headerSection

                            VStack(spacing: AppTheme.Space.paddingPage) {
                                topicsCard(proxy)
                            }
                            // 不再压缩/下沉当前页——解锁重点是"呈现新内容"，旧页保持不动、随整页转场离场

                            captureButton
                        }
                        .padding(.top, AppTheme.Space.paddingSection)     // 顶部呼吸
                        .padding(.bottom, AppTheme.Space.paddingPage)
                        // 锁回屏宽、左对齐
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentMargins(.top, topInset, for: .scrollContent)
                }
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
        .onChange(of: listResetToken) { _, _ in
            expandedCategoryId = nil   // 切回 Mine：回到初始收起
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
        Text("Reach 20 pops in any topic to start practicing.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    // ── 无数据空状态（方案A · 极简居中）──────────────────────────────────
    // 中央徽章 = 生活缤纷方向 H4 的暖单色版（时刻小卡，只留品牌橙 + 暖中性灰）。
    // CTA 复用 captureButton：空状态下 isReady 恒为 false，点了跳 Tab1 去记录。
    private var emptyStateView: some View {
        // 中央内容块：相对整页垂直居中
        VStack(spacing: 0) {
            EmptyMomentGlyph()
                .padding(.bottom, 26)

            Text("Nothing here yet")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.bottom, AppTheme.Space.paddingM)

            Text("Capture a moment from your day. It becomes English you can use.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // CTA：overlay 沉底，不参与中央块的居中计算（否则内容会被顶偏上）
        .overlay(alignment: .bottom) {
            captureButton
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
                .padding(.bottom, AppTheme.Space.titleToContent)

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
                            loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                        )
                        .id(cat.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .warmGlassCard()
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
    }

    // 单开手风琴 + 滚动锚定：展开时把点开的行滚到顶部对齐，收起上一个，视线始终锁在这一行。
    private func toggleExpand(_ id: String, _ proxy: ScrollViewProxy) {
        let willExpand = expandedCategoryId != id
        withAnimation(.easeInOut(duration: 0.28)) {
            expandedCategoryId = willExpand ? id : nil
            if willExpand { proxy.scrollTo(id, anchor: .top) }
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
            .frame(height: 52)    // 与 Tab1 InputBar 胶囊同高
            .background(AppTheme.Color.interactive)   // 保持染色黑（点击变橙显得怪，去掉）
            .clipShape(Capsule())
            // 光晕层挂为 pill 的 background：尺寸跟随胶囊、不参与布局。
            // 原来作为 ZStack 兄弟节点的贪婪 Capsule 会把 button 撑满整个可用高度
            // （在底部 overlay 里可见胶囊因此被顶到屏幕正中）
            .background {
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
            .blur(radius: buttonBlur)     // + 虚化，溶进能量爆发
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
        #if DEBUG
        // 临时走查钩子：TAB2_EMPTY=1 强制空状态（验证完即删，勿提交）
        if ProcessInfo.processInfo.environment["TAB2_EMPTY"] == "1" { return [] }
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

// MARK: - 空状态中央徽章（方案A · H4 暖单色：玻璃圆 + 微倾时刻小卡）

/// 一张微倾的迷你"时刻卡"：浅橘照片区 + 橙色小太阳 + 暖灰小山与文字行，
/// 只取品牌橙与暖中性灰两族，不引入多色，避免杂乱。
private struct EmptyMomentGlyph: View {
    var body: some View {
        ZStack {
            // 暖橙光晕：提亮顶部区域，限制在玻璃圆内避免撑大间距
            Circle()
                .fill(AppTheme.Color.brandStrong.opacity(0.12))
                .frame(width: 80, height: 80)
                .blur(radius: 14)

            ZStack {
                momentCard
                // 卡外一颗橙色小点，破开对称、添一点"散落的生活感"
                Circle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 5, height: 5)
                    .offset(x: 19, y: -17)
            }
            .frame(width: 88, height: 88)
            // 88 直径 + 44 圆角 = 正圆；走 glassCard 的暖白配方（ultraThin 裸用在浅底上发灰）
            .glassCard(cornerRadius: 44)
        }
        .clipShape(Circle())   // 裁掉光晕溢出，保持视觉边界等于玻璃圆
    }

    private var momentCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            photoArea
                .frame(width: 20, height: 16)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppTheme.Color.textFaint)
                .frame(width: 14, height: 3)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppTheme.Color.border)
                .frame(width: 9, height: 3)
        }
        .padding(4)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(AppTheme.Color.border, lineWidth: 0.5)
        )
        .rotationEffect(.degrees(-7))
    }

    /// 照片区：浅橘底 + 橙色小太阳 + 暖灰双山峰
    private var photoArea: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.brandSubtleBg

            Path { p in
                p.move(to: CGPoint(x: 0, y: 16))
                p.addLine(to: CGPoint(x: 6, y: 9))
                p.addLine(to: CGPoint(x: 11, y: 14))
                p.addLine(to: CGPoint(x: 14, y: 11))
                p.addLine(to: CGPoint(x: 20, y: 16))
                p.closeSubpath()
            }
            .fill(AppTheme.Color.textFaint.opacity(0.7))

            Circle()
                .fill(AppTheme.Color.brandStrong)
                .frame(width: 6, height: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 3)
                .padding(.top, 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Unlocked view

private struct Tab2UnlockedView: View {
    let vm: Tab2HomeViewModel
    var topInset: CGFloat = 0
    var listResetToken: UUID = UUID()
    let onTalk: (String) -> Void

    // 单开手风琴：同时只展开一个 Topics-in-Progress 主题；切回 Mine 时回收起。
    @State private var expandedCategoryId: String?

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollViewReader { proxy in
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

                        contentSections(proxy)
                    }
                    .padding(.bottom, AppTheme.Space.paddingPage * 2)
                }
                .contentMargins(.top, topInset, for: .scrollContent)
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
        withAnimation(.easeInOut(duration: 0.28)) {
            expandedCategoryId = willExpand ? id : nil
            if willExpand { proxy.scrollTo(id, anchor: .top) }
        }
    }

    @ViewBuilder
    private func contentSections(_ proxy: ScrollViewProxy) -> some View {
        if let data = vm.data {
            let hero   = vm.heroCategory()
            let heroId = hero?.id
            let otherUnlocked = data.categories.filter { $0.unlocked && $0.id != heroId }

            // 已解锁分类：独立 Serif 标题 "Materials Yours" + 横向 Peek 轮播卡片
            if hero != nil || !otherUnlocked.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your materials")
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
                                .frame(width: 350)
                            }

                            ForEach(otherUnlocked) { cat in
                                Tab2HeroCard(
                                    category: cat,
                                    isFirstUnlock: false,
                                    onTalk: { onTalk(cat.sceneCategory) }
                                )
                                .frame(width: 350)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.vertical, 16)   // 给玻璃卡阴影留出不裁切的空间
                    }
                }
            }

            // Topics in Progress——独立 Serif 标题 + 磨砂玻璃列表容器
            let stillFilling = data.categories.filter { !$0.unlocked && $0.wordCount >= 1 }
            if !stillFilling.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.titleToContent) {
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
                                loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                            )
                            .id(cat.id)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .warmGlassCard()
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
