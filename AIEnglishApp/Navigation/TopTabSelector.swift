import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            tabItem(.today, icon: "sun.max",        label: "Today")
            tabItem(.mine,  icon: "books.vertical", label: "Mine")
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }

    private func tabItem(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: icon)
                    .imageScale(.small)
                if isSelected {
                    Text(label)
                        .font(AppTheme.Font.tabLabel)
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
            .padding(.horizontal, isSelected ? AppTheme.Space.paddingCard : AppTheme.Space.paddingS)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background(isSelected ? AppTheme.Color.accentBuddy : AppTheme.Color.inputBg)
            .foregroundStyle(isSelected ? AppTheme.Color.pageBg : AppTheme.Color.textSecondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
