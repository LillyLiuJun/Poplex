import SwiftUI

/// Gemini 风格可变渐进式通透毛玻璃底托（Translucent Variable Blur Backdrop）。
///
/// 视觉设计准则（精确对齐 Gemini iOS 客户端）：
/// 1. **高通透毛玻璃（High Translucency）**：保留底层 `.ultraThinMaterial` 真实高斯模糊，
///    但将暖色基底透明度控制在极轻量级（~0.12），确保穿过的内容（文字/卡片）在 Bar 背后
///    清晰保持流动感和模糊辨识度，呈现出绝佳的 Z 轴景深与通透感。
/// 2. **自然消隐软边（Smooth Edge Mask）**：在朝向内容区的一侧施加 24~28pt 的平滑渐隐遮罩，
///    无任何生硬的矩形切边或厚重遮挡墙。
/// 3. **精准几何延伸**：
///    - 顶栏：背景向上延伸穿过状态栏/灵动岛，向下柔和散开 24pt。
///    - 底栏：背景向下延伸穿过底部安全区，向上柔和散开 28pt，内容自然穿过输入框流向底缘。
struct VariableBlurBackdrop: View {
    enum Direction {
        case top    // 顶栏：上实下虚（向上覆盖状态栏，向下渐隐）
        case bottom // 底栏：下实上虚（向下覆盖底安全区，向上渐隐）
    }

    var direction: Direction
    /// 渐隐过渡区高度（超出组件本体朝内容侧延伸的平滑消融区域）
    var extraExtend: CGFloat
    /// 渐变基色（默认绑定主题 pageBg）
    var baseColor: Color

    init(
        direction: Direction,
        extraExtend: CGFloat = 24,
        baseColor: Color = AppTheme.Color.pageBg
    ) {
        self.direction = direction
        self.extraExtend = extraExtend
        self.baseColor = baseColor
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height + extraExtend
            let fadeRatio = extraExtend / max(totalHeight, 1)

            ZStack {
                // Layer 1: 真实硬件级高斯模糊材质（提供 Gemini 同款通透毛玻璃散焦）
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Layer 2: 极轻量暖色融合（0.12 透明度：刚好中和冷灰，同时保持 100% 通透景深）
                Rectangle()
                    .fill(baseColor.opacity(0.12))

                // Layer 3: 柔和环境光微渐变（提供极细腻的明暗过渡，不阻挡底层内容）
                if direction == .top {
                    LinearGradient(
                        stops: [
                            .init(color: baseColor.opacity(0.18), location: 0.0),
                            .init(color: baseColor.opacity(0.06), location: max(0, 1.0 - fadeRatio)),
                            .init(color: baseColor.opacity(0.00), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: baseColor.opacity(0.00), location: 0.0),
                            .init(color: baseColor.opacity(0.06), location: min(1.0, fadeRatio)),
                            .init(color: baseColor.opacity(0.18), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            // 核心：平滑贝塞尔 Alpha 遮罩，让模糊材质在边缘如空气般自然渐隐
            .mask {
                if direction == .top {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.92), location: max(0, 1.0 - fadeRatio)),
                            .init(color: .white.opacity(0.65), location: max(0, 1.0 - fadeRatio * 0.65)),
                            .init(color: .white.opacity(0.25), location: max(0, 1.0 - fadeRatio * 0.30)),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.25), location: min(1.0, fadeRatio * 0.30)),
                            .init(color: .white.opacity(0.65), location: min(1.0, fadeRatio * 0.65)),
                            .init(color: .white.opacity(0.92), location: min(1.0, fadeRatio)),
                            .init(color: .white, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(height: totalHeight)
            .offset(y: direction == .bottom ? -extraExtend : 0)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - View Modifiers

extension View {
    /// 添加 Gemini 风格可变渐进式通透模糊底托
    /// - Parameters:
    ///   - direction: .top（顶栏）或 .bottom（底栏）
    ///   - extraExtend: 渐隐过渡区高度，默认 24pt
    ///   - baseColor: 渐变底色，默认 AppTheme.Color.pageBg
    func variableBlurBackdrop(
        direction: VariableBlurBackdrop.Direction,
        extraExtend: CGFloat = 24,
        baseColor: Color = AppTheme.Color.pageBg
    ) -> some View {
        background(
            VariableBlurBackdrop(direction: direction, extraExtend: extraExtend, baseColor: baseColor)
        )
    }

    /// 向后兼容的暖色条修饰符
    func warmGlassBar(softEdge: Edge.Set = []) -> some View {
        let direction: VariableBlurBackdrop.Direction = softEdge.contains(.bottom) ? .top : .bottom
        return variableBlurBackdrop(direction: direction, extraExtend: 24)
    }
}
