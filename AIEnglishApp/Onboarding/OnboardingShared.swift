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
        }
        .disabled(!isEnabled)
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
