import SwiftUI
import UIKit

private enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug, suggestion, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bug:        return "Bug"
        case .suggestion: return "Suggestion"
        case .other:      return "Other"
        }
    }
}

/// App 内反馈表单（方案 C）：类型 + 内容 + 选填邮箱 → submit-feedback Edge Function。
/// 与 Settings / About 同一视觉语言：暖纸底 + Canvas + 衬线标题 + 暖近白卡片输入。
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category: FeedbackCategory = .bug
    @State private var body_: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var errorMessage: String?

    private enum FocusedField { case detail, email }
    @FocusState private var focus: FocusedField?

    /// 无障碍字号下分类胶囊改为纵向排列——见 `categoryChipLayout`。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 成功浮层要多停一会儿、焦点要挪过去，都只在读屏开着时才做。
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// 提交成功后把读屏焦点搬到浮层上。不搬的话焦点仍停在表单里，
    /// 浮层那句 "Thanks — we got it." 永远不会被念到。
    @AccessibilityFocusState private var successFocused: Bool

    private let bodyLimit = 1000
    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private var trimmedBody: String {
        body_.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// 产品 UI 使用英文千分位，避免设备地区把上限显示成 `1.000` 或 `1000`。
    ///
    /// 计数走**未 trim 的原文长度**，与下面截断用的口径是同一个。
    /// 此前计数按 trim 后算、截断按原文算，两套口径并存：在末尾敲几个空格，
    /// 计数显示 `998/1,000` 却再也打不进字——看起来还剩额度，实际已经到顶。
    /// 用户看到的数就该是他实际打进去的字符数；trim 只发生在提交那一刻。
    private var bodyCountLabel: String {
        let format = Self.countFormatter
        let count = format.string(from: NSNumber(value: body_.count)) ?? "\(body_.count)"
        let limit = format.string(from: NSNumber(value: bodyLimit)) ?? "\(bodyLimit)"
        return "\(count)/\(limit)"
    }
    private var canSubmit: Bool { !trimmedBody.isEmpty && !isSubmitting }

    /// 成功浮层在自动关闭前停留多久。
    ///
    /// 1.1s 是按「看一眼就够」定的，对读屏用户不成立：焦点搬过去、读屏开口念完
    /// "Thanks — we got it." 本身就要一秒出头，页面已经关了，用户从头到尾
    /// 没听到任何确认，不知道反馈到底发出去没有。开读屏时给到 3s。
    ///
    /// 这两个数只服务这一个浮层，不上任何设计尺度，按 CLAUDE.md 的
    /// component-private 例外留在使用处。
    private var successDwell: TimeInterval { voiceOverEnabled ? 3.0 : 1.1 }

    private var deviceInfo: String {
        "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
    }

    var body: some View {
        SettingsScreen(onBack: { dismiss() }, pinnedTitle: "Feedback", dismissesKeyboardOnScroll: true) {
            categoryField
            detailField
            emailField

            if let errorMessage {
                Text(errorMessage)
                    // statusNote 的语义是「加载态 / 空态 / 系统提示性短句」，正是这里的用途。
                    // 此前用的 buddy 语义是「场景追问」，属于学习内容那一族，挪用会让
                    // 将来调追问字体时连带动到错误提示。
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.danger)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            submitButton
        }
        // 空白处提供明确的收键盘路径；输入控件会优先处理自身的点按。
        .onTapGesture { focus = nil }
        .overlay {
            if didSucceed { successOverlay }
        }
    }

    // MARK: - Fields

    /// 三个字段共用的骨架：**标题 → 控件**，一个结构写一次。
    ///
    /// 四大原则里的「重复」和「亲密性」靠它落地：三段的层级顺序、左轴、
    /// 间距完全同源，改一处三处一起变。
    private func formField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            fieldLabel(label)
            content()
        }
        // 左轴统一收在这一层：三个字段的标题与控件全部锚在 paddingPage 上，
        // 各字段不再自己加水平内边距（此前 Details 卡内文字轴被推到 41，
        // 与 Email / chip 的 36 差 5pt——外框对齐、文字不对齐，正是"乱"的来源）。
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var categoryField: some View {
        formField("What's this about?") {
            categoryChipLayout {
                ForEach(FeedbackCategory.allCases) { c in
                    categoryChip(c)
                }
            }
            // 三个胶囊是一组互斥选项，不是三个孤立按钮。`.contain` 保留每个
            // 胶囊自身可聚焦、可点，同时让读屏在进出这一组时报出组名——
            // 否则用户听到的第一句就是 "Bug"，不知道这是在问什么。
            .accessibilityElement(children: .contain)
            .accessibilityLabel("What's this about?")
        }
    }

    /// 无障碍字号下改横排为竖排。
    ///
    /// 三个胶囊的总宽 = 三段文字 + 六份 `paddingCard` 内边距 + 两份间距。文字随
    /// Dynamic Type 放大而内边距是死数，最大档下 subheadline 约 49pt，
    /// "Suggestion" 一项就要 280pt 上下，三项合计远超 iPhone 16 Pro 去掉页边距后的
    /// 353pt 可用宽——HStack 只能把文字挤到换行甚至截断，"Suggestion" 会断成两截。
    /// 竖排后每个胶囊都能独占一整行的可用宽度（胶囊本身仍是 intrinsic 宽度，
    /// 不拉伸等宽——竖排解的是「三项挤一行」，不是「三项要一样宽」）。
    ///
    /// 用 `AnyLayout` 而不是 if/else 两套子树：与 `SettingsInfoRow.textLayout`
    /// 同一手法，胶囊视图身份不变，切换字号时选中态不会闪。
    private var categoryChipLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.Space.paddingS))
            : AnyLayout(HStackLayout(spacing: AppTheme.Space.paddingS))
    }

    private func categoryChip(_ c: FeedbackCategory) -> some View {
        let selected = category == c
        return Button {
            category = c
        } label: {
            Text(c.label)
                // 复用上传胶囊的动作字体：同为「无图标的胶囊型操作」，
                // 与它同一语义。此前用的 buddy 语义是「场景追问」，属学习内容一族，
                // 挪用会让将来调追问字体时连带动到这里。
                .font(AppTheme.Font.compactActionLabel)
                .foregroundStyle(selected ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(
                    selected ? AppTheme.Color.brandTint : AppTheme.Color.cardBg,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(selected ? Color.clear : AppTheme.Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.iconControl)
        // 选中与否目前只靠底色和描边表达，那是纯视觉的。读屏用户依次听过
        // Bug / Suggestion / Other，三句一模一样，无从知道哪一项是当前选中的，
        // 也就无法确认将要提交的类别。`.isSelected` 让读屏在名字后补一句「已选中」。
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 多行输入用 `TextField(axis: .vertical)` 而不是 `TextEditor`。
    ///
    /// `TextEditor` 底层是 `UITextView`，自带一层垂直 inset 和 5pt 的
    /// `lineFragmentPadding`，两者都是 UIKit 的内部实现细节、不是公开契约。
    /// 之前为了让光标落在 placeholder 上，用 `contentMargins` 手工减掉了这两个数
    /// （`-8` / `-5`），代价是整条文字轴被推到 41，与本页其它元素的 36 对不齐，
    /// 而且 iOS 改一次内衬就会悄悄错位。
    ///
    /// `TextField` 没有这层内衬，缩进完全由外面的 `.padding(paddingCard)` 决定，
    /// 于是**和 Email 框、分类 chip 自动落在同一条文字轴上**，两个魔法数一并消失。
    /// 高度也从写死的 150 改成 `lineLimit(4...)`：空态不再是一大片没有内容支撑的
    /// 留白，写长了自己长高。
    private var detailField: some View {
        formField("Details") {
            // 计数与输入区**上下排开**，不是叠在输入区上。
            // 叠放（overlay）时正文会从无底色的计数背后滚过去，两边都读不清；
            // 旧版没出问题是因为 TextEditor 自带 24pt 底部内衬恰好让开了 21pt 的
            // 计数——那 3pt 余量是巧合，且计数会随系统字号放大而内衬是死数，
            // 大字号下必然压上。分成两行则任何字号都不可能重叠。
            VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
                ZStack(alignment: .topLeading) {
                    if body_.isEmpty {
                        // 用自绘 placeholder 而非 TextField 的内置 prompt：内置 prompt
                        // 的颜色跟随系统灰，改不到 token 层的 textMuted。
                        Text("Tell us what happened…")
                            .font(AppTheme.Font.englishBody)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .allowsHitTesting(false)
                            // 对读屏隐藏：它是输入框的提示，不是页面上独立的一段文字。
                            // 不隐藏的话，VoiceOver 会把它当正文念一遍，
                            // 用户听完还是不知道这个框要填什么。
                            .accessibilityHidden(true)
                    }
                    TextField("", text: $body_, axis: .vertical)
                        // 输入框本身没有名字（prompt 传的是空串），读屏只会说「文本框」。
                        // label 给出字段名，hint 承接提示文字那句话。
                        .accessibilityLabel("Details")
                        .accessibilityHint("Tell us what happened")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .tint(AppTheme.Color.interactive)
                        .lineLimit(4...)
                        .focused($focus, equals: .detail)
                        .onChange(of: body_) { _, newValue in
                            if newValue.count > bodyLimit {
                                body_ = String(newValue.prefix(bodyLimit))
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(bodyCountLabel)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .accessibilityLabel("\(body_.count) of \(bodyLimit) characters")
            }
            .padding(AppTheme.Space.paddingCard)
            .surfaceCard(cornerRadius: AppTheme.Radius.large,
                         fillColor: AppTheme.Color.settingsCardSurface)
        }
    }

    private var emailField: some View {
        formField("Email (optional)") {
            ZStack(alignment: .leading) {
                // `verbatim` 防止邮箱格式被识别为链接而覆盖指定的灰度。
                if email.isEmpty {
                    Text(verbatim: "name@example.com")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)   // 同上：提示文字不是独立正文
                }
                TextField("", text: $email)
                    .accessibilityLabel("Email, optional")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .tint(AppTheme.Color.interactive)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .submitLabel(.done)
                    .onSubmit { focus = nil }
                    .focused($focus, equals: .email)
            }
            .padding(AppTheme.Space.paddingCard)
            .surfaceCard(cornerRadius: AppTheme.Radius.large,
                         fillColor: AppTheme.Color.settingsCardSurface)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                Text("Send")
                    .font(AppTheme.Font.ctaLabel)
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .opacity(isSubmitting ? 0 : 1)
                if isSubmitting {
                    ProgressView().tint(AppTheme.Color.textOnChip)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.paddingCard)
            .background(
                (canSubmit ? AppTheme.Color.interactive : AppTheme.Color.neutralFaint),
                in: Capsule()
            )
        }
        .buttonStyle(.iconControl)
        .disabled(!canSubmit)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - Pieces

    /// 与 Settings 的分组标题完全同款：subheadline 衬线 medium + 次要墨色。
    ///
    /// 原来是「全大写 + 字距 + 弱灰」的小标签，与本页 largeTitle 衬线大标题**不同族**，
    /// 像从另一个 App 抄来的表单字段名。另外去掉了 `.uppercased()`——
    /// 全大写是「标签」的语气，而 "What's this about?" 本就是一句提问，
    /// 大写会把它读成字段名而不是在问你。
    /// 水平内边距由 `formField` 统一施加，这里**不要**再加一遍——
    /// 左轴只允许有一个出口，否则改边距时必须记得改两处。
    private func fieldLabel(_ t: String) -> some View {
        Text(t)
            .font(AppTheme.Font.settingsSectionTitleSerif)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    private var successOverlay: some View {
        ZStack {
            AppTheme.Color.scrimOverlay.ignoresSafeArea()
            VStack(spacing: AppTheme.Space.paddingCard) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    // 纯装饰：信息全在下面那句话里。`children: .combine` 会把子元素的
                    // 标签串起来，不会自动丢掉图标那份，于是成功确认可能被念成
                    // 「勾选 圆形 填充，图像，Thanks — we got it」，夹带一串实现名。
                    // 与 SettingsRowIconView 同一处理（该组件两处都以此收尾）。
                    .accessibilityHidden(true)
                Text("Thanks — we got it.")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }
            .padding(AppTheme.Space.paddingHero)
            .surfaceCard(cornerRadius: AppTheme.Radius.large,
                         fillColor: AppTheme.Color.settingsCardSurface)
            // 勾图标 + 文案合成一个元素：图标本身没有信息量，单独聚焦只会
            // 多念一次「图像」。合并后这一格就是那句话本身。
            .accessibilityElement(children: .combine)
            .accessibilityFocused($successFocused)
        }
        .transition(.opacity)
        // 浮层盖住整页，视觉上表单已经不可用了；不声明 isModal 的话读屏仍能
        // 划到后面的输入框和 Send 键，念出一个用户根本看不见、也点不动的表单。
        .accessibilityAddTraits(.isModal)
        // 焦点转移要等浮层真的进入无障碍树之后再做，否则这次赋值会落空。
        .onAppear { successFocused = true }
    }

    // MARK: - Submit

    private func submit() async {
        // 先收键盘：成功浮层是全屏的，键盘留在上面会把
        // "Thanks — we got it." 盖掉半截。
        focus = nil
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var req = URLRequest(url: SupabaseConfig.submitFeedbackFunctionURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 20
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try await SupabaseManager.setAuthHeaders(on: &req)

            var payload: [String: String] = [
                "category": category.rawValue,
                "body": trimmedBody,
                "app_version": Bundle.main.appVersion,
                "device_info": deviceInfo,
            ]
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEmail.isEmpty { payload["contact_email"] = trimmedEmail }
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            switch http.statusCode {
            case 200..<300:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.2)) { didSucceed = true }
                try? await Task.sleep(for: .seconds(successDwell))
                dismiss()
            case 429:
                errorMessage = "You just sent feedback — please wait a moment."
            case 400:
                errorMessage = "Please check your feedback and try again."
            default:
                errorMessage = "Couldn't send. Please try again."
            }
        } catch {
            errorMessage = "Couldn't send. Check your connection and try again."
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
