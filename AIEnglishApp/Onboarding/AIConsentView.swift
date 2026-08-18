import SwiftUI
import SafariServices

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

/// AI 数据同意门：首次调用 generate 前弹出，符合 App Review 5.1.2(i) 第三方 AI 披露要求。
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ai_consent_accepted_at") private var aiConsentAt: Double = 0
    @State private var showPrivacy = false

    var onAgree: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题固定在弹窗顶部：滚动阅读文案时弹窗"身份"始终可见
            // （与系统权限弹窗惯例一致——标题与按钮固定，中间内容滚动）。
            Text("Before you continue")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.bottom, AppTheme.Space.paddingCard)

            // 文案区可滚：小屏/大字号下文案变长时在弹窗内滚动，按钮始终可见。
            // 弹窗尺寸不变（medium detent），正常字号下无感。
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("This content is generated through Google's Gemini API. We don't collect your real identity or use your data for ads. You can delete all your data anytime in Settings.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(AppTheme.Typography.lineBody)

                    Button {
                        showPrivacy = true
                    } label: {
                        Text("Learn more in our Privacy Policy")
                            .font(AppTheme.Font.buddy)
                            .foregroundStyle(AppTheme.Color.brandStrong)
                    }
                    .buttonStyle(.plain)
                }
            }
            // 理想高度声明为 0：弹窗协商高度时不会把「文案完整高度」算进去，
            // sheet 保持 medium 半屏不撑高；运行时再拿「弹窗总高 - 标题 - 按钮区」的
            // 剩余空间，内容超出时才能滚动。
            .frame(minHeight: 0, idealHeight: 0, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: AppTheme.Space.paddingM) {
                Button {
                    aiConsentAt = Date().timeIntervalSince1970
                    dismiss()
                    onAgree?()
                } label: {
                    Text("Agree and continue")
                        .font(AppTheme.Font.ctaLabel)
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.paddingCard)
                        .background(AppTheme.Color.interactive, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(AppTheme.Font.buddy)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.paddingS)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingHero)
        .padding(.bottom, AppTheme.Space.paddingScreenBottom)
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://poplex-legal.vercel.app/privacy.html")!)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    AIConsentView()
}
