import SwiftUI

/// Onboarding 第二页：机制说明 —— 回答"它是怎么工作的"。
/// 结构 = 文案（怎么做）+ 三种输入方式列表（机制可视化，纯展示）+ 单一 CTA。
/// 与第一页同节奏：入场渐次淡入上移，图标带轻微弹簧 pop。
struct OnboardingScreen2View: View {
    var onBack: () -> Void
    var onForward: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct CaptureMode: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { icon }
    }

    private let modes: [CaptureMode] = [
        CaptureMode(icon: "camera",    title: "Snap a photo",            detail: "Your surroundings become the lesson."),
        CaptureMode(icon: "mic",       title: "Say what's on your mind", detail: "Your thoughts, captured in English."),
        CaptureMode(icon: "keyboard",  title: "Type a few words",        detail: "Even a fragment is enough."),
    ]

    var body: some View {
        ZStack {
            OnboardingAuraBackground()

            VStack(alignment: .leading, spacing: 0) {
                backButton

                Spacer()

                textBlock
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                Spacer().frame(height: AppTheme.Space.paddingSection)

                VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                    ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                        captureModeRow(mode, delay: 0.18 + Double(index) * 0.1)
                            .onboardingEntrance(
                                appeared: appeared,
                                reduceMotion: reduceMotion,
                                delay: 0.18 + Double(index) * 0.1
                            )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer()

                OnboardingPrimaryButton(title: "Continue", action: onForward)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.5)
            }
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward, onRight: onBack)
        .onAppear { appeared = true }
    }

    // MARK: - 返回

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(AppTheme.Space.paddingS)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.leading, AppTheme.Space.paddingCard)
        .padding(.top, AppTheme.Space.paddingCard)
    }

    // MARK: - 文案区：标题（品牌橙强调收尾短语）+ 一句机制说明

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            (Text("Capture it\n")
                + Text("your way.").foregroundStyle(AppTheme.Color.brandStrong))
                .font(AppTheme.Font.hero)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("A photo, a voice note, or a few typed words — AI turns it into English you can actually say.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 输入方式行（纯展示，无点击 affordance）

    private func captureModeRow(_ mode: CaptureMode, delay: Double) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Space.paddingCard) {
            Image(systemName: mode.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.Color.brandStrong)
                .frame(width: AppTheme.Size.iconBadge, height: AppTheme.Size.iconBadge)
                .background(AppTheme.Color.brandSubtleBg, in: Circle())
                .scaleEffect(appeared && !reduceMotion ? 1 : 0.6)
                .animation(AppTheme.Motion.tabSelection.delay(delay), value: appeared)

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text(mode.title)
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(mode.detail)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingScreen2View(onBack: {}, onForward: {})
}
