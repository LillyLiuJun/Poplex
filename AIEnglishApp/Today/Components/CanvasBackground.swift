import SwiftUI

/// 首页画布装饰层（温润极简）：暖灰网格点底纹 + 底部品牌橘光晕。
/// 纯装饰、不拦截交互、对无障碍隐藏；透明（不填底色，叠在 pageBg 之上）；颜色一律走 token。
struct CanvasBackground: View {
    /// 网格点间距（pt）
    private let gridSpacing: CGFloat = 18
    /// 网格点半径（pt）
    private let dotRadius: CGFloat = 0.6

    var body: some View {
        ZStack {
            // 暖灰网格点：提供淡淡的秩序 / 效率感底纹
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

            // 底部品牌橘光晕：覆盖下半屏的柔和渐变（对齐参考稿 bg-aura-bottom），不刺眼
            VStack {
                Spacer()
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Color.canvasAura.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 240
                        )
                    )
                    .frame(width: 420, height: 340)
                    .blur(radius: 50)
                    .offset(y: 80)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
