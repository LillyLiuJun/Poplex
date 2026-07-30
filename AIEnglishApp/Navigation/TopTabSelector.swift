import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab
    /// True while the user is scrolling into content; hides tab labels to reduce obstruction
    var compact: Bool = false
    @Namespace private var thumbNamespace

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today, icon: "sun.max",        label: "Capture")
            tabItem(.mine,  icon: "books.vertical", label: "Library")
        }
        .padding(.horizontal, AppTheme.Space.paddingXS)
        .padding(.vertical, AppTheme.Space.paddingXS)
        .glassBarItem(in: Capsule(), interactive: false)
        // tabSelection drives thumb moves; topBarCompact drives label show/hide
        .animation(AppTheme.Motion.tabSelection, value: selectedTab)
        .animation(AppTheme.Motion.topBarCompact, value: compact)
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
                // Label hidden when compact — even for the selected tab
                if isSelected && !compact {
                    Text(label)
                        .font(AppTheme.Font.tabLabel)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
            .padding(.horizontal, (isSelected && !compact) ? AppTheme.Space.paddingCard : AppTheme.Space.paddingM)
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
