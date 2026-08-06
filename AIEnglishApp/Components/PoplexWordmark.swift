import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 字标度量（唯一真源）

/// Poplex 字标的全部比例常量。
///
/// 字标是「一半图形、一半文字」：`P` 是 `PoplexPShape`（与 App 图标同一份路径，
/// 含 −6° 斜切），`oplex` 是系统衬线 Bold Italic，末尾一枚墨点当句号。
///
/// **唯一输入量是 P 的字高 H**，其余尺寸全部由它推出 —— 所以调用方只给一个
/// `capHeight`，不要在外面自己算字号或间距。
/// 完整规格见 `docs/design-system/poplex-wordmark-spec.html`。
enum PoplexWordmarkMetrics {
    /// P 的碗向右悬出、`o` 又矮又圆，两个墨迹框刚好贴上时看着仍然是散的 ——
    /// 正字体里这一对本来就带负 kerning。
    static let kernRatio: CGFloat = -0.045        // × 字号
    static let dotDiameterRatio: CGFloat = 9.0 / 56.0   // × 字号
    static let dotLeadingRatio: CGFloat = 3.0 / 56.0    // × 字号
    /// 四周安全边距，任何元素不得进入。
    static let clearSpaceRatio: CGFloat = 0.5     // × 字高

    /// 低于这个字高就去掉墨点 —— 再小它会退化成一个脏点，不如没有。
    static let periodMinCapHeight: CGFloat = 18

    /// 字体 cap height 占 em 的比例（New York Bold ≈ 0.70）。
    /// 向 UIFont 实测一次并缓存：写死 0.70 会在系统换字体时悄悄错位。
    private static let capPerEm: CGFloat = {
        #if canImport(UIKit)
        let probe: CGFloat = 100
        let base = UIFont.systemFont(ofSize: probe, weight: .bold)
        let serif = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: probe) }
        let cap = (serif ?? base).capHeight
        return cap > 0 ? cap / probe : 0.70
        #else
        return 0.70
        #endif
    }()

    /// 由 P 的字高反查 `oplex` 应该用多大字号。
    static func fontSize(forCapHeight h: CGFloat) -> CGFloat { h / capPerEm }
}

// MARK: - 字标

/// 横版全称字标。方版（App 图标 / favicon / 头像）请直接用 `PoplexPShape`，
/// 不要把字标塞进方框。
///
/// ```swift
/// PoplexWordmark(capHeight: 24)                       // 主版：纸底橙字
/// PoplexWordmark(capHeight: 20, style: .onBrand)      // 橙底反白
/// PoplexWordmark(capHeight: 24, style: .mono(.white)) // 单色（照片上 / 印刷）
/// ```
struct PoplexWordmark: View {

    enum Style {
        /// 主版：橙字 + 墨点。用在暖纸底上。
        case brand
        /// 橙底反白：纸色字 + 墨点保持墨色。
        case onBrand
        /// 深色模式：橙字 + 纸色点。
        case onInk
        /// 单色：字和点同色。给印刷、他方品牌色、照片叠加用。
        case mono(Color)
    }

    /// P 的字高。字标唯一的尺寸输入。
    var capHeight: CGFloat = 24
    var style: Style = .brand
    /// 是否显示句末墨点。默认跟随尺寸自动决定（< 18pt 自动去掉）。
    var showsPeriod: Bool? = nil

    private var fontSize: CGFloat { PoplexWordmarkMetrics.fontSize(forCapHeight: capHeight) }
    private var dotSize: CGFloat { fontSize * PoplexWordmarkMetrics.dotDiameterRatio }
    private var dotLeading: CGFloat { fontSize * PoplexWordmarkMetrics.dotLeadingRatio }
    private var kern: CGFloat { fontSize * PoplexWordmarkMetrics.kernRatio }

    private var showsPeriodResolved: Bool {
        showsPeriod ?? (capHeight >= PoplexWordmarkMetrics.periodMinCapHeight)
    }

    private var letterColor: Color {
        switch style {
        case .brand, .onInk: return AppTheme.Color.brandStrong
        case .onBrand:       return AppTheme.Color.splashBg
        case .mono(let c):   return c
        }
    }

    private var periodColor: Color {
        switch style {
        case .brand, .onBrand: return AppTheme.Color.splashDot
        case .onInk:           return AppTheme.Color.splashBg
        case .mono(let c):     return c
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: kern) {
            PoplexPShape()
                .fill(letterColor, style: FillStyle(eoFill: true))
                .frame(width: capHeight * PoplexPShape.aspect, height: capHeight)
                // 墨迹底边就是基线（P 无降部），所以基线 = frame 底边
                .alignmentGuide(.lastTextBaseline) { d in d.height }

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("oplex")
                    .font(AppTheme.Font.wordmark(size: fontSize))
                    .foregroundStyle(letterColor)

                if showsPeriodResolved {
                    Circle()
                        .fill(periodColor)
                        .frame(width: dotSize, height: dotSize)
                        .padding(.leading, dotLeading)
                        .alignmentGuide(.lastTextBaseline) { d in d.height }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Poplex")
    }

    /// 带规范安全边距（0.5 H）的版本。放进有其他元素的版面时用它。
    func withClearSpace() -> some View {
        padding(capHeight * PoplexWordmarkMetrics.clearSpaceRatio)
    }
}

#Preview("字标 · 各版本") {
    VStack(alignment: .leading, spacing: 28) {
        PoplexWordmark(capHeight: 36)
        PoplexWordmark(capHeight: 24)
        PoplexWordmark(capHeight: 18)
        PoplexWordmark(capHeight: 14)                      // 自动去掉墨点
        PoplexWordmark(capHeight: 24, style: .onBrand)
            .padding(12)
            .background(AppTheme.Color.brandStrong)
        PoplexWordmark(capHeight: 24, style: .onInk)
            .padding(12)
            .background(AppTheme.Color.splashDot)
        PoplexWordmark(capHeight: 24, style: .mono(AppTheme.Color.textPrimary))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Color.splashBg)
}
