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

// MARK: - 页面背景：暖米白 + 底部品牌橙光晕（与首页 CanvasBackground 同一光晕配方）

struct OnboardingAuraBackground: View {
    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .clipped()
                // aspect-fill 的图片实际布局会超出 frame，clip 只裁绘制不裁
                // 命中区域——纯展示卡，整体放弃命中以防吞掉下方按钮的点击
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                Text("MOMENT")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .padding(.horizontal, AppTheme.Space.paddingS)
                    .padding(.vertical, AppTheme.Space.paddingXS)
                    .background(AppTheme.Color.chipMoment, in: Capsule())

                Text(sentence)
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
