import SwiftUI

/// 首页画布装饰层（温润极简）：暖灰网格点底纹 + 底部品牌橘光晕。
/// 纯装饰、不拦截交互、对无障碍隐藏；透明（不填底色，叠在 pageBg 之上）；颜色一律走 token。
struct CanvasBackground: View {
    /// 网格点间距（pt）
    private let gridSpacing: CGFloat = 18
    /// 网格点半径（pt）
    private let dotRadius: CGFloat = 0.6
    /// 是否显示上部那缕暖光（Tab2 保留；Tab1 传 false 只留底部光晕）
    var showTopAura: Bool = true

    var body: some View {
        // 网格点为主体（Canvas 填满建议尺寸、不撑宽）。橙光晕改用 .overlay：
        // overlay 的固定宽度子视图不会向上撑大父容器，从而不再把 Tab2 的 ZStack
        // 撑到 460pt 导致整页左右溢出（Tab1 用 .background 不受影响，Tab2 用 ZStack 子视图会）。
        Canvas { context, size in
            let dot = Path(
                ellipseIn: CGRect(x: 0, y: 0, width: dotRadius * 2, height: dotRadius * 2)
            )
            let color = GraphicsContext.Shading.color(
                AppTheme.Color.canvasGridDot.opacity(0.08)
            )
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(dot.offsetBy(dx: x, dy: y), with: color)
                    x += gridSpacing
                }
                y += gridSpacing
            }
        }
        // 底部品牌橘暖光：贴着屏幕底部、藏在输入框后面的一缕暖意
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.Color.canvasAura.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 460, height: 260)
                .blur(radius: 44)
                .offset(y: 150)
        }
        // 上部一缕更淡的暖光（偏右、避开顶栏），与底部呼应；Tab1 关闭
        .overlay(alignment: .top) {
            if showTopAura {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Color.canvasAura.opacity(0.14), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 380, height: 260)
                    .blur(radius: 55)
                    .offset(x: 60, y: 90)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
