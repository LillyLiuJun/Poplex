import SwiftUI

/// Onboarding 第一页：品牌第一印象 + 情感钩子。
/// 结构 = 排版（价值主张）+ 悬浮样品时刻卡（产品产出证据）+ 单一 CTA。
/// 温润极简：暖米白底 + 底部品牌橙光晕，入场渐次淡入上移，之后静止。
struct OnboardingScreen1View: View {
    var onForward: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            aura

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                textBlock
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .entrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                Spacer().frame(height: AppTheme.Space.paddingHero)

                sampleMomentCard
                    .padding(.horizontal, AppTheme.Space.paddingSection)
                    .entrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.22)

                Spacer()

                continueButton
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .entrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.38)
            }
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward)
        .onAppear { appeared = true }
    }

    // MARK: - 文案区：大标题（品牌橙强调收尾短语）+ 一句支撑

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            (Text("Build your expression\nfrom ")
                + Text("work and life.").foregroundStyle(AppTheme.Color.brandStrong))
                .font(AppTheme.Font.hero)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Capture a moment. Get English you can actually say.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 样品时刻卡：第一页就看到第三页能亲手做出的产出（首尾呼应）

    private var sampleMomentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("card_morning_coffee")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .clipped()

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                Text("MOMENT")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .padding(.horizontal, AppTheme.Space.paddingS)
                    .padding(.vertical, AppTheme.Space.paddingXS)
                    .background(AppTheme.Color.chipMoment, in: Capsule())

                Text("Momo shakes off the rain after our morning walk.")
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.Space.paddingCard)
        }
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Shadow.cardRadius,
            x: AppTheme.Shadow.cardX,
            y: AppTheme.Shadow.cardY
        )
        .rotationEffect(.degrees(-2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample moment card: a photo of a dog shaking off rain, with the English sentence, Momo shakes off the rain after our morning walk.")
    }

    // MARK: - CTA：品牌橙实心胶囊，全宽，唯一主动作

    private var continueButton: some View {
        Button(action: onForward) {
            Text("Continue")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.textOnChip)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .background(AppTheme.Color.brandStrong, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.85))
    }

    // MARK: - 底部品牌橙光晕（与首页 CanvasBackground 同一配方，仅取光晕层）

    private var aura: some View {
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 入场动效：淡入 + 上移；Reduce Motion 时只做淡入

private extension View {
    func entrance(appeared: Bool, reduceMotion: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .animation(.easeOut(duration: 0.55).delay(delay), value: appeared)
    }
}

#Preview {
    OnboardingScreen1View(onForward: {})
}
