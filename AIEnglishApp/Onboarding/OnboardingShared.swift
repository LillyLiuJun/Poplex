import SwiftUI

/// Onboarding 共享 UI 单元：主按钮 / 背景 / 入场动效。
/// 各页只组合这些组件，不在页面里重复拼装样式。

// MARK: - 主按钮：品牌橙实心胶囊，全宽

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
                .background(AppTheme.Color.brandStrong, in: Capsule())
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

// MARK: - 入场动效：淡入 + 上移；Reduce Motion 时只做淡入

extension View {
    func onboardingEntrance(appeared: Bool, reduceMotion: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .animation(.easeOut(duration: 0.55).delay(delay), value: appeared)
    }
}
