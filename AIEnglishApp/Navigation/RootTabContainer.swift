import SwiftUI

enum RootTabContainerLayout {
    static let space = "RootTabContainerSpace"
}

enum RootTabSwipeIntent {
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
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
    @State private var selectedTab: AppTab =
        ProcessInfo.processInfo.environment["START_TAB"] == "mine" ? .mine : .today
    #else
    @State private var selectedTab: AppTab = .today
    #endif
    @State private var showSettings = false
    @State private var showUsageLimit = false
    @State private var mineListResetToken = UUID()
    @State private var mineSwipeActionOpen = false
    @State private var mineDetailActive = false
    @State private var topBarHeight: CGFloat = 0
    @State private var capturedSwipeOpen = false
    @State private var captureRecorded = false
    // Fullscreen image preview — lifted to root so it covers the top bar
    @State private var previewImage: UIImage?
    @State private var previewAnchor: UnitPoint = .center
    @State private var globalToast: String?
    @State private var globalToastImage: String?

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
        .onPreferenceChange(TopBarHeightKey.self) { topBarHeight = $0 }
        .background(AppTheme.Color.pageBg)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showUsageLimit) {
            UsageLimitSheet(onFeedbackSubmitted: {
                globalToastImage = "paperplane.fill"
                globalToast = FeedbackView.successToastMessage
            })
        }
        .toast(
            message: $globalToast,
            systemImage: globalToastImage,
            placement: .bottom
        )
        .onReceive(NotificationCenter.default.publisher(for: .showAppToast)) { note in
            if let payload = note.object as? AppToastPayload {
                globalToastImage = payload.systemImage
                globalToast = payload.message
            }
        }
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
        }
    }

    private var contentArea: some View {
        ZStack {
            TodayView(
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
        .coordinateSpace(name: RootTabContainerLayout.space)
        .simultaneousGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .named(RootTabContainerLayout.space))
                .onChanged { value in
                    // 下拉刷新同样是 DragGesture。只有已经显露出明确横向意图时才写根容器状态，
                    // 避免垂直下拉触发 RootTabContainer 重算并取消 ScrollView.refreshable 任务。
                    guard RootTabSwipeIntent.isHorizontal(value.translation) else { return }
                    // 明确成为水平手势的第一帧捕获状态；垂直下拉阶段不写根容器状态。
                    if !captureRecorded {
                        captureRecorded = true
                        capturedSwipeOpen = mineSwipeActionOpen
                    }
                }
                .onEnded { value in
                    let didCaptureHorizontalSwipe = captureRecorded
                    defer {
                        if didCaptureHorizontalSwipe {
                            captureRecorded = false
                        }
                    }
                    let dx = value.translation.width
                    let predictedDx = value.predictedEndTranslation.width

                    // 水平意图判断：水平位移必须严格大于垂直位移（45°，同系统侧滑返回标准）
                    guard RootTabSwipeIntent.isHorizontal(value.translation) else { return }

                    // 50pt 实测位移 或 100pt 惯性轻扫预测（斜率已过才到这里，不单独绕过）
                    let isLeftSwipe = dx < -50 || predictedDx < -100
                    let isRightSwipe = dx > 50 || predictedDx > 100

                    if isLeftSwipe && selectedTab == .today {
                        withAnimation(AppTheme.Motion.tabSelection) { selectedTab = .mine }
                    } else if isRightSwipe && selectedTab == .mine {
                        if capturedSwipeOpen {
                            // Delete action was open — reset list state, don't switch tab
                            mineListResetToken = UUID()
                            mineSwipeActionOpen = false
                        } else if !mineDetailActive {
                            withAnimation(AppTheme.Motion.tabSelection) { selectedTab = .today }
                        }
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
