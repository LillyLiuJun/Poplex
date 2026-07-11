import SwiftUI

struct RootTabContainer: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            topBar
            contentArea
        }
        .background(AppTheme.Color.pageBg)
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
        // simultaneousGesture 让我们的手势与子视图手势同时运行，不互相阻断。
        // 方向判断保证：左滑只在 Today 触发切换，右滑只在 Mine 触发切换，
        // 与 Mine 列表行的左滑删除方向相反，完全不冲突。
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
            Circle()
                .fill(AppTheme.Color.border)
                .frame(width: 32, height: 32)
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
