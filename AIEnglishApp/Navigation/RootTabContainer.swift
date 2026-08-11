import SwiftUI

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
    @State private var mineListResetToken = UUID()
    @State private var mineSwipeActionOpen = false
    @State private var mineDetailActive = false
    @State private var topBarHeight: CGFloat = 0
    @State private var topBarCompact = false
    @State private var capturedSwipeOpen = false
    @State private var captureRecorded = false

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
            MineView(listResetToken: mineListResetToken, swipeActionOpen: $mineSwipeActionOpen, detailActive: $mineDetailActive, topInset: topBarHeight, onSwitchToToday: {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .today }
                        })
                .opacity(selectedTab == .mine ? 1 : 0)
                .allowsHitTesting(selectedTab == .mine)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    // Capture swipe state at gesture start, before List's onEnded can clear it
                    if !captureRecorded {
                        captureRecorded = true
                        capturedSwipeOpen = mineSwipeActionOpen
                    }
                }
                .onEnded { value in
                    defer { captureRecorded = false }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) else { return }
                    if dx < -60 && selectedTab == .today {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .mine }
                    } else if dx > 60 && selectedTab == .mine {
                        if capturedSwipeOpen {
                            // Delete was open — reset list, don't switch tab
                            mineListResetToken = UUID()
                            mineSwipeActionOpen = false
                        } else {
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
                    .glassBarItem(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Space.paddingPage)

            Spacer()

            TopTabSelector(selectedTab: $selectedTab, compact: selectedTab == .today && topBarCompact)
                .padding(.trailing, AppTheme.Space.paddingPage)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        // Gemini 风格可变渐进式通透毛玻璃底托：背景向上贯穿状态栏/灵动岛，向下 24pt 平滑消隐进入内容区
        .background {
            VariableBlurBackdrop(direction: .top, extraExtend: 24)
                .ignoresSafeArea(.container, edges: .top)
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
