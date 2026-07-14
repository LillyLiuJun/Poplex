import SwiftUI

/// 顶栏浮层的实测高度，向下传给 Mine 以在其独立 NavigationStack 内预留等高空位
private struct TopBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct RootTabContainer: View {
    @State private var selectedTab: AppTab = .today
    @State private var showAccountMenu = false
    @State private var mineListResetToken = UUID()
    @State private var mineSwipeActionOpen = false
    @State private var mineDetailActive = false
    @State private var topBarHeight: CGFloat = 0
    @State private var capturedSwipeOpen = false
    @State private var captureRecorded = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var menuItems: [AccountMenuItem] {
        [
            AccountMenuItem(id: "settings", icon: "gearshape",   title: "Settings") {},
            AccountMenuItem(id: "about",    icon: "info.circle", title: "About")    {},
        ]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Content fills full screen; topBar floats as a safeArea inset above it.
            // Hidden while a Mine detail page is pushed — detail pages own their own chrome.
            contentArea
                // Frosted bar behind the floating glass pills: content scrolling up
                // is blurred (not shown through cleanly) behind the status bar + topBar.
                // Applied before safeAreaInset so the topBar glass renders on top of it.
                .overlay(alignment: .top) {
                    if !(selectedTab == .mine && mineDetailActive) {
                        topBarBlur
                    }
                }
                .safeAreaInset(edge: .top) {
                    if !(selectedTab == .mine && mineDetailActive) {
                        topBar
                    }
                }
                .onPreferenceChange(TopBarHeightKey.self) { topBarHeight = $0 }

            // Dismiss layer — only intercepts taps when menu is visible
            if showAccountMenu {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeMenu() }
            }

            // Menu always in hierarchy; scale + opacity drive the animation
            AccountMenuView(items: menuItems, appVersion: appVersion, onDismiss: closeMenu)
                .padding(.leading, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingHero)
                .scaleEffect(showAccountMenu ? 1.0 : 0.75, anchor: .topLeading)
                .opacity(showAccountMenu ? 1.0 : 0)
                .allowsHitTesting(showAccountMenu)
        }
        .background(AppTheme.Color.pageBg)
        .onChange(of: selectedTab) { oldTab, _ in
            if oldTab == .mine {
                mineListResetToken = UUID()
                mineSwipeActionOpen = false
            }
        }
    }

    /// 顶栏渐进式模糊（参考 Stoic）：两层叠加，盖在滚动内容之上、顶栏玻璃胶囊之下。
    ///
    /// 层1 —— 毛玻璃 + 渐变 mask：统一模糊经 mask 让「显示强度」自上而下递减，模拟
    ///   variable blur（顶部彻底液化内容、底部无模糊），下沿羽化消融，无硬分割线。
    /// 层2 —— 画布同色 alpha 渐变：顶部半透明盖住状态栏保证时间/电量可读，
    ///   轻量不透明度（max 0.85）让遮罩本身无"存在感"，缓出至全透明。
    ///
    /// 高度 = 状态栏 + 顶栏 + 羽化段（paddingHero+12pt）；+12pt 给内容留足呼吸空间，
    /// 避免卡片刚触到遮罩就被硬切断。纯视觉、不拦截点击。
    // TODO(token): 待数值定稿后把这些 opacity 提进 AppTheme 语义层。
    private var topBarBlur: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let solidH  = safeTop + topBarHeight            // 状态栏 + 顶栏：实模糊区
            let fadeH   = AppTheme.Space.paddingHero + 12  // 羽化段：延长 12pt 增加呼吸空间
            let totalH  = solidH + fadeH
            let solid   = solidH / totalH                   // 实区占比（mask 拐点）

            ZStack(alignment: .top) {
                // 层1：毛玻璃，mask 让模糊随显示强度自上而下递减
                // stops 间距拉宽，过渡更平缓，增加"虚化纵深"
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black,               location: 0),
                                .init(color: .black,               location: solid * 0.85),
                                .init(color: .black.opacity(0.45), location: solid),
                                .init(color: .black.opacity(0.12), location: solid + (1 - solid) * 0.55),
                                .init(color: .clear,               location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // 层2：画布同色 alpha 渐变，整体减重（max 0.85）让遮罩"无存在感"
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Color.pageBg.opacity(0.85), location: 0),
                        .init(color: AppTheme.Color.pageBg.opacity(0.60), location: safeTop / totalH),
                        .init(color: AppTheme.Color.pageBg.opacity(0.15), location: solid),
                        .init(color: AppTheme.Color.pageBg.opacity(0.0),  location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .frame(height: totalH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    private func openMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showAccountMenu = true }
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.18)) { showAccountMenu = false }
    }

    private var contentArea: some View {
        ZStack {
            TodayView()
                .opacity(selectedTab == .today ? 1 : 0)
                .allowsHitTesting(selectedTab == .today)
            MineView(listResetToken: mineListResetToken, swipeActionOpen: $mineSwipeActionOpen, detailActive: $mineDetailActive, topInset: topBarHeight)
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
                showAccountMenu ? closeMenu() : openMenu()
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

            TopTabSelector(selectedTab: $selectedTab)
                .padding(.trailing, AppTheme.Space.paddingPage)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
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
