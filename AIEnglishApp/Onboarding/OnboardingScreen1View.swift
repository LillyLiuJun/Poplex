import SwiftUI

/// Onboarding 第一页：品牌第一印象 + 价值主张。
/// 视觉 = 顶部品牌字标「Poplex.」报头（左对齐、与标题共左轴）+ 居中纯黑衬线封面大
/// 标题 + 一句灰副标题。报头用共享的 `PoplexWordmark`（与开屏 / 图标同源、同度量，
/// 不漂移）。背景沿用 OnboardingView 的共享背景（暖纸 + 圆点 + 极淡底部光晕），
/// 与 Screen2 / Capture 三屏一致。
struct OnboardingScreen1View: View {
    var isActive: Bool = true
    var onForward: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 报头字标的 P 字高。
    private let mastheadCapHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottom) {
            // ScrollView 兜底：小屏/大字号下内容超出视口时可滚，正常字号下无感
            // （内容不足一屏不弹、不可拖，与 Screen2 / Capture 同款机制）。
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 品牌报头（长版字标 Poplex.，与开屏 / 图标同源）。左对齐、与标题共左轴。
                        // 顶部位置只由 onboardingHeaderTop 一个数决定（N-1 单一真源），
                        // 与 Screen2 / Capture 三处标题的起始高度一致。
                        PoplexWordmark(capHeight: mastheadCapHeight)
                            .padding(.leading, AppTheme.Space.paddingPage)
                            .padding(.top, AppTheme.Size.onboardingHeaderTop)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.0)

                        // 文字组垂直居中：上下均分留白。
                        Spacer(minLength: AppTheme.Space.paddingSection)

                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        Spacer(minLength: AppTheme.Space.paddingSection)
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for the absolute bottom button
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            OnboardingBottomFade()

            OnboardingPrimaryButton(title: "Continue", action: onForward)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.30)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward)
        // 首屏靠 onAppear 触发入场：延到下一帧再翻 appeared，否则初始隐藏态来不及
        // 渲染，淡入会被 SwiftUI 跳过。
        .onAppear { if isActive { triggerEntrance() } }
        .onChange(of: isActive) { _, active in if active { triggerEntrance() } }
    }

    private func triggerEntrance() {
        guard !appeared else { return }
        DispatchQueue.main.async { appeared = true }
    }

    // MARK: - 文案区：纯黑衬线封面大标题 + 一句价值副标题
    // 标题 / 副标题错峰入场，形成封面揭幕的层次。

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text("Build your expression\nfrom work & life.")
                .font(AppTheme.Font.onboardingHeroSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

            // 副标题讲"价值"，不重复 Screen2 的"机制"，避免两屏冗余。
            Text("Not textbooks. Not drills.\nJust what's happening around you.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .lineSpacing(AppTheme.Typography.lineBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.18)
        }
    }
}

#Preview {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(onForward: {})
    }
}
