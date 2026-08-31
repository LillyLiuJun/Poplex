import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // ViewThatFits 求值期间两个候选行会同时参与布局（即使只有一个最终渲染），
    // 各自独立的 Namespace 确保它们的 matchedGeometryEffect 锚点不会共用同一个
    // id，避免出现「同一 id 两个锚点」的运行时冲突或选中胶囊错位/跳变。
    @Namespace private var fullLabelNamespace
    @Namespace private var iconOnlyNamespace

    var body: some View {
        // 参考图的呼吸感：两个文字目标彼此独立，但作为一组仍保持稳定的视觉中心。
        // 辅助功能字号下直接用纯图标行，不进 ViewThatFits——避免文字候选在超大字号下
        // 参与布局求值（旧版一直是「辅助功能字号=纯图标」的硬规则，这里保持一致）。
        // 标准字号区间交给 ViewThatFits 按 RootTabContainer 实际让出的宽度择优：
        // 文字放不下时整组退化为纯图标，而不是让拒绝压缩的 Text 溢出预留槽位、
        // 撞上 Settings 按钮。
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                tabRow(iconOnly: true, namespace: iconOnlyNamespace)
            } else {
                ViewThatFits(in: .horizontal) {
                    tabRow(iconOnly: false, namespace: fullLabelNamespace)
                    tabRow(iconOnly: true, namespace: iconOnlyNamespace)
                }
            }
        }
        .animation(AppTheme.Motion.tabSelection, value: selectedTab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private func tabRow(iconOnly: Bool, namespace: Namespace.ID) -> some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            tabItem(.today, icon: "sun.max", label: "Today", iconOnly: iconOnly, namespace: namespace)
            tabItem(.mine, icon: "books.vertical", label: "Library", iconOnly: iconOnly, namespace: namespace)
        }
    }

    private func tabItem(_ tab: AppTab, icon: String, label: String, iconOnly: Bool, namespace: Namespace.ID) -> some View {
        let isSelected = selectedTab == tab
        // 选中胶囊的填充、玻璃裁剪、点击热区三处必须是同一个形状，否则某次
        // 圆角调整可能只改到其中一两处，出现「玻璃背景方了但热区还是圆的」。
        let thumbShape = RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
        return Button {
            withAnimation(AppTheme.Motion.tabSelection) {
                selectedTab = tab
            }
        } label: {
            Group {
                if iconOnly {
                    Image(systemName: icon)
                        .imageScale(.medium)
                        .accessibilityHidden(true)
                } else {
                    Text(label)
                        .font(AppTheme.Font.tabLabel)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingM)
            .frame(minHeight: AppTheme.Size.topTabSelectionHeight)
            // 参考图中两个标签都使用深色文字；当前页只通过毛玻璃胶囊识别。
            .foregroundStyle(AppTheme.Color.textPrimary)
            .background {
                if isSelected {
                    thumbShape
                        .fill(Color.clear)
                        // 与左侧 Settings 入口使用同一套浮层毛玻璃配方；
                        // Tab 之间仍没有共用外框，只有当前页成为独立的玻璃胶囊。
                        .surfaceFloating(in: thumbShape, interactive: false)
                        .matchedGeometryEffect(id: "tabThumb", in: namespace)
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
