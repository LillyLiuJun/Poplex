#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - 品牌优化全真画板 (Brand Optimization Canvas)
// =====================================================================
// 🎯 核心使命：
//   1. 100% 满屏原生展示，零伪外壳、零顶部遮挡控件，直达真实真机体感；
//   2. Tab2 Footer 严格收敛为 8pt / 9pt / 10pt 灰调「纯文字」与「文字+灰Logo」共 6 大方案；
//   3. 严格遵循 Token 规范 (AppTheme.Color.textMuted, AppTheme.Space.tab2FooterTop 等)；
//   4. 零外部依赖，纯 Swift 原生呈现。

// MARK: - Tab2 Footer 6 组纯灰方案枚举

enum Tab2FooterSixVariant: String, CaseIterable, Identifiable {
    case textOnly8  = "方案 1 · 8pt 纯文字 (灰调)"
    case textOnly9  = "方案 2 · 9pt 纯文字 (灰调)"
    case textOnly10 = "方案 3 · 10pt 纯文字 (灰调)"
    case lockup8    = "方案 4 · 8pt 文字 + 灰色 Logo"
    case lockup9    = "方案 5 · 9pt 文字 + 灰色 Logo"
    case lockup10   = "方案 6 · 10pt 文字 + 灰色 Logo"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .textOnly8: return "8pt 纯文字"
        case .textOnly9: return "9pt 纯文字"
        case .textOnly10: return "10pt 纯文字"
        case .lockup8: return "8pt 图+字"
        case .lockup9: return "9pt 图+字"
        case .lockup10: return "10pt 图+字"
        }
    }

    var badge: String {
        switch self {
        case .textOnly8: return "极致纤细"
        case .textOnly9: return "黄金微缩"
        case .textOnly10: return "清晰易读"
        case .lockup8: return "微印章"
        case .lockup9: return "定稿选用"
        case .lockup10: return "平衡饱满"
        }
    }

    var capHeight: CGFloat {
        switch self {
        case .textOnly8, .lockup8: return 8.0
        case .textOnly9, .lockup9: return AppTheme.Size.tab2FooterWordmarkCapHeight
        case .textOnly10, .lockup10: return 10.0
        }
    }

    var hasSproutIcon: Bool {
        switch self {
        case .textOnly8, .textOnly9, .textOnly10: return false
        case .lockup8, .lockup9, .lockup10: return true
        }
    }

    var sproutHeight: CGFloat {
        switch self {
        case .lockup8: return 10.0
        case .lockup9: return AppTheme.Size.tab2FooterSproutHeight
        case .lockup10: return 12.0
        default: return 0.0
        }
    }

    var description: String {
        switch self {
        case .textOnly8:
            return "P 字高 8.0pt。最轻盈纤细，上下留白最大，视觉重心极度退后。"
        case .textOnly9:
            return "P 字高 9.0pt。缩减 28% 的黄金平衡点，既有书籍扉页版权签名的雅致，又保持字骨清晰。"
        case .textOnly10:
            return "P 字高 10.0pt。缩减 20%，适度留白，适合偏好字标依然具备明确可读性的场景。"
        case .lockup8:
            return "10pt 灰调嫩芽 + 8pt 灰调字标。微小的芽苗图形与字标形成完整品牌签名，全灰克制。"
        case .lockup9:
            return "11pt 灰调嫩芽 + 9pt 灰调字标（已定稿）。图字比例最协调，既有嫩芽破土的有机轮廓，又完全融入灰调。"
        case .lockup10:
            return "12pt 灰调嫩芽 + 10pt 灰调字标。品牌识别度最高，图形与文字存在感适中。"
        }
    }
}

// =====================================================================
// MARK: - Tab2 Footer 原子签名组件 (Tab2FooterSignoffView)
// =====================================================================

struct Tab2FooterSignoffView: View {
    let variant: Tab2FooterSixVariant

    var body: some View {
        VStack(spacing: AppTheme.Space.tab2FooterBrandToTagline) {
            brandMark

            Text(MineView.footerTagline())
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var brandMark: some View {
        if variant.hasSproutIcon {
            HStack(spacing: AppTheme.Space.tab2FooterMarkSpacing) {
                PoplexSproutMark(
                    height: variant.sproutHeight,
                    tintColor: AppTheme.Color.textMuted
                )

                PoplexWordmarkMono(
                    capHeight: variant.capHeight,
                    color: AppTheme.Color.textMuted
                )
            }
        } else {
            PoplexWordmarkMono(
                capHeight: variant.capHeight,
                color: AppTheme.Color.textMuted
            )
        }
    }
}

// =====================================================================
// MARK: - 画板 1: Tab2 Footer 6 方案全景并列检视页 (全屏自然流)
// =====================================================================

struct Tab2FooterSixMatrixView: View {
    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 页面说明头
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tab2 页脚签名 · 6 大纯灰方案")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Text("排除纯 Logo 与橙色方案，仅聚焦 8 / 9 / 10pt 灰色纯文字 vs 文字+灰色 Logo")
                            .font(AppTheme.Font.statusNote)
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Text("文案：Build English from your daily life.")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.Color.brandStrong)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, 16)

                    // 6 大方案卡片流
                    VStack(spacing: 16) {
                        ForEach(Tab2FooterSixVariant.allCases) { variant in
                            VStack(spacing: 0) {
                                // 卡片标题行
                                HStack {
                                    Text(variant.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppTheme.Color.textPrimary)
                                    Spacer()
                                    Text(variant.badge)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.Color.textMuted.opacity(0.12))
                                        .foregroundStyle(AppTheme.Color.textSecondary)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)

                                // 真实页脚背景容器 (带晨曦暖光)
                                ZStack(alignment: .bottom) {
                                    AppTheme.Color.pageBg
                                        .frame(height: 140)

                                    BottomAuraFooter()
                                        .frame(height: 100)

                                    Tab2FooterSignoffView(variant: variant)
                                        .padding(.bottom, 24)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                        .stroke(AppTheme.Color.cardBorder, lineWidth: 1)
                                )
                                .padding(.horizontal, 12)

                                // 说明文字
                                Text(variant.description)
                                    .font(AppTheme.Font.statusNote)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                            }
                            .background(AppTheme.Color.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                    .stroke(AppTheme.Color.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// =====================================================================
// MARK: - 画板 2: Tab2 全页真实长滚动画板 (装载选定 Footer)
// =====================================================================

struct Tab2FullPagePreviewContainer: View {
    var footerVariant: Tab2FooterSixVariant = .lockup9

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 模拟前序卡片列表
                    VStack(spacing: AppTheme.Space.paddingSection) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Topics in progress")
                                .font(AppTheme.Font.sectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            cardMock(title: "Coffee & Morning Routine", count: "4 words", subtitle: "Last practiced today · Order an iced oat latte")
                            cardMock(title: "Airport & Flight Departure", count: "6 words", subtitle: "Last practiced yesterday · Terminal 2 Gate check-in")
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Space.tab2ContentTop)

                    // 96pt 呼吸断层 (tab2FooterTop)
                    Spacer()
                        .frame(height: AppTheme.Space.tab2FooterTop)

                    // 页脚收束
                    Tab2FooterSignoffView(variant: footerVariant)
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                }
            }

            // 晨曦暖光托底
            BottomAuraFooter()
                .allowsHitTesting(false)
        }
    }

    private func cardMock(title: String, count: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppTheme.Font.buddy)
                    .fontWeight(.medium)
                Spacer()
                Text(count)
                    .font(AppTheme.Font.tab2ProgressCount)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            Text(subtitle)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(16)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

// =====================================================================
// MARK: - Xcode Canvas 纯净全屏预览 (零伪外框 · 零遮挡顶栏)
// =====================================================================

// 1. Tab2 Footer 6 个方案直接一屏滚动对比
#Preview("Tab2 Footer · 6大纯灰方案对比") {
    Tab2FooterSixMatrixView()
}

// 2. Tab2 全页滚动真实沉浸感 (方案5: 9pt 文字 + 灰色 Logo)
#Preview("Tab2 全页 · 方案5 (9pt字+灰Logo)") {
    Tab2FullPagePreviewContainer(footerVariant: .lockup9)
}

// 3. Tab2 全页滚动真实沉浸感 (方案2: 9pt 纯文字)
#Preview("Tab2 全页 · 方案2 (9pt纯文字)") {
    Tab2FullPagePreviewContainer(footerVariant: .textOnly9)
}

// 4. Onboarding S1 全屏真实效果 (36pt Logo · 视觉自然居中)
#Preview("Onboarding S1 · 36pt Logo (居中)") {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(mastheadMarkHeight: 36, onForward: {})
    }
}

// 5. Onboarding S1 全屏真实效果 (32pt Logo · 视觉自然居中)
#Preview("Onboarding S1 · 32pt Logo (居中)") {
    ZStack {
        OnboardingAuraBackground()
        OnboardingScreen1View(mastheadMarkHeight: 32, onForward: {})
    }
}
#endif
