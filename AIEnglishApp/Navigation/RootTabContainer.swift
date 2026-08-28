import SwiftUI

enum RootTabContainerLayout {
    static let space = "RootTabContainerSpace"
}

enum RootTabSwipeIntent {
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }
}

struct IgnoredTabSwipeFrameKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

/// 顶栏浮层的实测高度，向下传给 Mine 以在其独立 NavigationStack 内预留等高空位
private struct TopBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 避免 PreferenceKey 逐帧坐标上报触发 RootTabContainer 根视图高频重绘的引用容器
private final class IgnoredFramesStore {
    var frames: [CGRect] = []
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
    @State private var mineListResetToken = UUID()
    @State private var mineSwipeActionOpen = false
    @State private var mineDetailActive = false
    @State private var topBarHeight: CGFloat = 0
    @State private var topBarCompact = false
    @State private var capturedSwipeOpen = false
    @State private var captureRecorded = false
    @State private var ignoredFramesStore = IgnoredFramesStore()

    // Fullscreen image preview — lifted to root so it covers the top bar
    @State private var previewImage: UIImage?
    @State private var previewAnchor: UnitPoint = .center

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
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .mine {
                mineSwipeActionOpen = false
            }
            // 切到 Tab2 时刷新数据（view 永远在 hierarchy，onAppear 不会重触发）
            if newTab == .mine {
                mineListResetToken = UUID()
            }
            // Restore full topBar on tab switch so the new tab's header is always visible
            withAnimation(AppTheme.Motion.topBarCompact) { topBarCompact = false }
        }
    }

    private var contentArea: some View {
        ZStack {
            TodayView(topBarCompact: $topBarCompact, isActive: selectedTab == .today, onImagePreview: { img, anchor in
                previewAnchor = anchor
                withAnimation(.spring(duration: 0.35)) { previewImage = img }
            }, topInset: topBarHeight)
                .opacity(selectedTab == .today ? 1 : 0)
                .allowsHitTesting(selectedTab == .today)
            MineView(listResetToken: mineListResetToken, swipeActionOpen: $mineSwipeActionOpen, detailActive: $mineDetailActive, topInset: topBarHeight, isActive: selectedTab == .mine, onSwitchToToday: {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .today }
                        })
                .opacity(selectedTab == .mine ? 1 : 0)
                .allowsHitTesting(selectedTab == .mine)
        }
        .contentShape(Rectangle())
        .coordinateSpace(name: RootTabContainerLayout.space)
        .onPreferenceChange(IgnoredTabSwipeFrameKey.self) { frames in
            ignoredFramesStore.frames = frames
        }
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
                    let start = value.startLocation
                    // 忽略帧来自 Tab2 横向轮播区，只在 Tab2 可见时才有意义
                    if selectedTab == .mine {
                        guard !ignoredFramesStore.frames.contains(where: { $0.contains(start) }) else { return }
                    }

                    let dx = value.translation.width
                    let dy = value.translation.height
                    let predictedDx = value.predictedEndTranslation.width

                    // 水平意图判断：水平位移必须严格大于垂直位移（45°，同系统侧滑返回标准）
                    guard RootTabSwipeIntent.isHorizontal(value.translation) else { return }

                    // 50pt 实测位移 或 100pt 惯性轻扫预测（斜率已过才到这里，不单独绕过）
                    let isLeftSwipe = dx < -50 || predictedDx < -100
                    let isRightSwipe = dx > 50 || predictedDx > 100

                    if isLeftSwipe && selectedTab == .today {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .mine }
                    } else if isRightSwipe && selectedTab == .mine {
                        if capturedSwipeOpen {
                            // Delete action was open — reset list state, don't switch tab
                            mineListResetToken = UUID()
                            mineSwipeActionOpen = false
                        } else if !mineDetailActive {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .today }
                        }
                    }
                }
        )
    }

    private var topBar: some View {
        HStack {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "person.fill")
                    .imageScale(.medium)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                    .surfaceFloating(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Space.paddingPage)

            Spacer()

            TopTabSelector(selectedTab: $selectedTab, compact: selectedTab == .today && topBarCompact)
                .padding(.trailing, AppTheme.Space.paddingPage)
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
