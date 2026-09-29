#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - About AI & Feedback 排印比例探索实验室 (Subpages Typography Lab)
// =====================================================================
// 🎯 核心目标：
//   针对用户提出的「About AI 和 Feedback 页面的标题和正文的字体大小以及比例都有问题」：
//   - 生产基线：主标题 22pt vs 正文 17pt（落差仅 1.29:1，正文笨重如黑墙，字段标 15pt 反被 17pt 输入正文倒挂）；
//   - 方案 A（高定编辑杂志风 · 推荐）：主标题拉大至 28pt，正文降至舒适阅读的 15pt，落差达到黄金 1.87:1，层级从容优雅；
//   - 方案 B（轻盈极简功能风）：主标题保持 22pt，正文与输入框果断压减至 14pt，微缩紧凑，极致克制。

// MARK: - 排印方案枚举

enum SubpageTypographyMode: String, CaseIterable, Identifiable {
    case baseline           = "原版基线 (22pt Bold / 17pt 倒挂)"
    case proposalA          = "方案 A · 高定大标 (28pt Bold / 15pt)"
    case proposalC1_Bold    = "★ 方案 C1+ · 紧凑加粗标 (20pt Bold 粗衬线 / 15pt)"
    case proposalC1_Regular = "方案 C1 · 雅致轻标 (20pt Regular 细衬线 / 15pt)"
    case proposalSmallMicro = "方案 C2 · 微缩克制标 (18pt Bold / 14pt)"
    case proposalB          = "方案 B · 轻盈极简 (22pt Bold / 14pt)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .baseline:           return "原版基线"
        case .proposalA:          return "方案A (28大)"
        case .proposalC1_Regular: return "★ C1(20细·落地)"
        case .proposalC1_Bold:    return "C1+ (20粗)"
        case .proposalSmallMicro: return "C2 (18微)"
        case .proposalB:          return "方案B (22)"
        }
    }

    // ── 1. 页面大标题 ──
    var pageTitleFont: Font {
        switch self {
        case .baseline:
            return .custom("Charter-Bold", size: 22, relativeTo: .title2)
        case .proposalA:
            return .custom("Charter-Bold", size: 28, relativeTo: .largeTitle)
        case .proposalC1_Bold:
            // 往小调 + 加粗：20pt Bold 粗衬线
            return .custom("Charter-Bold", size: 20, relativeTo: .title3)
        case .proposalC1_Regular:
            // 往小调 + 细体：20pt Regular 细衬线
            return .custom("Charter", size: 20, relativeTo: .title3)
        case .proposalSmallMicro:
            return .custom("Charter-Bold", size: 18, relativeTo: .headline)
        case .proposalB:
            return .custom("Charter-Bold", size: 22, relativeTo: .title2)
        }
    }
    var pageTitleSizeDesc: String {
        switch self {
        case .baseline:           return "Charter 22pt · Bold (700)"
        case .proposalA:          return "Charter 28pt · Bold (700) 大气破局"
        case .proposalC1_Bold:    return "Charter 20pt · Bold (700) ★ 紧凑加粗标"
        case .proposalC1_Regular: return "Charter 20pt · Regular (400) 细衬线雅致书香"
        case .proposalSmallMicro: return "Charter 18pt · Bold (700) 微缩克制"
        case .proposalB:          return "Charter 22pt · Bold (700)"
        }
    }

    // ── 2. About AI 长正文 ──
    var aboutAIBodyFont: Font {
        switch self {
        case .baseline:
            return .custom("GothicA1-Regular", size: 17, relativeTo: .body)
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return .custom("GothicA1-Light", size: 15, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Regular", size: 14, relativeTo: .footnote)
        }
    }
    var aboutAIBodySizeDesc: String {
        switch self {
        case .baseline:           return "Gothic A1 17pt · Regular 400 (76u 粗重方块)"
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return "Gothic A1 15pt · Light 300 (60u 舒适书籍阅读)"
        case .proposalSmallMicro, .proposalB:
            return "Gothic A1 14pt · Regular 400 (精炼微缩说明)"
        }
    }

    var aboutAIBodyLineSpacing: CGFloat {
        switch self {
        case .baseline:           return 4.0
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return 6.0
        case .proposalSmallMicro, .proposalB:
            return 3.5
        }
    }

    // ── 3. About AI 外链文字 ──
    var aboutAILinkFont: Font {
        switch self {
        case .baseline:
            return .custom("GothicA1-Regular", size: 17, relativeTo: .body)
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return .custom("GothicA1-Medium", size: 15, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Medium", size: 14, relativeTo: .footnote)
        }
    }

    // ── 4. Feedback 引导副标题 ──
    var feedbackSubheadFont: Font {
        switch self {
        case .baseline:
            return .custom("GothicA1-Regular", size: 13, relativeTo: .footnote)
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return .custom("GothicA1-Regular", size: 14.5, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Regular", size: 13, relativeTo: .footnote)
        }
    }
    var feedbackSubheadDesc: String {
        switch self {
        case .baseline:           return "13pt (比组标还小，断层严重)"
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return "14.5pt (主副承接自然，清晰开朗)"
        case .proposalSmallMicro, .proposalB:
            return "13pt (轻描淡写)"
        }
    }

    // ── 5. Feedback 表单组标题 ──
    var feedbackFieldLabelFont: Font {
        switch self {
        case .baseline, .proposalA, .proposalC1_Bold:
            return .custom("Charter", size: 15, relativeTo: .subheadline)
        case .proposalC1_Regular:
            return .custom("Charter", size: 14.5, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Medium", size: 13, relativeTo: .caption)
        }
    }
    var feedbackFieldLabelDesc: String {
        switch self {
        case .baseline:           return "Charter 15pt · Regular (被 17pt 逆向压制)"
        case .proposalA, .proposalC1_Bold:
            return "Charter 15pt · Regular (与 15pt 输入平齐呼应)"
        case .proposalC1_Regular: return "Charter 14.5pt · Regular (雅致平稳)"
        case .proposalSmallMicro, .proposalB:
            return "Gothic A1 13pt · Medium (紧凑小分组标)"
        }
    }

    // ── 6. Feedback 分类 Chip ──
    var feedbackChipFont: Font {
        switch self {
        case .baseline:
            return .custom("GothicA1-Regular", size: 15, relativeTo: .subheadline)
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return .custom("GothicA1-Medium", size: 14, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Regular", size: 13.5, relativeTo: .footnote)
        }
    }

    // ── 7. Feedback 输入框文字 & 占位符 ──
    var feedbackInputFont: Font {
        switch self {
        case .baseline:
            return .custom("GothicA1-Regular", size: 17, relativeTo: .body)
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return .custom("GothicA1-Regular", size: 15, relativeTo: .subheadline)
        case .proposalSmallMicro, .proposalB:
            return .custom("GothicA1-Regular", size: 14, relativeTo: .footnote)
        }
    }
    var feedbackInputDesc: String {
        switch self {
        case .baseline:           return "17pt (粗笨、写两行就挤爆)"
        case .proposalA, .proposalC1_Bold, .proposalC1_Regular:
            return "15pt (工整克制、多行输入从容)"
        case .proposalSmallMicro, .proposalB:
            return "14pt (微小紧凑)"
        }
    }

    // ── 核心比例指标 ──
    var ratioBadge: String {
        switch self {
        case .baseline:           return "落差 1.29:1 (严重扁平互抢)"
        case .proposalA:          return "黄金落差 1.87:1 (主从分明)"
        case .proposalC1_Bold:    return "经典级差 1.33:1 (20pt Bold · 紧凑有力★)"
        case .proposalC1_Regular: return "文人比例 1.33:1 (20pt 细衬线 · 极温润)"
        case .proposalSmallMicro: return "微缩比例 1.28:1 (18pt 纯粹系统附录)"
        case .proposalB:          return "落差 1.57:1 (功能紧凑)"
        }
    }

    var critiqueNotes: String {
        switch self {
        case .baseline:
            return "【病灶现状】主标题 22pt 太小撑不住，正文 17pt 粗笨像黑块墙。Feedback 中父级标题 15pt 反被 17pt 输入文字倒挂，视线忽大忽小上下颠簸。"
        case .proposalA:
            return "【高定大标】主标题拉大到 28pt Bold 一锤定音，正文 15pt 舒展呼吸，气场最强，形成绝对的展示性焦点。"
        case .proposalC1_Bold:
            return "【往小调·加粗标★】主标题收至 20pt 并保留 Charter Bold 粗体！既解决 28pt 偏大问题，又具备明确的主张与清晰度，与 15pt 正文形成 1.33:1 经典级差！"
        case .proposalC1_Regular:
            return "【当前生产落地】字号 20pt 且使用 Regular 400 细衬线，正文配 15pt Light 300！黑度温润安静，像经典书籍正文题记，极富书卷气。"
        case .proposalSmallMicro:
            return "【往小调·微缩克制】字号下探至 18pt，正文配 14pt，页面整体变为微型纯附录，极度安静无感，像系统法律声明。"
        case .proposalB:
            return "【极简功能风格】主标题保 22pt，正文与输入全部压缩至 14pt，整体致密收敛，类似系统高级设置风格。"
        }
    }
}

// MARK: - 主交互实验室视窗

struct SubpagesTypographyExplorationPreview: View {
    @State private var selectedMode: SubpageTypographyMode = .proposalC1_Regular
    @State private var selectedTab: Int = 0 // 0: About AI, 1: Feedback, 2: 方案横评看板

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部控制中枢
                controlConsole

                Divider().opacity(0.15)

                // 核心预览视口
                TabView(selection: $selectedTab) {
                    // Tab 0: About AI 披露页真机复刻
                    AboutAIReplicaScreen(mode: selectedMode)
                        .tag(0)

                    // Tab 1: Feedback 反馈表单页真机复刻
                    FeedbackReplicaScreen(mode: selectedMode)
                        .tag(1)

                    // Tab 2: 方案全景横向深度对比看板
                    TypographyMatrixAuditScreen(currentMode: selectedMode)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(AppTheme.Color.pageBg)
            .navigationTitle("排印与比例优化实验室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(selectedMode.ratioBadge)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Color.brandWash)
                        .foregroundStyle(AppTheme.Color.brandInk)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - 控制中枢 (Console)

    private var controlConsole: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            // 1. 页面选择切换
            Picker("页面视窗", selection: $selectedTab) {
                Text("01 · About AI 披露页").tag(0)
                Text("02 · Feedback 表单页").tag(1)
                Text("03 · 深度对比看板").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingS)

            // 2. 排印方案即时切换胶囊
            HStack(spacing: 6) {
                ForEach(SubpageTypographyMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedMode = mode
                        }
                    } label: {
                        Text(mode.shortName)
                            .font(.system(size: 11.5, weight: selectedMode == mode ? .semibold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedMode == mode
                                    ? AppTheme.Color.textPrimary
                                    : AppTheme.Color.cardBg
                            )
                            .foregroundStyle(
                                selectedMode == mode
                                    ? AppTheme.Color.textOnChip
                                    : AppTheme.Color.textSecondary
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedMode == mode ? Color.clear : AppTheme.Color.border, lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 3. 当前方案核心诊断与点评提示
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: selectedMode == .proposalA ? "sparkles" : (selectedMode == .baseline ? "exclamationmark.triangle.fill" : "slider.horizontal.3"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedMode == .proposalA ? AppTheme.Color.brandInk : (selectedMode == .baseline ? Color.orange : AppTheme.Color.textSecondary))

                    Text(selectedMode.rawValue)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Text(selectedMode.critiqueNotes)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingS)
        }
        .background(AppTheme.Color.cardBg.opacity(0.85))
    }
}

// =====================================================================
// MARK: - 01 · About AI 披露页真机复刻 (AboutAIReplicaScreen)
// =====================================================================

struct AboutAIReplicaScreen: View {
    let mode: SubpageTypographyMode
    @State private var safariURL: String?

    var body: some View {
        SettingsScreen(onBack: {}, pinnedTitle: "Personal data") {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                // 页面主标题
                Text(AboutAIView.title)
                    .font(mode.pageTitleFont)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .animation(.easeInOut(duration: 0.2), value: mode)

                // 两大段披露正文
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Poplex creates your English learning content using AI (Google Gemini), based on the text and images you provide. This content is generated automatically and may be inaccurate or inappropriate — it's for learning reference only, not professional advice.")

                    Text("To generate content, the text and photos you provide are sent to Google Gemini for processing. We don't collect your real identity or use your data for ads. You can delete all your data anytime in Settings.")
                }
                .font(mode.aboutAIBodyFont)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(mode.aboutAIBodyLineSpacing)
                .animation(.easeInOut(duration: 0.2), value: mode)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 外链部分
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                linkRow("Privacy Policy")
                linkRow("Terms of Service")
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 附带该屏参数标尺
            specsBanner(
                title: "About AI 画面排印度量",
                items: [
                    ("主标题", mode.pageTitleSizeDesc),
                    ("正文文字", mode.aboutAIBodySizeDesc),
                    ("行距/透气度", "\(mode.aboutAIBodyLineSpacing)pt (舒朗通透)"),
                    ("字号落差比", mode.ratioBadge)
                ]
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingSection)
        }
    }

    private func linkRow(_ label: String) -> some View {
        Button(action: {}) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Text(label)
                    .font(mode.aboutAILinkFont)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Image(systemName: "arrow.up.right")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func specsBanner(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.Color.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Spacer()
                        Text(item.1)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Color.border, lineWidth: 0.6))
        }
    }
}

// =====================================================================
// MARK: - 02 · Feedback 表单页真机复刻 (FeedbackReplicaScreen)
// =====================================================================

struct FeedbackReplicaScreen: View {
    let mode: SubpageTypographyMode

    @State private var category: FeedbackCategory = .suggestion
    @State private var body_: String = "When I entered a longer phrase in Tab1, the card took a while to load and the font weight felt quite thick."
    @State private var email: String = "design@poplex.app"
    @FocusState private var isDetailFocused: Bool

    var body: some View {
        SettingsScreen(onBack: {}, pinnedTitle: "Feedback", dismissesKeyboardOnScroll: true) {
            // 1. 引导 Header
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text("We'd love your feedback")
                    .font(mode.pageTitleFont)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .animation(.easeInOut(duration: 0.2), value: mode)

                Text("Share your ideas, report an issue, or request an invite code for extra quota.")
                    .font(mode.feedbackSubheadFont)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(3)
                    .animation(.easeInOut(duration: 0.2), value: mode)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 2. 类型单选
            formSection("What's this about?") {
                HStack(spacing: AppTheme.Space.paddingS) {
                    ForEach(FeedbackCategory.allCases) { c in
                        categoryChip(c)
                    }
                }
            }

            // 3. 详情输入框
            formSection("Details") {
                VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
                    ZStack(alignment: .topLeading) {
                        if body_.isEmpty {
                            Text("Tell us what happened…")
                                .font(mode.feedbackInputFont)
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        TextField("", text: $body_, axis: .vertical)
                            .font(mode.feedbackInputFont)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .lineLimit(4...7)
                            .focused($isDetailFocused)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)

                    Text("\(body_.count)/1,000")
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

            // 4. 邮箱输入框
            formSection("Email (optional)") {
                TextField("name@example.com", text: $email)
                    .font(mode.feedbackInputFont)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(AppTheme.Space.paddingCard)
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                            .fill(AppTheme.Color.cardBg)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                            .stroke(AppTheme.Color.border, lineWidth: 0.8)
                    }
                    .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
            }

            // 5. 提交按钮
            Button(action: {}) {
                HStack(spacing: AppTheme.Space.paddingS) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Send feedback")
                        .font(AppTheme.Font.ctaLabel)
                }
                .foregroundStyle(AppTheme.Color.textOnChip)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.Color.interactive, in: Capsule())
                .shadow(color: AppTheme.Color.textPrimary.opacity(0.16), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 4)

            // 附带该屏参数标尺
            specsBanner(
                title: "Feedback 表单排印度量",
                items: [
                    ("主标题", mode.pageTitleSizeDesc),
                    ("副标题引导", mode.feedbackSubheadDesc),
                    ("分组标题", mode.feedbackFieldLabelDesc),
                    ("输入框正文", mode.feedbackInputDesc)
                ]
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingSection)
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(title)
                .font(mode.feedbackFieldLabelFont)
                .foregroundStyle(AppTheme.Color.textSecondary)

            content()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func categoryChip(_ c: FeedbackCategory) -> some View {
        let isSelected = category == c
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                category = c
            }
        } label: {
            HStack(spacing: 5) {
                if c == .suggestion {
                    Image(systemName: "lightbulb").font(.system(size: 11))
                } else if c == .bug {
                    MinimalistBugIcon()
                } else {
                    Image(systemName: "ellipsis").font(.system(size: 11))
                }

                Text(c.label)
                    .font(mode.feedbackChipFont)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppTheme.Color.textSecondary : AppTheme.Color.textMuted)
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
            }
            .overlay {
                Capsule()
                    .stroke(isSelected ? AppTheme.Color.brandTint : AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
            }
            .shadow(color: AppTheme.Shadow.pillAmbientColor, radius: isSelected ? 4 : 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func specsBanner(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.Color.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Spacer()
                        Text(item.1)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Color.border, lineWidth: 0.6))
        }
    }
}

// =====================================================================
// MARK: - 03 · 深度对比看板 (TypographyMatrixAuditScreen)
// =====================================================================

struct TypographyMatrixAuditScreen: View {
    let currentMode: SubpageTypographyMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                // 导读说明
                VStack(alignment: .leading, spacing: 4) {
                    Text("About AI & Feedback 排印矩阵审计")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("微观对比三套方案的落差比、字符容积与层级流向，找出最契合 Warm Editorial 的解法。")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingPage)

                // 核心横向方案卡片
                ForEach(SubpageTypographyMode.allCases) { mode in
                    modeAuditCard(mode: mode, isCurrent: currentMode == mode)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
            .padding(.bottom, 60)
        }
    }

    private func modeAuditCard(mode: SubpageTypographyMode, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 卡片顶栏
            HStack {
                Text(mode.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                if isCurrent {
                    Text("当前视窗激活")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.Color.brandStrong)
                        .foregroundStyle(Color.white)
                        .clipShape(Capsule())
                }
            }

            Text(mode.critiqueNotes)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Color.textSecondary)

            Divider().opacity(0.12)

            // 排印标尺微型阶梯展示
            VStack(alignment: .leading, spacing: 8) {
                // 1. 标题预览
                HStack(alignment: .firstTextBaseline) {
                    Text("标题标本")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: 60, alignment: .leading)

                    Text("How AI uses your data")
                        .font(mode.pageTitleFont)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .lineLimit(1)
                }

                // 2. 正文标本
                HStack(alignment: .top) {
                    Text("正文标本")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: 60, alignment: .leading)
                        .padding(.top, 2)

                    Text("Poplex creates your English learning content using AI (Google Gemini), based on the text and images you provide...")
                        .font(mode.aboutAIBodyFont)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(mode.aboutAIBodyLineSpacing)
                }

                // 3. Feedback 输入框标本
                HStack(alignment: .firstTextBaseline) {
                    Text("输入标本")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: 60, alignment: .leading)

                    HStack(spacing: 8) {
                        Text("Details (15pt)")
                            .font(mode.feedbackFieldLabelFont)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Color.textMuted)
                        Text("Tell us what happened…")
                            .font(mode.feedbackInputFont)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }
                }
            }
            .padding(12)
            .background(AppTheme.Color.pageBg.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 底部指标条
            HStack {
                Text("落差比：\(mode.ratioBadge)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mode == .proposalA ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)

                Spacer()

                Text(mode == .proposalA ? "★ 推荐方案" : "")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(isCurrent ? AppTheme.Color.brandStrong.opacity(0.5) : AppTheme.Color.border, lineWidth: isCurrent ? 1.5 : 0.8)
        )
        .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
    }
}

// MARK: - 预览注入

#Preview("About AI & Feedback 排印实验室") {
    SubpagesTypographyExplorationPreview()
}
#endif
