import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab
    @Namespace private var thumbNamespace

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today, icon: "sun.max",        label: "Today")
            tabItem(.mine,  icon: "books.vertical", label: "Mine")
        }
        .padding(.horizontal, AppTheme.Space.paddingXS)
        .padding(.vertical, AppTheme.Space.paddingXS)
        .glassBarItem(in: Capsule(), interactive: false)
    }

    private func tabItem(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(AppTheme.Motion.tabSelection) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: icon)
                    .imageScale(.medium)
                if isSelected {
                    Text(label)
                        .font(AppTheme.Font.tabLabel)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
            .padding(.horizontal, isSelected ? AppTheme.Space.paddingCard : AppTheme.Space.paddingM)
            .frame(minHeight: AppTheme.Size.barControl - AppTheme.Space.paddingXS * 2)
            .foregroundStyle(isSelected ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
            .background {
                // Single thumb slides between tabs via matchedGeometryEffect —
                // gives the native segmented-control "one moving pill" feel
                if isSelected {
                    Capsule()
                        .fill(AppTheme.Color.pageBg)
                        .shadow(
                            color: AppTheme.Shadow.cardColor,
                            radius: AppTheme.Shadow.cardRadius / 2,
                            x: AppTheme.Shadow.cardX,
                            y: AppTheme.Shadow.cardY
                        )
                        .matchedGeometryEffect(id: "tabThumb", in: thumbNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
