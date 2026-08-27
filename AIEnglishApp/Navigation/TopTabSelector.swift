import SwiftUI

struct TopTabSelector: View {
    @Binding var selectedTab: AppTab
    /// True while the user is scrolling into content; hides tab labels to reduce obstruction
    var compact: Bool = false
    @Namespace private var thumbNamespace
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 无障碍字号（AX1 及以上）下强制收起标签，只留图标。
    ///
    /// 标签用了 `.fixedSize()`——它拒绝被压缩，这是刻意的：切换动画期间若允许换行，
    /// 胶囊会抖。代价是无障碍字号下这个胶囊会一路撑宽到超过屏宽；顶栏是 overlay 层，
    /// 一旦它比屏幕宽，整层就会被居中，**全屏内容随之左移出屏**
    /// （左上角头像被裁掉、页面标题首字母被切）。
    ///
    /// 所以这里换一种降级：不压字、不截断，直接退回图标态。
    /// 选中态胶囊和图标都还在、功能不丢，图标本身仍随字号放大——
    /// 对放大字号的用户，比一行挤扁的小字更好认。
    private var collapsesLabels: Bool {
        compact || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today, icon: "sun.max",        label: "Today")
            tabItem(.mine,  icon: "books.vertical", label: "Library")
        }
        .padding(.horizontal, AppTheme.Space.paddingXS)
        .padding(.vertical, AppTheme.Space.paddingXS)
        .surfaceFloating(in: Capsule(), interactive: false)
        // tabSelection drives thumb moves; topBarCompact drives label show/hide
        .animation(AppTheme.Motion.tabSelection, value: selectedTab)
        .animation(AppTheme.Motion.topBarCompact, value: collapsesLabels)
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
                // Label hidden when collapsed — even for the selected tab
                if isSelected && !collapsesLabels {
                    Text(label)
                        .font(AppTheme.Font.tabLabel)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
            .padding(.horizontal, (isSelected && !collapsesLabels) ? AppTheme.Space.paddingCard : AppTheme.Space.paddingM)
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
        // 无障碍名称必须显式给：标签在 compact / 无障碍字号下会被隐藏，
        // 此时按钮里只剩一个 SF Symbol，VoiceOver 会去念符号名
        // （"sun maximum" / "books vertical"），而不是导航语义。
        // 显式 label 让读屏结果与视觉状态解耦，两种形态下念的都是同一个词。
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
