import SwiftUI

/// 兜底态（生成失败 / 放弃）的纸雕插画：与空输入区叠纸同族——三层暖色纸卡
/// 叠出层次，前景卡上几条淡描边暗示"本该长出的时刻卡"，右上角一枚小橙徽标
/// 呼应动作（retry = 刷新；explore = 前进）。橙色仅用于 ≤30pt 的小面积角标。
struct OnboardingFallbackIllustration: View {
    enum Kind {
        case retry   // 可重试的出错态
        case explore // 放弃后引导进 App

        var glyph: String {
            switch self {
            case .retry:   return "arrow.clockwise"
            case .explore: return "arrow.right"
            }
        }
    }

    let kind: Kind

    private var cardSize: CGFloat { AppTheme.Size.onboardingFallbackCardSize }
    private var badge: CGFloat { AppTheme.Size.onboardingFallbackBadge }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 叠纸层
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.brandTint)
                    .frame(width: cardSize + 16, height: cardSize + 8)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -8, y: 6)

                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.neutralFaint.opacity(0.5))
                    .frame(width: cardSize + 8, height: cardSize + 4)
                    .rotationEffect(.degrees(4))
                    .offset(x: 6, y: 2)

                // 前景纸卡 + 淡描边"文字条"
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.cardBg)
                    .frame(width: cardSize, height: cardSize)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 7) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 34, height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 46, height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 24, height: 5)
                        }
                        .padding(.leading, 12)
                    }
                    .shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    )
            }
            .frame(
                width: AppTheme.Size.onboardingFallbackIllustrationWidth,
                height: AppTheme.Size.onboardingFallbackIllustrationHeight
            )

            // 橙色角标
            Image(systemName: kind.glyph)
                .font(.system(size: AppTheme.Size.onboardingFallbackBadgeGlyph, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: badge, height: badge)
                .background(AppTheme.Color.brandStrong, in: Circle())
                .offset(x: 4, y: -2)
        }
        .frame(
            width: AppTheme.Size.onboardingFallbackIllustrationWidth,
            height: AppTheme.Size.onboardingFallbackIllustrationHeight
        )
        .accessibilityHidden(true)
    }
}
