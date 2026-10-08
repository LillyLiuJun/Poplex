import SwiftUI

/// Onboarding 第一页：品牌第一印象 + 价值主张。
/// 视觉 = 顶部品牌字标「Poplex.」报头（左对齐、与标题共左轴）+ 居中纯黑衬线封面大
/// 标题 + 一句灰副标题。报头用共享的 `PoplexLockupMark`（横排组合，
/// 不漂移）。背景沿用 OnboardingView 的共享背景（暖纸 + 圆点 + 极淡底部光晕），
/// 与 Screen2 / Capture 三屏一致。
struct OnboardingScreen1View: View {
    var isActive: Bool = true
    var onForward: () -> Void
    var mastheadMarkHeight: CGFloat = AppTheme.Size.onboardingS1MastheadMarkHeight

    init(
        isActive: Bool = true,
        mastheadMarkHeight: CGFloat = AppTheme.Size.onboardingS1MastheadMarkHeight,
        onForward: @escaping () -> Void
    ) {
        self.isActive = isActive
        self.mastheadMarkHeight = mastheadMarkHeight
        self.onForward = onForward
    }

    @State private var appeared = false
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 放大前的报头 frame 高（= 规范下限）。图形的可见上沿 / 左沿以它为基准定位，
    /// 放大只向下、向右长，不挪动图形原来的左上角。
    private let mastheadReferenceFrameHeight: CGFloat = PoplexLockupMark.minimumHeight

    /// 组合的 frame 相对基准 frame 多出来的留白：用负偏移吃掉，让可见图形的左上角留在原位。
    private var mastheadInsets: (top: CGFloat, leading: CGFloat) {
        let lockup = PoplexLockupMark(markHeight: mastheadMarkHeight)
        return (
            top: lockup.topInset - mastheadReferenceFrameHeight * PoplexLockupMark.topInsetRatio,
            leading: lockup.leadingInset - mastheadReferenceFrameHeight * PoplexLockupMark.leadingInsetRatio
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ScrollView 兜底：小屏/大字号下内容超出视口时可滚，正常字号下无感
            // （内容不足一屏不弹、不可拖，与 Screen2 / Capture 同款机制）。
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 品牌报头（横排组合：单图形 + 暖墨字标）。左对齐、与标题共左轴。
                        PoplexLockupMark(markHeight: mastheadMarkHeight)
                            .padding(.leading, AppTheme.Space.paddingPage - mastheadInsets.leading)
                            .padding(.top, AppTheme.Size.onboardingS1MastheadTop - mastheadInsets.top)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.0)

                        // 上方弹性留白吸收机型差异
                        Spacer(minLength: AppTheme.Space.onboardingHeaderToContent)

                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        // 方案 1 锚定 CTA：文字组下缘 → Continue 上缘 = onboardingHeroToCTA (160pt，下沉40pt)。
                        // 尾块 = 该距离 + 按钮自身占位（下边距 + 高）
                        Color.clear.frame(
                            height: AppTheme.Size.onboardingHeroToCTA
                                + AppTheme.Size.onboardingContinueBottom
                                + AppTheme.Size.inputBarMinHeight
                        )
                    }
                    .frame(minHeight: geo.size.height)
                    .onboardingScrollOffsetProbe($scrollOffset)   // iOS 17 走 KVO 兜底，iOS 18+ 无副作用
                }
                .scrollBounceBehavior(.basedOnSize)
                .onboardingScrollOffsetTracking($scrollOffset)
            }

            // 顶部渐隐随滚动出现（F-4）：静止时标题完整，一滚才吃掉标题顶部。
            OnboardingTopFade(scrollOffset: scrollOffset)

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
        // 标题→副标：与其余三页同档。光学间距的参照是行高——46pt 标题行高约 55、
        // 副标行高 22，8pt 的间隙在两个行盒之间读起来与 34pt 标题页一致，不需要单开一档。
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
            Text("Build your language\nfrom work & life.")
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

#Preview("Onboarding S1 · 定稿 (36pt Logo)") {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(onForward: {})
    }
}

#Preview("Onboarding S1 · 32pt Logo (轻巧秀气)") {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(mastheadMarkHeight: 32, onForward: {})
    }
}

#Preview("Onboarding S1 · 40pt Logo (原版)") {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(mastheadMarkHeight: 40, onForward: {})
    }
}
