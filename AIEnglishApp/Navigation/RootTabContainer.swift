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
    @State private var topBarCompact = false
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
            // Restore full topBar on tab switch so the new tab's header is always visible
            withAnimation(AppTheme.Motion.topBarCompact) { topBarCompact = false }
        }
    }

    private func openMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showAccountMenu = true }
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.18)) { showAccountMenu = false }
    }

    private var contentArea: some View {
        ZStack {
            TodayView(topBarCompact: $topBarCompact)
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

            TopTabSelector(selectedTab: $selectedTab, compact: topBarCompact)
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
