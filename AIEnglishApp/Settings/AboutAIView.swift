import SwiftUI

/// AI 数据披露页：与 Settings / Tab2 同一视觉语言 —— 暖纸底 + Canvas 装饰
/// + 衬线标题 + 纯文字链接。App Review 5.1.2(i) 第三方 AI 披露页。
struct AboutAIView: View {
    /// Settings 列表里链接到这页的那一行标签。
    ///
    /// 保留 `your`（而非 "How AI uses data"）是有意的：这页是 App Store 5.1.2(i)
    /// 要求的第三方 AI 披露入口，合规要点正是「**你的**数据被发给了第三方」；
    /// 去掉物主代词会读成一般性政策说明，也不合产品的人称。
    ///
    /// 不再是页面固定标题的单一真源——固定标题另有更短的 "Personal data"（见
    /// body 里的 `pinnedTitle`），导航条容不下这整句。两处从今往后各自维护：
    /// 合规要点（"your"）落在用户点进来时先看到的行标签和正文里，固定标题
    /// 只是进来之后的路标，简化措辞不影响披露内容本身。
    static let title = "How AI uses your data"

    @Environment(\.dismiss) private var dismiss
    @State private var safariItem: IdentifiableURL?

    var body: some View {
        SettingsScreen(onBack: { dismiss() }, pinnedTitle: "Personal data") {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text(Self.title)
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Poplex creates your English learning content using AI (Google Gemini), based on the text and images you provide. This content is generated automatically and may be inaccurate or inappropriate — it's for learning reference only, not professional advice.")
                    Text("To generate content, the text and photos you provide are sent to Google Gemini for processing. We don't collect your real identity or use your data for ads. You can delete all your data anytime in Settings.")
                }
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppTheme.Space.paddingPage)

            linkStack
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Pieces

    /// 纯文字链接（无容器）：橙色标签 + 右上外链箭头，左对齐。
    private var linkStack: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            linkRow("Privacy Policy") { safariItem = IdentifiableURL(LegalLinks.privacy) }
            linkRow("Terms of Service") { safariItem = IdentifiableURL(LegalLinks.terms) }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 文字与箭头走种子品牌橙 `brandStrong`（#FF7622）—— PM 明确指定用品牌色。
    ///
    /// ⚠️ **已知代价，非疏漏**：#FF7622 对暖纸底（#FBF6F1）约 **2.9:1**，
    /// 达不到 WCAG AA 对正文的 4.5:1，也差一点点够不到非文字元素的 3:1；
    /// `brandStrong` 的 token 注释原文写的是「满饱和图形…**永不做文字**」，
    /// 橙做文字的合规出口本是 `brandInk`（#C2410C，5.09:1）。
    /// 而这页恰好是 App Store 5.1.2(i) 的合规披露页。
    ///
    /// 权衡由 PM 拍板：品牌辨识度优先。若日后要换回合规档，
    /// 把下面两处 `brandStrong` 改成 `brandInk` 即可，无其他连带。
    private func linkRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Text(label)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Image(systemName: "arrow.up.right")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.iconControl)
    }
}

#Preview {
    NavigationStack {
        AboutAIView()
    }
}
