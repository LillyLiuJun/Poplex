import SwiftUI

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
    @State private var feedbackToast: String?
    /// 推入二级页时自增 → 外壳把设置页滚回顶部。见 body 里的 onChange 说明。
    @State private var scrollToTopToken = 0
    #if DEBUG
    @State private var showResetUnlockAlert = false
    @State private var debugToast: String?
    #endif

    /// 最后一张卡与版本号之间的距离，打破卡片吸附，达到 pageFooterTop (72pt) 深度呼吸留白。
    /// 因为 SettingsScreen 的 VStack 已经自带 paddingSection (32pt)，
    /// 这里补齐差额：72 - 32 = 40pt。
    private static let sectionToFooter =
        AppTheme.Space.pageFooterTop - AppTheme.Space.paddingSection

    var footerTopExtraPadding: CGFloat = Self.sectionToFooter
    var footerBottomPadding: CGFloat = AppTheme.Space.pageFooterBottom

    init(
        previewToast: String? = nil,
        footerTopExtraPadding: CGFloat = Self.sectionToFooter,
        footerBottomPadding: CGFloat = AppTheme.Space.pageFooterBottom
    ) {
        self._feedbackToast = State(initialValue: previewToast)
        self.footerTopExtraPadding = footerTopExtraPadding
        self.footerBottomPadding = footerBottomPadding
    }

    var body: some View {
        NavigationStack {
            SettingsScreen(
                pinnedTitle: "Settings",
                bottomPadding: footerBottomPadding,
                scrollToTopToken: scrollToTopToken
            ) {
                languageCard
                legalCard
                supportCard
                accountCard
                #if DEBUG
                developerCard
                #endif
                versionFooter
            }
            .navigationDestination(isPresented: $showAboutAI) {
                AboutAIView()
            }
            .navigationDestination(isPresented: $showFeedback) {
                FeedbackView(onSuccess: {
                    feedbackToast = FeedbackView.successToastMessage
                })
            }
            // 从二级页返回时，设置页应当回到顶部而不是停在离开时的位置。
            // 这里刻意在**推入**那一刻重置（`new == true`），不是在返回那一刻：
            // 两者结果一样，但推入时页面正被盖住，用户看不到滚动跳变；
            // 若放在返回时做，跳变正好发生在他盯着这一页的瞬间。
            //
            // 一般导航（如 Tab2 → 词条）应保留滚动位置，那是系统标准行为。
            // Settings 是例外：它是只有两层的 sheet、内容不到两屏，
            // 没有值得"记住的位置"，且页面无导航栏——停在半途会露出一个
            // 没有标题的页顶，读起来像出错而不像回到原处。
            .onChange(of: showAboutAI) { _, new in if new { scrollToTopToken += 1 } }
            .onChange(of: showFeedback) { _, new in if new { scrollToTopToken += 1 } }
        }
        .toast(message: $feedbackToast, systemImage: "paperplane.fill", placement: .bottom)
        #if DEBUG
        .toast(message: $debugToast)
        #endif
        // 挂在 NavigationStack **之外**：二级页推上来后关闭键依然浮着
        .overlay(alignment: .top) { closeButton }
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
        .presentationDragIndicator(.hidden)
        #if DEBUG
        .alert("Reset Library unlock?", isPresented: $showResetUnlockAlert) {
            Button("Reset", role: .destructive) { resetLibraryUnlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Library will go back to its locked state. Debug builds only.")
        }
        #endif
    }

    // MARK: - Close button (top-right, floats over the warm canvas)

    /// **不带遮罩底**：这颗键挂在 NavigationStack 之外，会画在二级页之上；
    /// 给它加满宽的顶栏遮罩，就等于用父层的模糊盖住二级页自己的返回键
    /// （看着发虚、也点不动）。遮罩现由 `SettingsScreen` 逐页提供，
    /// 每一页的返回键都压在自己那层遮罩之上，这颗关闭键再压在最上面。
    private var closeButton: some View {
        HStack {
            Spacer()
            SettingsCircleButton(kind: .close) { dismiss() }
                .padding(.trailing, AppTheme.Space.paddingPage)
        }
        .padding(.top, AppTheme.Space.titleToContent)
    }

    // MARK: - Page title

    /// 页面大标题。与 AI 披露页、反馈页同为 largeTitle 衬线，三页顶部同款。
    /// 此前这里是 84pt 圆形 app-icon 报头——一个设置页不需要再自我介绍一次品牌，
    /// 用户是从 App 内部进来的，页面该先回答「这是哪儿」。
    // MARK: - Section cards

    /// 语言：只读两行，页面第一个分组（标题固定在顶栏，不在滚动内容里）。
    /// 图标是地球（目标语言）+ 人（母语）——语言中立，不含 A/文/国旗，
    /// 详见 SettingsRowIcon 的注释。
    private var languageCard: some View {
        SettingsCard("My language") {
            SettingsInfoRow(icon: .targetLanguage,
                            label: "Target language",
                            value: LearningLanguages.target)
            SettingsRowDivider()
            SettingsInfoRow(icon: .nativeLanguage,
                            label: "Native language",
                            value: LearningLanguages.native)
        }
    }

    /// 文案去掉了全部 `&`（原为 About & Legal / AI & Your Data / Feedback & Report /
    /// Delete Account & Data）。四个 & 挤在一屏里视觉噪音大，且行长参差、右端 chevron 不齐。
    /// 大小写统一为**句首大写**，与分组标题（My language）一致；
    /// Privacy Policy / Terms of Service 保持每词大写——它们是法律文档的**正式名称**，
    /// 属专有名词，小写反而像在指代别的东西。
    private var legalCard: some View {
        SettingsCard("Legal") {
            SettingsActionRow(icon: .aiData, label: AboutAIView.title) {
                showAboutAI = true
            }
            SettingsRowDivider()
            SettingsActionRow(icon: .privacy, label: "Privacy Policy") {
                safariItem = IdentifiableURL(LegalLinks.privacy)
            }
            SettingsRowDivider()
            SettingsActionRow(icon: .terms, label: "Terms of Service") {
                safariItem = IdentifiableURL(LegalLinks.terms)
            }
        }
    }

    private var supportCard: some View {
        SettingsCard("Support") {
            SettingsActionRow(icon: .feedback, label: "Send feedback") {
                showFeedback = true
            }
        }
    }

    private var accountCard: some View {
        SettingsCard("Account") {
            SettingsActionRow(icon: .delete,
                              label: "Delete account",
                              tint: AppTheme.Color.danger,
                              iconTint: AppTheme.Color.danger,
                              showsChevron: false) {
                showDeleteAlert = true
            }
        }
    }

    #if DEBUG
    private var developerCard: some View {
        SettingsCard("Developer") {
            SettingsActionRow(icon: .reset,
                              label: "Reset Library unlock",
                              showsChevron: false) {
                showResetUnlockAlert = true
            }
        }
    }

    /// 加确认 + 成功提示的理由：这个动作会把 Tab2 打回未解锁态，代价不小，
    /// 而它此前既没有确认也没有任何反馈——点完屏幕毫无变化，分不清是没生效
    /// 还是生效了但看不见（清单 B4 第 7 条）。
    private func resetLibraryUnlock() {
        UserDefaults.standard.removeObject(forKey: Tab2Defaults.permanentlyUnlocked)
        UserDefaults.standard.removeObject(forKey: Tab2Defaults.firstUnlockShown)
        // 清理历史旧版本可能残留的 debug 脏数据
        let legacyKeys = ["debug_keep_ready_mock", "debug_force_tab2_empty", "debug_trigger_ready_state", "debug_trigger_milestone_demo"]
        legacyKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        debugToast = "Library unlock reset."
    }
    #endif

    /// 严谨克制的页脚版本号：句首大写 + caption 直立端正衬线（方案 2：严肃书籍出版感，杜绝随性感）。
    private var versionFooter: some View {
        Text("Version \(Bundle.main.appVersion)")
            .font(AppTheme.Font.settingsVersion)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, footerTopExtraPadding)
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

#Preview("Settings · 真实 Sheet 效果 (含顶部横线)", traits: .fixedLayout(width: 393, height: 852)) {
    ZStack(alignment: .bottom) {
        AppTheme.Color.pageBg.ignoresSafeArea()
        Color.black.opacity(0.24).ignoresSafeArea()

        SettingsView()
            .frame(height: 740)
            .background(AppTheme.Color.pageBg)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.large,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppTheme.Radius.large,
                style: .continuous
            ))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -4)
    }
}

/// 交互式预览：在 Xcode Live Preview 中点击按钮即可呼出真实系统 Sheet
private struct SettingsInteractivePreview: View {
    @State private var showSettings = true

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            Button {
                showSettings = true
            } label: {
                Text("Open Settings Sheet")
                    .font(AppTheme.Font.ctaLabel)
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.Color.interactive, in: Capsule())
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview("Settings · 交互式实时弹窗演示 (Xcode Live 预览)") {
    SettingsInteractivePreview()
}

#Preview("Settings · 正式生产效果 (Option 2 · 72/28)") {
    SettingsView()
}

