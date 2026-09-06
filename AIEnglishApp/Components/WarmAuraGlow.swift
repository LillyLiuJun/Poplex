import SwiftUI

// MARK: - 底部暖光 B 档专用组件（WarmAuraGlow）
//
// 规范文档：`docs/design-system/底部暖光规范_v1.md`
//
// 本组件（9 档非线性椭圆）专供 B 档（Tab2 解锁后）。
// Tab1 与 Tab2 解锁前走控件背板；Onboarding 是 A 档的有意例外，用的是
// OnboardingAuraBackground 里那颗 2 档径向 RadialGradient 椭圆（0.20 / r220 / 460×260），
// 不是本组件——两者曲线不同，别互相套用。

extension Gradient {
    /// Tab2 列表底部（`BottomAuraFooter`）使用的 9 档非线性缓出位置表：
    /// 0.00 / 0.28 / 0.46 / 0.60 / 0.72 / 0.83 / 0.92 / 0.97 / 1.00。
    ///
    /// 全局三档暖光规则（详见 `docs/design-system/底部暖光规范_v1.md`）：
    /// - A 档 · 主场景 + 底部常驻控件：暖光归控件背板（Tab1、Tab2 解锁前）
    /// - B 档 · 主场景 + 无底部常驻控件：一抹收尾微光椭圆（只有 Tab2 解锁后）
    /// - C 档 · 工具层 / Sheet：不给暖光（Settings、Feedback、AboutAI）
    ///
    /// 本组件为 B 档专属实现（`BottomAuraFooter`：宽 320、高 170、峰值 0.17、endRadius 150、offsetY 90）。
    /// 此处收拢 8 档透明度 + 1 档 clear 的非线性位置结构，防抄错抄漏。
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

/// 暖光晕椭圆：B 档收尾微光，径向渐变 + 44pt 模糊。
/// 宽度 320、高度 170（收进屏宽以内，横向衰减可见，读作光团而非光带）。
/// 纯装饰：不拦截交互、对无障碍隐藏，两样都收在组件内。
/// 规范详见 `docs/design-system/底部暖光规范_v1.md`。
struct WarmAuraGlow: View {
    let stops: [Gradient.Stop]
    let endRadius: CGFloat
    let offsetY: CGFloat
    var width: CGFloat = 320
    var height: CGFloat = 170

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(stops: stops, center: .center, startRadius: 0, endRadius: endRadius)
            )
            .frame(width: width, height: height)
            .blur(radius: 44)
            .offset(y: offsetY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
