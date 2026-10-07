#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit (使用额度弹窗) 生产级全状态像素级画板与设计审计 (最新规范版)
// =====================================================================
// 🎯 核心目标：
//   1. 100% 像素级复原当前最新生产代码 (UsageLimitButton.swift -> UsageLimitSheet) 的真实表现；
//   2. 包含已落地的方案 2-C 极细连续微线轨、方案 1 细线描边胶囊 CTA、Charter 24pt 细衬线与去焦虑焦黑满额；
//   3. 加载菊花位置与行高槽精准还原：采用 AppTheme.Size.usageLimitQuotaRowMinHeight (30pt) 保底行高槽，
//      加载态用「隐藏数字占位 + overlay 菊花」：占位撑出与数字态一致的行高与基线（实测加载 ↔ 已加载
//      副文/进度轨/说明句位移均为 0），菊花 (usageLimitSpinnerSlotSize 22×22) 叠其上并按
//      usageLimitSpinnerOpticalOffset (+6pt，相对占位中心) 校准到 / 5 字身中线；
//      占位宽度即数字自然宽度（副文横向也不位移），全局 HStack 保持 paddingXS (4pt)，自适应 Dynamic Type；
//   4. 弹窗高度全面同步最新生产口径：在线达标 365pt (旧版 375pt)、离线达标 395pt (旧版 405pt)、离线空态 295pt (旧版 310pt)；
//   5. 真实系统级弹窗容器仿真：使用生产同源 AppTheme.Color.scrimOverlay 暖调暗色遮罩与 AppTheme.Color.pageBg 暖纸底；
//   6. 嵌入动态交互式滑块 (Slider 0...5)，动态观察未达标 (260pt) 到达标 (365pt) 的展开弹性动画。

// =====================================================================
// MARK: - 业务状态枚举定义 (最新落地规格)
// =====================================================================

enum UsageLimitVisualState: String, CaseIterable, Identifiable {
    case normalOnline         = "01 · 正常在线未达标 (2/5 · 260pt)"
    case limitReached         = "02 · 在线满额达标 (5/5 · 365pt · 细线胶囊)"
    case offlineCacheNormal   = "03 · 离线未达标带缓存 (2/5 · 260pt · 弱网提示)"
    case offlineCacheReached  = "04 · 离线且满额达标 (5/5 · 395pt · 弱网提示)"
    case offlineEmpty         = "05 · 冷启动离线空态 (–/5 · 295pt · 重试按钮)"
    case zeroInitial          = "06 · 初始零使用状态 (0/5 · 260pt · 空轨道)"
    case loadingState         = "07 · 加载过渡态 (包裹菊花 · 260pt · 零跳变)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .normalOnline:        return "2/5 在线"
        case .limitReached:        return "5/5 达标"
        case .offlineCacheNormal:  return "2/5 离线"
        case .offlineCacheReached: return "5/5 离线"
        case .offlineEmpty:        return "离线空态"
        case .zeroInitial:         return "0/5 初始"
        case .loadingState:        return "包裹菊花"
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .normalOnline, .zeroInitial, .offlineCacheNormal, .loadingState:
            return 260
        case .limitReached:
            return 365
        case .offlineCacheReached:
            return 395
        case .offlineEmpty:
            return 295
        }
    }

    var usedCount: Int? {
        switch self {
        case .normalOnline, .offlineCacheNormal:
            return 2
        case .limitReached, .offlineCacheReached:
            return 5
        case .zeroInitial:
            return 0
        case .offlineEmpty, .loadingState:
            return nil
        }
    }

    var isFailed: Bool {
        switch self {
        case .offlineCacheNormal, .offlineCacheReached, .offlineEmpty:
            return true
        default:
            return false
        }
    }

    var diagnosisNotes: String {
        switch self {
        case .normalOnline:
            return "【正常在线未满】：高度 260pt。Charter 24pt Regular 细衬线数字 + 15pt Light 副文，2.0pt 极薄连续微线轨（暖中灰未满填充），0.5pt 细描边双层微阴影，顶栏无冗余关闭键。"
        case .limitReached:
            return "【在线额度用尽】：高度轻量化为 365pt。卸除刺眼警报红，采用温润克制的深焦黑满额客观陈述；Charter 16.5pt 细衬线说明 + 44pt 细线描边胶囊 CTA，彻底消除压迫感。"
        case .offlineCacheNormal:
            return "【离线未满带缓存】：高度 260pt。使用本地缓存显示 2/5 与微线轨，底部追加严格 16pt 左对齐的 wifi.slash 离线弱网注记。"
        case .offlineCacheReached:
            return "【离线满额带缓存】：高度优化为 395pt。包含 44pt 细线描边邀请码胶囊，底部追加弱网同步提示，纵向间距舒展匀称。"
        case .offlineEmpty:
            return "【冷启动离线空态】：高度收敛为 295pt。主卡片展示 36pt 中灰图标、Charter 20pt 细衬线标题与 14pt 离线说明，配备规范的 40pt 细线 Try again 按钮。"
        case .zeroInitial:
            return "【初始零使用】：高度 260pt。展示 0 / 5，2.0pt 极薄底槽完全空白，底部展示严格左对齐的零点刷新出版物注记。"
        case .loadingState:
            return "【网络请求过渡态】：高度 260pt。采用隐藏 Text(\"0\") 基线包裹占位，菊花精密锁定在数字槽位中心；数据加载完成后原位替换为数字，达成零排版跳动 (Zero Layout Hitch)。"
        }
    }
}

// =====================================================================
// MARK: - 1:1 像素级生产复刻组件 (UsageLimitSheetProductionReplica)
// =====================================================================

/// 100% 像素级复现生产代码 UsageLimitSheet 的页面结构、包裹菊花与渲染要素
struct UsageLimitSheetProductionReplica: View {
    @State private var dailyLimit: Int
    @State private var usedCount: Int?
    @State private var loadFailed: Bool
    private let isPreviewInjected: Bool

    init(
        usedCount: Int? = 2,
        dailyLimit: Int = 5,
        loadFailed: Bool = false
    ) {
        self._usedCount = State(initialValue: usedCount)
        self._dailyLimit = State(initialValue: dailyLimit)
        self._loadFailed = State(initialValue: loadFailed)
        self.isPreviewInjected = true
    }

    private var isLimitReached: Bool {
        guard let usedCount else { return false }
        return usedCount >= dailyLimit
    }

    private var sheetHeight: CGFloat {
        if usedCount == nil && loadFailed {
            return 295
        }
        if isLimitReached {
            return loadFailed ? 395 : 365
        }
        return 260
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                // 1. 顶栏：句首大写 Daily limit · Charter 20pt Regular 细衬线 · 纯净留白无关闭键
                headerRow

                if usedCount == nil && loadFailed {
                    // 状态 5：冷启动离线空状态卡片 (295pt · 含 Try again 按钮)
                    offlineEmptyCard
                } else {
                    // 状态 1 / 2 / 3 / 4 / 6 / 7 主卡片 (方案 2-C 极细精工规范)
                    usageCard

                    if isLimitReached {
                        // 达标说明文案 (去焦虑、舒展排版)
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        // 申请邀请码高定 CTA 按钮 (方案 1 细线描边胶囊)
                        feedbackCTAButton

                        if loadFailed {
                            offlineCachedNote
                                .padding(.top, AppTheme.Space.paddingXS)
                        }
                    } else if loadFailed {
                        offlineCachedNote
                            .padding(.top, AppTheme.Space.paddingS)
                    } else {
                        // 正常零点刷新注记 (左对齐出版物风)
                        normalFooterNote
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.titleToContent)
            .padding(.bottom, AppTheme.Space.paddingPage)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Color.pageBg)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.Color.pageBg)
    }

    // MARK: - Subviews

    /// 1. 顶栏：句首大写 Daily limit · Charter 22pt Bold 粗衬线（增强定力压轴） · 纯净留白无关闭键
    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.usageLimitSheetTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
        }
        .padding(.top, AppTheme.Space.paddingXS)
    }

    /// 2. 用量卡片 (方案 2-C)：Charter 24pt 细衬线数字 + 15pt Light 副文 + 2.0pt 极薄连续微线 + 0.5pt 边框贴地双层阴影
    private var usageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingXS) {
                if let usedCount {
                    Text("\(usedCount)")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                } else if loadFailed {
                    Text("–")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    // 与生产一致：隐藏数字占位撑出同样的行高与基线，菊花以 overlay 叠上（不参与布局）。
                    Text("0")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .hidden()
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.Color.textSecondary)
                                .frame(
                                    width: AppTheme.Size.usageLimitSpinnerSlotSize,
                                    height: AppTheme.Size.usageLimitSpinnerSlotSize
                                )
                                .offset(y: AppTheme.Size.usageLimitSpinnerOpticalOffset)
                        }
                }

                Text("/ \(dailyLimit) generations today")
                    .font(AppTheme.Font.quotaSubtext)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()
            }
            .frame(minHeight: AppTheme.Size.usageLimitQuotaRowMinHeight)

            // 方案 2-C: 2.0pt 极薄连续微线轨 (底槽 neutralFaint 30%，满额深焦黑，未满暖中灰)
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                        .frame(height: AppTheme.Size.usageLimitProgressBarHeight)
                    if usedCount != nil {
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                            .frame(
                                width: max(geo.size.width * ratio, AppTheme.Size.usageLimitProgressBarHeight),
                                height: AppTheme.Size.usageLimitProgressBarHeight
                            )
                    }
                }
            }
            .frame(height: AppTheme.Size.usageLimitProgressBarHeight)
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
    }

    /// 3. 达标说明段落 (去焦虑方案)：Charter 16.5pt Regular + Gothic A1 14pt Light
    private var limitReachedText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("You've reached today's limit.")
                .font(AppTheme.Font.quotaReachedTitle)
                .foregroundStyle(AppTheme.Color.settingsRowText)

            Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                .font(AppTheme.Font.quotaReachedBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 4. 申请邀请码 CTA 按钮 (方案 1 细线描边胶囊)：44pt · 暖近白底 + 0.8pt 细描边 + 焦黑文字
    private var feedbackCTAButton: some View {
        Button {} label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 14, weight: .medium))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.quotaFeedbackAction)
            }
            .foregroundStyle(AppTheme.Color.settingsRowText)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.usageLimitCTAHeight)
            .background(AppTheme.Color.cardBg, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.cardBorder, lineWidth: AppTheme.Size.usageLimitCTABorderWidth)
            }
            .shadow(
                color: AppTheme.Shadow.pillContactColor,
                radius: AppTheme.Shadow.pillContactRadius,
                x: AppTheme.Shadow.pillContactX,
                y: AppTheme.Shadow.pillContactY
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// 5. 正常脚注：严格 16pt 左对齐出版物注记风
    private var normalFooterNote: some View {
        Text("Your daily generations refresh every day at midnight.")
            .font(AppTheme.Font.settingsFormIntro)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 6. 弱网与离线提示：左对齐，12pt 图标 + 13.5pt 柔和注记
    private var offlineCachedNote: some View {
        HStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: loadFailed ? "wifi.slash" : "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
            Text(loadFailed
                ? "You're offline. Showing last synced usage."
                : "Couldn't refresh. Showing last synced usage.")
                .font(AppTheme.Font.settingsFormIntro)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 7. 冷启动离线空状态卡片：包含 Try again 按钮 (295pt 高度规范)
    private var offlineEmptyCard: some View {
        VStack(spacing: AppTheme.Space.paddingM) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 36, height: 36)

            VStack(spacing: AppTheme.Space.paddingXS) {
                Text("Couldn't check quota")
                    .font(AppTheme.Font.settingsDocumentTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("Check your connection and try again.")
                    .font(AppTheme.Font.settingsFormIntro)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {} label: {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.neutralFaint.opacity(0.4), in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 4)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
    }
}

// =====================================================================
// MARK: - 对齐 Settings / Tab2 沉稳通透版 (UsageLimitSheetSettingsAligned)
// =====================================================================

/// 副文样式探索枚举
enum UsageLimitSubtextStyle {
    /// 线上现状：Gothic A1 15pt Light (300) · textSecondary (灰调发虚)
    case baselineLight300
    /// 方案 A：对齐 Settings 页面 Target language 字符样式 (Gothic A1 15pt ExtraLight 200 · settingsRowText 焦黑主字感)
    case targetLanguageExtraLight200
    /// 方案 B：字重提升至 Regular (400) 扎实版 (Gothic A1 15pt Regular 400 · textSecondary)
    case regular400

    var font: Font {
        switch self {
        case .baselineLight300:
            return AppTheme.Font.quotaSubtext
        case .targetLanguageExtraLight200:
            return Font.custom("GothicA1-ExtraLight", size: 15, relativeTo: .subheadline)
        case .regular400:
            return Font.custom("GothicA1-Regular", size: 15, relativeTo: .subheadline)
        }
    }

    var textColor: Color {
        switch self {
        case .baselineLight300:
            return AppTheme.Color.textSecondary
        case .targetLanguageExtraLight200:
            return AppTheme.Color.settingsRowText
        case .regular400:
            return AppTheme.Color.textSecondary
        }
    }

    var label: String {
        switch self {
        case .baselineLight300:
            return "现状 Light 300 (发虚)"
        case .targetLanguageExtraLight200:
            return "方案 A · Target language 同款 (ExtraLight 200 + 焦黑)"
        case .regular400:
            return "方案 B · Regular 400 扎实版"
        }
    }
}

/// 优化版组件：支持动态测试底色、副文字符与微轨高度
struct UsageLimitSheetSettingsAligned: View {
    @State private var dailyLimit: Int
    @State private var usedCount: Int?
    @State private var loadFailed: Bool
    private let isPreviewInjected: Bool
    private let subtextStyle: UsageLimitSubtextStyle
    private let trackHeight: CGFloat
    private let cardFillColor: Color

    init(
        usedCount: Int? = 2,
        dailyLimit: Int = 5,
        loadFailed: Bool = false,
        subtextStyle: UsageLimitSubtextStyle = .targetLanguageExtraLight200,
        trackHeight: CGFloat = 3.0,
        cardFillColor: Color = AppTheme.Color.settingsCardSurface
    ) {
        self._usedCount = State(initialValue: usedCount)
        self._dailyLimit = State(initialValue: dailyLimit)
        self._loadFailed = State(initialValue: loadFailed)
        self.isPreviewInjected = true
        self.subtextStyle = subtextStyle
        self.trackHeight = trackHeight
        self.cardFillColor = cardFillColor
    }

    private var isLimitReached: Bool {
        guard let usedCount else { return false }
        return usedCount >= dailyLimit
    }

    private var sheetHeight: CGFloat {
        if usedCount == nil && loadFailed { return 295 }
        if isLimitReached { return loadFailed ? 395 : 365 }
        return 260
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                headerRow

                if usedCount == nil && loadFailed {
                    offlineEmptyCard
                } else {
                    usageCard

                    if isLimitReached {
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        feedbackCTAButton

                        if loadFailed {
                            offlineCachedNote
                                .padding(.top, AppTheme.Space.paddingXS)
                        }
                    } else if loadFailed {
                        offlineCachedNote
                            .padding(.top, AppTheme.Space.paddingS)
                    } else {
                        normalFooterNote
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.titleToContent)
            .padding(.bottom, AppTheme.Space.paddingPage)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Color.pageBg)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.Color.pageBg)
    }

    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.usageLimitSheetTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
        }
        .padding(.top, AppTheme.Space.paddingXS)
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingXS) {
                if let usedCount {
                    Text("\(usedCount)")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                } else if loadFailed {
                    Text("–")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    Text("0")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .hidden()
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.Color.textSecondary)
                        }
                }

                Text("/ \(dailyLimit) generations today")
                    .font(subtextStyle.font)
                    .foregroundStyle(subtextStyle.textColor)

                Spacer()
            }
            .frame(minHeight: AppTheme.Size.usageLimitQuotaRowMinHeight)

            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    // 底槽：3.0pt 时采用纯净通透纸感底槽 (opacity 0.20)；2.0pt 时吃原 0.30
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(trackHeight >= 3.0 ? 0.20 : 0.30))
                        .frame(height: trackHeight)
                    if usedCount != nil {
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                            .frame(
                                width: max(geo.size.width * ratio, trackHeight),
                                height: trackHeight
                            )
                    }
                }
            }
            .frame(height: trackHeight)
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(
            cornerRadius: AppTheme.Radius.large,
            fillColor: cardFillColor
        )
    }

    private var limitReachedText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("You've reached today's limit.")
                .font(AppTheme.Font.quotaReachedTitle)
                .foregroundStyle(AppTheme.Color.settingsRowText)

            Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                .font(AppTheme.Font.quotaReachedBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    private var feedbackCTAButton: some View {
        Button {} label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 14, weight: .medium))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.quotaFeedbackAction)
            }
            .foregroundStyle(AppTheme.Color.settingsRowText)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.usageLimitCTAHeight)
            .background(AppTheme.Color.settingsCardSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.cardBorder, lineWidth: AppTheme.Size.usageLimitCTABorderWidth)
            }
            .shadow(
                color: AppTheme.Shadow.pillContactColor,
                radius: AppTheme.Shadow.pillContactRadius,
                x: AppTheme.Shadow.pillContactX,
                y: AppTheme.Shadow.pillContactY
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var normalFooterNote: some View {
        Text("Your daily generations refresh every day at midnight.")
            .font(AppTheme.Font.settingsFormIntro)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    private var offlineCachedNote: some View {
        HStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: loadFailed ? "wifi.slash" : "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
            Text(loadFailed
                ? "You're offline. Showing last synced usage."
                : "Couldn't refresh. Showing last synced usage.")
                .font(AppTheme.Font.settingsFormIntro)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    private var offlineEmptyCard: some View {
        VStack(spacing: AppTheme.Space.paddingM) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 36, height: 36)

            VStack(spacing: AppTheme.Space.paddingXS) {
                Text("Couldn't check quota")
                    .font(AppTheme.Font.settingsDocumentTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("Check your connection and try again.")
                    .font(AppTheme.Font.settingsFormIntro)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {} label: {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.neutralFaint.opacity(0.4), in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 4)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity)
        .surfaceCard(
            cornerRadius: AppTheme.Radius.large,
            fillColor: AppTheme.Color.settingsCardSurface
        )
    }
}

// =====================================================================
// MARK: - 1:1 像素级系统 Sheet 仿真画板 (UsageLimitCanvasFrame)
// =====================================================================

/// 模拟真机 iPhone 16 (393 × 852) 视口下，真实弹出的底部 Sheet 效果
struct UsageLimitCanvasFrame<SheetContent: View>: View {
    let sheetHeight: CGFloat
    let title: String
    let subtitle: String
    @ViewBuilder let sheetContent: () -> SheetContent

    init(
        sheetHeight: CGFloat,
        title: String = "Daily limit",
        subtitle: String = "Usage Quota Sheet",
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
        self.sheetHeight = sheetHeight
        self.title = title
        self.subtitle = subtitle
        self.sheetContent = sheetContent
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 底层宿主界面模拟 (Tab1 暖纸底色 + 顶部微胶囊)
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 模拟 Tab1 顶部栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageGaugeIcon()
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .surfacePill(in: Circle())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                // 宿主背景模拟卡片
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.6))
                        .frame(height: 180)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.4))
                        .frame(height: 120)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.bottom, 60)

                Spacer()
            }

            // 2. 真实生产环境同款暖调暗色遮罩 (AppTheme.Color.scrimOverlay · neutral950 @ 25%)
            AppTheme.Color.scrimOverlay
                .ignoresSafeArea()

            // 3. 底部 Sheet 仿真容器 (严格对齐 iOS 17 原生圆角与物理阴影)
            ZStack(alignment: .top) {
                sheetContent()

                // 系统原生顶部拖拽把手指示条 (36×5pt)
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .frame(height: sheetHeight)
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
        .frame(width: 393, height: 852)
        .clipped()
    }
}

// =====================================================================
// MARK: - 全功能交互式实验室 (UsageLimitInteractiveLab)
// =====================================================================

struct UsageLimitInteractiveLab: View {
    @State private var selectedPreset: UsageLimitVisualState = .normalOnline
    @State private var dynamicCount: Double = 2
    @State private var isOfflineMode: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    /// 动态计算出的当前弹窗高度 (严格对齐生产口径 260pt / 365pt / 395pt / 295pt)
    private var computedHeight: CGFloat {
        if selectedPreset == .offlineEmpty {
            return 295
        }
        if selectedPreset == .loadingState {
            return 260
        }
        let count = Int(dynamicCount)
        if count >= 5 {
            return isOfflineMode ? 395 : 365
        } else {
            return 260
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部控制台 ──
            VStack(spacing: 10) {
                // 1. 预设状态胶囊选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(UsageLimitVisualState.allCases) { state in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    applyPreset(state)
                                }
                            } label: {
                                Text(state.shortTag)
                                    .font(.system(size: 11.5, weight: selectedPreset == state ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedPreset == state ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                    .foregroundStyle(selectedPreset == state ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedPreset == state ? AppTheme.Color.brandTint : AppTheme.Color.border,
                                            lineWidth: 0.8
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // 2. 动效滑块与网络开关 (滑块去红色，采用焦黑 settingsRowText)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("生成次数: \(Int(dynamicCount)) / 5")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.Color.settingsRowText)
                            Spacer()
                            Text(Int(dynamicCount) >= 5 ? "已达标展开 (365pt)" : "未满额度 (260pt)")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        }

                        Slider(value: $dynamicCount, in: 0...5, step: 1)
                            .tint(Int(dynamicCount) >= 5 ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                    }

                    Divider()
                        .frame(height: 28)

                    // 离线开关
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isOfflineMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isOfflineMode ? "wifi.slash" : "wifi")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isOfflineMode ? "离线" : "在线")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(isOfflineMode ? AppTheme.Color.neutralFaint.opacity(0.4) : AppTheme.Color.cardBg)
                        .foregroundStyle(isOfflineMode ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 3. 诊断信息条
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedPreset.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text(selectedPreset.diagnosisNotes)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) {
                Divider()
            }

            // ── 中间 1:1 真机满屏画布 (驱动像素级复刻副本) ──
            UsageLimitCanvasFrame(sheetHeight: computedHeight) {
                if selectedPreset == .offlineEmpty {
                    // 状态 05: 离线冷启空态 (295pt)
                    UsageLimitSheetProductionReplica(usedCount: nil, dailyLimit: 5, loadFailed: true)
                } else if selectedPreset == .loadingState {
                    // 状态 07: 首次加载过渡态 (包裹菊花 · 260pt)
                    UsageLimitSheetProductionReplica(usedCount: nil, dailyLimit: 5, loadFailed: false)
                } else {
                    // 动态次数实时驱动 (260pt ~ 365pt / 离线 395pt)
                    UsageLimitSheetProductionReplica(
                        usedCount: Int(dynamicCount),
                        dailyLimit: 5,
                        loadFailed: isOfflineMode
                    )
                }
            }
            .scaleEffect(0.92, anchor: .top)
            .frame(maxHeight: .infinity)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func applyPreset(_ state: UsageLimitVisualState) {
        selectedPreset = state
        if let count = state.usedCount {
            dynamicCount = Double(count)
        }
        isOfflineMode = state.isFailed
    }
}

// =====================================================================
// MARK: - 真实系统级底层 Sheet 唤起器 (UsageLimitSystemSheetLauncher)
// =====================================================================

/// 在真实 SwiftUI 运行环境中体验原生手势、拖拽阻尼与系统级过渡
struct UsageLimitSystemSheetLauncher: View {
    @State private var showSheet = false
    @State private var currentCount: Int = 2
    @State private var isOffline: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingSection) {
                // 模拟 Tab1 顶栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageLimitButton {
                        showSheet = true
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: AppTheme.Space.paddingM) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.Color.brandStrong)

                    Text("Tap the gauge button above or click below to present the real SwiftUI .sheet()")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // 快速调节次数
                    Stepper("Test Used Count: \(currentCount) / 5", value: $currentCount, in: 0...5)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Toggle("Simulate Offline Mode", isOn: $isOffline)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Button {
                        showSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Open Daily Limit Sheet")
                                .font(AppTheme.Font.ctaLabel)
                        }
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.Color.interactive, in: Capsule())
                        .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSheet) {
            UsageLimitSheet(usedCount: currentCount, dailyLimit: 5, initialLoadFailed: isOffline)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵 (全状态最新落地规范)
// =====================================================================

#Preview("00 · ★ 全状态交互实验室 (动效滑块 · 状态切换 · 规范诊断)") {
    UsageLimitInteractiveLab()
}

#Preview("01 · 状态 1: 正常在线未达标 (2/5 · 260pt · 纯正客观)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProductionReplica(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · 状态 2: 在线额度已用尽 (5/5 · 365pt · 细线胶囊)") {
    UsageLimitCanvasFrame(sheetHeight: 365) {
        UsageLimitSheetProductionReplica(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("03 · 状态 3: 离线未达标带缓存 (2/5 · 260pt · 弱网提示)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProductionReplica(usedCount: 2, dailyLimit: 5, loadFailed: true)
    }
}

#Preview("04 · 状态 4: 离线且达标带缓存 (5/5 · 395pt · 弱网提示)") {
    UsageLimitCanvasFrame(sheetHeight: 395) {
        UsageLimitSheetProductionReplica(usedCount: 5, dailyLimit: 5, loadFailed: true)
    }
}

#Preview("05 · 状态 5: 冷启动离线空状态 (–/5 · 295pt · 重试按钮)") {
    UsageLimitCanvasFrame(sheetHeight: 295) {
        UsageLimitSheetProductionReplica(usedCount: nil, dailyLimit: 5, loadFailed: true)
    }
}

#Preview("06 · 状态 6: 0次初始未用态 (0/5 · 260pt · 空轨道)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProductionReplica(usedCount: 0, dailyLimit: 5)
    }
}

#Preview("07 · 状态 7: 首次加载拉取中 (包裹菊花 · 260pt · 零跳变)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProductionReplica(usedCount: nil, dailyLimit: 5, loadFailed: false)
    }
}

#Preview("08 · 真实系统底层 Sheet (支持原生手势拖拽关闭)") {
    UsageLimitSystemSheetLauncher()
}

#Preview("09 · 严密验收: 状态01已加载 vs 状态07加载中 叠层零跳动透视比对") {
    ZStack {
        // 底层：状态 01 已加载 (2/5)
        UsageLimitCanvasFrame(sheetHeight: 260) {
            UsageLimitSheetProductionReplica(usedCount: 2, dailyLimit: 5)
        }

        // 顶层：状态 07 加载中 (菊花)，以 65% 半透明叠在上面，用于肉眼检视零跳变与光学对齐
        UsageLimitCanvasFrame(sheetHeight: 260) {
            UsageLimitSheetProductionReplica(usedCount: nil, dailyLimit: 5, loadFailed: false)
        }
        .opacity(0.65)
    }
}

// MARK: - 便捷探索视图组件

/// 方案 A：对齐 Settings Target language 字符样式 + 3.0pt 饱满通透微轨 (推荐版)
/// - 副文：Gothic A1 15pt ExtraLight 200 · settingsRowText 焦黑
/// - 底色：settingsCardSurface 纯净暖白
/// - 轨道：3.0pt 饱满通透微轨 (底槽 0.20 通透纸感)
struct UsageLimitSheetVariantA_3ptTrack: View {
    var usedCount: Int? = 2
    var dailyLimit: Int = 5
    var loadFailed: Bool = false

    var body: some View {
        UsageLimitSheetSettingsAligned(
            usedCount: usedCount,
            dailyLimit: dailyLimit,
            loadFailed: loadFailed,
            subtextStyle: .targetLanguageExtraLight200,
            trackHeight: 3.0,
            cardFillColor: AppTheme.Color.settingsCardSurface
        )
    }
}

/// 方案 A 便捷别名 (向后兼容)
typealias UsageLimitSheetVariantA_TargetLanguage = UsageLimitSheetVariantA_3ptTrack

/// 方案 A 变体：其余 100% 对齐方案 A，但轨道保持线上现状 2.0pt (对照版)
/// - 副文：Gothic A1 15pt ExtraLight 200 · settingsRowText 焦黑
/// - 底色：settingsCardSurface 纯净暖白
/// - 轨道：2.0pt 线上现状微线轨 (底槽 0.30 灰暗，端点 R1.0pt)
struct UsageLimitSheetVariantA_2ptTrack: View {
    var usedCount: Int? = 2
    var dailyLimit: Int = 5
    var loadFailed: Bool = false

    var body: some View {
        UsageLimitSheetSettingsAligned(
            usedCount: usedCount,
            dailyLimit: dailyLimit,
            loadFailed: loadFailed,
            subtextStyle: .targetLanguageExtraLight200,
            trackHeight: AppTheme.Size.usageLimitProgressBarHeight,
            cardFillColor: AppTheme.Color.settingsCardSurface
        )
    }
}

/// 方案 B：字重提升至 Regular (400) 扎实版
/// - 副文：Gothic A1 15pt Regular 400 · textSecondary
/// - 底色：settingsCardSurface 纯净暖白
/// - 轨道：3.0pt 饱满通透微轨
struct UsageLimitSheetVariantB_Regular400: View {
    var usedCount: Int? = 2
    var dailyLimit: Int = 5
    var loadFailed: Bool = false

    var body: some View {
        UsageLimitSheetSettingsAligned(
            usedCount: usedCount,
            dailyLimit: dailyLimit,
            loadFailed: loadFailed,
            subtextStyle: .regular400,
            trackHeight: 3.0,
            cardFillColor: AppTheme.Color.settingsCardSurface
        )
    }
}

// MARK: - 微距显微镜对比画板 (Macro Comparison View)

/// 专门针对微轨高度 (2.0pt vs 3.0pt) 与副文字重 (Light 300 vs ExtraLight 200 vs Regular 400) 的显微镜级检视
struct UsageLimitMacroComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 1. 进度微轨高度与端点圆角显微镜
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("1. 进度微轨高度对比 (Track Height & Clarity)")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Spacer()
                    Text("Macro 300% Zoom")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.Color.brandInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Color.brandWash, in: Capsule())
                }

                VStack(spacing: 16) {
                    // 2.0pt 线上现状
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("A. 线上现状: 2.0pt 极薄微线 (发灰发硬 · 像发丝横截面)")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Spacer()
                            Text("Height 2.0pt · Radius 1.0pt")
                                .font(.caption2.monospaced())
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }

                        // 1:1 实际尺寸
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.Color.neutralFaint.opacity(0.30))
                                .frame(height: 2.0)
                            Capsule()
                                .fill(AppTheme.Color.textSecondary)
                                .frame(width: 140, height: 2.0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 3x 放大效果
                        HStack(spacing: 8) {
                            Text("3x 放大视效:")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Color.textMuted)
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.Color.neutralFaint.opacity(0.30))
                                    .frame(height: 6.0)
                                Capsule()
                                    .fill(AppTheme.Color.textSecondary)
                                    .frame(width: 140, height: 6.0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(AppTheme.Color.warmGlassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 3.0pt 饱满通透微轨
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("B. 推荐微调: 3.0pt 饱满通透轨 (丰润胶囊端点 · 纯净通透纸感)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Color.brandInk)
                            Spacer()
                            Text("Height 3.0pt · Radius 1.5pt")
                                .font(.caption2.monospaced())
                                .foregroundStyle(AppTheme.Color.brandInk)
                        }

                        // 1:1 实际尺寸
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.Color.neutralFaint.opacity(0.20))
                                .frame(height: 3.0)
                            Capsule()
                                .fill(AppTheme.Color.textSecondary)
                                .frame(width: 140, height: 3.0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 3x 放大效果
                        HStack(spacing: 8) {
                            Text("3x 放大视效:")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Color.textMuted)
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.Color.neutralFaint.opacity(0.20))
                                    .frame(height: 9.0)
                                Capsule()
                                    .fill(AppTheme.Color.textSecondary)
                                    .frame(width: 140, height: 9.0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(AppTheme.Color.settingsCardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }
            }

            // 2. 副文字符排版样式对比
            VStack(alignment: .leading, spacing: 12) {
                Text("2. 副文字符排版样式对比 (/ 5 generations today)")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                VStack(spacing: 12) {
                    // 样式 1：线上现状 Light 300
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("现状: Gothic A1 15pt Light 300 · textSecondary")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.Color.textMuted)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("5").font(AppTheme.Font.quotaHeroNumber).foregroundStyle(AppTheme.Color.settingsRowText)
                                Text("/ 5 generations today")
                                    .font(AppTheme.Font.quotaSubtext)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                            }
                        }
                        Spacer()
                        Text("⚠️ 在白底上发虚发灰")
                            .font(.caption2)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                    .padding(14)
                    .background(AppTheme.Color.warmGlassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 样式 2：方案 A · 对齐 Target language (15pt ExtraLight 200 + settingsRowText)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("方案 A: Gothic A1 15pt ExtraLight 200 · settingsRowText 焦黑 (Target language 同款)")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.Color.brandInk)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("5").font(AppTheme.Font.quotaHeroNumber).foregroundStyle(AppTheme.Color.settingsRowText)
                                Text("/ 5 generations today")
                                    .font(Font.custom("GothicA1-ExtraLight", size: 15, relativeTo: .subheadline))
                                    .foregroundStyle(AppTheme.Color.settingsRowText)
                            }
                        }
                        Spacer()
                        Text("✨ 纤细工笔 · 近黑沉着")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.Color.brandInk)
                    }
                    .padding(14)
                    .background(AppTheme.Color.settingsCardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.Color.cardBorder, lineWidth: 0.5))

                    // 样式 3：方案 B · 提升字重至 Regular 400 (15pt Regular 400 + textSecondary)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("方案 B: Gothic A1 15pt Regular 400 · textSecondary (扎实稳健版)")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("5").font(AppTheme.Font.quotaHeroNumber).foregroundStyle(AppTheme.Color.settingsRowText)
                                Text("/ 5 generations today")
                                    .font(Font.custom("GothicA1-Regular", size: 15, relativeTo: .subheadline))
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                            }
                        }
                        Spacer()
                        Text("🛡️ 清晰扎实 · 零发虚")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    .padding(14)
                    .background(AppTheme.Color.settingsCardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }
            }
        }
        .padding(20)
        .background(AppTheme.Color.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - 真实设备预览容器 (无截断 · 贴底全展开)

/// 模拟真机 (iPhone 16/17 Pro) 真实底部 Sheet 贴底效果，绝不裁切内容
struct UsageLimitStandaloneDevicePreview<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            // 宿主背景
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack {
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageGaugeIcon()
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .surfacePill(in: Circle())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()
            }

            // 暗调蒙层
            AppTheme.Color.scrimOverlay.ignoresSafeArea()

            // 底部 Sheet 本体 (自然贴底，不固定死 500pt 导致截断)
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                content()
            }
            .frame(maxWidth: .infinity)
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
        .ignoresSafeArea(edges: .bottom)
    }
}

/// 纯净卡片走查容器 (用于多栏横向平铺对比，无多余大手机壳，零截断)
struct UsageLimitSheetCardPlate<Content: View>: View {
    let title: String
    let tag: String
    let tagColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text(tag)
                    .font(.caption2.bold())
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tagColor.opacity(0.12), in: Capsule())
            }

            content()
                .frame(width: 350)
                .background(AppTheme.Color.pageBg)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.Color.cardBorder, lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
        }
    }
}

// MARK: - Previews

#Preview("01 · ★ 方案 A (3.0pt 饱满轨): Target language 字符 + 暖白底 (推荐版)") {
    UsageLimitStandaloneDevicePreview {
        UsageLimitSheetVariantA_3ptTrack(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · ★ 方案 A 对照 (2.0pt 现状轨): 其余全为方案 A · 仅轨道保持现状 2.0pt") {
    UsageLimitStandaloneDevicePreview {
        UsageLimitSheetVariantA_2ptTrack(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("03 · ★ 方案 A 轨道 AB 对决: 3.0pt 饱满轨 (左) vs 2.0pt 现状轨 (右)") {
    ScrollView(.horizontal, showsIndicators: true) {
        HStack(alignment: .top, spacing: 24) {
            // 左：3.0pt 饱满轨
            UsageLimitSheetCardPlate(
                title: "方案 A · 3.0pt 饱满微轨",
                tag: "推荐 · 端点 R1.5pt",
                tagColor: AppTheme.Color.brandInk
            ) {
                UsageLimitSheetVariantA_3ptTrack(usedCount: 2, dailyLimit: 5)
            }

            // 右：2.0pt 现状轨
            UsageLimitSheetCardPlate(
                title: "方案 A · 2.0pt 现状微轨",
                tag: "对照 · 线上现状高度",
                tagColor: AppTheme.Color.textSecondary
            ) {
                UsageLimitSheetVariantA_2ptTrack(usedCount: 2, dailyLimit: 5)
            }
        }
        .padding(24)
    }
    .background(Color(white: 0.93))
}

#Preview("04 · 线上现状版: Light 300 发虚对照 (2.0pt轨 · 暗底)") {
    UsageLimitStandaloneDevicePreview {
        UsageLimitSheetProductionReplica(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("05 · 方案 A (3.0pt轨): 5/5 满额达标态 (展开说明与邀请码 CTA)") {
    UsageLimitStandaloneDevicePreview {
        UsageLimitSheetVariantA_3ptTrack(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("06 · 方案 A (2.0pt现状轨): 5/5 满额达标态 (展开说明与邀请码 CTA)") {
    UsageLimitStandaloneDevicePreview {
        UsageLimitSheetVariantA_2ptTrack(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("10 · 【全景平铺】方案 A (3.0pt) vs 方案 A (2.0pt) vs 线上现状 vs Settings真机") {
    ScrollView(.horizontal, showsIndicators: true) {
        HStack(alignment: .top, spacing: 24) {
            // 1. 方案 A (3.0pt 轨)
            UsageLimitSheetCardPlate(
                title: "1. 方案 A (3.0pt 轨)",
                tag: "3.0pt轨 / 暖白卡 / 焦黑200",
                tagColor: AppTheme.Color.brandInk
            ) {
                UsageLimitSheetVariantA_3ptTrack(usedCount: 2, dailyLimit: 5)
            }

            // 2. 方案 A 对照版 (2.0pt 现状轨)
            UsageLimitSheetCardPlate(
                title: "2. 方案 A (2.0pt 现状轨)",
                tag: "2.0pt轨 / 暖白卡 / 焦黑200",
                tagColor: AppTheme.Color.brandInk
            ) {
                UsageLimitSheetVariantA_2ptTrack(usedCount: 2, dailyLimit: 5)
            }

            // 3. 线上现状版
            UsageLimitSheetCardPlate(
                title: "3. 线上现状版",
                tag: "2.0pt轨 / 暗底 / 300发虚",
                tagColor: AppTheme.Color.textSecondary
            ) {
                UsageLimitSheetProductionReplica(usedCount: 2, dailyLimit: 5)
            }

            // 4. Settings 参照物
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("4. Settings 真实参照物")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Spacer()
                    Text("My language 分组卡")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Settings")
                        .font(AppTheme.Font.pageTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("My language")
                        .font(AppTheme.Font.settingsSectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.settingsSectionTitle)
                    VStack(spacing: 0) {
                        HStack {
                            Text("Target language").foregroundStyle(AppTheme.Color.settingsRowText)
                            Spacer()
                            Text("English").foregroundStyle(AppTheme.Color.textSecondary)
                        }
                        .padding(.vertical, 14)
                        Divider()
                        HStack {
                            Text("Native language").foregroundStyle(AppTheme.Color.settingsRowText)
                            Spacer()
                            Text("Chinese").foregroundStyle(AppTheme.Color.textSecondary)
                        }
                        .padding(.vertical, 14)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large, fillColor: AppTheme.Color.settingsCardSurface)
                }
                .padding(20)
                .frame(width: 350)
                .background(AppTheme.Color.pageBg)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.Color.cardBorder, lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
            }
        }
        .padding(24)
    }
    .background(Color(white: 0.93))
}

#Preview("11 · 【微距显微镜】微轨 (2.0pt vs 3.0pt) & 三种副文字重精准比对") {
    ScrollView {
        UsageLimitMacroComparisonView()
            .padding(20)
    }
    .background(Color(white: 0.92))
}

#endif

