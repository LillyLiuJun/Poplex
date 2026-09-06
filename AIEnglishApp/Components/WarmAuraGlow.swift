import SwiftUI

// MARK: - 底部暖光 B 档专用组件（WarmAuraGlow）
//
// 规范文档：`docs/design-system/底部暖光规范_v1.md`
//
// 本组件专供 B 档（Tab2 解锁后列表底部微光收尾）。
// Tab1 与 Tab2 解锁前走控件背板；Onboarding 是 A 档的有意例外，用的是
// OnboardingAuraBackground 里那颗 2 档径向 RadialGradient 椭圆（0.20 / r220 / 460×260），
// 不是本组件——两者曲线与几何模型不同，别互相套用。

/// 暖光晕椭圆：B 档收尾微光，等比压制无截断单层椭圆径向渐变 + 柔和高斯模糊。
/// 宽度 320、扁平压制比 0.32（高度约 102pt）、下沉 offsetY 60pt、峰值 0.11、模糊 20pt。
/// 从几何源头消除了旧版“正圆径向渐变遭扁椭圆硬裁切”导致的内外双层光圈缺陷。
/// 纯装饰：不拦截交互、对无障碍隐藏，两样都收在组件内。
/// 规范详见 `docs/design-system/底部暖光规范_v1.md`。
struct WarmAuraGlow: View {
    var width: CGFloat = 320
    var height: CGFloat = 102
    var peakOpacity: Double = 0.11
    var offsetY: CGFloat = 60
    var blurRadius: CGFloat = 20

    var endRadius: CGFloat { width / 2 }

    /// 规范 B 档默认构造器（3D 定稿：320×102，峰值 0.11，下沉 60pt，模糊 20pt）
    init(
        width: CGFloat = 320,
        height: CGFloat = 102,
        peakOpacity: Double = 0.11,
        offsetY: CGFloat = 60,
        blurRadius: CGFloat = 20
    ) {
        self.width = width
        self.height = height
        self.peakOpacity = peakOpacity
        self.offsetY = offsetY
        self.blurRadius = blurRadius
    }

    /// 方案 3D 专属 4 档各向同性渐变阶梯：
    /// 0.00 峰值 -> 0.35 衰减至 70% -> 0.70 衰减至 25% -> 1.00 纯透明
    var gradientStops: [Gradient.Stop] {
        [
            Gradient.Stop(color: AppTheme.Color.canvasAura.opacity(peakOpacity), location: 0.0),
            Gradient.Stop(color: AppTheme.Color.canvasAura.opacity(peakOpacity * 0.70), location: 0.35),
            Gradient.Stop(color: AppTheme.Color.canvasAura.opacity(peakOpacity * 0.25), location: 0.70),
            Gradient.Stop(color: .clear, location: 1.0)
        ]
    }

    var body: some View {
        let scaleY = width > 0 ? height / width : 0.32

        Circle()
            .fill(
                RadialGradient(
                    stops: gradientStops,
                    center: .center,
                    startRadius: 0,
                    endRadius: width / 2
                )
            )
            .frame(width: width, height: width)
            .scaleEffect(y: scaleY, anchor: .center)
            .blur(radius: blurRadius)
            .offset(y: offsetY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
