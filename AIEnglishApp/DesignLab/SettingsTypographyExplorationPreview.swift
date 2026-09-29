#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Settings 列表行字重与墨色探索 (Light 300 vs ExtraLight 200 极黑)
// =====================================================================
// 🎯 需求演进：
//   - 用户确认认可方案 1（Gothic A1 Light 300 · 17pt · 60u 字干）的方向，要求【保留方案一】；
//   - 进一步要求补充一种【再细一点、然后再黑一点】的排印进行对比：
//     1. 再细一点：下探至 Gothic A1 官方 ExtraLight (200) 档位，字干厚度仅 46 unit（比 Light 300 再细 23.3%）！
//     2. 再黑一点：突破既有 neutral900 (#211811) 的暖灰调，采用「绝对纯黑 #000000」或「极致深焦墨 #0A0705」，
//        以高对比度弥补极细字干的识读力，呈现犹如高定杂志针管笔（Rapidograph）般的精工锐利质感。

enum SettingsTypographyProposal: String, CaseIterable, Identifiable {
    case adopted       = "【采纳落地】ExtraLight 200 · 极致深焦黑 (#0A0705)"
    case baseline      = "原版基线 (Regular 400 · 76u · #211811)"
    case option1Light  = "方案 1 (Light 300 · 60u · #211811)"
    case option2Ultra  = "方案 2 (ExtraLight 200 · 纯黑 #000)"
    case option3Deep   = "方案 3 (ExtraLight 200 · 焦黑 #0A0705)"

    var id: String { rawValue }

    var shortCode: String {
        switch self {
        case .adopted:      return "★ 200 焦黑"
        case .baseline:     return "400 原版"
        case .option1Light: return "300 原色"
        case .option2Ultra: return "200 纯黑"
        case .option3Deep:  return "200 焦黑"
        }
    }

    /// 字体字号 (保持 17pt 不变，专注对比字重与墨色)
    var fontSize: CGFloat {
        17.0
    }

    /// 真实字体对象 (动态加载 GothicA1-Regular / GothicA1-Light / GothicA1-ExtraLight)
    func font(relativeTo style: Font.TextStyle = .body) -> Font {
        switch self {
        case .adopted:
            return AppTheme.Font.settingsRowLabel(legibilityWeight: nil)
        case .baseline:
            return AppTheme.Font.englishBody // GothicA1-Regular 17pt
        case .option1Light:
            return .custom("GothicA1-Light", size: 17.0, relativeTo: style)
        case .option2Ultra, .option3Deep:
            return .custom("GothicA1-ExtraLight", size: 17.0, relativeTo: style)
        }
    }

    /// 辅助数值字体 (Target language: English)
    func valueFont(relativeTo style: Font.TextStyle = .body) -> Font {
        switch self {
        case .adopted:
            return AppTheme.Font.settingsRowLabel(legibilityWeight: nil)
        case .baseline:
            return AppTheme.Font.englishBody
        case .option1Light:
            return .custom("GothicA1-Light", size: 17.0, relativeTo: style)
        case .option2Ultra, .option3Deep:
            return .custom("GothicA1-ExtraLight", size: 17.0, relativeTo: style)
        }
    }

    /// 文字墨水颜色
    var labelColor: Color {
        switch self {
        case .adopted:
            return AppTheme.Color.settingsRowText
        case .baseline, .option1Light:
            return AppTheme.Color.textPrimary // 生产标准炭黑 #211811 (17.2:1)
        case .option2Ultra:
            return Color.black
        case .option3Deep:
            return Color(red: 10.0 / 255.0, green: 7.0 / 255.0, blue: 5.0 / 255.0)
        }
    }

    /// 危险操作行字色 (Delete account)
    var dangerColor: Color {
        AppTheme.Color.danger
    }

    /// 看板技术指标
    var specBadge: String {
        switch self {
        case .adopted:      return "200 ExLight · 46u · #0A0705 ★ 生产"
        case .baseline:     return "400 Reg · 76u · #211811"
        case .option1Light: return "300 Light · 60u · #211811"
        case .option2Ultra: return "200 ExLight · 46u · #000000"
        case .option3Deep:  return "200 ExLight · 46u · #0A0705"
        }
    }

    /// 设计决策推导
    var rationale: String {
        switch self {
        case .adopted:
            return "【当前采纳落地】：ExtraLight 200（字干仅 46u）搭配极致深焦黑 #0A0705。高对比度弥补极细字干的光通量，针管笔精工锐利，告别原版黑块感同时杜绝轻飘！"
        case .baseline:
            return "生产现状：Gothic A1 400 实际骨架 76 unit，相当于西文 Medium，高对比度下显得笨重压抑，产生黑块感。"
        case .option1Light:
            return "【用户保留方案】：官方 Light 300，字干 60 unit（纤细 21%）！完美对应 SF Pro Regular 的标准西文骨架，通透轻盈。"
        case .option2Ultra:
            return "【再细一点 + 纯黑】：字重下探到 ExtraLight 200（字干仅 46u，再细 23%），字色升级为 100% 绝对纯黑 (#000000)。极致锐利，如精工针管笔雕刻，极富现代设计感。"
        case .option3Deep:
            return "【再细一点 + 焦黑】：ExtraLight 200 (46u) 配深焦黑 (#0A0705)，比 200 纯黑多一丝暖调墨润感，同样极致纤细，更贴合暖纸灰底色。"
        }
    }
}

// =====================================================================
// MARK: - 行首 Icon 颜色色阶枚举 (卸重实验)
// =====================================================================

enum SettingsIconColorOption: String, CaseIterable, Identifiable {
    case mutedMatchingChevron = "★ 方案 1: 轻柔中灰 (#7C7773 · 与箭头同色)"
    case softCharcoalMedium   = "方案 2: 适中暖灰 (#635C55 · 舒适过渡)"
    case currentSecondary     = "当前现状: 偏深暖灰 (#4B4640 · 显重)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .mutedMatchingChevron: return "★ 同箭头灰 #7C7773"
        case .softCharcoalMedium:   return "适中暖灰 #635C55"
        case .currentSecondary:     return "当前深灰 #4B4640"
        }
    }

    var color: Color {
        switch self {
        case .mutedMatchingChevron:
            return AppTheme.Color.textMuted // #7C7773 (4.4:1)
        case .softCharcoalMedium:
            return Color(red: 99.0 / 255.0, green: 92.0 / 255.0, blue: 85.0 / 255.0) // #635C55 (6.5:1)
        case .currentSecondary:
            return AppTheme.Color.textSecondary // #4B4640 (9.9:1)
        }
    }

    var explanation: String {
        switch self {
        case .mutedMatchingChevron:
            return "【强烈推荐】：图标与右侧展开箭头同色（#7C7773）。图标彻底卸下深色块的压迫感，轻柔通透，把视觉焦点 100% 还给中间的 200 焦黑文字！"
        case .softCharcoalMedium:
            return "【平衡过渡】：比当前深灰退后半步（#635C55），消除黑块重感，同时比箭头略深一点点，保留轻微的前后层次。"
        case .currentSecondary:
            return "【当前现状】：深灰 9.9:1（#4B4640），在 200 极细文字面前显得色块面积偏大偏重，形成压迫感。"
        }
    }
}

// =====================================================================
// MARK: - 右上角关闭按钮底纹样式枚举 (卸重实验)
// =====================================================================

enum SettingsCloseButtonStyle: String, CaseIterable, Identifiable {
    case pillMicroShadow = "★ 方案 A: 顶栏精细微阴影 (单层利落)"
    case flatBorder      = "方案 B: 纯平微边框 (无阴影)"
    case flatClean       = "方案 C: 纯平无边框 (极简浮纸)"
    case baselineHeavy   = "现状对照: 16pt大阴影 (双底纹重感)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .pillMicroShadow: return "★ 方案A(精细微阴)"
        case .flatBorder:      return "方案B(纯平微边)"
        case .flatClean:       return "方案C(纯平无边)"
        case .baselineHeavy:   return "现状(16pt大阴影)"
        }
    }

    var explanation: String {
        switch self {
        case .pillMicroShadow:
            return "【强烈推荐 · 方案 A】：采用顶栏专属贴地微阴影（blur 3 / y 1 / 4%）+ 0.5pt 发丝微边。彻底移除 16pt 漫反射外圈灰晕，轮廓利落，单层立住！"
        case .flatBorder:
            return "【纯粹无阴影 · 方案 B】：彻底去掉 shadow，仅靠 0.5pt 浅灰边框与暖白底色立出边界，绝无第二层底纹。"
        case .flatClean:
            return "【极简温润 · 方案 C】：无阴影且无边框，纯粹是 #FFFDFB 暖白圆面浮在暖纸底上。"
        case .baselineHeavy:
            return "【现状病灶 · 对照组】：44pt 小圆套了 16pt 卡片大阴影，在浅底上晕出一大圈弥散灰色，视觉上被误判为双层底纹。"
        }
    }
}

// =====================================================================
// MARK: - 生产级页面复印件 (SettingsReplicaScreen)
// =====================================================================

struct SettingsReplicaScreen: View {
    let proposal: SettingsTypographyProposal
    var iconColorOption: SettingsIconColorOption = .mutedMatchingChevron
    var closeButtonStyle: SettingsCloseButtonStyle = .pillMicroShadow
    var onDismiss: (() -> Void)? = nil

    @State private var showAboutAI = false
    @State private var showFeedback = false
    @State private var showDeleteAlert = false
    @State private var feedbackToast: String? = nil

    init(
        proposal: SettingsTypographyProposal,
        iconColorOption: SettingsIconColorOption = .mutedMatchingChevron,
        closeButtonStyle: SettingsCloseButtonStyle = .pillMicroShadow,
        onDismiss: (() -> Void)? = nil
    ) {
        self.proposal = proposal
        self.iconColorOption = iconColorOption
        self.closeButtonStyle = closeButtonStyle
        self.onDismiss = onDismiss
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        NavigationStack {
            SettingsScreen(
                pinnedTitle: "Settings",
                bottomPadding: AppTheme.Space.pageFooterBottom
            ) {
                languageCard
                legalCard
                supportCard
                accountCard
                developerCard
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
        }
        .appToast(
            message: $feedbackToast,
            systemImage: "paperplane.fill",
            semantic: .positive,
            placement: .bottom
        )
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                LabCircleButton(kind: .close, style: closeButtonStyle) {
                    onDismiss?()
                }
                .padding(.trailing, AppTheme.Space.paddingPage)
            }
            .padding(.top, AppTheme.Space.titleToContent)
        }
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, expressions, and progress. This action cannot be undone.")
        }
    }

    private var languageCard: some View {
        SettingsCard("My language") {
            ReplicaInfoRow(
                icon: .targetLanguage,
                label: "Target language",
                value: "English",
                proposal: proposal,
                iconTint: iconColorOption.color
            )
            SettingsRowDivider()
            ReplicaInfoRow(
                icon: .nativeLanguage,
                label: "Native language",
                value: "Chinese",
                proposal: proposal,
                iconTint: iconColorOption.color
            )
        }
    }

    private var legalCard: some View {
        SettingsCard("Legal") {
            ReplicaActionRow(
                icon: .aiData,
                label: "How AI uses your data",
                proposal: proposal,
                iconTint: iconColorOption.color
            ) {
                showAboutAI = true
            }
            SettingsRowDivider()
            ReplicaActionRow(
                icon: .privacy,
                label: "Privacy Policy",
                proposal: proposal,
                iconTint: iconColorOption.color
            ) {}
            SettingsRowDivider()
            ReplicaActionRow(
                icon: .terms,
                label: "Terms of Service",
                proposal: proposal,
                iconTint: iconColorOption.color
            ) {}
        }
    }

    private var supportCard: some View {
        SettingsCard("Support") {
            ReplicaActionRow(
                icon: .feedback,
                label: "Send feedback",
                proposal: proposal,
                iconTint: iconColorOption.color
            ) {
                showFeedback = true
            }
        }
    }

    private var accountCard: some View {
        SettingsCard("Account") {
            ReplicaActionRow(
                icon: .delete,
                label: "Delete account",
                proposal: proposal,
                iconTint: iconColorOption.color,
                isDanger: true,
                showsChevron: false
            ) {
                showDeleteAlert = true
            }
        }
    }

    private var developerCard: some View {
        SettingsCard("Developer") {
            ReplicaActionRow(
                icon: .reset,
                label: "Reset Library unlock",
                proposal: proposal,
                iconTint: iconColorOption.color,
                showsChevron: false
            ) {}
        }
    }

    private var versionFooter: some View {
        Text("Version 1.0 (Build 1)")
            .font(AppTheme.Font.settingsVersion)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, AppTheme.Space.pageFooterTop - AppTheme.Space.paddingSection)
    }
}

private struct ReplicaActionRow: View {
    let icon: SettingsRowIcon
    let label: String
    let proposal: SettingsTypographyProposal
    var iconTint: Color = AppTheme.Color.settingsRowIconTint
    var isDanger: Bool = false
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingCard) {
                SettingsRowIconView(
                    icon: icon,
                    tint: isDanger ? proposal.dangerColor : iconTint
                )

                Text(label)
                    .font(proposal.font())
                    .foregroundStyle(isDanger ? proposal.dangerColor : proposal.labelColor)

                Spacer()

                if showsChevron {
                    SettingsChevronReplica()
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowSurface)
    }
}

private struct ReplicaInfoRow: View {
    let icon: SettingsRowIcon
    let label: String
    let value: String
    let proposal: SettingsTypographyProposal
    var iconTint: Color = AppTheme.Color.settingsRowIconTint

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(alignment: isStacked ? .top : .center, spacing: AppTheme.Space.paddingCard) {
            SettingsRowIconView(icon: icon, tint: iconTint)

            if isStacked {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(proposal.font())
                        .foregroundStyle(proposal.labelColor)
                    Text(value)
                        .font(proposal.valueFont())
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            } else {
                HStack {
                    Text(label)
                        .font(proposal.font())
                        .foregroundStyle(proposal.labelColor)
                    Spacer()
                    Text(value)
                        .font(proposal.valueFont())
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingCard)
    }
}

private struct SettingsChevronReplica: View {
    @ScaledMetric(relativeTo: .body) private var glyph = AppTheme.Size.settingsChevronGlyph

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
                with: .color(AppTheme.Color.textMuted),
                style: StrokeStyle(lineWidth: AppTheme.Size.settingsChevronStroke, lineCap: .round)
            )
        }
        .frame(width: glyph, height: glyph)
        .accessibilityHidden(true)
    }
}

// =====================================================================
// MARK: - 实验室专属圆形关闭按钮组件 (支持底盘卸重模式)
// =====================================================================

private struct LabCircleButton: View {
    let kind: SettingsCircleButton.Kind
    let style: SettingsCloseButtonStyle
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var side = AppTheme.Size.barControl

    var body: some View {
        Button(action: action) {
            Image(systemName: kind.systemImage)
                .font(kind.font)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: side, height: side)
                .background {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                }
                .overlay {
                    if style == .flatBorder || style == .pillMicroShadow || style == .baselineHeavy {
                        Circle()
                            .strokeBorder(
                                AppTheme.Color.border.opacity(style == .flatBorder ? 0.75 : 0.45),
                                lineWidth: 0.5
                            )
                    }
                }
                .modifier(CloseButtonShadowModifier(style: style))
        }
        .buttonStyle(.iconControl)
        .accessibilityLabel(kind.accessibilityLabel)
    }
}

private struct CloseButtonShadowModifier: ViewModifier {
    let style: SettingsCloseButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .pillMicroShadow:
            content
                .shadow(
                    color: AppTheme.Shadow.pillContactColor,
                    radius: AppTheme.Shadow.pillContactRadius,
                    x: 0,
                    y: 1
                )
        case .flatBorder, .flatClean:
            content // 彻底零阴影，纯粹纸平面
        case .baselineHeavy:
            content
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius / 2, // 16pt 漫反射
                    x: 0,
                    y: AppTheme.Shadow.cardY / 2          // 6pt 下移
                )
        }
    }
}

// =====================================================================
// MARK: - 交互式对比实验室 (SettingsTypographyInteractiveLab)
// =====================================================================

struct SettingsTypographyInteractiveLab: View {
    @State private var selectedProposal: SettingsTypographyProposal = .adopted
    @State private var selectedIconColor: SettingsIconColorOption = .mutedMatchingChevron
    @State private var selectedCloseBtnStyle: SettingsCloseButtonStyle = .pillMicroShadow

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部交互控制台
            VStack(spacing: 7) {
                // 1. 排印字重切换胶囊
                HStack(spacing: 5) {
                    ForEach(SettingsTypographyProposal.allCases) { p in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedProposal = p
                            }
                        } label: {
                            Text(p.shortCode)
                                .font(.system(size: 11, weight: selectedProposal == p ? .semibold : .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedProposal == p
                                        ? AppTheme.Color.textPrimary
                                        : AppTheme.Color.cardBg
                                )
                                .foregroundStyle(
                                    selectedProposal == p
                                        ? AppTheme.Color.textOnChip
                                        : AppTheme.Color.textSecondary
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedProposal == p ? Color.clear : AppTheme.Color.border, lineWidth: 0.6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 7)

                // 2. ★ 行首图标颜色卸重切换
                HStack(spacing: 5) {
                    Text("行首Icon:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    ForEach(SettingsIconColorOption.allCases) { opt in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedIconColor = opt
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Circle().fill(opt.color).frame(width: 7, height: 7)
                                Text(opt.shortTag)
                                    .font(.system(size: 10.5, weight: selectedIconColor == opt ? .semibold : .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(selectedIconColor == opt ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                            .foregroundStyle(selectedIconColor == opt ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedIconColor == opt ? AppTheme.Color.brandTint : AppTheme.Color.border, lineWidth: 0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 3. ★ 右上角关闭按钮底盘切换 (本次专项实验)
                HStack(spacing: 5) {
                    Text("关闭底纹:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    ForEach(SettingsCloseButtonStyle.allCases) { style in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedCloseBtnStyle = style
                            }
                        } label: {
                            Text(style.shortTag)
                                .font(.system(size: 10.5, weight: selectedCloseBtnStyle == style ? .semibold : .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(selectedCloseBtnStyle == style ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                .foregroundStyle(selectedCloseBtnStyle == style ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selectedCloseBtnStyle == style ? AppTheme.Color.brandTint : AppTheme.Color.border, lineWidth: 0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 4. 当前配置状态看板
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(selectedProposal.shortCode + " · " + selectedIconColor.shortTag + " · " + selectedCloseBtnStyle.shortTag)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Spacer()
                    }

                    Text(selectedCloseBtnStyle.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(1.5)
                }
                .padding(9)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, 6)
            }
            .background(AppTheme.Color.pageBg)

            Divider().opacity(0.18)

            // 下方呈现真实的生产复印件页面
            SettingsReplicaScreen(
                proposal: selectedProposal,
                iconColorOption: selectedIconColor,
                closeButtonStyle: selectedCloseBtnStyle
            )
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }
}

// =====================================================================
// MARK: - 全景并排大画板 (SettingsTypographySideBySidePanorama)
// =====================================================================

struct SettingsTypographySideBySidePanorama: View {
    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 24) {
                ForEach(SettingsTypographyProposal.allCases) { proposal in
                    VStack(alignment: .leading, spacing: 10) {
                        // 标头卡
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(proposal.rawValue)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                Spacer()
                                Text(proposal.specBadge)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppTheme.Color.brandInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.Color.brandWash, in: RoundedRectangle(cornerRadius: 4))
                            }

                            Text(proposal.rationale)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(width: 375)
                        .background(AppTheme.Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.Color.border, lineWidth: 0.6)
                        )

                        // 375pt 原生宽度模拟手机屏
                        SettingsReplicaScreen(proposal: proposal)
                            .frame(width: 375, height: 780)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(white: 0.93).ignoresSafeArea())
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("00 · ★ 全功能实验室 (排印·图色·关闭键一体切换)") {
    SettingsTypographyInteractiveLab()
}

#Preview("00-1 · 方案 A (★ 推荐 · 顶栏精细微阴影 · 单层干净 · 满屏)") {
    SettingsReplicaScreen(proposal: .adopted, iconColorOption: .mutedMatchingChevron, closeButtonStyle: .pillMicroShadow)
}

#Preview("00-2 · 方案 B (纯平微边框 · 纯粹无阴影 · 满屏)") {
    SettingsReplicaScreen(proposal: .adopted, iconColorOption: .mutedMatchingChevron, closeButtonStyle: .flatBorder)
}

#Preview("00-3 · 方案 C (纯平无边框 · 极简浮纸 · 满屏)") {
    SettingsReplicaScreen(proposal: .adopted, iconColorOption: .mutedMatchingChevron, closeButtonStyle: .flatClean)
}

#Preview("00-4 · 现状对照 (16pt大阴影 · 双底纹重感 · 满屏)") {
    SettingsReplicaScreen(proposal: .adopted, iconColorOption: .mutedMatchingChevron, closeButtonStyle: .baselineHeavy)
}

#Preview("01 · 方案 1 (保留方案 · Light 300 · 60u · #211811)") {
    SettingsReplicaScreen(proposal: .option1Light)
}

#Preview("02 · 方案 2 (再细一点再黑一点 · ExtraLight 200 · 纯黑 #000)") {
    SettingsReplicaScreen(proposal: .option2Ultra)
}

#Preview("03 · 方案 3 (再细再黑 · ExtraLight 200 · 焦黑 #0A0705)") {
    SettingsReplicaScreen(proposal: .option3Deep)
}

#Preview("04 · 对照组：原版生产 (Regular 400 · 76u · #211811)") {
    SettingsReplicaScreen(proposal: .baseline)
}

#Preview("05 · 并排走廊 (Side-by-Side Panorama)", traits: .landscapeLeft) {
    SettingsTypographySideBySidePanorama()
}

#endif
