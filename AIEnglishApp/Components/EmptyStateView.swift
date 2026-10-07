import SwiftUI

/// 统一的空状态排版容器（EmptyStateView）
///
/// 遵循「版式 2：黄金律·画廊中心」视觉语言：
/// - 采用 4:6 黄金律负空间留白（上方 46pt，下方 120pt 留白流向底栏），
///   将视觉焦点提升至黄金分割点（约 40% 高度），彻底消除下坠沉闷感；
/// - 居中对称画廊构图，插画与标题、副标统一居中；
/// - 组内节奏严格遵从 token：插画 → 大标题走 `Space.paddingSection`（32pt），
///   大标题 → 副标走 `Space.onboardingTitleToLead`（8pt，紧者成组）；
/// - 副标最大宽度约束在 300pt 内，保证优雅自然的两行断句。
struct EmptyStateView: View {
    var title: String = "Nothing here yet."
    var subtitle: String = "Your captured moments will gather here as personalized speaking topics."
    var showsIllustration: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // 上方 4 份留白 (光学中心上提至 40% 黄金分割点，彻底消除下坠感)
            Spacer(minLength: AppTheme.Space.emptyStateTopMin)

            if showsIllustration {
                EmptyStateIllustration()
                    .padding(.bottom, AppTheme.Space.paddingSection)
            }

            Text(title)
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .multilineTextAlignment(.center)
                .padding(.top, AppTheme.Space.onboardingTitleToLead)
                .frame(maxWidth: AppTheme.Size.emptyStateSubtitleMaxWidth)

            // 下方 6 份留白 (从容通透，流淌到底部常驻操作栏)
            Spacer(minLength: AppTheme.Space.emptyStateBottomMin)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        EmptyStateView()
    }
}
