import SwiftUI
import SafariServices

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// About AI & Your Data：与 Settings / Tab2 同一视觉语言 —— 暖纸底 + Canvas 装饰
/// + 衬线标题 + 暖近白卡片链接。App Review 5.1.2(i) 第三方 AI 披露页。
struct AboutAIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var safariItem: IdentifiableURL?

    private let privacyURL = URL(string: "https://poplex-legal.vercel.app/privacy.html")!
    private let termsURL   = URL(string: "https://poplex-legal.vercel.app/terms.html")!

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                    backRow

                    Text("AI & Your Data")
                        .font(AppTheme.Font.pageTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        Text("Poplex creates your English learning content using AI (Google Gemini), based on the text and images you provide. This content is generated automatically and may be inaccurate or inappropriate — it's for learning reference only, not professional advice.")
                        Text("To generate content, the text and photos you provide are sent to Google Gemini for processing. We don't collect your real identity or use your data for ads. You can delete all your data anytime in Settings.")
                    }
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    linkStack
                }
                .padding(.top, AppTheme.Space.paddingS)
                .padding(.bottom, AppTheme.Space.paddingScreenBottom)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Pieces

    private var backRow: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                    .background(AppTheme.Color.cardBg, in: Circle())
                    .shadow(color: AppTheme.Shadow.cardColor,
                            radius: AppTheme.Shadow.cardRadius / 2, x: 0, y: AppTheme.Shadow.cardY / 2)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 纯文字链接（无容器）：橙色标签 + 右上外链箭头，左对齐。
    private var linkStack: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            linkRow("Privacy Policy") { safariItem = IdentifiableURL(url: privacyURL) }
            linkRow("Terms of Service") { safariItem = IdentifiableURL(url: termsURL) }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

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
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AboutAIView()
    }
}
