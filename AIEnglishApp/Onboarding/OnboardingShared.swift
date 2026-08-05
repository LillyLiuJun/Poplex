import SwiftUI

/// Onboarding 共享 UI 单元：主按钮 / 背景 / 入场动效。
/// 各页只组合这些组件，不在页面里重复拼装样式。

// MARK: - 主按钮：染色近黑实心胶囊，全宽（Warm Editorial：CTA 走 interactive，橙留作稀有强调）

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.textOnChip)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .background(AppTheme.Color.interactive, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.85))
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

            // 底部橙光晕（参数与 CanvasBackground 对齐）
            Color.clear
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
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 时刻卡：照片 + MOMENT chip + 英文句子
/// 第一页展示"样品"、第三页展示"用户亲手做出的结果"，同构以形成闭环。

struct OnboardingMomentCard: View {
    let image: Image
    let sentence: String
    var photoHeight: CGFloat = 168
    
    @State private var isBreathing = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .scaleEffect(isBreathing ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 8.0).repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .allowsHitTesting(false)
                .onAppear {
                    isBreathing = true
                }

            Text(sentence)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4) // Slight inset to align optically with the image
        }
        // No background or shadow -> flat integrated design
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
