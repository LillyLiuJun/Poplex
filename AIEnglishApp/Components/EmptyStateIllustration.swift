import SwiftUI

/// Tab2 零素材空状态插画：两张自然叠放的纸片。
///
/// 视觉语法与 Onboarding 相机插画同源：奶油橙底片 + 暖白前卡 + 暖灰结构线。
/// 前卡使用三行抽象内容痕迹；中间一行由「短线—圆点—短线」构成一个整体，
/// 横线在圆点两侧止住，不从圆点底下穿过。
struct EmptyStateIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            paperCard(
                color: AppTheme.Color.brandTint,
                rotation: AppTheme.Rotation.emptyStateCardBack
            )
            .offset(
                x: AppTheme.Size.emptyStateCardBackOffsetX,
                y: AppTheme.Size.emptyStateCardBackOffsetY
            )

            ZStack {
                paperCard(
                    color: AppTheme.Color.cardBg,
                    rotation: AppTheme.Rotation.emptyStateCardFront,
                    showsHairline: true
                )

                contentGlyph
                    .rotationEffect(.degrees(AppTheme.Rotation.emptyStateCardFront))
            }
            .offset(
                x: AppTheme.Size.emptyStateCardFrontOffsetX,
                y: AppTheme.Size.emptyStateCardFrontOffsetY
            )
            .shadow(
                color: AppTheme.Shadow.emptyStateFrontColor,
                radius: AppTheme.Shadow.emptyStateFrontRadius,
                x: AppTheme.Shadow.emptyStateFrontX,
                y: AppTheme.Shadow.emptyStateFrontY
            )
        }
        .frame(
            width: AppTheme.Size.emptyStateIllustrationWidth,
            height: AppTheme.Size.emptyStateIllustrationHeight
        )
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }

    private func paperCard(
        color: Color,
        rotation: CGFloat,
        showsHairline: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
            .fill(color)
            .frame(
                width: AppTheme.Size.emptyStateCardWidth,
                height: AppTheme.Size.emptyStateCardHeight
            )
            .overlay {
                if showsHairline {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .strokeBorder(
                            AppTheme.Color.border.opacity(
                                AppTheme.Opacity.illustrationHairline
                            ),
                            lineWidth: AppTheme.Size.emptyStateCardHairlineWidth
                        )
                }
            }
            .rotationEffect(.degrees(rotation))
    }

    private var contentGlyph: some View {
        VStack(spacing: AppTheme.Size.emptyStateGlyphLineSpacing) {
            glyphLine(width: AppTheme.Size.emptyStateGlyphTopLineWidth)
                .offset(x: AppTheme.Size.emptyStateGlyphTopLineOffsetX)

            HStack(spacing: AppTheme.Size.emptyStateGlyphFocusGap) {
                glyphLine(width: AppTheme.Size.emptyStateGlyphFocusLeftLineWidth)
                focusDot
                glyphLine(width: AppTheme.Size.emptyStateGlyphFocusRightLineWidth)
            }

            glyphLine(width: AppTheme.Size.emptyStateGlyphBottomLineWidth)
                .offset(x: AppTheme.Size.emptyStateGlyphBottomLineOffsetX)
        }
    }

    private var focusDot: some View {
        Circle()
            .fill(AppTheme.Color.brandStrong)
            .frame(
                width: AppTheme.Size.emptyStateGlyphFocusDot,
                height: AppTheme.Size.emptyStateGlyphFocusDot
            )
            .overlay {
                Circle()
                    .fill(AppTheme.Color.brandWashLight)
                    .frame(
                        width: AppTheme.Size.emptyStateGlyphFocusCore,
                        height: AppTheme.Size.emptyStateGlyphFocusCore
                    )
            }
    }

    private func glyphLine(width: CGFloat) -> some View {
        Capsule()
            .fill(AppTheme.Color.emptyStateIllustrationOutline)
            .frame(width: width, height: AppTheme.Size.emptyStateGlyphLineHeight)
    }
}

#Preview {
    ZStack(alignment: .leading) {
        AppTheme.Color.pageBg.ignoresSafeArea()
        EmptyStateIllustration()
            .padding(.leading, AppTheme.Space.paddingPage)
    }
}
