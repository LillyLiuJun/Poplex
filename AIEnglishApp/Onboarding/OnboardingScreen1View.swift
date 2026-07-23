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
            OnboardingAuraBackground()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                textBlock
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                Spacer().frame(height: AppTheme.Space.paddingHero)

                sampleMomentCard
                    .padding(.horizontal, AppTheme.Space.paddingSection)
                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.22)

                Spacer()

                OnboardingPrimaryButton(title: "Continue", action: onForward)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.38)
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
}

#Preview {
    OnboardingScreen1View(onForward: {})
}
