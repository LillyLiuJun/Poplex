import SwiftUI

/// 空输入区插画：一张品牌浅橙底片托起明亮相机窗。
/// 104×72 名义尺寸保持不变，不影响卡内 24/16/24/24 的布局度量。
/// 相机使用自绘 24pt 线性语言：1.5pt 暖灰描边 + 品牌橙镜头环，
/// 不依赖 emoji 或 SF Symbol，作为装饰性视觉锚点对 VoiceOver 隐藏。
struct OnboardingCaptureIllustration: View {
    var body: some View {
        ZStack {
            // 后层：单张暖橙底片，提供品牌温度但不制造厚重叠卡。
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(AppTheme.Color.brandTint)
                .frame(width: 72, height: 52)
                .rotationEffect(.degrees(-8))
                .offset(x: -7, y: 2)

            // 前层：明亮相机窗。
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.cardBg)
                    .frame(width: 64, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .strokeBorder(
                                AppTheme.Color.border.opacity(0.55),
                                lineWidth: 1
                            )
                    }

                cameraGlyph
            }
            .offset(x: 5, y: 4)
            .shadow(
                color: AppTheme.Shadow.paperLayerColor,
                radius: AppTheme.Shadow.paperLayerRadius,
                x: AppTheme.Shadow.paperLayerX,
                y: AppTheme.Shadow.paperLayerY
            )
        }
        .frame(
            width: AppTheme.Size.onboardingUploadIllustrationWidth,
            height: AppTheme.Size.onboardingUploadIllustrationHeight
        )
        .scaleEffect(0.95)
        .accessibilityHidden(true)
    }

    /// 24pt 活跃绘制区：线宽与页面轻量 SF Symbols 接近，镜头环承担唯一强橙强调。
    private var cameraGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    AppTheme.Color.textSecondary,
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 34, height: 23)
                .offset(y: 2)

            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.Color.textSecondary)
                .frame(width: 10, height: 4)
                .offset(x: -7, y: -11.5)

            Circle()
                .stroke(AppTheme.Color.brandStrong, lineWidth: 2)
                .frame(width: 13, height: 13)
                .offset(y: 2)

            Circle()
                .fill(AppTheme.Color.brandWashLight)
                .frame(width: 7, height: 7)
                .offset(y: 2)

            Circle()
                .fill(AppTheme.Color.brandStrong)
                .frame(width: 3, height: 3)
                .offset(x: 11, y: -4.5)
        }
        .frame(width: 40, height: 32)
    }
}
