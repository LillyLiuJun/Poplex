import SwiftUI

/// 首页画布装饰层（温润极简）：暖灰网格点底纹 + 底部品牌橘光晕。
///
/// 曾有一个 `showTopAura` 开关控制的上部暖光，2026-08-28 随 Settings 改造删除：
/// 当时全部生产调用点都传 false（唯一走默认值的是 EmptyStateView 的 #Preview），
/// 即它在产品里从未显示过；留着只会让下一个人写 `CanvasBackground()` 时
/// 莫名带上一层没人要的光晕。要恢复请查 git。
///
/// **与 PR #44 合并时的处理**：#44 在同一位置新增了 `showBottomAura`（错误态关掉
/// 品牌橘，避免被误读为错误色），并在 `Tab2LoadErrorView` 里写了
/// `CanvasBackground(showTopAura: false, showBottomAura: false)`。
/// 顶光晕既已不存在，那半个参数无意义，调用点改为只传 `showBottomAura: false`，
/// #44 的意图（错误态不出现任何光晕）完全保留。
/// 纯装饰、不拦截交互、对无障碍隐藏；透明（不填底色，叠在 pageBg 之上）；颜色一律走 token。
struct CanvasBackground: View {
    /// 网格点间距（pt）
    private let gridSpacing: CGFloat = 18
    /// 网格点半径（pt）
    private let dotRadius: CGFloat = 0.6
    /// 是否显示底部品牌橘光。错误等中性状态可关闭，避免品牌色被误读为错误色。
    var showBottomAura: Bool = true

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
            if showBottomAura {
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
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
