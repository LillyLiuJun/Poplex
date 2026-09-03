import SwiftUI

/// 统一的空状态排版容器（EmptyStateView）
///
/// 遵循 Onboarding Screen1 的 Warm Editorial 杂志排版语言：
/// - 左对齐轴锚在 `Space.paddingPage`，与页面标题、字标同源；
/// - 组内节奏由 token 定死：插画 → 大标题走 `Space.titleToContent`，
///   大标题 → 副标走更紧的 `Space.onboardingTitleToLead`（紧者成组）；
/// - 上下用等权 `Spacer()` 而非固定高度。调用方通常还会在底部 overlay 一个 CTA，
///   写死的底部留白既猜不准 CTA 实际高度，也会在大 Dynamic Type 下把内容顶出屏幕。
struct EmptyStateView: View {
    var title: String = "Nothing here yet."
    var subtitle: String = "Start with a moment from your day."
    var showsIllustration: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            if showsIllustration {
                EmptyStateIllustration()
                    .padding(.bottom, AppTheme.Space.titleToContent)
            }

            Text(title)
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AppTheme.Space.onboardingTitleToLead)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        EmptyStateView()
    }
}
