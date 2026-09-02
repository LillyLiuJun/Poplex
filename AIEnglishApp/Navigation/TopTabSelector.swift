import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab
    // 选中胶囊只在一行文字 Tab 间移动，单 Namespace 足够。
    @Namespace private var thumbNamespace

    var body: some View {
        // 顶部 Tab 始终显示文字（2026-08-31 决定：不再做辅助功能字号下的图标退化）。
        // 大字号下文字有放大上限（AppTheme.Typography.topTabLabelMaxDynamicTypeSize），
        // 保证最窄屏（375pt）上「Today / Library」两个标签也放得下，
        // 不会溢出撞上两侧的 Settings 入口。
        HStack(spacing: AppTheme.Size.topTabItemSpacing) {
            tabItem(.today)
            tabItem(.mine)
        }
        .animation(AppTheme.Motion.tabSelection, value: selectedTab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let label = tab.title
        let isSelected = selectedTab == tab
        // 选中胶囊的填充、玻璃裁剪、点击热区三处必须是同一个形状，否则某次
        // 圆角调整可能只改到其中一两处，出现「玻璃背景方了但热区还是圆的」。
        let thumbShape = RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
        return Button {
            withAnimation(AppTheme.Motion.tabSelection) {
                selectedTab = tab
            }
        } label: {
            Text(label)
                .font(AppTheme.Font.tabLabel)
                .dynamicTypeSize(...AppTheme.Typography.topTabLabelMaxDynamicTypeSize)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, AppTheme.Space.paddingM)
                .frame(minHeight: AppTheme.Size.topTabSelectionHeight)
                // 选中态双重信号：选中项使用 textPrimary 配合浮动药丸，未选中项压淡至 textSecondary 且无背景（保持裸字）
                .foregroundStyle(isSelected ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
                .background {
                    if isSelected {
                        thumbShape
                            .fill(Color.clear)
                            // 换用专为小药丸定制的 surfacePill：双层微阴影（contact + ambient）与顶部 0.5pt 内高光
                            .surfacePill(in: thumbShape, interactive: false)
                            .matchedGeometryEffect(id: "tabThumb", in: thumbNamespace)
                    }
                }
                .frame(minWidth: AppTheme.Size.barControl, minHeight: AppTheme.Size.barControl)
                .contentShape(thumbShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
