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
                .navigationDestination(for: MineRoute.self) { route in
                    switch route {
                    case .conversation(let cat):
                        ConversationView(sceneCategory: cat)
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
                onTalk: { cat in path.append(.conversation(sceneCategory: cat)) }
            )
        } else {
            Tab2LockedView(
                vm: vm,
                onCapture: { onSwitchToToday?() }
            )
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

    private let inputTarget = 5
    private let wordTarget  = 20
    
    @State private var unlockState: UnlockState = .idle

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()
            
            // 1. 待解锁页面内容（固定顶栏空间，卡片与 Header 独立协同避让）
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingPage) {
                    headerSection
                    
                    VStack(spacing: AppTheme.Space.paddingPage) {
                        inputsCard
                        topicsCard
                    }
                    .scaleEffect(unlockState == .charging ? 0.95 : (unlockState == .releasing ? 0.88 : 1.0))
                    .offset(y: unlockState == .charging ? 6 : (unlockState == .releasing ? 12 : 0))
                    .opacity(unlockState == .releasing ? 0.0 : 1.0)
                    .blur(radius: unlockState == .releasing ? 8 : 0)
                    .animation(.easeInOut(duration: 0.35), value: unlockState)
                    
                    captureButton
                }
                .padding(.vertical, AppTheme.Space.paddingPage)
            }

            // 2. 震撼全屏多重能量爆破浪潮 (Multi-layer Fullscreen Shockwave)
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 70)
                
                ZStack {
                    // (1) 先行亮白高光爆破核心 (White Flash Core)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .position(center)
                        .scaleEffect(unlockState == .releasing ? 4.0 : 0.01)
                        .opacity(unlockState == .releasing ? 0.0 : (unlockState == .charging ? 0.3 : 0.0))
                        .animation(unlockState == .releasing ? .easeOut(duration: 0.25) : .none, value: unlockState)

                    // (2) 领头冲击波环 (Outer Shockwave Ring)
                    Circle()
                        .stroke(AppTheme.Color.brandStrong.opacity(0.8), lineWidth: 16)
                        .frame(width: 120, height: 120)
                        .position(center)
                        .scaleEffect(unlockState == .releasing ? 32 : 0.01)
                        .opacity(unlockState == .releasing ? 0.0 : 0.9)
                        .animation(unlockState == .releasing ? .easeOut(duration: 0.4) : .none, value: unlockState)

                    // (3) 物理全屏实心能量巨浪 (Main Solid Orange Wave Sweep)
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 120, height: 120)
                        .position(center)
                        .scaleEffect(unlockState == .releasing ? 45 : 0.001)
                        .opacity(unlockState == .releasing ? 1.0 : 0.0)
                        .animation(
                            unlockState == .releasing 
                                ? .spring(response: 0.38, dampingFraction: 0.65) 
                                : .none, 
                            value: unlockState
                        )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // ── 待解锁 header ────────────────────────────────────────────────────
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            // 左对齐的精简 Lock Icon + LOCKED 标签
            HStack(spacing: AppTheme.Space.paddingS) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Color.brandSubtleBg)
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .rotationEffect(.degrees(unlockState == .charging ? -12 : (unlockState == .releasing ? 30 : 0)))
                }
                
                Text("LOCKED")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.brandStrong.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, AppTheme.Space.paddingXS)

            Text("Not open yet")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(AppTheme.Color.textPrimary)
            
            hintText
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.bottom, AppTheme.Space.paddingS)
        // 顶部 Header 动效处理：蓄力时平稳贴合(y:+3)，释放时向上顺畅离场(y:-28, opacity:0)
        .offset(y: unlockState == .charging ? 3 : (unlockState == .releasing ? -28 : 0))
        .opacity(unlockState == .releasing ? 0.0 : (unlockState == .charging ? 0.85 : 1.0))
        .animation(.easeInOut(duration: 0.35), value: unlockState)
    }

    private var hintText: some View {
        Text("Add 5 moments in ")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
        + Text("Capture")
            .font(AppTheme.Font.englishBody).bold()
            .foregroundStyle(AppTheme.Color.textSecondary)
        + Text(". Reach 20 words in any topic to start practicing.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    // ── INPUTS progress (Card) ──────────────────────────────────────────
    private var inputsCard: some View {
        let count  = vm.data?.inputCount ?? 0
        let fill   = min(CGFloat(count) / CGFloat(inputTarget), 1.0)
        
        return VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                Text("MOMENTS")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Spacer()
                momentsCountLabel(count: count, target: inputTarget)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.brandStrong.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: max(geo.size.width * fill, count > 0 ? 4 : 0), height: 4)
                        .animation(.easeOut(duration: 0.4), value: count)
                }
            }
            .frame(height: 4)
        }
        .padding(AppTheme.Space.paddingPage)
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

    @ViewBuilder
    private func momentsCountLabel(count: Int, target: Int) -> some View {
        let isReached = count >= target
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 13, weight: isReached ? .bold : .semibold))
                .foregroundStyle(isReached ? AppTheme.Color.brandStrong : AppTheme.Color.textPrimary)
            Text(" of \(target)")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    // ── TOPICS list (Card) ───────────────────────────────────────────────
    private var topicsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("TOPICS", note: "Any one reaching 20 opens it.")
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingPage)
                .padding(.bottom, 12)

            let cats  = categoriesWithWords
            let topId = closestCategory?.id
            
            if cats.isEmpty {
                Text("Capture a moment to get started.")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingPage)
            } else {
                VStack(spacing: 4) {
                    ForEach(cats) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isHighlighted: cat.id == topId,
                            loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                        )
                    }
                }
                .padding(.bottom, AppTheme.Space.paddingPage)
            }
        }
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

    // ── CTA ──────────────────────────────────────────────────────────────
    private var captureButton: some View {
        let isReady = vm.isReadyToUnlock
        return Button {
            if isReady {
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
                    
                    // 3. 能量波覆盖全屏后平滑解锁 (480ms)
                    try? await Task.sleep(nanoseconds: 480_000_000)
                    vm.confirmUnlock()
                }
            } else {
                onCapture()
            }
        } label: {
            ZStack {
                // 舒张发光的背影光晕层 (Bloom Glow Layer)
                Capsule()
                    .fill(AppTheme.Color.brandStrong)
                    .blur(radius: unlockState == .releasing ? 24 : 0)
                    .scaleEffect(unlockState == .releasing ? 1.4 : 0.8)
                    .opacity(unlockState == .releasing ? 0.7 : 0.0)

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
                .background(AppTheme.Color.brandStrong)
                .clipShape(Capsule())
                .shadow(
                    color: AppTheme.Color.brandStrong.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
                .scaleEffect(buttonScale)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingS)
    }

    private var buttonScale: CGFloat {
        switch unlockState {
        case .idle: return 1.0
        case .charging: return 0.84
        case .releasing: return 1.18
        }
    }

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
                            .font(.system(size: 32, weight: .bold, design: .serif))
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
                        .font(.system(size: 24, weight: .bold, design: .serif))
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
                        .font(.system(size: 24, weight: .bold, design: .serif))
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
