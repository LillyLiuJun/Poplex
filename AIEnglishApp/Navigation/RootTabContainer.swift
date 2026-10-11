import SwiftUI

enum RootTabContainerLayout {
    static let space = "RootTabContainerSpace"
}

enum RootTabSwipeLock: Equatable {
    case undetermined
    case horizontal
    case vertical
}

/// 手势结束时该做的事——从判定逻辑里剥离出来，好让 RootTabSwipeIntent.resolveAction
/// 保持纯函数、可脱离 View 单测，不用真的驱动一次 DragGesture 才能验证触发门槛。
enum RootTabSwipeAction: Equatable {
    case none
    case switchToMine
    case switchToToday
    /// Tab2 的滑动删除态在手势开始时是打开的：右滑切回 Today 前，先把它收起、
    /// 重置列表，不真的切 Tab（用户此时的右滑意图是关掉删除条，不是换页）。
    case resetMineListForOpenDelete
}

enum RootTabSwipeIntent {
    /// 水平主导判定：水平位移必须严格大于垂直位移的 1.7 倍（约 60°），杜绝斜向滑动误判。
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 1.7
    }

    /// 手势进行中，从当前锁定态推出下一帧的锁定态。
    /// 只有尚未锁定（.undetermined）且实测位移越过 10pt 最低确认门槛时才会真正判定
    /// 方向；一旦锁定（水平或垂直）就保持不变，直到手势结束由调用方重置。
    static func nextLock(current: RootTabSwipeLock, translation: CGSize) -> RootTabSwipeLock {
        guard current == .undetermined else { return current }
        let totalDistance = hypot(translation.width, translation.height)
        guard totalDistance >= 10 else { return .undetermined }
        return isHorizontal(translation) ? .horizontal : .vertical
    }

    /// 手势结束，决定要不要切 Tab / 收起 Tab2 滑动删除态。
    /// lock 必须在手势初期就已锁定为水平——垂直手势或从未越过 10pt 门槛的手势，
    /// 哪怕松手那一刻位移看起来很大，也一律不触发（意图锁定只在手势早期判一次）。
    static func resolveAction(
        lock: RootTabSwipeLock,
        translation: CGSize,
        predictedTranslation: CGSize,
        selectedTab: AppTab,
        capturedSwipeOpen: Bool,
        mineDetailActive: Bool,
        claimedByInnerScroll: Bool = false
    ) -> RootTabSwipeAction {
        guard lock == .horizontal else { return .none }
        // 内部横向滚动区（如 More topics to explore）已认领这次手势：整段归它，不切页。
        guard !claimedByInnerScroll else { return .none }

        let dx = translation.width
        let predictedDx = predictedTranslation.width

        // 触发门槛：实测位移 80pt，或 实测位移 35pt 且 惯性预测位移 160pt（右滑取正）
        let isLeftSwipe = dx < -80 || (dx < -35 && predictedDx < -160)
        let isRightSwipe = dx > 80 || (dx > 35 && predictedDx > 160)

        if isLeftSwipe && selectedTab == .today {
            return .switchToMine
        } else if isRightSwipe && selectedTab == .mine {
            if capturedSwipeOpen {
                return .resetMineListForOpenDelete
            } else if !mineDetailActive {
                return .switchToToday
            }
        }
        return .none
    }
}

/// 顶栏浮层的实测高度，向下传给 Mine 以在其独立 NavigationStack 内预留等高空位
private struct TopBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct RootTabContainer: View {
    // DEBUG 启动参数：START_TAB=mine 时首屏直接落在 Tab2，方便 UI 走查/截图
    #if DEBUG
    @State private var selectedTab: AppTab = {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        if env["START_TAB"] == "today" || args.contains("-startTabToday") || args.contains("-screenshotTab1Feed") {
            return .today
        }
        return .mine
    }()
    #else
    @State private var selectedTab: AppTab = .today
    #endif
    @State private var showSettings = false
    @State private var showUsageLimit = false
    @State private var todayActivationToken = UUID()
    @State private var mineListResetToken = UUID()
    @State private var mineSwipeActionOpen = false
    @State private var mineDetailActive = false
    @State private var topBarHeight: CGFloat = 0
    @State private var capturedSwipeOpen = false
    @State private var captureRecorded = false
    @State private var swipeLock: RootTabSwipeLock = .undetermined
    @State private var swipeArbiter = TabSwipeArbiter()
    // Fullscreen image preview — lifted to root so it covers the top bar
    @State private var previewImage: UIImage?
    @State private var previewAnchor: UnitPoint = .center
    @State private var globalToastItem: AppToastItem?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Content fills full screen; topBar floats as an overlay so
            // content scrolls behind it and the blur feels natural.
            contentArea

            // Top bar — overlay on content; glassBarItem elements blur
            // individually, no full-width material (avoids color-shift strip)
            if !(selectedTab == .mine && mineDetailActive) {
                topBar
            }

            // Fullscreen image preview — always-present container so only
            // the inner conditional views animate in/out, matching the
            // original overlay pattern and avoiding ghosting on dismiss.
            ZStack {
                if previewImage != nil {
                    Color.black
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) { previewImage = nil }
                        }
                }
                if let img = previewImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                        Button {
                            withAnimation(.spring(duration: 0.3)) { previewImage = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white, Color(uiColor: .systemGray3))
                                .padding()
                        }
                    }
                    .transition(.scale(scale: 0.1, anchor: previewAnchor).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: previewImage != nil)
            .allowsHitTesting(previewImage != nil)
        }
        .overlay {
            // Settings / UsageLimit sheet 弹出期间，给呈现视图叠一层暖调遮罩（neutral950 @ 25%）。
            // 系统的调暗层压在其上时，底下暖调染过的底色会让合成结果显著偏暖，
            // 消除系统冷灰中性遮罩在顶部露出的生硬感，同时完全保留原生 sheet 下拉手势。
            if showSettings || showUsageLimit {
                AppTheme.Color.scrimOverlay
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showSettings || showUsageLimit)
        .onPreferenceChange(TopBarHeightKey.self) { topBarHeight = $0 }
        .background(AppTheme.Color.pageBg)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showUsageLimit) {
            UsageLimitSheet(onFeedbackSubmitted: {
                globalToastItem = AppToastItem(
                    message: FeedbackView.successToastMessage,
                    systemImage: "paperplane.fill",
                    semantic: .positive
                )
            })
        }
        .appToast(item: $globalToastItem, placement: .bottom)
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab != newTab {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            if oldTab == .mine {
                mineSwipeActionOpen = false
            }
            // 切到 Tab2 时刷新数据（view 永远在 hierarchy，onAppear 不会重触发）
            if newTab == .mine {
                mineListResetToken = UUID()
            }
            // 切回 Tab1 时对齐最新（view 永远在 hierarchy，onAppear 不会重触发）
            if newTab == .today && oldTab != .today {
                todayActivationToken = UUID()
            }
        }
    }

    private var contentArea: some View {
        ZStack {
            TodayView(
                activationToken: todayActivationToken,
                isActive: selectedTab == .today,
                onImagePreview: { img, anchor in
                    previewAnchor = anchor
                    withAnimation(.spring(duration: 0.35)) { previewImage = img }
                },
                // 达标 banner 点击 → 打开与顶栏仪表盘同款的额度 Sheet
                onOpenUsageLimit: { showUsageLimit = true },
                topInset: topBarHeight
            )
                .opacity(selectedTab == .today ? 1 : 0)
                .allowsHitTesting(selectedTab == .today)
            MineView(listResetToken: mineListResetToken, swipeActionOpen: $mineSwipeActionOpen, detailActive: $mineDetailActive, topInset: topBarHeight, isActive: selectedTab == .mine, onSwitchToToday: {
                            withAnimation(AppTheme.Motion.tabSelection) { selectedTab = .today }
                        })
                .opacity(selectedTab == .mine ? 1 : 0)
                .allowsHitTesting(selectedTab == .mine)
        }
        .contentShape(Rectangle())
        .environment(\.tabSwipeArbiter, swipeArbiter)
        .coordinateSpace(name: RootTabContainerLayout.space)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .named(RootTabContainerLayout.space))
                .onChanged { value in
                    let nextLock = RootTabSwipeIntent.nextLock(current: swipeLock, translation: value.translation)
                    if nextLock != swipeLock {
                        swipeLock = nextLock
                        if nextLock == .horizontal, !captureRecorded {
                            captureRecorded = true
                            capturedSwipeOpen = mineSwipeActionOpen
                        }
                    }
                }
                .onEnded { value in
                    let action = RootTabSwipeIntent.resolveAction(
                        lock: swipeLock,
                        translation: value.translation,
                        predictedTranslation: value.predictedEndTranslation,
                        selectedTab: selectedTab,
                        capturedSwipeOpen: capturedSwipeOpen,
                        mineDetailActive: mineDetailActive,
                        claimedByInnerScroll: swipeArbiter.isClaimed()
                    )
                    swipeLock = .undetermined
                    captureRecorded = false

                    switch action {
                    case .none:
                        break
                    case .switchToMine:
                        withAnimation(AppTheme.Motion.tabSelection) { selectedTab = .mine }
                    case .switchToToday:
                        withAnimation(AppTheme.Motion.tabSelection) { selectedTab = .today }
                    case .resetMineListForOpenDelete:
                        // Delete action was open — reset list state, don't switch tab
                        mineListResetToken = UUID()
                        mineSwipeActionOpen = false
                    }
                }
        )
    }

    private var topBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                // 为左右两侧各预留「页边距 + 标准顶栏控件」槽位：选择器仍以
                // 屏幕绝对中心对齐，同时在较大 Dynamic Type 下不会侵入 Settings。
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton { showSettings = true }
                    // 由 topBarSideClearance 反推，而非另起一份 paddingPage 字面值：
                    // 这样 clearance 改了，这条留白会跟着变，不会两边各改各的悄悄错开。
                    .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
                Spacer()
                UsageLimitButton { showUsageLimit = true }
                    // 与左侧汉堡按钮对称反推，保持左右配重与页边距严格一致
                    .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TopBarHeightKey.self, value: geo.size.height)
            }
        )
    }
}

#Preview {
    RootTabContainer()
}
