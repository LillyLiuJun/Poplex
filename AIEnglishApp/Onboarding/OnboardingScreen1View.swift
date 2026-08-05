import SwiftUI

/// Onboarding 第一页：品牌第一印象 + 价值主张。
/// 克制排版（对齐 Tab2「Not open yet」）：纯衬线大标题 + 一句灰副标题 + 单一 CTA。
/// 背景不自绘——沿用 OnboardingView 的共享背景（暖纸 + 圆点 + 极淡底部光晕），
/// 与 Screen2 / Capture 三屏一致。品牌色不点在标题上，留给顶部 logo 位。
struct OnboardingScreen1View: View {
    var isActive: Bool = true
    var onForward: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部 logo 位：品牌 logo 资源到位后放这里（当前留白占位，
                // 高度与 Screen2 的返回栏对齐，保证三屏标题起始位置一致）。
                Color.clear
                    .frame(height: 36)
                    .padding(.top, AppTheme.Space.paddingCard)

                // 文字组垂直居中：把原来堆在顶部、中间空洞的布局改为上下均分留白。
                Spacer(minLength: AppTheme.Space.paddingSection)

                textBlock
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: AppTheme.Space.paddingSection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            OnboardingPrimaryButton(title: "Continue", action: onForward)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.30)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward)
        // 首屏靠 onAppear 触发入场：必须延到下一帧再翻 appeared，否则初始
        // (opacity 0 / offset) 状态来不及渲染，动画会被 SwiftUI 跳过。
        .onAppear { if isActive { triggerEntrance() } }
        .onChange(of: isActive) { _, active in if active { triggerEntrance() } }
    }

    private func triggerEntrance() {
        guard !appeared else { return }
        DispatchQueue.main.async { appeared = true }
    }

    // MARK: - 文案区：纯黑衬线封面大标题（品牌色不点标题）+ 一句价值副标题
    // 标题 / 副标题错峰入场，形成封面揭幕的层次。

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text("Build your expression\nfrom work & life.")
                .font(AppTheme.Font.onboardingHeroSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

            // 副标题讲"价值"，不重复 Screen2 的"机制"，避免两屏冗余。
            // 手动断成对称两行，避免自动折行出现 "Just what's" 孤字尾。
            Text("Not textbooks. Not drills.\nJust what's happening around you.")
                .font(AppTheme.Font.englishBody)
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
