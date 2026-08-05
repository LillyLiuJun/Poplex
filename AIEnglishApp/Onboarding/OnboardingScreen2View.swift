import SwiftUI

/// Onboarding 第二页：机制说明 —— 回答"它是怎么工作的"。
/// 结构 = 文案（怎么做）+ 三种输入方式列表（机制可视化，纯展示）+ 单一 CTA。
/// 与第一页同节奏：入场渐次淡入上移，图标带轻微弹簧 pop。
struct OnboardingScreen2View: View {
    var isActive: Bool = true
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
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Dummy top bar area to match backButton
                        Color.clear
                            .frame(height: 36)
                            .padding(.top, AppTheme.Space.paddingCard)
                        
                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.top, AppTheme.Space.paddingCard)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        Spacer().frame(height: AppTheme.Space.paddingSection)

                        VStack(spacing: AppTheme.Space.paddingM) {
                            ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                                cardModeRow(mode)
                                    .onboardingEntrance(
                                        appeared: appeared,
                                        reduceMotion: reduceMotion,
                                        delay: 0.18 + Double(index) * 0.1
                                    )
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                        Spacer()
                    }
                    .padding(.bottom, 120) // Give space for the absolute bottom button
                    .frame(minHeight: geo.size.height) // Full height
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            
            OnboardingPrimaryButton(title: "Continue", action: onForward)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.5)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward, onRight: onBack)
        // 三页并排渲染，onAppear 启动即触发——入场动画必须在页面真正可见时才播
        .onAppear { if isActive { appeared = true } }
        .onChange(of: isActive) { _, active in if active { appeared = true } }
    }

    // MARK: - 文案区：标题（品牌橙强调收尾短语）+ 一句机制说明

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Share your context, in any format.")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Drop a photo, speak, or type. AI does the rest.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 输入方式行（独立卡片排版）

    private func cardModeRow(_ mode: CaptureMode) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Space.paddingM) {
            // Icon in rounded orange box
            Image(systemName: mode.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.Color.brandStrong)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(AppTheme.Color.brandStrong.opacity(0.1))
                )
            
            // Text block
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(mode.detail)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Space.paddingM)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingScreen2View(onBack: {}, onForward: {})
}
