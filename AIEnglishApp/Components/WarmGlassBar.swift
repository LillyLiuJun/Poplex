import SwiftUI

/// ChatGPT / Gemini 风格可变渐进式通透毛玻璃底托（Translucent Variable Blur Backdrop）。
/// 目前只服务 Tab1 底部 InputBar；顶栏遮罩见下方 `TopBarProgressiveMask`（两者视觉诉求不同，
/// 顶栏不需要 extraExtend/底色融合这套底栏专属机制，曾经共用一个 direction 开关反而互相牵制）。
///
/// 视觉设计准则：
/// 1. **顶部极微弱羽化（Subtle Top Fade）**：朝向内容区的上边缘羽化极其轻微自然（对齐 ChatGPT），
///    输入框上方的卡片和文字不会提前发灰发暗，保持内容区最高通透度。
/// 2. **内部丝滑散焦（Smooth In-Pill Defocus）**：内容滑动进入输入框本体背后时，平滑且迅速地过渡散焦与实底融合。
/// 3. **底部坚实沉稳（Solid Bottom Protection）**：输入框下沿与底部安全区（Home Bar）保持饱满的实底遮蔽（对齐初始版本），
///    底色浑然一体（几乎不可见），绝不透底穿帮。
struct VariableBlurBackdrop: View {
    /// 渐隐过渡区高度（超出组件本体朝内容侧延伸的平滑消融区域）
    var extraExtend: CGFloat
    /// 渐变基色（默认绑定主题 pageBg）
    var baseColor: Color

    init(
        extraExtend: CGFloat = 16,
        baseColor: Color = AppTheme.Color.pageBg
    ) {
        self.extraExtend = extraExtend
        self.baseColor = baseColor
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height + extraExtend
            let fadeRatio = extraExtend / max(totalHeight, 1)

            ZStack {
                // Layer 1: 真实硬件级高斯模糊材质（提供通透毛玻璃散焦）
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Layer 2: 极轻量暖色融合（刚好中和冷灰）
                Rectangle()
                    .fill(baseColor.opacity(0.12))

                // Layer 3: 底部沉稳实底渐变（上部轻量通透，底部安全区高度实底，消除透底感）
                LinearGradient(
                    stops: [
                        .init(color: baseColor.opacity(0.00), location: 0.0),
                        .init(color: baseColor.opacity(0.02), location: min(1.0, fadeRatio)),
                        .init(color: baseColor.opacity(0.25), location: min(1.0, fadeRatio + (1.0 - fadeRatio) * 0.25)),
                        .init(color: baseColor.opacity(0.65), location: min(1.0, fadeRatio + (1.0 - fadeRatio) * 0.55)),
                        .init(color: baseColor.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // 核心：平滑非线性 Alpha 遮罩。ChatGPT 顶通透 + 原始底沉稳：
            // 上沿极微弱羽化，内部平滑散焦，底部 100% 坚实遮罩
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),                                       // 离开输入框顶部 16pt：0% 完全透明
                        .init(color: .white.opacity(0.04), location: min(1.0, fadeRatio * 0.45)),  // 输入框上方预备区：4% 极微弱羽化
                        .init(color: .white.opacity(0.24), location: min(1.0, fadeRatio)),         // 精确在输入框上沿：24% 通透起步
                        .init(color: .white.opacity(0.75), location: min(1.0, fadeRatio + (1.0 - fadeRatio) * 0.18)), // 深入输入框上部：迅速提升遮蔽
                        .init(color: .white.opacity(0.96), location: min(1.0, fadeRatio + (1.0 - fadeRatio) * 0.38)), // 输入框中段：高度遮蔽
                        .init(color: .white, location: min(1.0, fadeRatio + (1.0 - fadeRatio) * 0.55)),                // 输入框下沿及以下：100% 满浓度保护
                        .init(color: .white, location: 1.0)                                        // 底部安全区：满浓度实底，沉稳不透
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: totalHeight)
            .offset(y: -extraExtend)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Top bar mask

/// Tab1 顶栏遮罩：ChatGPT 风格自然渐进式高质感遮罩——状态栏区域满浓度保护，
/// 按钮区域丝滑衰减到高通透，下边缘极轻触底后完全消隐。
/// 固定比例节点（相对于 `.ignoresSafeArea(.container, edges: .top)` 扩展后的整条遮罩高度），
/// 已在 iPhone 17 / 16 Pro / 13 上真机验证；换更极端的安全区高度或 Dynamic Type 需要重新校准。
struct TopBarProgressiveMask: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),                // 0~59pt 状态栏区域：100% 浓度，充分遮盖背景
                        .init(color: .white, location: 0.38),               // 状态栏主体：保持稳定保护
                        .init(color: .white.opacity(0.68), location: 0.54), // 按钮上边缘：柔和衰减起点
                        .init(color: .white.opacity(0.32), location: 0.74), // 按钮中心：高通透，文字清晰可读
                        .init(color: .white.opacity(0.08), location: 0.92), // 按钮下边缘：极轻微触底
                        .init(color: .clear, location: 1.0)                 // 离开按钮区域：0% 完全透明
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - View Modifiers

extension View {
    /// 添加 Tab1 底栏可变渐进式通透模糊底托
    /// - Parameters:
    ///   - extraExtend: 渐隐过渡区高度，默认 16pt
    ///   - baseColor: 渐变底色，默认 AppTheme.Color.pageBg
    func variableBlurBackdrop(
        extraExtend: CGFloat = 16,
        baseColor: Color = AppTheme.Color.pageBg
    ) -> some View {
        background(
            VariableBlurBackdrop(extraExtend: extraExtend, baseColor: baseColor)
        )
    }
}
