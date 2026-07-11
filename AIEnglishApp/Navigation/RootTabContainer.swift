import SwiftUI

struct RootTabContainer: View {
    @State private var selectedTab: AppTab = .today
    @State private var showAccountMenu = false

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
            VStack(spacing: 0) {
                topBar
                contentArea
            }
            .background(AppTheme.Color.pageBg)

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
            MineView()
                .opacity(selectedTab == .mine ? 1 : 0)
                .allowsHitTesting(selectedTab == .mine)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) else { return }
                    if dx < -60 && selectedTab == .today {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .mine }
                    } else if dx > 60 && selectedTab == .mine {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .today }
                    }
                }
        )
    }

    private var topBar: some View {
        HStack {
            Button {
                showAccountMenu ? closeMenu() : openMenu()
            } label: {
                Circle()
                    .fill(AppTheme.Color.border)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Space.paddingPage)
            Spacer()
            TopTabSelector(selectedTab: $selectedTab)
                .padding(.trailing, AppTheme.Space.paddingPage)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview {
    RootTabContainer()
}
