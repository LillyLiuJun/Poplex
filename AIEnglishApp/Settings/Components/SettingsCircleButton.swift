import SwiftUI

/// 设置区三个页面共用的圆形控件（返回 / 关闭）。
///
/// 此前这个配方在 SettingsView(closeButton) / AboutAIView(backRow) / FeedbackView(backRow)
/// 里各写了一遍，只有图标名和 SF Symbol 字重不同。三份拷贝意味着调一次阴影要改三处。
struct SettingsCircleButton: View {
    enum Kind {
        case back
        case close

        var systemImage: String {
            switch self {
            case .back:  return "chevron.left"
            case .close: return "xmark"
            }
        }

        /// 返回箭头本身细，用 .body 才够分量；xmark 笔画密，.footnote 就够。
        /// 两者都是 icon glyph，按 CLAUDE.md 豁免 Font token 规则，但仍随 Dynamic Type。
        var font: Font {
            switch self {
            case .back:  return .system(.body, weight: .semibold)
            case .close: return .system(.footnote, weight: .semibold)
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .back:  return "Back"
            case .close: return "Close"
            }
        }
    }

    let kind: Kind
    let action: () -> Void

    /// 圆底跟着字号放大。图标用的是 `.system(.body)` / `.footnote`，二者都随
    /// Dynamic Type growing，而 barControl 是死数 44——最大无障碍字号下 .body 约 53pt，
    /// 比圆底还大，图标会顶出圆形背景。同一行的行首图标与 chevron 已按同样理由改过。
    @ScaledMetric(relativeTo: .body) private var side = AppTheme.Size.barControl

    // 不复用 .surfacePill(in: Circle())：那份配方是为汉堡键/用量环/Tab 滑块这类
    // 「浮于玻璃质感容器上的可交互控件」调的，自带 pillAmbientColor 环境阴影 +
    // 顶部白色渐隐高光；套在 Settings 这颗 44pt 纯色返回/关闭键上，双层阴影 +
    // 高光会显脏（发灰的双层底纹）。这里保持单层贴地阴影 + 0.5pt 描边的扁平配方，
    // 是刻意分道扬镳，不是遗漏未复用。若后续出现第二个「扁平卡片圆按钮」消费者，
    // 再考虑抽成共享 modifier。
    var body: some View {
        Button(action: action) {
            Image(systemName: kind.systemImage)
                .font(kind.font)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: side, height: side)
                .background(AppTheme.Color.cardBg, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                }
                .shadow(
                    color: AppTheme.Shadow.pillContactColor,
                    radius: AppTheme.Shadow.pillContactRadius,
                    x: AppTheme.Shadow.pillContactX,
                    y: AppTheme.Shadow.pillContactY
                )
                .contentShape(Circle())
        }
        .buttonStyle(.iconControl)
        .accessibilityLabel(kind.accessibilityLabel)
    }
}
