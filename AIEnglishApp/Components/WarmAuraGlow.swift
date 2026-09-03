import SwiftUI

extension Gradient {
    /// Tab2 列表底部（`BottomAuraFooter`）与 Onboarding 页面背景（`OnboardingAuraBackground`）
    /// 共用的 9 档非线性缓出位置表：0.00 / 0.28 / 0.46 / 0.60 / 0.72 / 0.83 / 0.92 / 0.97 / 1.00。
    /// 两处的这份位置表原本是各抄一份，locations 完全相同、只有透明度序列不同——
    /// 位置表收在这里只此一份，调用方各自传入自己那 8 档透明度（最后一档固定 clear）。
    /// 两边的透明度峰值（0.22 vs 0.32）与 endRadius（220 vs 300）是有意调出的两档亮度，
    /// 不是意外漂移，所以这里不把数值也收拢成一份——只收拢会被抄错、抄漏的结构本身。
    static func warmAuraStops(opacities: [Double]) -> [Gradient.Stop] {
        // assert 而非 precondition：纯视觉渐变，Release 下传错档数宁可画偏也不闪退；
        // 调用点全是字面量，DEBUG 立崩即可在开发期拦住。
        assert(opacities.count == 8, "warmAuraStops 需要恰好 8 档透明度，第 9 档固定为 clear")
        let locations: [Double] = [0.00, 0.28, 0.46, 0.60, 0.72, 0.83, 0.92, 0.97]
        var stops = zip(opacities, locations).map { opacity, location in
            Gradient.Stop(color: AppTheme.Color.canvasAura.opacity(opacity), location: location)
        }
        stops.append(.init(color: .clear, location: 1.00))
        return stops
    }
}

/// 暖光晕椭圆：460×260、44pt 模糊、径向渐变。峰值透明度、渐变半径、纵向偏移
/// 由调用方指定；渐变结构（位置表）见 `Gradient.warmAuraStops(opacities:)`。
/// 纯装饰：不拦截交互、对无障碍隐藏，两样都收在组件内——第三处调用无需再各自补标注。
struct WarmAuraGlow: View {
    let stops: [Gradient.Stop]
    let endRadius: CGFloat
    let offsetY: CGFloat

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(stops: stops, center: .center, startRadius: 0, endRadius: endRadius)
            )
            .frame(width: 460, height: 260)
            .blur(radius: 44)
            .offset(y: offsetY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
