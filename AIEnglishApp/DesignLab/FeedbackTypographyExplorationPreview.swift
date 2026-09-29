#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Feedback 排印比例全真画布 (Feedback Typography Canvas)
// =====================================================================
// 🎯 核心原则：
//   1. 拒绝双栏并排挤压（避免折行变形）；
//   2. 100% 原生全屏满宽渲染，所见即所得；
//   3. 底部轻量悬浮胶囊一键原位切换对比（In-Place A/B Toggle）；
//   4. 原生提供独立 Preview，支持 Xcode Canvas 官方多设备对比。

// MARK: - 排印方案枚举

enum FeedbackTypographyOption: String, CaseIterable, Identifiable {
    case option1AboutAI_Light   = "★ 推荐方案 1 (About AI 规范 · 20细 / 15轻)"
    case option2AboutAI_Regular = "方案 2 (About AI 规范 · 20细 / 15实)"
    case baseline               = "原版基线 (线上现状 · 22粗 / 17倒挂)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .option1AboutAI_Light:   return "★ 推荐 (20细/15轻)"
        case .option2AboutAI_Regular: return "方案 2 (20细/15实)"
        case .baseline:               return "原版基线 (17倒挂)"
        }
    }

    var badgeText: String {
        switch self {
        case .option1AboutAI_Light:   return "20pt 细衬线 · 15pt 舒展正文 · 抹平倒挂"
        case .option2AboutAI_Regular: return "20pt 细衬线 · 15pt 饱满正文 · 抹平倒挂"
        case .baseline:               return "22pt 粗衬线 · 17pt 倒挂反超 · 笨重卡屏"
        }
    }

    // ── 1. 顶部大标题 ──
    var introTitleFont: Font {
        switch self {
        case .option1AboutAI_Light, .option2AboutAI_Regular:
            // 与 About AI 刚刚落地的 settingsDocumentTitleSerif 100% 同款：Charter 20pt Regular 细衬线
            return .custom("Charter", size: 20, relativeTo: .title3)
        case .baseline:
            return .custom("Charter-Bold", size: 22, relativeTo: .title2)
        }
    }

    // ── 2. 引导副标题 ──
    var introSubtitleFont: Font {
        switch self {
        case .option1AboutAI_Light:
            return .custom("GothicA1-Light", size: 14.5, relativeTo: .subheadline)
        case .option2AboutAI_Regular:
            return .custom("GothicA1-Regular", size: 14.5, relativeTo: .subheadline)
        case .baseline:
            return .custom("GothicA1-Regular", size: 13, relativeTo: .footnote)
        }
    }

    // ── 3. 表单组标 (Details / Email) ──
    var fieldLabelFont: Font {
        .custom("Charter", size: 15, relativeTo: .subheadline)
    }

    // ── 4. 分类 Chip 胶囊 ──
    var chipFont: Font {
        switch self {
        case .option1AboutAI_Light, .option2AboutAI_Regular:
            return .custom("GothicA1-Medium", size: 14, relativeTo: .subheadline)
        case .baseline:
            return .custom("GothicA1-Regular", size: 15, relativeTo: .subheadline)
        }
    }

    // ── 5. 多行输入正文 & 单行邮箱 ──
    var inputFont: Font {
        switch self {
        case .option1AboutAI_Light:
            // 与 About AI 15pt Light 体系同源：15pt Light 300！
            return .custom("GothicA1-Light", size: 15, relativeTo: .subheadline)
        case .option2AboutAI_Regular:
            return .custom("GothicA1-Regular", size: 15, relativeTo: .subheadline)
        case .baseline:
            return .custom("GothicA1-Regular", size: 17, relativeTo: .body)
        }
    }

    var inputLineSpacing: CGFloat {
        switch self {
        case .option1AboutAI_Light:   return 4.5
        case .option2AboutAI_Regular: return 3.5
        case .baseline:               return 2.5
        }
    }
}

// =====================================================================
// MARK: - 主画板视图 (单屏全真体验 + 底部轻量原位切换器)
// =====================================================================

struct FeedbackTypographyExplorationPreview: View {
    @State private var currentOption: FeedbackTypographyOption = .option1AboutAI_Light

    // 表单状态
    @State private var selectedCategory: FeedbackCategory = .suggestion
    @State private var feedbackText: String = "The AI generated scenes are super helpful, but I noticed the pronunciation playback sometimes pauses abruptly when switching words."
    @State private var emailText: String = "alex.designer@example.com"
    @State private var isSubmitting: Bool = false
    @State private var showSuccessToast: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 全屏原生 Feedback 页面 (100% 满宽满屏，拒绝任何多余外壳和双栏压缩)
            FeedbackScreenView(
                option: currentOption,
                category: $selectedCategory,
                bodyText: $feedbackText,
                emailText: $emailText,
                isSubmitting: $isSubmitting,
                onSubmit: triggerSubmit
            )
            .animation(.easeInOut(duration: 0.22), value: currentOption)

            // 2. 底部悬浮轻量控制器 (Floating In-Place Switcher)
            floatingSwitcher
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 3. 提交成功 Toast
            if showSuccessToast {
                toastNotification
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - 悬浮切换条 (极简毛玻璃药丸)

    private var floatingSwitcher: some View {
        VStack(spacing: 8) {
            // 方案参数指示胶囊
            HStack(spacing: 6) {
                Circle()
                    .fill(currentOption == .baseline ? AppTheme.Color.danger : Color.green)
                    .frame(width: 6, height: 6)

                Text(currentOption.badgeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.85))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)

            // 三项无缝切换 Segment
            HStack(spacing: 4) {
                ForEach(FeedbackTypographyOption.allCases) { opt in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            currentOption = opt
                        }
                    } label: {
                        Text(opt.shortTag)
                            .font(.system(size: 12, weight: currentOption == opt ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background {
                                if currentOption == opt {
                                    Capsule()
                                        .fill(AppTheme.Color.textPrimary)
                                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                                }
                            }
                            .foregroundStyle(currentOption == opt ? Color.white : AppTheme.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color(white: 0.98).opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
        }
    }

    private var toastNotification: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.green)
            Text(FeedbackView.successToastMessage)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.88))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    private func triggerSubmit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSubmitting = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSuccessToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSuccessToast = false
                }
            }
        }
    }
}

// =====================================================================
// MARK: - 100% 全真原生 Feedback 视图 (FeedbackScreenView)
// =====================================================================

struct FeedbackScreenView: View {
    let option: FeedbackTypographyOption
    @Binding var category: FeedbackCategory
    @Binding var bodyText: String
    @Binding var emailText: String
    @Binding var isSubmitting: Bool
    var onSubmit: () -> Void

    @FocusState private var isDetailFocused: Bool
    @FocusState private var isEmailFocused: Bool

    private let bodyLimit = 1000

    private var bodyCountLabel: String {
        "\(bodyText.count)/\(bodyLimit)"
    }

    private var canSubmit: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. 顶栏 (返回键 + 居中 Pinned Title)
                topBarHeader

                // 2. 页面主标题 + 引导副文案
                introTitleSection

                // 3. 分类选项组
                categorySection

                // 4. Details 核心输入卡片 (核心优化点！)
                detailFieldSection

                // 5. Email 选填项
                emailFieldSection

                // 6. 提交按钮
                submitButtonSection

                // 底部为浮动控制器留足呼吸空隙
                Spacer(minLength: 80)
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .onTapGesture {
            isDetailFocused = false
            isEmailFocused = false
        }
    }

    // MARK: - 子视图组件

    private var topBarHeader: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.Color.cardBg.opacity(0.8))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)

            Spacer()

            Text("Feedback")
                .font(AppTheme.Font.settingsPinnedTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, 10)
    }

    private var introTitleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("We'd love your feedback")
                .font(option.introTitleFont)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Share your ideas, report an issue, or request an invite code for extra quota.")
                .font(option.introSubtitleFont)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("What's this about?")
                .font(option.fieldLabelFont)
                .foregroundStyle(AppTheme.Color.textSecondary)

            HStack(spacing: AppTheme.Space.paddingS) {
                ForEach(FeedbackCategory.allCases) { c in
                    categoryChip(c)
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var detailFieldSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            HStack {
                Text("Details")
                    .font(option.fieldLabelFont)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()

                if option == .baseline {
                    Text("17pt 倒挂反超")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.Color.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.danger.opacity(0.08))
                        .clipShape(Capsule())
                } else {
                    Text("15pt 平齐消除倒挂")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
                ZStack(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("Tell us what happened…")
                            .font(option.inputFont)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .padding(.top, 4)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $bodyText)
                        .font(option.inputFont)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .lineSpacing(option.inputLineSpacing)
                        .scrollContentBackground(.hidden)
                        .focused($isDetailFocused)
                        .frame(minHeight: 120)
                }

                Text(bodyCountLabel)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(AppTheme.Space.paddingCard)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .fill(AppTheme.Color.cardBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(isDetailFocused ? AppTheme.Color.inputFocusBorder : AppTheme.Color.border, lineWidth: 0.8)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var emailFieldSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Email (optional)")
                .font(option.fieldLabelFont)
                .foregroundStyle(AppTheme.Color.textSecondary)

            ZStack(alignment: .leading) {
                if emailText.isEmpty {
                    Text(verbatim: "name@example.com")
                        .font(option.inputFont)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                TextField("", text: $emailText)
                    .font(option.inputFont)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .keyboardType(.emailAddress)
                    .focused($isEmailFocused)
            }
            .padding(AppTheme.Space.paddingCard)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .fill(AppTheme.Color.cardBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(isEmailFocused ? AppTheme.Color.inputFocusBorder : AppTheme.Color.border, lineWidth: 0.8)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var submitButtonSection: some View {
        Button(action: onSubmit) {
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
            .shadow(
                color: canSubmit ? AppTheme.Color.interactive.opacity(0.2) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .disabled(!canSubmit)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, 4)
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
                    .font(option.chipFont)
                    .foregroundStyle(selected ? AppTheme.Color.textSecondary : AppTheme.Color.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, 8)
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
        .buttonStyle(.plain)
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
}

// =====================================================================
// MARK: - Xcode Canvas 独立全尺寸预览入口
// =====================================================================

#Preview("★ 推荐方案 1 (About AI 规范 · 20细 / 15轻)") {
    FeedbackScreenView(
        option: .option1AboutAI_Light,
        category: .constant(.suggestion),
        bodyText: .constant("The AI generated scenes are super helpful, but I noticed the pronunciation playback sometimes pauses abruptly when switching words."),
        emailText: .constant("alex.designer@example.com"),
        isSubmitting: .constant(false),
        onSubmit: {}
    )
}

#Preview("原版基线 (线上现状 · 22粗 / 17倒挂)") {
    FeedbackScreenView(
        option: .baseline,
        category: .constant(.suggestion),
        bodyText: .constant("The AI generated scenes are super helpful, but I noticed the pronunciation playback sometimes pauses abruptly when switching words."),
        emailText: .constant("alex.designer@example.com"),
        isSubmitting: .constant(false),
        onSubmit: {}
    )
}

#Preview("📱 交互画板 (含底部切换器)") {
    FeedbackTypographyExplorationPreview()
}
#endif
