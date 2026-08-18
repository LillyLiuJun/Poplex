import SwiftUI

private enum OnboardingScreen2Layout {
    // 滚动位移探针的坐标空间名（F-4 TopFade）
    static let scrollSpace = "onboardingScreen2Scroll"
}

/// Onboarding 第二页：机制说明 —— 回答"它是怎么工作的"。
/// 结构 = 文案（怎么做）+ 「捕捉瞬间」视觉拼贴（照片碎片 / 语音条 / 打字气泡，
/// 用视觉元素本身呈现三种输入，而非图标+文字清单）+ 单一 CTA。
/// 照片刻意做成小而倾斜的"素材碎片"，把完整照片→英文卡的高潮留给 Capture 屏。
struct OnboardingScreen2View: View {
    var isActive: Bool = true
    var onBack: () -> Void
    var onForward: () -> Void

    @State private var appeared = false
    @State private var cursorVisible = true
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 语音条声波的柱高（固定示意波形）。
    private let waveHeights: [CGFloat] = [7, 14, 22, 11, 19, 9, 16, 23, 12, 8]

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题顶部位置只由 onboardingHeaderTop 一个数决定（N-1 单一真源）。
                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.top, AppTheme.Size.onboardingHeaderTop)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        // Continue 下移后底部弹性空隙变大，加大这里把拼贴整体下移、吃掉上方空
                        Spacer().frame(height: AppTheme.Space.paddingHero)

                        capturedMomentsCollage
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        Spacer()
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for the absolute bottom button
                    .frame(minHeight: geo.size.height) // Full height
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(
                                key: OnboardingScrollOffsetKey.self,
                                value: -contentGeo.frame(in: .named(OnboardingScreen2Layout.scrollSpace)).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: OnboardingScreen2Layout.scrollSpace)
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(OnboardingScrollOffsetKey.self) { scrollOffset = $0 }
            }

            // 顶部渐隐随滚动出现（F-4）：静止时标题完整，一滚才吃掉标题顶部。
            OnboardingTopFade(progress: min(1, max(0, scrollOffset / 24)))

            OnboardingBottomFade()

            OnboardingPrimaryButton(title: "Continue", action: onForward)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.5)
        }
        .overlay(alignment: .topLeading) {
            OnboardingBackButton(action: onBack)
                .padding(.top, AppTheme.Size.onboardingBackInset)
                .padding(.leading, AppTheme.Space.paddingM)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward, onRight: onBack)
        // 三页并排渲染，onAppear 启动即触发——入场动画必须在页面真正可见时才播
        .onAppear {
            if isActive { appeared = true }
            startCursorBlink()
        }
        .onChange(of: isActive) { _, active in if active { appeared = true } }
    }

    /// 打字气泡光标闪烁：延到下一帧翻转 cursorVisible，配合 repeatForever 起搏。
    private func startCursorBlink() {
        guard !reduceMotion else { return }
        DispatchQueue.main.async { cursorVisible = false }
    }

    // MARK: - 文案区：标题 + 一句机制说明

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Share your context, in any format.")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Drop a photo, speak, or type. AI does the rest.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .lineSpacing(AppTheme.Typography.lineBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 「捕捉瞬间」拼贴：三张视觉碎片，轻微倾斜叠放，错峰入场

    private var capturedMomentsCollage: some View {
        ZStack {
            photoCard
                .rotationEffect(.degrees(-5))
                .offset(x: -58, y: -120)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.16)

            voiceCard
                .rotationEffect(.degrees(4))
                .offset(x: 58, y: 0)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.28)

            textCard
                .rotationEffect(.degrees(-2))
                .offset(x: -30, y: 128)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.40)
        }
        .frame(height: 400)
    }

    // 照片碎片（拍立得式白边小卡 + 手写感注脚）
    private var photoCard: some View {
        VStack(spacing: 6) {
            Image("onboarding_hero")
                .resizable()
                .scaledToFill()
                .frame(width: 188, height: 146)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            // "真实感"微文案（非解释性）：让照片像随手拍下的一刻。
            Text("morning coffee")
                .font(AppTheme.Font.chineseFaint)
                .italic()
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.bottom, 2)
        }
        .padding(6)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }

    // 语音条（播放键 + 声波 + 时长）
    private var voiceCard: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            ZStack {
                Circle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 30, height: 30)
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.textOnChip)
            }

            HStack(spacing: 3) {
                ForEach(Array(waveHeights.enumerated()), id: \.offset) { _, h in
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: 26)

            Text("0:04")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }

    // 打字气泡（一句正在输入的话 + 光标 + "now" 时间戳）
    private var textCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("The subway was so packed today")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Rectangle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 2, height: 17)
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                        value: cursorVisible
                    )
            }

            Text("now")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .frame(width: 232, alignment: .leading)
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }
}

// 拼贴碎片共用的柔和悬浮阴影。
private extension View {
    func collageShadow() -> some View {
        shadow(color: AppTheme.Shadow.cardColor, radius: 16, x: 0, y: 8)
    }
}

#Preview {
    OnboardingScreen2View(onBack: {}, onForward: {})
}
