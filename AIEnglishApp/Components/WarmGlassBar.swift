import SwiftUI

/// Tab1 底部 InputBar 纸色渐隐背板（Paper-tone Progressive Backdrop）。
///
/// 名字里的 "VariableBlur" 是留给方案 B（真·可变模糊，CAFilter variableBlur）的占位——
/// 当前内部实现是单层纯色渐变，完全不含任何模糊/失焦效果，是有意的、不是命名遗留。
/// 方案 B 落地时只替换这个类型的内部实现，对外 API（extraExtend/baseColor）保持不变，
/// 三处调用点不用跟着改（TodayView 底栏生产用 1 处，TodayView/MessageRow 的 #Preview
/// 各 1 处）。注意顶栏走的是 TopBarProgressiveMask，与本组件无关。方案 B 做完之前，
/// 别被名字误导去找模糊效果——现在真的没有。
///
/// 视觉设计准则（§3.03）：
/// 1. **全纸色同源渐变**：彻底移除系统 `.ultraThinMaterial`（避免冷灰材质导致文字淡出前先发灰），
///    改用 `clear → 暖化后的纸色（pageBg + inputBackdropWarmTint）`。
/// 2. **多段非线性缓出羽化**：上段 0~30% 核心区平滑衰减，70~100% 极长尾，全程无平台、无拐点，
///    消除马赫带效应（Mach band effect）带来的视觉硬边。
/// 3. **底端 100% 饱满实底遮蔽**：底端混入 5.5% 暖橙，承担 Tab1 底部承托暖光，并确保 Home Bar 安全区不透底穿帮。
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

            ZStack {
                // Layer 1: 纸色基底非线性渐变（clear → 100% 满浓度 baseColor）
                LinearGradient(
                    stops: [
                        .init(color: .clear,                  location: 0.00), // 上沿起点：0% 完全透明
                        .init(color: baseColor.opacity(0.04),  location: 0.03), // 极长尾衰减，消除马赫带硬边
                        .init(color: baseColor.opacity(0.13),  location: 0.08),
                        .init(color: baseColor.opacity(0.29),  location: 0.17),
                        .init(color: baseColor.opacity(0.50),  location: 0.28),
                        .init(color: baseColor.opacity(0.72),  location: 0.40),
                        .init(color: baseColor.opacity(0.88),  location: 0.54),
                        .init(color: baseColor.opacity(0.97),  location: 0.72),
                        .init(color: baseColor,                location: 1.00)  // 底部安全区：100% 满浓度实底
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Layer 2: 暖光补偿层（clear → 100% inputBackdropWarmTint，承担 Tab1 底部承托暖光）
                LinearGradient(
                    stops: [
                        .init(color: .clear,                                               location: 0.00),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.04),  location: 0.03),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.13),  location: 0.08),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.29),  location: 0.17),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.50),  location: 0.28),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.72),  location: 0.40),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.88),  location: 0.54),
                        .init(color: AppTheme.Color.inputBackdropWarmTint.opacity(0.97),  location: 0.72),
                        .init(color: AppTheme.Color.inputBackdropWarmTint,                location: 1.00)
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

/// Tab1 / Tab2 顶栏遮罩：纯纸色非线性渐隐（pageBg → clear）。
///
/// 彻底移除系统 `.ultraThinMaterial`（消除原本压在顶栏的冷灰雾与 -16 亮度 / -5 暖度断层），
/// 改用与 `SheetTopScrim` 完全同源的 `pageBg` 多段逼近非线性缓出渐变：
/// - 顶部状态栏区域：100% 满浓度 `pageBg`，滚动内容向上穿过时彻底平滑消失
/// - 按钮与下边缘区域：长尾缓出羽化至 `.clear`，全程无平台、无拐点，消除马赫带效应
struct TopBarProgressiveMask: View {
    private let base = AppTheme.Color.pageBg

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: base,                location: 0.00), // 状态栏顶部：完全不透
                .init(color: base.opacity(0.97),  location: 0.28),
                .init(color: base.opacity(0.88),  location: 0.46),
                .init(color: base.opacity(0.72),  location: 0.60),
                .init(color: base.opacity(0.50),  location: 0.72),
                .init(color: base.opacity(0.29),  location: 0.83),
                .init(color: base.opacity(0.13),  location: 0.92),
                .init(color: base.opacity(0.04),  location: 0.97),
                .init(color: .clear,              location: 1.00)  // 顶栏下沿：干净归零
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
