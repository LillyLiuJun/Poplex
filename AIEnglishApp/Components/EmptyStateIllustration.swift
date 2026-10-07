import SwiftUI

/// Tab2 零素材空状态插画：极简手账便签卡（手账 B 原版方案）。
///
/// 视觉设计语言：
/// - 纯粹的 Modern Flat Papercraft：温暖透气的品牌晨曦漫射底光 + -3° 自然倾斜的纯白便签卡；
/// - 纯净克制的纸张微接触阴影与 0.8pt 微细边线，彻底摒弃厚重拟物浮雕感；
/// - 卡面内以品牌暖橙呼吸圆点（#FF7622）引导首行焦点，底部带有淡橙色 Poplex 品牌压印微徽标。
struct EmptyStateIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 背部晨曦漫射柔光（暖意呼吸氛围）
            LinearGradient(
                stops: [
                    .init(color: AppTheme.Color.brandTint.opacity(AppTheme.Opacity.emptyStateGlowTint), location: AppTheme.Size.emptyStateGlowStopTint),
                    .init(color: AppTheme.Color.brandStrong.opacity(AppTheme.Opacity.emptyStateGlowBrand), location: AppTheme.Size.emptyStateGlowStopBrand),
                    .init(color: AppTheme.Color.emptyStateGlowFade, location: AppTheme.Size.emptyStateGlowStopFade)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: AppTheme.Size.emptyStateGlowWidth, height: AppTheme.Size.emptyStateGlowHeight)
            .blur(radius: AppTheme.Size.emptyStateGlowBlur)
            .offset(x: AppTheme.Size.emptyStateGlowOffset, y: AppTheme.Size.emptyStateGlowOffset)

            // 便签卡本体（微倾斜 -3°，纯净现代纸感）
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppTheme.Radius.emptyStateNote)
                    .fill(AppTheme.Color.cardBg)
                    .frame(width: AppTheme.Size.emptyStateNoteWidth, height: AppTheme.Size.emptyStateNoteHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.emptyStateNote)
                            .strokeBorder(
                                AppTheme.Color.cardBorder.opacity(AppTheme.Opacity.emptyStateNoteBorder),
                                lineWidth: AppTheme.Size.emptyStateNoteHairline
                            )
                    }
                    .shadow(
                        color: AppTheme.Shadow.emptyStateNoteColor,
                        radius: AppTheme.Shadow.emptyStateNoteRadius,
                        x: AppTheme.Shadow.emptyStateNoteX,
                        y: AppTheme.Shadow.emptyStateNoteY
                    )

                VStack(alignment: .leading, spacing: AppTheme.Size.emptyStateNoteRowSpacing) {
                    // 首行焦点：品牌暖橙呼吸圆点 + 浅灰首行线
                    HStack(spacing: AppTheme.Size.emptyStateFocusGap) {
                        Circle()
                            .fill(AppTheme.Color.brandStrong)
                            .frame(width: AppTheme.Size.emptyStateFocusDot, height: AppTheme.Size.emptyStateFocusDot)

                        Capsule()
                            .fill(AppTheme.Color.textSecondary.opacity(AppTheme.Opacity.emptyStateFocusLine))
                            .frame(width: AppTheme.Size.emptyStateFocusLineWidth, height: AppTheme.Size.emptyStateFocusLineHeight)
                    }

                    // 中行文字痕迹
                    Capsule()
                        .fill(AppTheme.Color.textSecondary.opacity(AppTheme.Opacity.emptyStateMiddleLine))
                        .frame(width: AppTheme.Size.emptyStateMiddleLineWidth, height: AppTheme.Size.emptyStateTraceLineHeight)

                    // 底行文字痕迹
                    Capsule()
                        .fill(AppTheme.Color.textSecondary.opacity(AppTheme.Opacity.emptyStateBottomLine))
                        .frame(width: AppTheme.Size.emptyStateBottomLineWidth, height: AppTheme.Size.emptyStateTraceLineHeight)

                    Spacer(minLength: 0)

                    // 右下角品牌压印微徽标 (P Stamp)
                    HStack {
                        Spacer()
                        Circle()
                            .stroke(AppTheme.Color.brandStrong.opacity(AppTheme.Opacity.emptyStateStampRing), lineWidth: AppTheme.Size.emptyStateStampStroke)
                            .frame(width: AppTheme.Size.emptyStateStampDiameter, height: AppTheme.Size.emptyStateStampDiameter)
                            .overlay {
                                Text("P")
                                    .font(AppTheme.Font.emptyStateStampGlyph)
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                            }
                    }
                }
                .padding(AppTheme.Size.emptyStateNotePadding)
            }
            .frame(width: AppTheme.Size.emptyStateNoteWidth, height: AppTheme.Size.emptyStateNoteHeight)
            .rotationEffect(.degrees(AppTheme.Rotation.emptyStateNote))
        }
        .frame(
            width: AppTheme.Size.emptyStateIllustrationWidth,
            height: AppTheme.Size.emptyStateIllustrationHeight
        )
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        EmptyStateIllustration()
    }
}
