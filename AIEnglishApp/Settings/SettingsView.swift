import SwiftUI
import SafariServices

// MARK: - SFSafariViewController wrapper

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

// MARK: - SettingsView

/// 设置页：与 Tab1/Tab2 同一视觉语言 —— 暖纸底 + Canvas 装饰 + 圆形 app-icon 报头
/// + 衬线分区标题 + 暖近白卡片行组（弃用系统 insetGrouped 灰底分组）。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAboutAI = false
    @State private var showFeedback = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var safariItem: IdentifiableURL?

    private let privacyURL = URL(string: "https://poplex-legal.vercel.app/privacy.html")!
    private let termsURL   = URL(string: "https://poplex-legal.vercel.app/terms.html")!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Color.pageBg.ignoresSafeArea()
                CanvasBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                        brandHeader
                        aboutLegalCard
                        supportCard
                        accountCard
                        #if DEBUG
                        developerCard
                        #endif
                        versionFooter
                    }
                    .padding(.top, AppTheme.Space.paddingHero)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showAboutAI) {
                AboutAIView()
            }
            .navigationDestination(isPresented: $showFeedback) {
                FeedbackView()
            }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all your learning data. This can't be undone.")
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .disabled(isDeleting)
        .overlay {
            if isDeleting {
                AppTheme.Color.scrimOverlay.ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.Color.cardBg)
            }
        }
    }

    // MARK: - Close button (top-right, floats over the warm canvas)

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(.footnote, weight: .semibold))   // icon glyph，随 Dynamic Type
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .background(AppTheme.Color.cardBg, in: Circle())
                .shadow(color: AppTheme.Shadow.cardColor,
                        radius: AppTheme.Shadow.cardRadius / 2, x: 0, y: AppTheme.Shadow.cardY / 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingS)
    }

    // MARK: - Brand header (round app-icon mark)

    /// 圆形 app-icon 头像：直接用图标母版（含 P + 墨点 + 斜切），圆形裁切。
    private var brandHeader: some View {
        Image("PoplexIconMark")
            .resizable()
            .scaledToFill()
            .frame(width: AppTheme.Size.brandMark, height: AppTheme.Size.brandMark)
            .clipShape(Circle())
            .shadow(color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius, x: 0, y: AppTheme.Shadow.cardY)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Section cards

    private var aboutLegalCard: some View {
        settingsCard("About & Legal") {
            settingsRow(icon: "sparkles", label: "AI & Your Data") {
                showAboutAI = true
            }
            rowDivider
            settingsRow(icon: "lock", label: "Privacy Policy") {
                safariItem = IdentifiableURL(url: privacyURL)
            }
            rowDivider
            settingsRow(icon: "doc.text", label: "Terms of Service") {
                safariItem = IdentifiableURL(url: termsURL)
            }
        }
    }

    private var supportCard: some View {
        settingsCard("Support") {
            settingsRow(icon: "bubble.left", label: "Feedback & Report") {
                showFeedback = true
            }
        }
    }

    private var accountCard: some View {
        settingsCard("Account") {
            settingsRow(icon: "trash", label: "Delete Account & Data",
                        tint: AppTheme.Color.danger, iconTint: AppTheme.Color.danger,
                        showsChevron: false) {
                showDeleteAlert = true
            }
        }
    }

    #if DEBUG
    private var developerCard: some View {
        settingsCard("Developer") {
            settingsRow(icon: "arrow.counterclockwise", label: "Reset Library unlock",
                        showsChevron: false) {
                UserDefaults.standard.removeObject(forKey: "tab2_permanently_unlocked")
                UserDefaults.standard.removeObject(forKey: "tab2_first_unlock_shown")
            }
        }
    }
    #endif

    private var versionFooter: some View {
        Text("Version \(appVersion)")
            .font(AppTheme.Font.pos)
            .foregroundStyle(AppTheme.Color.textFaint)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Building blocks

    /// 分区：衬线标题在卡外（与 Tab2 "Materials Yours" 同款）+ 暖近白卡容器（柔阴影）。
    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(title.uppercased())
                .font(AppTheme.Font.groupLabel)
                .tracking(AppTheme.Typography.trackingLabel)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .shadow(color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius, x: 0, y: AppTheme.Shadow.cardY)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    /// 卡内行：线性图标 + 标签 + 可选箭头。默认前景近黑、图标暖灰；危险行传 danger。
    private func settingsRow(
        icon: String,
        label: String,
        tint: Color = AppTheme.Color.textPrimary,
        iconTint: Color = AppTheme.Color.textSecondary,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingCard) {
                Image(systemName: icon)
                    .font(.system(.body))                       // icon glyph，随 Dynamic Type
                    .foregroundStyle(iconTint)
                    .frame(width: AppTheme.Size.rowIcon, alignment: .center)
                Text(label)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(tint)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textFaint)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 行间细分割线，左侧内缩到与文字标签对齐（图标列宽 + 两侧间距）。
    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.Color.divider)
            .padding(.leading, AppTheme.Space.paddingCard + AppTheme.Size.rowIcon + AppTheme.Space.paddingCard)
    }

    // MARK: - Delete account

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            var request = URLRequest(url: SupabaseConfig.deleteAccountFunctionURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try await SupabaseManager.setAuthHeaders(on: &request)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return }

            try? await SupabaseManager.signOut()
            let keys = ["onboarding_completed_at", "ai_consent_accepted_at",
                        "tab2_permanently_unlocked", "tab2_first_unlock_shown",
                        "mine_last_scene_count"]
            keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

            dismiss()
        } catch {
            // 静默失败：按钮重新可点，用户可重试
        }
    }
}

#Preview {
    SettingsView()
}
