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
    /// 删号失败原因。非 nil 即弹错误 alert。
    /// 早先这里是空 catch（注释写「静默失败：按钮重新可点，用户可重试」）——
    /// 结果是删号挂了近三周没人发现：用户只看到转圈然后回到原样，无从报告，
    /// 开发也无从定位，最后靠一次完整的后端排查才找到根因。
    /// 失败必须可见，这也是 CLAUDE.md「每个页面必须定义 error 状态」的要求。
    @State private var deleteErrorMessage: String?
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
        .alert("Couldn't delete account", isPresented: deleteErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Something went wrong. Please try again.")
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
                UserDefaults.standard.removeObject(forKey: Tab2Defaults.permanentlyUnlocked)
                UserDefaults.standard.removeObject(forKey: Tab2Defaults.firstUnlockShown)
                // 清理历史旧版本可能残留的 debug 脏数据
                let legacyKeys = ["debug_keep_ready_mock", "debug_force_tab2_empty", "debug_trigger_ready_state", "debug_trigger_milestone_demo"]
                legacyKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
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

    private var deleteErrorPresented: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteErrorMessage = nil
        defer { isDeleting = false }

        do {
            var request = URLRequest(url: SupabaseConfig.deleteAccountFunctionURL)
            request.httpMethod = "POST"
            // 后端要串行删 7 张表 + Storage 对象 + auth 用户，空账号实测已近 10s，
            // 有素材的账号更久。30s 对这条链路太紧，超时会被误当成「删不掉」。
            request.timeoutInterval = 90
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try await SupabaseManager.setAuthHeaders(on: &request)

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            guard let status, (200..<300).contains(status) else {
                deleteErrorMessage = Self.deleteErrorMessage(status: status)
                return
            }

            try? await SupabaseManager.signOut()
            // 服务器数据没了，本地镜像也必须一起清——App 随后会静默注册一个新匿名账号，
            // 残留的缓存/记录会被新账号读到，表现为「账号删了、内容还在」。
            // 完整清单在 LocalUserData，新增本地存储时只需在那里补一行。
            let localFullyCleared = await LocalUserData.clearAll()
            // 服务端会如实回报 Storage 是否确认清空。字段缺失时按「已清空」处理：
            // 老版本函数不返回该字段，不能因为解不出来就吓唬用户。
            let serverFullyCleared = Self.storageCleared(from: data)

            // 有残留时如实告知——不能一边留着用户的照片、一边宣称「全部数据已删除」。
            // 提示写到**根一级**：clearAll() 已把 onboarding 标记归 0，
            // RootView 马上会切到 OnboardingView，本页连同 sheet 一起销毁，
            // 挂在这里的 alert 不会有宿主（见 AccountDeletionNotice）。
            if !localFullyCleared || !serverFullyCleared {
                AccountDeletionNotice.shared.message = Self.partialCleanupWarning(
                    localCleared: localFullyCleared,
                    serverCleared: serverFullyCleared
                )
            }
            dismiss()
        } catch {
            deleteErrorMessage = Self.deleteErrorMessage(error: error)
        }
    }

    static let genericDeleteError =
        "We couldn't delete your account. Please try again."

    /// 服务端 `storage_cleared` 解码。字段缺失 → 视为已清空（老版本函数兼容）。
    static func storageCleared(from data: Data) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 2xx 却给不出 JSON body 属异常信号。但告诉用户没有意义——
            // 他对此做不了任何事，弹窗只会制造焦虑。记日志便于排查，
            // 行为上仍按「已清空」处理（与字段缺失一致）。
            if !data.isEmpty {
                print("[delete-account] 2xx response with non-JSON body, assuming storage cleared")
            }
            return true
        }
        // 字段缺失 = 老版本 Edge Function，正常情况，不记日志也不警告用户。
        guard let cleared = obj["storage_cleared"] as? Bool else { return true }
        return cleared
    }

    /// 账号确实删掉了、但有东西没擦干净时的文案。
    /// 刻意不含「全部数据已删除」这类断言——那正是残留时不成立的部分。
    /// 本地与服务端分开措辞：前者用户重装即可清除，后者用户做不了什么，
    /// 硬让他「重装试试」只会白折腾。
    static func partialCleanupWarning(localCleared: Bool, serverCleared: Bool) -> String {
        let head = "Your account was deleted."
        switch (localCleared, serverCleared) {
        case (false, false):
            return "\(head) Some files couldn't be removed: a few uploaded images remain on our servers, and some files remain on this device — reinstalling the app clears the device ones."
        case (false, true):
            return "\(head) Some files couldn't be removed from this device — reinstalling the app will clear them."
        case (true, false):
            return "\(head) A few uploaded images couldn't be removed from our servers."
        case (true, true):
            return head
        }
    }

    /// HTTP 状态码 → 用户可见文案。
    /// 401 单独给话术：这是会话过期的典型码，重开 App 就能拿到新会话
    /// （历史上正是「过期 JWT → 401 → 静默吞掉」让删号挂了近三周没人发现）。
    /// 其余码不向用户暴露数字，只给可执行的下一步。
    static func deleteErrorMessage(status: Int?) -> String {
        status == 401
            ? "Your session expired. Please reopen the app and try again."
            : genericDeleteError
    }

    /// 抛出的错误 → 用户可见文案。
    /// 断网与超时必须分开说：前者用户能自己解决；后者要提醒「可能已经删成功了」——
    /// 服务端不会因为客户端超时而停止，不提示这一点，用户会反复重试一件已完成的事。
    static func deleteErrorMessage(error: Error) -> String {
        switch (error as? URLError)?.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "You're offline. Check your connection and try again."
        case .timedOut:
            return "This is taking longer than expected. Reopen the app to check whether your account was already deleted."
        default:
            return genericDeleteError
        }
    }
}

#Preview {
    SettingsView()
}
