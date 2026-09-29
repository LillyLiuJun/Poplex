import SwiftUI
import UIKit

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case suggestion, bug, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .suggestion: return "Suggestion"
        case .bug:        return "Bug"
        case .other:      return "Other"
        }
    }
}

/// 单线极简小甲虫图标（极简版）：
/// 彻底去除腿部折线与头部重叠弧，仅保留柔和圆润身体、翅缝微线与两根向外舒展的微触角。
/// 线条权重 1.0pt，视觉极其轻柔收敛。
struct MinimalistBugIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2 + 0.6

            let stroke = StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)

            // 1. 身体（柔和圆润椭圆轮廓）
            let bodyRect = CGRect(x: cx - 3.2, y: cy - 2.6, width: 6.4, height: 7.2)
            context.stroke(Path(ellipseIn: bodyRect), with: .foreground, style: stroke)

            // 2. 翅膀分缝微线（上下留空，更显透气）
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: cx, y: cy - 1.8))
            centerLine.addLine(to: CGPoint(x: cx, y: cy + 3.8))
            context.stroke(centerLine, with: .foreground, style: stroke)

            // 3. 两根柔和微触角（平滑贝塞尔曲线向上自然舒展）
            var leftAntenna = Path()
            leftAntenna.move(to: CGPoint(x: cx - 1.4, y: cy - 2.6))
            leftAntenna.addQuadCurve(
                to: CGPoint(x: cx - 3.0, y: cy - 5.2),
                control: CGPoint(x: cx - 1.8, y: cy - 4.2)
            )
            context.stroke(leftAntenna, with: .foreground, style: stroke)

            var rightAntenna = Path()
            rightAntenna.move(to: CGPoint(x: cx + 1.4, y: cy - 2.6))
            rightAntenna.addQuadCurve(
                to: CGPoint(x: cx + 3.0, y: cy - 5.2),
                control: CGPoint(x: cx + 1.8, y: cy - 4.2)
            )
            context.stroke(rightAntenna, with: .foreground, style: stroke)
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

/// App 内反馈表单：类型 + 内容 + 选填邮箱 → submit-feedback Edge Function。
/// 视觉风格：Warm Minimalism（暖纸底 + 衬线大标题 + 暖近白卡片输入 + 质感深色胶囊交互）。
struct FeedbackView: View {
    /// 提交成功的统一 toast 文案。展示责任在页面宿主（Settings、额度 Sheet 宿主
    /// 各自在 onSuccess 里弹自己的 toast）：FeedbackView 只发触觉反馈并关闭，
    /// 不再自行发全局 toast——否则与宿主的 toast 叠加出现两次（审计发现 ④）。
    /// 文案收敛为一个常量，避免多处复制（清单 C4 同源问题）。
    static let successToastMessage = "Thank you for your feedback."

    @Environment(\.dismiss) private var dismiss

    @State private var category: FeedbackCategory = .suggestion
    @State private var body_: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    var onSuccess: (() -> Void)?

    private enum FocusedField { case detail, email }
    @FocusState private var focus: FocusedField?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

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

    private var bodyCountLabel: String {
        let format = Self.countFormatter
        let count = format.string(from: NSNumber(value: body_.count)) ?? "\(body_.count)"
        let limit = format.string(from: NSNumber(value: bodyLimit)) ?? "\(bodyLimit)"
        return "\(count)/\(limit)"
    }

    private var canSubmit: Bool { !trimmedBody.isEmpty && !isSubmitting }

    private var deviceInfo: String {
        "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
    }

    init(
        initialCategory: FeedbackCategory = .suggestion,
        initialBody: String = "",
        initialEmail: String = "",
        initialErrorMessage: String? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self._category = State(initialValue: initialCategory)
        self._body_ = State(initialValue: initialBody)
        self._email = State(initialValue: initialEmail)
        self._errorMessage = State(initialValue: initialErrorMessage)
        self.onSuccess = onSuccess
    }

    var body: some View {
        SettingsScreen(onBack: { dismiss() }, pinnedTitle: "Feedback", dismissesKeyboardOnScroll: true) {
            introHeader

            categoryField
            detailField
            emailField

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13, weight: .medium))
                    Text(errorMessage)
                        .font(AppTheme.Font.statusNote)
                }
                .foregroundStyle(AppTheme.Color.danger)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            submitButton
        }
        .onTapGesture { focus = nil }
    }

    // MARK: - Subviews & Fields

    private var introHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("We'd love your feedback")
                .font(AppTheme.Font.settingsDocumentTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Share your ideas, report an issue, or request an invite code for extra quota.")
                .font(AppTheme.Font.settingsFormIntro)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func formField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            fieldLabel(label)
            content()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var categoryField: some View {
        formField("What's this about?") {
            categoryChipLayout {
                ForEach(FeedbackCategory.allCases) { c in
                    categoryChip(c)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("What's this about?")
        }
    }

    private var categoryChipLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.Space.paddingS))
            : AnyLayout(HStackLayout(spacing: AppTheme.Space.paddingS))
    }

    private func categoryChip(_ c: FeedbackCategory) -> some View {
        let selected = category == c
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                category = c
            }
        } label: {
            HStack(spacing: 5) {
                categoryIcon(c)
                    .foregroundStyle(selected ? AppTheme.Color.textSecondary : AppTheme.Color.textMuted)

                Text(c.label)
                    .font(AppTheme.Font.feedbackChipLabel)
                    .foregroundStyle(selected ? AppTheme.Color.textSecondary : AppTheme.Color.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(selected ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
            }
            .overlay {
                Capsule()
                    .stroke(selected ? AppTheme.Color.brandTint : AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
            }
            .shadow(
                color: AppTheme.Shadow.pillAmbientColor,
                radius: selected ? 4 : 2,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func categoryIcon(_ c: FeedbackCategory) -> some View {
        switch c {
        case .suggestion:
            Image(systemName: "lightbulb")
                .font(.system(size: 12, weight: .regular))
        case .bug:
            MinimalistBugIcon()
        case .other:
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .regular))
        }
    }

    private var detailField: some View {
        formField("Details") {
            VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
                ZStack(alignment: .topLeading) {
                    if body_.isEmpty {
                        Text("Tell us what happened…")
                            .font(AppTheme.Font.settingsFormInput)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextField("", text: $body_, axis: .vertical)
                        .accessibilityLabel("Details")
                        .accessibilityHint("Tell us what happened")
                        .font(AppTheme.Font.settingsFormInput)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .tint(AppTheme.Color.interactive)
                        .lineLimit(4...8)
                        .focused($focus, equals: .detail)
                        .onChange(of: body_) { _, newValue in
                            if newValue.count > bodyLimit {
                                body_ = String(newValue.prefix(bodyLimit))
                            }
                        }
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)

                Text(bodyCountLabel)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .accessibilityLabel("\(body_.count) of \(bodyLimit) characters")
            }
            .padding(AppTheme.Space.paddingCard)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .fill(AppTheme.Color.cardBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(focus == .detail ? AppTheme.Color.inputFocusBorder : AppTheme.Color.border, lineWidth: 0.8)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
        }
    }

    private var emailField: some View {
        formField("Email (optional)") {
            ZStack(alignment: .leading) {
                if email.isEmpty {
                    Text(verbatim: "name@example.com")
                        .font(AppTheme.Font.settingsFormInput)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: $email)
                    .accessibilityLabel("Email, optional")
                    .font(AppTheme.Font.settingsFormInput)
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
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .fill(AppTheme.Color.cardBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(focus == .email ? AppTheme.Color.inputFocusBorder : AppTheme.Color.border, lineWidth: 0.8)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                HStack(spacing: AppTheme.Space.paddingS) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Send feedback")
                        .font(AppTheme.Font.ctaLabel)
                }
                .foregroundStyle(canSubmit ? AppTheme.Color.textOnChip : AppTheme.Color.controlDisabledText)
                .opacity(isSubmitting ? 0 : 1)

                if isSubmitting {
                    ProgressView()
                        .tint(AppTheme.Color.textOnChip)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                Capsule()
                    .fill(canSubmit ? AppTheme.Color.interactive : AppTheme.Color.controlDisabledBg)
            }
            .overlay {
                Capsule()
                    .stroke(canSubmit ? Color.clear : AppTheme.Color.controlDisabledBorder, lineWidth: 0.8)
            }
            .shadow(
                color: canSubmit ? AppTheme.Color.interactive.opacity(0.2) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!canSubmit)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingS)
    }

    // MARK: - Helper Views

    private func fieldLabel(_ t: String) -> some View {
        Text(t)
            .font(AppTheme.Font.settingsSectionTitleSerif)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    // MARK: - Email Validation

    private func isValidEmail(_ text: String) -> Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Submit

    private func submit() async {
        focus = nil
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty && !isValidEmail(trimmedEmail) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = "Please check your email address and try again."
            return
        }

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
            if !trimmedEmail.isEmpty { payload["contact_email"] = trimmedEmail }
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            switch http.statusCode {
            case 200..<300:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // toast 由页面宿主展示（onSuccess），FeedbackView 不再自行发全局
                // toast——否则与宿主的 toast 叠加出现两次（审计发现 ④）。
                onSuccess?()
                dismiss()
            case 429:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "You just sent feedback — please wait a moment."
            case 400:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorKey = json["error"] as? String,
                   errorKey == "invalid_email" {
                    errorMessage = "Please check your email address and try again."
                } else {
                    errorMessage = "Please check your feedback and try again."
                }
            default:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "Couldn't send. Please try again."
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if let urlError = error as? URLError,
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                errorMessage = "You're offline. Check your connection and try again."
            } else {
                errorMessage = "Couldn't send. Check your connection and try again."
            }
        }
    }
}

// MARK: - Previews

#Preview("FeedbackView · Empty Form") {
    NavigationStack {
        FeedbackView()
    }
}

#Preview("FeedbackView · Filled Ready to Send") {
    NavigationStack {
        FeedbackView(
            initialCategory: .suggestion,
            initialBody: "I would love to request an invite code to increase my daily generation quota. The app has been super helpful for my daily speaking practice!",
            initialEmail: "alex@example.com"
        )
    }
}

#Preview("FeedbackView · Error State") {
    NavigationStack {
        FeedbackView(
            initialCategory: .suggestion,
            initialBody: "I would love to request an invite code to increase my daily generation quota.",
            initialEmail: "alex@example.com",
            initialErrorMessage: "You're offline. Check your connection and try again."
        )
    }
}
