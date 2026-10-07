#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 02 达标态（额度已用尽）轻量化与去重感优化方案沙箱
// =====================================================================
// 🎯 背景与设计痛点剖析：
//   用户反馈在 02 状态（5/5 额度已达标）时，底部区域“感觉有点重”：
//   1. 视觉黑块过重：原先的 48pt 实心焦黑胶囊 (interactive #0A0705) 位于暖纸底 (#FAF8F5) 上，
//      在仅有 375pt 的半屏 sheet 底部形成了巨大的视觉下沉块，宛如支付强阻断弹窗；
//   2. 标题排印过重：原先的 "You've reached today's limit." 采用了 Charter 17pt Bold，
//      西文衬线加粗后笔画对比极其强烈，带有浓重黑度与压迫感；
//   3. 纵向层级堆叠：说明标题 + 说明正文 + 巨幅大按钮三层直排，空间密集。
//
// 💡 本沙箱提供 4 套高审美、轻量化的优化提案供对比决策：
//   - 【Baseline】: 当前方案 C（实心纯黑胶囊，对照基准）
//   - 【方案 1 · 细线描边胶囊 (Outlined Ghost Pill)】: 暖近白底 + 0.8pt 细描边，保留胶囊认知，彻底卸除大黑块；
//   - 【方案 2 · 浅暖灰底柔和胶囊 (Soft Warm Tinted Pill)】: 浅暖灰底 (neutralFaint 35%)，无边框无阴影，温润如次级按钮；
//   - 【方案 3 · Settings 风格一体化操作卡 (Settings Action Card)】: 借鉴 SettingsActionRow，将说明与行动收拢为一张轻卡，右侧带 chevron，一体化极高；
//   - 【方案 4 · 编辑风纯文字链接 (Editorial Text Link)】: 借鉴 AboutAIView，去容器化，纯文本 + 优雅带箭外链，视觉重量为零。

// =====================================================================
// MARK: - 方案枚举定义
// =====================================================================

enum LimitReachedStyle: String, CaseIterable, Identifiable {
    case baseline = "Baseline (当前黑胶囊)"
    case proposal1 = "方案 1 (细线描边胶囊)"
    case proposal2 = "方案 2 (浅暖灰底胶囊)"
    case proposal3 = "方案 3 (Settings 一体卡)"
    case proposal4 = "方案 4 (编辑风纯文字链)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .baseline:  return "Baseline"
        case .proposal1: return "方案 1: 细线描边"
        case .proposal2: return "方案 2: 浅暖灰底"
        case .proposal3: return "方案 3: Settings卡"
        case .proposal4: return "方案 4: 文字链接"
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .baseline:  return 375
        case .proposal1: return 365
        case .proposal2: return 365
        case .proposal3: return 345
        case .proposal4: return 340
        }
    }

    var weightLevel: String {
        switch self {
        case .baseline:  return "极重 (48pt 纯黑实心)"
        case .proposal1: return "轻盈 (0.8pt 细线描边)"
        case .proposal2: return "柔和 (浅米灰无框底)"
        case .proposal3: return "整合 (去堆叠 一体卡)"
        case .proposal4: return "极轻 (零容器 纯字链)"
        }
    }

    var description: String {
        switch self {
        case .baseline:
            return "当前版本：Charter 17pt Bold 标题 + 48pt 实心深焦黑胶囊。对比度过强，底部下坠感明显。"
        case .proposal1:
            return "细线描边胶囊：标题降重为 Charter 16.5pt Regular；CTA 采用暖近白底 + 0.8pt cardBorder 细描边 + 焦黑文字，保留明确按钮心智，彻底消灭黑块。"
        case .proposal2:
            return "浅暖灰底胶囊：标题 Charter 16.5pt Regular；CTA 采用 neutralFaint 35% 浅灰底，无边框无投影，对齐 iOS 原生次级按钮，温润平缓。"
        case .proposal3:
            return "Settings 一体卡：取消「标题+长句+大钮」三层堆叠，转化为一张与 Settings 列表同源的 20pt 轻卡。左侧信封与说明，右侧小箭头，整卡可点。"
        case .proposal4:
            return "编辑风纯文字链：对齐 About AI 页面风格。完全去除外层任何容器，左对齐标题与正文后紧跟一条高贵带箭文字链接，极致书卷气，零视觉重量。"
        }
    }
}

// =====================================================================
// MARK: - 各方案对应的下半区组件实现
// =====================================================================

// --- Baseline: 当前纯黑胶囊 ---
struct LimitReachedSectionBaseline: View {
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingCard) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                // 原版加粗，黑度较重
                Text("You've reached today's limit.")
                    .font(AppTheme.Font.cardSentence) // Charter 17pt Bold
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                    .font(AppTheme.Font.settingsFormIntro)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)

            Button(action: onAction) {
                HStack(spacing: AppTheme.Space.paddingS) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Send feedback for invite code")
                        .font(AppTheme.Font.ctaLabel)
                }
                .foregroundStyle(AppTheme.Color.textOnChip)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.Color.interactive, in: Capsule())
                .shadow(color: AppTheme.Color.interactive.opacity(0.18), radius: 8, y: 3)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// --- 方案 1: 细线描边胶囊 (Outlined Ghost Pill) ---
struct LimitReachedSectionProposal1: View {
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                // 升级：降重为 Charter 16.5pt Regular 细衬线，优雅不吵闹
                Text("You've reached today's limit.")
                    .font(.custom("Charter", size: 16.5, relativeTo: .body))
                    .foregroundStyle(AppTheme.Color.settingsRowText)

                Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                    .font(.custom("GothicA1-Light", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)

            // 升级：暖白底 + 0.8pt cardBorder 描边 + 焦黑文字，告别纯黑大块
            Button(action: onAction) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 14, weight: .medium))
                    Text("Send feedback for invite code")
                        .font(.custom("GothicA1-Medium", size: 14, relativeTo: .subheadline))
                }
                .foregroundStyle(AppTheme.Color.settingsRowText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppTheme.Color.cardBg, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// --- 方案 2: 浅暖灰底柔和次级胶囊 (Soft Warm Tinted Pill) ---
struct LimitReachedSectionProposal2: View {
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                // 细衬线常规体，温润书卷感
                Text("You've reached today's limit.")
                    .font(.custom("Charter", size: 16.5, relativeTo: .body))
                    .foregroundStyle(AppTheme.Color.settingsRowText)

                Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                    .font(.custom("GothicA1-Light", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)

            // 升级：极柔浅暖灰底 (neutralFaint 35%)，无框无影，如同纸面印痕
            Button(action: onAction) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 14, weight: .medium))
                    Text("Send feedback for invite code")
                        .font(.custom("GothicA1-Medium", size: 14, relativeTo: .subheadline))
                }
                .foregroundStyle(AppTheme.Color.settingsRowText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppTheme.Color.neutralFaint.opacity(0.35), in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// --- 方案 3: Settings 风格一体化操作卡 (Settings Action Card) ---
struct LimitReachedSectionProposal3: View {
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 12) {
                // 左侧小信封图标徽标
                ZStack {
                    Circle()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.35))
                        .frame(width: 36, height: 36)
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                }

                // 中间主副文排版：结构收拢，不再有冗长堆叠
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've reached today's limit")
                        .font(.custom("Charter", size: 15.5, relativeTo: .body))
                        .foregroundStyle(AppTheme.Color.settingsRowText)

                    Text("Send feedback to request extra quota")
                        .font(.custom("GothicA1-Light", size: 13, relativeTo: .caption))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Spacer()

                // 右侧 Settings 风格小箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.settingsRowIconTint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1.5)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// --- 方案 4: 编辑风纯文字链接 (Editorial Text Link) ---
struct LimitReachedSectionProposal4: View {
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("You've reached today's limit.")
                    .font(.custom("Charter", size: 16.5, relativeTo: .body))
                    .foregroundStyle(AppTheme.Color.settingsRowText)

                Text("Want to keep generating today? We're happy to grant extra generations.")
                    .font(.custom("GothicA1-Light", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .padding(.horizontal, AppTheme.Space.paddingXS)

            // 升级：纯文字链接，配小信封与右上外链箭头，零视觉容器重量
            Button(action: onAction) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 13, weight: .medium))
                    Text("Send feedback for invite code")
                        .font(.custom("GothicA1-Medium", size: 14, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.Color.brandStrong)
                .padding(.vertical, 4)
                .padding(.horizontal, AppTheme.Space.paddingXS)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// =====================================================================
// MARK: - 完整的 5/5 达标态 Sheet 壳体组件 (用于真实呈现整屏视觉)
// =====================================================================

struct UsageLimitSheetRefined: View {
    let style: LimitReachedStyle
    let onFeedback: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingCard) {
            // 1. 顶栏：句首大写 Daily limit · Charter 22pt Bold 粗衬线（增强定力压轴）
            HStack {
                Text("Daily limit")
                    .font(AppTheme.Font.usageLimitSheetTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
            }
            .padding(.top, 4)

            // 2. 方案 2-C 极细微线用量卡片 (5/5 焦黑充满)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("5")
                        .font(.custom("Charter", size: 24, relativeTo: .title2))
                        .foregroundStyle(AppTheme.Color.settingsRowText)

                    Text("/ 5 generations today")
                        .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Spacer()
                }

                // 2.0pt 极薄微线轨：5/5 满额深焦黑填满，平静客观
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                            .frame(height: 2.0)
                        Capsule()
                            .fill(AppTheme.Color.settingsRowText)
                            .frame(width: geo.size.width, height: 2.0)
                    }
                }
                .frame(height: 2.0)
                .padding(.top, 2)
            }
            .padding(AppTheme.Space.paddingCard)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)

            // 3. 达标区差异化呈现
            Group {
                switch style {
                case .baseline:
                    LimitReachedSectionBaseline(onAction: onFeedback)
                case .proposal1:
                    LimitReachedSectionProposal1(onAction: onFeedback)
                case .proposal2:
                    LimitReachedSectionProposal2(onAction: onFeedback)
                case .proposal3:
                    LimitReachedSectionProposal3(onAction: onFeedback)
                case .proposal4:
                    LimitReachedSectionProposal4(onAction: onFeedback)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.titleToContent)
        .padding(.bottom, AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.Color.pageBg)
    }
}

// =====================================================================
// MARK: - 交互式对比实验室 (UsageLimitReachedLabView)
// =====================================================================

struct UsageLimitReachedLabView: View {
    @State private var selectedStyle: LimitReachedStyle = .proposal1
    @State private var showFeedbackModal = false
    @State private var showFullSheetDemo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部控制与方案切换 Bar
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LimitReachedStyle.allCases) { style in
                                let isSelected = (selectedStyle == style)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedStyle = style
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isSelected {
                                            Circle()
                                                .fill(AppTheme.Color.brandStrong)
                                                .frame(width: 5, height: 5)
                                        }
                                        Text(style.shortTitle)
                                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? AppTheme.Color.cardBg : AppTheme.Color.neutralFaint.opacity(0.3))
                                    .foregroundStyle(isSelected ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay {
                                        if isSelected {
                                            Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // 方案说明与量化卡片
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedStyle.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Text(selectedStyle.description)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("高度: \(Int(selectedStyle.sheetHeight))pt")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.Color.settingsRowText)
                            Text(selectedStyle.weightLevel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selectedStyle == .baseline ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AppTheme.Color.neutralFaint.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.vertical, 10)
                .background(AppTheme.Color.cardBg)
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.6)
                }

                // 中间展示区域：以真实手机比例呈现半屏底板效果
                ScrollView {
                    VStack(spacing: 16) {
                        // 手机屏幕仿真框
                        VStack(spacing: 0) {
                            // 顶部抓手指示器仿真
                            Capsule()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 36, height: 4.5)
                                .padding(.top, 8)
                                .padding(.bottom, 2)

                            // 方案内芯渲染
                            UsageLimitSheetRefined(style: selectedStyle) {
                                showFeedbackModal = true
                            }
                        }
                        .frame(maxWidth: 375)
                        .frame(height: selectedStyle.sheetHeight)
                        .background(AppTheme.Color.pageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.Color.cardBorder, lineWidth: 1.0)
                        }
                        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
                        .padding(.top, 16)

                        // 真实弹窗体验入口
                        Button {
                            showFullSheetDemo = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 13))
                                Text("以真实 iOS 原生手势弹出测试此方案")
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppTheme.Color.cardBg)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("02 达标态轻量化探索")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFeedbackModal) {
                NavigationStack {
                    FeedbackView(
                        initialCategory: .suggestion,
                        initialBody: "I would like to request an invite code to increase my daily generation quota."
                    )
                }
            }
            .sheet(isPresented: $showFullSheetDemo) {
                UsageLimitSheetRefined(style: selectedStyle) {
                    showFeedbackModal = true
                }
                .presentationDetents([.height(selectedStyle.sheetHeight)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("00 · ★ 02达标态优化方案总览与对比实验室") {
    UsageLimitReachedLabView()
}

#Preview("01 · Baseline: 当前黑胶囊 (视觉沉重对照 · 375pt)") {
    UsageLimitSheetRefined(style: .baseline, onFeedback: {})
        .frame(width: 375, height: 375)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("02 · 方案 1: 细线描边胶囊 (Outlined Ghost · 365pt)") {
    UsageLimitSheetRefined(style: .proposal1, onFeedback: {})
        .frame(width: 375, height: 365)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("03 · 方案 2: 浅暖灰底柔和胶囊 (Soft Warm Tinted · 365pt)") {
    UsageLimitSheetRefined(style: .proposal2, onFeedback: {})
        .frame(width: 375, height: 365)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("04 · 方案 3: Settings 风格一体化操作卡 (Settings Row · 345pt)") {
    UsageLimitSheetRefined(style: .proposal3, onFeedback: {})
        .frame(width: 375, height: 345)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("05 · 方案 4: 编辑风纯文字链接 (Editorial Link · 340pt)") {
    UsageLimitSheetRefined(style: .proposal4, onFeedback: {})
        .frame(width: 375, height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("06 · 四方案同屏并排横向画廊 (直观视觉对比)") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
            ForEach(LimitReachedStyle.allCases) { style in
                VStack(spacing: 8) {
                    Text(style.shortTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 36, height: 4.5)
                            .padding(.top, 8)
                            .padding(.bottom, 2)

                        UsageLimitSheetRefined(style: style, onFeedback: {})
                    }
                    .frame(width: 320, height: style.sheetHeight)
                    .background(AppTheme.Color.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.Color.cardBorder, lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)

                    Text(style.weightLevel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(style == .baseline ? Color.red : Color.secondary)
                }
            }
        }
        .padding(24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#endif
