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

    private let bodyLimit = 1000

    private var trimmedBody: String {
        body_.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSubmit: Bool { !trimmedBody.isEmpty && !isSubmitting }

    private var deviceInfo: String {
        "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                    backRow

                    Text("Send Feedback")
                        .font(AppTheme.Font.pageTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    categoryField
                    detailField
                    emailField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Font.buddy)
                            .foregroundStyle(AppTheme.Color.danger)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    submitButton
                }
                .padding(.top, AppTheme.Space.paddingS)
                .padding(.bottom, AppTheme.Space.paddingScreenBottom)
            }
            .scrollDismissesKeyboard(.interactively)

            if didSucceed { successOverlay }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Fields

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            fieldLabel("What's this about?")
            HStack(spacing: AppTheme.Space.paddingS) {
                ForEach(FeedbackCategory.allCases) { c in
                    categoryChip(c)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func categoryChip(_ c: FeedbackCategory) -> some View {
        let selected = category == c
        return Button {
            category = c
        } label: {
            Text(c.label)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(selected ? AppTheme.Color.textOnChip : AppTheme.Color.textSecondary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(
                    selected ? AppTheme.Color.brandStrong : AppTheme.Color.cardBg,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(selected ? Color.clear : AppTheme.Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var detailField: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            fieldLabel("Details")
            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text("Describe what you experienced, or any feedback…")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.horizontal, AppTheme.Space.paddingCard + 5)
                        .padding(.vertical, AppTheme.Space.paddingCard + 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $body_)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(AppTheme.Space.paddingS)
                    .onChange(of: body_) { _, newValue in
                        if newValue.count > bodyLimit {
                            body_ = String(newValue.prefix(bodyLimit))
                        }
                    }
            }
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .shadow(color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius, x: 0, y: AppTheme.Shadow.cardY)
            .overlay(alignment: .bottomTrailing) {
                Text("\(trimmedBody.count)/\(bodyLimit)")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(AppTheme.Space.paddingS)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            fieldLabel("Email (optional)")
            TextField("you@example.com", text: $email)
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .padding(AppTheme.Space.paddingCard)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .shadow(color: AppTheme.Shadow.cardColor,
                        radius: AppTheme.Shadow.cardRadius, x: 0, y: AppTheme.Shadow.cardY)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            Text("Only used to reply to you — nothing else.")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, AppTheme.Space.paddingPage)
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
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.horizontal, AppTheme.Space.paddingPage)
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

    private func fieldLabel(_ t: String) -> some View {
        Text(t.uppercased())
            .font(AppTheme.Font.groupLabel)
            .tracking(AppTheme.Typography.trackingLabel)
            .foregroundStyle(AppTheme.Color.textMuted)
            .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var successOverlay: some View {
        ZStack {
            AppTheme.Color.scrimOverlay.ignoresSafeArea()
            VStack(spacing: AppTheme.Space.paddingCard) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Text("Thanks — we got it.")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }
            .padding(AppTheme.Space.paddingHero)
            .background(AppTheme.Color.cardBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .shadow(color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius, x: 0, y: AppTheme.Shadow.cardY)
        }
        .transition(.opacity)
    }

    // MARK: - Submit

    private func submit() async {
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
                try? await Task.sleep(for: .seconds(1.1))
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
