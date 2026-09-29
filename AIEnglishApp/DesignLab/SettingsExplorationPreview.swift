#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - 设置模块全景与交互画板 (Settings, Feedback & About AI Exploration)
// =====================================================================
// 🎯 核心原则：
//   1. 100% 像素级对齐线上生产真机效果（Warm Minimalism：暖纸底 #FCF8F3、近白卡片 #FFFDF8、衬线标题）。
//   2. 严格遵循项目最新字体三巨头底座：
//      - 英文衬线（内容主角与标题路标）：Charter (Bold 700 / Regular 400)
//      - 英文无衬线（界面基建与输入控件）：Gothic A1 (SemiBold 600 / Medium 500 / Regular 400)
//      - 中文 CJK（辅助说明）：冬青黑体 Hiragino Sans GB
//   3. 尊重 Xcode Canvas 原生视口：纯竖屏原生 iPhone 视口，绝不在画板内套画重复假手机壳。
//   4. 覆盖设置模块全部 3 大核心页面与全状态演进：
//      - 01 · SettingsView (主设置页 · 5 组卡片、72pt 留白页脚版本号、右上角常驻浮动关闭键)
//      - 02 · AboutAIView (数据披露页 · App Store 5.1.2(i) 合规披露、brandStrong #FF7622 品牌橙外链)
//      - 03 · FeedbackView (反馈表单页 · Suggestion / Bug 1.0pt 极简圆弧小甲虫 / Other、实时千分位字数、提交状态)
//      - 04 · 状态联动 (提交成功后 Settings 底部弹出的晨曦暖橙底 R8 藏书票便签 Toast，绝非绿色胶囊)

// =====================================================================
// MARK: - 模拟真实 Sheet 环境的容器包装
// =====================================================================

/// 包装二级页面，在独立预览时补齐右上角常驻的 SettingsCircleButton.close 悬浮键与 NavigationStack
private struct SettingsSubpageContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
        }
        .overlay(alignment: .topTrailing) {
            SettingsCircleButton(kind: .close) {}
                .padding(.trailing, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.titleToContent)
        }
    }
}

// =====================================================================
// MARK: - 真实可交互全流程沙盒 (SettingsLiveInteractiveFlowSandbox)
// =====================================================================

/// 完整可交互沙盒容器：在真实 iPhone 尺寸下点按体验 Settings -> Feedback / About AI 的推入、返回与 Toast 闭环
struct SettingsLiveInteractiveFlowSandbox: View {
    @State private var showSettingsSheet = true

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingSection) {
                VStack(spacing: AppTheme.Space.paddingS) {
                    Text("Poplex Settings Sandbox")
                        .font(AppTheme.Font.pageTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("Click below to open the complete interactive settings sheet flow.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Space.paddingCard)
                }

                Button {
                    showSettingsSheet = true
                } label: {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Open Settings Sheet")
                            .font(AppTheme.Font.ctaLabel)
                    }
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.Color.textPrimary, in: Capsule())
                    .shadow(color: AppTheme.Color.textPrimary.opacity(0.18), radius: 8, y: 3)
                    .padding(.horizontal, AppTheme.Space.paddingHero)
                }
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }
}

// =====================================================================
// MARK: - 全景画板对比视察 (SettingsPanoramaGallery)
// =====================================================================

/// 全景对比长画廊：平铺 Settings 全部页面状态、表单形态与 Toast 规范
struct SettingsPanoramaGallery: View {
    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                // 顶部说明
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text("Settings Exploration Gallery")
                        .font(AppTheme.Font.pageTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("100% 像素级对齐生产代码 · 字体铁三角 (Charter + Gothic A1 + 冬青黑) · Warm Minimalism 纸白质感")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingPage)

                // 卡片 1: Settings 主设置页全貌 (带版本号与 72pt 留白)
                PanoramaSectionCard(
                    title: "01 · SettingsView (Sheet Root)",
                    desc: "暖纸底 + 暖近白卡片 · Charter 衬线标题 · Gothic A1 正文 · 72pt 页脚呼吸断层"
                ) {
                    SettingsView()
                        .frame(height: 760)
                }

                // 卡片 2: About AI 披露页 (App Store 5.1.2(i) 合规)
                PanoramaSectionCard(
                    title: "02 · AboutAIView (Data Compliance)",
                    desc: "固定路标 Personal data · 大标题 How AI uses your data · brandStrong #FF7622 品牌橙外链"
                ) {
                    SettingsSubpageContainer {
                        AboutAIView()
                    }
                    .frame(height: 520)
                }

                // 卡片 3: Feedback 表单初始空态
                PanoramaSectionCard(
                    title: "03 · Feedback 表单 (初始空态)",
                    desc: "Suggestion 默认选中 · 占位文案 · 0/1,000 字数 · Send feedback 处于禁用灰色态"
                ) {
                    SettingsSubpageContainer {
                        FeedbackView(
                            initialCategory: .suggestion,
                            initialBody: "",
                            initialEmail: ""
                        )
                    }
                    .frame(height: 640)
                }

                // 卡片 4: Feedback 表单 Bug 选中态与填妥态
                PanoramaSectionCard(
                    title: "04 · Feedback 表单 (Bug 选中态与已输入)",
                    desc: "Canvas 1.0pt 极简圆弧小甲虫 · brandWash 浅橙底选中 · 实时千分位字数 · 按钮激活"
                ) {
                    SettingsSubpageContainer {
                        FeedbackView(
                            initialCategory: .bug,
                            initialBody: "The pronunciation audio sometimes buffers for 2-3 seconds on weak network connections.",
                            initialEmail: "alex@example.com"
                        )
                    }
                    .frame(height: 640)
                }

                // 卡片 5: Feedback 表单网络错误报错态
                PanoramaSectionCard(
                    title: "05 · Feedback 表单 (错误提示状态)",
                    desc: "exclamationmark.circle 红色错误提醒行 · 校验邮箱合法性与离线处理"
                ) {
                    SettingsSubpageContainer {
                        FeedbackView(
                            initialCategory: .suggestion,
                            initialBody: "I would love to see an offline mode for downloaded speaking scenes.",
                            initialEmail: "invalid-email-address",
                            initialErrorMessage: "Please check your email address and try again."
                        )
                    }
                    .frame(height: 680)
                }

                // 卡片 6: 生产级 Toast 规范对比 (Positive vs Blocked)
                PanoramaSectionCard(
                    title: "06 · 生产 Toast 规范 (AppToast · R8 藏书票便签)",
                    desc: "328pt 固定宽度 · 积极态：晨曦暖橙实色底 + 焦墨橙细边 + 纸飞机 · 受阻态：暖纸灰底"
                ) {
                    VStack(spacing: AppTheme.Space.paddingCard) {
                        // 积极成功态 (Feedback 成功)
                        AppToast(
                            message: FeedbackView.successToastMessage,
                            systemImage: "paperplane.fill",
                            semantic: .positive
                        )

                        // 动作受阻态 (Developer Reset 等)
                        AppToast(
                            message: "Library unlock reset.",
                            systemImage: "exclamationmark.circle",
                            semantic: .blocked
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Space.paddingHero)
                    .background(AppTheme.Color.pageBg)
                }

                // 卡片 7: 字体与排印 Token 速查表
                PanoramaSectionCard(
                    title: "07 · 排印与设计代币审计 (Production Token Audit)",
                    desc: "Charter (英文衬线) + Gothic A1 (英文无衬线) + 冬青黑体 (中文)"
                ) {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        tokenRow(
                            label: "顶栏固定路标",
                            token: "settingsPinnedTitleSerif",
                            fontDesc: "Charter 20pt · Bold 700",
                            sample: "Settings / Personal data / Feedback",
                            font: AppTheme.Font.settingsPinnedTitleSerif
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "卡外分区标题",
                            token: "settingsSectionTitleSerif",
                            fontDesc: "Charter 15pt · Regular 400",
                            sample: "My language / Legal / Details",
                            font: AppTheme.Font.settingsSectionTitleSerif
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "合规说明页标题",
                            token: "settingsDocumentTitleSerif",
                            fontDesc: "Charter 20pt · Regular 400 (细衬线温润雅致)",
                            sample: "How AI uses your data",
                            font: AppTheme.Font.settingsDocumentTitleSerif
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "合规说明长正文",
                            token: "settingsDocumentBody",
                            fontDesc: "Gothic A1 15pt · Light 300 (60u 字干书籍排版)",
                            sample: "Poplex creates your English learning content using AI...",
                            font: AppTheme.Font.settingsDocumentBody
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "设置列表行主标/值",
                            token: "settingsRowLabel",
                            fontDesc: "Gothic A1 17pt · ExtraLight 200 (46u 字干 · 利落工笔)",
                            sample: "Learning / English · Feedback · Privacy Policy",
                            font: AppTheme.Font.settingsRowLabel(legibilityWeight: nil)
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "通用正文/说明",
                            token: "englishBody",
                            fontDesc: "Gothic A1 17pt · Regular 400 (76u 字干)",
                            sample: "Poplex creates your English learning content using AI...",
                            font: AppTheme.Font.englishBody
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "分类胶囊标",
                            token: "feedbackChipLabel",
                            fontDesc: "Gothic A1 15pt · Regular 400",
                            sample: "Suggestion · Bug · Other",
                            font: AppTheme.Font.feedbackChipLabel
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "主提交按钮",
                            token: "ctaLabel",
                            fontDesc: "Gothic A1 17pt · Semibold 600",
                            sample: "Send feedback",
                            font: AppTheme.Font.ctaLabel
                        )

                        Divider().opacity(0.12)

                        tokenRow(
                            label: "版本号页脚",
                            token: "settingsVersion",
                            fontDesc: "Charter 12pt · Regular 400",
                            sample: "Version 1.0 (Build 1)",
                            font: AppTheme.Font.settingsVersion
                        )
                    }
                    .padding(AppTheme.Space.paddingCard)
                    .background(AppTheme.Color.cardBg)
                }
            }
            .padding(.bottom, AppTheme.Space.paddingScreenBottom)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func tokenRow(
        label: String,
        token: String,
        fontDesc: String,
        sample: String,
        font: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                Spacer()
                Text(token)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.brandInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Color.brandWash, in: RoundedRectangle(cornerRadius: 4))
            }

            Text(fontDesc)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)

            Text(sample)
                .font(font)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.top, 2)
        }
    }
}

/// 全景画板中的区块展示卡
private struct PanoramaSectionCard<Content: View>: View {
    let title: String
    let desc: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text(title)
                    .font(AppTheme.Font.settingsSectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text(desc)
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            content()
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                        .stroke(AppTheme.Color.border, lineWidth: 0.6)
                )
                .shadow(color: AppTheme.Shadow.cardColor, radius: 10, y: 4)
                .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("01 · Live Interactive Flow (可交互 Sheet 闭环)") {
    SettingsLiveInteractiveFlowSandbox()
}

#Preview("02 · SettingsView (主设置页)") {
    SettingsView()
}

#Preview("03 · AboutAIView (数据合规披露页)") {
    SettingsSubpageContainer {
        AboutAIView()
    }
}

#Preview("04 · FeedbackView · Default (反馈空态)") {
    SettingsSubpageContainer {
        FeedbackView()
    }
}

#Preview("05 · FeedbackView · Bug Selected (小甲虫选中态)") {
    SettingsSubpageContainer {
        FeedbackView(
            initialCategory: .bug,
            initialBody: "The pronunciation audio sometimes buffers for 2-3 seconds on weak network connections.",
            initialEmail: "alex@example.com"
        )
    }
}

#Preview("06 · FeedbackView · Error (错误提示态)") {
    SettingsSubpageContainer {
        FeedbackView(
            initialCategory: .suggestion,
            initialBody: "I would love to see an offline mode for downloaded speaking scenes.",
            initialEmail: "invalid-email-address",
            initialErrorMessage: "Please check your email address and try again."
        )
    }
}

#Preview("07 · Toast Tokens (正向暖橙 vs 受阻纸灰)") {
    VStack(spacing: AppTheme.Space.paddingSection) {
        AppToast(
            message: FeedbackView.successToastMessage,
            systemImage: "paperplane.fill",
            semantic: .positive
        )

        AppToast(
            message: "Library unlock reset.",
            systemImage: "exclamationmark.circle",
            semantic: .blocked
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Color.pageBg.ignoresSafeArea())
}

#Preview("08 · Panorama Gallery (全景画板)") {
    SettingsPanoramaGallery()
}

#endif
