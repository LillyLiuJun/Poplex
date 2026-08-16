import SwiftUI

/// Onboarding 共享 UI 单元：主按钮 / 背景 / 入场动效。
/// 各页只组合这些组件，不在页面里重复拼装样式。

// MARK: - 主按钮：染色近黑实心胶囊，全宽（Warm Editorial：CTA 走 interactive，橙留作稀有强调）

struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(isEnabled ? AppTheme.Color.textOnChip : AppTheme.Color.controlDisabledText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .background(
                    isEnabled ? AppTheme.Color.interactive : AppTheme.Color.controlDisabledBg,
                    in: Capsule()
                )
                .overlay {
                    if !isEnabled {
                        Capsule()
                            .strokeBorder(
                                AppTheme.Color.border,
                                lineWidth: AppTheme.Size.disabledControlBorderWidth
                            )
                    }
                }
                .frame(minHeight: AppTheme.Size.inputBarMinHeight) // 高度对齐 Tab1 InputBar capsule
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.85))
    }
}

// MARK: - 返回按钮：左上角悬空圆钮（与 Settings 子页 backRow 同配方）

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .background(AppTheme.Color.cardBg, in: Circle())
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius / 2,
                    x: 0,
                    y: AppTheme.Shadow.cardY / 2
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - 页面背景：暖米白 + 网格点底纹 + 底部品牌橙光晕（与 CanvasBackground 参数统一）

struct OnboardingAuraBackground: View {
    private let gridSpacing: CGFloat = 18
    private let dotRadius: CGFloat = 0.6

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            // 网格点底纹（与 Tab1/Tab2 CanvasBackground 一致）
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
            .ignoresSafeArea()

            // 底部橙光晕已并入 OnboardingBottomFade（纯色长雾层），
            // 不再在这里单独画一枚 Ellipse —— 避免两层各调各的参数、边缘对不齐。
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 底部渐隐托：纯色长雾（pageBg 渐变 + 品牌橙光晕并进同一层）
//
// 原先用 VariableBlurBackdrop（单层 ultraThinMaterial，模糊半径恒定、只有透明度在变）：
// 渐隐区顶部相当于"低透明度的全模糊副本"盖在清晰内容上，在满幅静止照片背后会露出
// 可见的重影边和亮度台阶（Tab1 能藏住是因为背后是文字气泡+留白，onboarding 背后
// 是照片，对比更高更暴露）。换成纯色渐变没有"糊掉的副本"，物理上不存在上缘。
// 品牌橙光晕原来是 OnboardingAuraBackground 里独立的一枚 Ellipse，现在并进这一层，
// 避免两层各调各的参数、模糊边缘互相对不齐。
struct OnboardingBottomFade: View {
    private let height: CGFloat = 186

    var body: some View {
        // 缓曲线渐变：前 24% 只积累到约 14% 不透明度（慢起步，穿过的文字不会被
        // 突兀截断），86% 处已完全不透明（把内容在够到按钮前彻底吃掉）。
        LinearGradient(
            stops: [
                .init(color: AppTheme.Color.pageBg.opacity(0), location: 0.0),
                .init(color: AppTheme.Color.pageBg.opacity(0.14), location: 0.24),
                .init(color: AppTheme.Color.pageBg, location: 0.86),
                .init(color: AppTheme.Color.pageBg, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        // 品牌橙光晕（参数与旧 OnboardingAuraBackground 版本对齐）用 overlay 叠加，
        // 而不是与渐变同层的 ZStack 兄弟——overlay 内容不参与基础视图的尺寸上报。
        // 之前用 ZStack 时，460pt 宽的椭圆会把整个组件的理想宽度顶到 460（超过页面
        // 实际宽度 ~402pt），父级 .frame(width:) 按理想尺寸居中摆放时会把整页内容
        // 顶偏，在页面边缘露出相邻页的内容（真机验证过）。
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
                .offset(y: 40)
                .allowsHitTesting(false)
        }
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - 时刻卡：照片贴顶 + MOMENT chip + 英文句子 + 中文释义 (方案 A · 统一时刻卡)
/// 结果渲染为与 App 内统一的时刻卡容器，形成"看到样品→亲手做出"闭环。

struct OnboardingMomentCard: View {
    let image: Image
    let sentence: String
    var translation: String? = nil
    var photoHeight: CGFloat = 195

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("MOMENT")
                    .font(AppTheme.Font.sectionLabel)
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.bottom, 2)

                Text(sentence)
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineSpacing(AppTheme.Typography.lineBody)
                    .fixedSize(horizontal: false, vertical: true)

                if let zh = translation, !zh.isEmpty {
                    Text(zh)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(AppTheme.Color.border.opacity(0.6), lineWidth: 1)
        )
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Shadow.cardRadius,
            x: AppTheme.Shadow.cardX,
            y: AppTheme.Shadow.cardY
        )
    }
}

// MARK: - 入场动效：淡入 + 上移；Reduce Motion 时只做淡入

extension View {
    func onboardingEntrance(appeared: Bool, reduceMotion: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .animation(.easeOut(duration: 0.55).delay(delay), value: appeared)
    }
}
