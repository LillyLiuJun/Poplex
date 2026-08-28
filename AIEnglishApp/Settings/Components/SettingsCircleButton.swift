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

    var body: some View {
        Button(action: action) {
            Image(systemName: kind.systemImage)
                .font(kind.font)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: side, height: side)
                .background(AppTheme.Color.cardBg, in: Circle())
                .shadow(color: AppTheme.Shadow.cardColor,
                        radius: AppTheme.Shadow.cardRadius / 2,
                        x: 0,
                        y: AppTheme.Shadow.cardY / 2)
        }
        .buttonStyle(.iconControl)
        .accessibilityLabel(kind.accessibilityLabel)
    }
}
