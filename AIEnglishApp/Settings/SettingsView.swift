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

// MARK: - Settings row artwork (matches visual spec §04)

private enum SettingsRowIcon {
    case aiData
    case privacy
    case terms
    case feedback
    case delete
    case reset
}

/// 视觉规范中的图标是定制 24×24 描边路径，不以近似 SF Symbol 替代。
/// 图标仅作按钮标签的装饰，按钮文字本身承载 VoiceOver 名称。
private struct SettingsRowIconView: View {
    let icon: SettingsRowIcon
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)
            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.settingsIconStroke,
                    lineCap: icon == .delete ? .round : .butt,
                    lineJoin: .round
                )
            )
        }
        .frame(
            width: AppTheme.Size.settingsRowIconGlyph,
            height: AppTheme.Size.settingsRowIconGlyph
        )
        .frame(width: AppTheme.Size.rowIcon)
        .accessibilityHidden(true)
    }

    private var path: Path {
        var path = Path()

        switch icon {
        case .aiData:
            path.move(to: CGPoint(x: 12, y: 3))
            path.addLine(to: CGPoint(x: 13.9, y: 8.1))
            path.addLine(to: CGPoint(x: 19, y: 10))
            path.addLine(to: CGPoint(x: 13.9, y: 11.9))
            path.addLine(to: CGPoint(x: 12, y: 17))
            path.addLine(to: CGPoint(x: 10.1, y: 11.9))
            path.addLine(to: CGPoint(x: 5, y: 10))
            path.addLine(to: CGPoint(x: 10.1, y: 8.1))
            path.closeSubpath()

        case .privacy:
            path.addRoundedRect(
                in: CGRect(x: 5, y: 10, width: 14, height: 10),
                cornerSize: CGSize(width: 2.4, height: 2.4)
            )
            path.move(to: CGPoint(x: 8.2, y: 10))
            path.addLine(to: CGPoint(x: 8.2, y: 7.2))
            path.addCurve(
                to: CGPoint(x: 15.8, y: 7.2),
                control1: CGPoint(x: 8.2, y: 5.1),
                control2: CGPoint(x: 9.9, y: 3.4)
            )
            path.addLine(to: CGPoint(x: 15.8, y: 10))

        case .terms:
            path.move(to: CGPoint(x: 6, y: 3.5))
            path.addLine(to: CGPoint(x: 13.5, y: 3.5))
            path.addLine(to: CGPoint(x: 18, y: 8))
            path.addLine(to: CGPoint(x: 18, y: 20.5))
            path.addLine(to: CGPoint(x: 6, y: 20.5))
            path.closeSubpath()
            path.move(to: CGPoint(x: 13.5, y: 3.5))
            path.addLine(to: CGPoint(x: 13.5, y: 8))
            path.addLine(to: CGPoint(x: 18, y: 8))
            path.move(to: CGPoint(x: 9, y: 13))
            path.addLine(to: CGPoint(x: 15, y: 13))
            path.move(to: CGPoint(x: 9, y: 16.5))
            path.addLine(to: CGPoint(x: 15, y: 16.5))

        case .feedback:
            path.move(to: CGPoint(x: 3.5, y: 6.5))
            path.addLine(to: CGPoint(x: 20.5, y: 6.5))
            path.addLine(to: CGPoint(x: 20.5, y: 17.5))
            path.addLine(to: CGPoint(x: 9.5, y: 17.5))
            path.addLine(to: CGPoint(x: 3.5, y: 21))
            path.closeSubpath()

        case .delete:
            path.move(to: CGPoint(x: 4.5, y: 7))
            path.addLine(to: CGPoint(x: 19.5, y: 7))
            path.move(to: CGPoint(x: 9.5, y: 7))
            path.addLine(to: CGPoint(x: 9.5, y: 4.2))
            path.addLine(to: CGPoint(x: 14.5, y: 4.2))
            path.addLine(to: CGPoint(x: 14.5, y: 7))
            path.move(to: CGPoint(x: 6.8, y: 7))
            path.addLine(to: CGPoint(x: 7.8, y: 20.8))
            path.addLine(to: CGPoint(x: 16.2, y: 20.8))
            path.addLine(to: CGPoint(x: 17.2, y: 7))

        case .reset:
            path.move(to: CGPoint(x: 7, y: 8))
            path.addLine(to: CGPoint(x: 7, y: 4))
            path.addLine(to: CGPoint(x: 3, y: 8))
            path.addLine(to: CGPoint(x: 7, y: 12))
            path.move(to: CGPoint(x: 7, y: 8))
            path.addCurve(
                to: CGPoint(x: 20, y: 12),
                control1: CGPoint(x: 14, y: 3),
                control2: CGPoint(x: 20, y: 6)
            )
            path.addCurve(
                to: CGPoint(x: 12, y: 21),
                control1: CGPoint(x: 20, y: 17),
                control2: CGPoint(x: 16, y: 21)
            )
        }

        return path
    }
}

private struct SettingsChevron: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)

            var path = Path()
            path.move(to: CGPoint(x: 9, y: 5))
            path.addLine(to: CGPoint(x: 16, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 19))

            context.stroke(
                path,
                with: .color(AppTheme.Color.border),
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.settingsChevronStroke,
                    lineCap: .round
                )
            )
        }
        .frame(
            width: AppTheme.Size.settingsChevronGlyph,
            height: AppTheme.Size.settingsChevronGlyph
        )
        .accessibilityHidden(true)
    }
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
            Text("This will permanently delete your account, expressions, and progress. This action cannot be undone.")
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
            settingsRow(icon: .aiData, label: "AI & Your Data") {
                showAboutAI = true
            }
            rowDivider
            settingsRow(icon: .privacy, label: "Privacy Policy") {
                safariItem = IdentifiableURL(url: privacyURL)
            }
            rowDivider
            settingsRow(icon: .terms, label: "Terms of Service") {
                safariItem = IdentifiableURL(url: termsURL)
            }
        }
    }

    private var supportCard: some View {
        settingsCard("Support") {
            settingsRow(icon: .feedback, label: "Feedback & Report") {
                showFeedback = true
            }
        }
    }

    private var accountCard: some View {
        settingsCard("Account") {
            settingsRow(icon: .delete, label: "Delete Account & Data",
                        tint: AppTheme.Color.danger, iconTint: AppTheme.Color.danger,
                        showsChevron: false) {
                showDeleteAlert = true
            }
        }
    }

    #if DEBUG
    private var developerCard: some View {
        settingsCard("Developer") {
            settingsRow(icon: .reset, label: "Reset Library unlock",
                        showsChevron: false) {
                UserDefaults.standard.removeObject(forKey: "tab2_permanently_unlocked")
                UserDefaults.standard.removeObject(forKey: "tab2_first_unlock_shown")
            }
        }
    }
    #endif

    private var versionFooter: some View {
        Text("Version \(Bundle.main.appVersion)")
            .font(AppTheme.Font.pos)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Building blocks

    /// 分区：衬线标题在卡外（与 Tab2 "Materials Yours" 同款）+ 暖纸内容卡。
    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 0) {
                content()
            }
            .surfaceCard()
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    /// 卡内行：线性图标 + 标签 + 可选箭头。默认前景近黑、图标暖灰；危险行传 danger。
    private func settingsRow(
        icon: SettingsRowIcon,
        label: String,
        tint: Color = AppTheme.Color.textPrimary,
        iconTint: Color = AppTheme.Color.textSecondary,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingCard) {
                SettingsRowIconView(icon: icon, tint: iconTint)
                Text(label)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(tint)
                Spacer()
                if showsChevron {
                    SettingsChevron()
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
