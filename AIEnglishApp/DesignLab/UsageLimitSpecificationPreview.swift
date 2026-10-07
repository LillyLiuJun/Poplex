#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 官方规范级落地画板 (方案 A · 包含全 7 状态与按钮颜色体系)
// =====================================================================
// 🎯 核心规范规格 (Single Source of Truth · 方案 A):
//   1. 顶栏定力：Charter 22pt Bold (AppTheme.Font.usageLimitSheetTitleSerif)，
//      彻底对齐 Tab2 章节定力与 Settings 大标题气场，纯净留白无冗余关闭键；
//   2. 计数卡片底色：AppTheme.Color.settingsCardSurface (纯净暖白 #FFFFFF)，
//      替换旧版半透明暗底，与 Settings 分组卡片、Tab2 核心内容卡片质感 100% 统一；
//   3. 计数副文：Gothic A1 15pt ExtraLight 200 + 焦墨 settingsRowText (#0A0705)，
//      与 Settings 页面 Target language 等行内文本规格完全一致，笔画清晰锐利；
//   4. 进度微轨：3.0pt 饱满通透连续微线轨 (底槽 opacity 0.20，滑轨 3.0pt 饱满圆角)，
//      兼顾极简通透与视网膜清晰可见性；
//   5. CTA 按钮色彩专项 (注意这个按钮的颜色使用)：
//      - 选型 1 (推荐 · 焦墨沉稳实心胶囊 Solid Charcoal)：深焦黑底 + 暖白字，与 22pt Bold 顶栏呼应，
//        作为主操作压轴承托，彻底解决原白底线框按钮“发虚、像输入框、与白卡片混淆”的问题；
//      - 选型 2 (现状精修 · 纯净暖白描边胶囊 Refined Bordered White)：暖白底 + 16% 焦黑描边，保持轻盈；
//      - 选型 3 (品牌暖橙活力胶囊 Brand Orange Accent)：#FF7622 品牌活力橙底 + 白字，正向权益赋能；
//      - 选型 4 (温润暖灰次级胶囊 Soft Neutral Secondary)：柔和浅暖灰底 + 焦黑字，柔和中性。
//   6. 全 7 种状态全覆盖：01 在线未满、02 在线满额、03 离线未满、04 离线满额、
//      05 冷启离线空态、06 初始零使用、07 包裹菊花过渡态 (零跳变)；
//   7. 弹窗高度标准：未满 260pt、在线满额 365pt、离线满额 395pt、离线空态 295pt。
// =====================================================================

// =====================================================================
// MARK: - 1. 业务状态与按钮配色枚举
// =====================================================================

/// Daily Limit 全 7 种业务视觉状态
enum UsageLimitSpecState: String, CaseIterable, Identifiable {
    case normalOnline         = "01 · 正常在线未达标 (2/5 · 260pt)"
    case limitReached         = "02 · 在线满额达标 (5/5 · 365pt · 展开说明与CTA)"
    case offlineCacheNormal   = "03 · 离线未达标带缓存 (2/5 · 260pt · 弱网注记)"
    case offlineCacheReached  = "04 · 离线且满额达标 (5/5 · 395pt · 展开说明+弱网注记)"
    case offlineEmpty         = "05 · 冷启动离线空态 (–/5 · 295pt · Try again按钮)"
    case zeroInitial          = "06 · 初始零使用状态 (0/5 · 260pt · 空轨道)"
    case loadingState         = "07 · 网络加载过渡态 (包裹菊花 · 260pt · 零跳变)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .normalOnline:        return "2/5 在线"
        case .limitReached:        return "5/5 满额"
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

    var diagnosisNote: String {
        switch self {
        case .normalOnline:
            return "【正常在线未满】：高度 260pt。Charter 22pt Bold 顶栏 + settingsCardSurface 暖白卡片 + ExtraLight 200 焦黑副文 + 3.0pt 饱满微线轨。"
        case .limitReached:
            return "【在线额度用尽】：高度 365pt。去焦虑深焦黑客观陈述 + 44pt 主操作 CTA 按钮，拉开层级、压轴呼应。"
        case .offlineCacheNormal:
            return "【离线未满带缓存】：高度 260pt。本地缓存显示 2/5 与微线轨，底部追加严格 16pt 左对齐的 wifi.slash 弱网注记。"
        case .offlineCacheReached:
            return "【离线满额带缓存】：高度 395pt。包含邀请码 CTA 胶囊与弱网注记，舒展匀称无拥挤感。"
        case .offlineEmpty:
            return "【冷启动离线空态】：高度收敛为 295pt。暖白主卡片展示 36pt 中灰图标、Charter 20pt 标题与规范的 Try again 胶囊按钮。"
        case .zeroInitial:
            return "【初始零使用】：高度 260pt。展示 0 / 5，3.0pt 底槽通透空白，底部显示零点自动刷新出版物注记。"
        case .loadingState:
            return "【网络加载过渡态】：高度 260pt。采用隐藏 Text(\"0\") 基线包裹占位，菊花精密锁定中线，加载完毕替换数字零跳动。"
        }
    }
}

/// 申请邀请码 CTA 按钮颜色样式选型
enum UsageLimitCTAColorStyle: String, CaseIterable, Identifiable {
    case solidCharcoal      = "选型 1 · 沉稳焦墨实心 (推荐 · 对齐 Feedback)"
    case borderedWarmWhite  = "选型 2 · 纯净暖白描边 (现状精修 · 强化轮廓)"
    case brandOrange        = "选型 3 · 品牌暖橙活力 (正向权益赋能)"
    case softNeutral        = "选型 4 · 温润暖灰次级 (低饱和中性过渡)"

    var id: String { rawValue }

    var badgeText: String {
        switch self {
        case .solidCharcoal:     return "沉稳焦墨 (推荐)"
        case .borderedWarmWhite: return "暖白细描边"
        case .brandOrange:       return "品牌活力橙"
        case .softNeutral:       return "温润暖灰底"
        }
    }

    var rationaleDescription: String {
        switch self {
        case .solidCharcoal:
            return "【推荐理由】：底色采用沉稳深焦黑 (#0A0705)，文字图标为暖白 (#FFFDFB)。与 22pt Bold 顶栏及 Settings/Feedback 提交键形成上下呼应，在白卡片与米色背景下方压轴定势，明确指示“核心主动操作”，彻底告别像输入框或发白无力的视觉缺陷。"
        case .borderedWarmWhite:
            return "【现状加固】：底色为纯净暖白，描边由 0.35 发虚线提升为 16% 焦黑清晰线。极度轻盈，但与上方白卡片同色，仍有一定弱化可能。"
        case .brandOrange:
            return "【品牌赋能】：底色为种子橙 #FF7622，文字纯白。在用户额度耗尽的受挫时刻，以温暖明亮的品牌色提供“获取新额度”的积极出口。"
        case .softNeutral:
            return "【次级中性】：底色为 neutral100 柔和浅暖灰，描边为 neutral200。介于黑底与白底之间，与纯白卡片自然分离层级。"
        }
    }

    // 视觉样式属性配置
    var backgroundColor: Color {
        switch self {
        case .solidCharcoal:     return AppTheme.Color.interactive
        case .borderedWarmWhite: return AppTheme.Color.settingsCardSurface
        case .brandOrange:       return AppTheme.Color.brandStrong
        case .softNeutral:       return AppTheme.Color.controlDisabledBg
        }
    }

    var foregroundColor: Color {
        switch self {
        case .solidCharcoal, .brandOrange:
            return AppTheme.Color.textOnChip
        case .borderedWarmWhite, .softNeutral:
            return AppTheme.Color.settingsRowText
        }
    }

    var borderColor: Color {
        switch self {
        case .solidCharcoal:     return Color.clear
        case .borderedWarmWhite: return AppTheme.Color.settingsRowText.opacity(0.16)
        case .brandOrange:       return Color.clear
        case .softNeutral:       return AppTheme.Color.border
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .solidCharcoal, .brandOrange: return 0
        case .borderedWarmWhite:           return 0.9
        case .softNeutral:                 return 0.8
        }
    }

    var shadowColor: Color {
        switch self {
        case .solidCharcoal:
            return Color.black.opacity(0.12)
        case .borderedWarmWhite:
            return AppTheme.Shadow.pillContactColor
        case .brandOrange:
            return AppTheme.Color.brandStrong.opacity(0.24)
        case .softNeutral:
            return Color.black.opacity(0.04)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .solidCharcoal: return 6
        case .borderedWarmWhite: return AppTheme.Shadow.pillContactRadius
        case .brandOrange: return 8
        case .softNeutral: return 3
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .solidCharcoal: return 2
        case .borderedWarmWhite: return AppTheme.Shadow.pillContactY
        case .brandOrange: return 3
        case .softNeutral: return 1
        }
    }
}

// =====================================================================
// MARK: - 2. 方案 A 官方规范级组件 (UsageLimitSpecSheet)
// =====================================================================

struct UsageLimitSpecSheet: View {
    let state: UsageLimitSpecState
    var ctaStyle: UsageLimitCTAColorStyle = .solidCharcoal
    var customUsedCount: Int? = nil

    private var effectiveUsedCount: Int? {
        customUsedCount ?? state.usedCount
    }

    private var isLimitReached: Bool {
        guard let count = effectiveUsedCount else { return false }
        return count >= 5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                // 1. 顶栏：Charter 22pt Bold (usageLimitSheetTitleSerif) · 纯净留白无冗余关闭键
                headerRow

                if state == .offlineEmpty {
                    // 状态 05：冷启动离线空状态卡片 (295pt)
                    offlineEmptyCard
                } else {
                    // 状态 01 / 02 / 03 / 04 / 06 / 07：主计数卡片 (方案 A 规范)
                    usageCard

                    if isLimitReached {
                        // 达标说明文案 (去焦虑、沉稳客观排版)
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        // 申请邀请码 CTA 按钮 (支持 4 种颜色样式，默认推荐沉稳焦墨)
                        feedbackCTAButton

                        if state.isFailed {
                            // 离线且达标弱网注记
                            offlineCachedNote
                                .padding(.top, 2)
                        }
                    } else if state.isFailed {
                        // 离线未达标弱网注记
                        offlineCachedNote
                            .padding(.top, 2)
                    } else {
                        // 正常未达标脚注
                        normalFooterNote
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingCard)
            .padding(.bottom, AppTheme.Space.paddingScreenBottom)
        }
        .scrollDisabled(true)
    }

    // ── 内部各模块视图 ──

    /// 1. 顶栏：Charter 22pt Bold
    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.usageLimitSheetTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Spacer()
        }
    }

    /// 2. 主计数卡片 (方案 A 核心规范：settingsCardSurface 纯白底 + 200 焦黑副文 + 3.0pt 饱满微线轨)
    private var usageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            // 数字 + 副文字行 (保底行高 30pt，零跳变)
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingXS) {
                if let count = effectiveUsedCount {
                    Text("\(count)")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                } else if state.isFailed {
                    Text("–")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    // 包裹菊花过渡态 (状态 07)
                    Text("0")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .hidden()
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.Color.textSecondary)
                        }
                }

                // 副文：方案 A (Gothic A1 15pt ExtraLight 200 + 焦黑 settingsRowText)
                Text("/ 5 generations today")
                    .font(Font.custom("GothicA1-ExtraLight", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.settingsRowText)

                Spacer()
            }
            .frame(minHeight: AppTheme.Size.usageLimitQuotaRowMinHeight)

            // 进度微轨：3.0pt 饱满通透连续微线轨
            GeometryReader { geo in
                let ratio = min(max(CGFloat(effectiveUsedCount ?? 0) / 5.0, 0), 1.0)
                let trackHeight: CGFloat = 3.0

                ZStack(alignment: .leading) {
                    // 通透底槽 (opacity 0.20 暖中灰)
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.20))
                        .frame(height: trackHeight)

                    if effectiveUsedCount != nil {
                        // 饱满滑轨 (满额焦黑，未满中灰)
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                            .frame(
                                width: max(geo.size.width * ratio, trackHeight),
                                height: trackHeight
                            )
                    }
                }
            }
            .frame(height: 3.0)
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(
            cornerRadius: AppTheme.Radius.large,
            fillColor: AppTheme.Color.settingsCardSurface
        )
    }

    /// 3. 达标说明文案
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

    /// 4. 申请邀请码 CTA 按钮 (支持 4 种颜色形态)
    private var feedbackCTAButton: some View {
        Button {} label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 14, weight: .medium))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.quotaFeedbackAction)
            }
            .foregroundStyle(ctaStyle.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.usageLimitCTAHeight)
            .background(ctaStyle.backgroundColor, in: Capsule())
            .overlay {
                if ctaStyle.borderWidth > 0 {
                    Capsule()
                        .stroke(ctaStyle.borderColor, lineWidth: ctaStyle.borderWidth)
                }
            }
            .shadow(
                color: ctaStyle.shadowColor,
                radius: ctaStyle.shadowRadius,
                x: 0,
                y: ctaStyle.shadowY
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// 5. 正常脚注 (左对齐出版物注记风)
    private var normalFooterNote: some View {
        Text("Your daily generations refresh every day at midnight.")
            .font(AppTheme.Font.settingsFormIntro)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 6. 弱网注记
    private var offlineCachedNote: some View {
        HStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .medium))
            Text("You're offline. Showing last synced usage.")
                .font(AppTheme.Font.settingsFormIntro)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 7. 冷启动离线空态卡片 (状态 05)
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

            // Try again 按钮 (规范胶囊)
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
                .background(AppTheme.Color.neutralFaint.opacity(0.35), in: Capsule())
                .overlay(Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8))
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
// MARK: - 3. 稳健无截断画板基座 (Spec Preview Plates)
// =====================================================================

/// 独立全景卡片画板基座 (杜绝任何边缘截断，支持平铺走查)
struct UsageLimitSpecPlate<Content: View>: View {
    let title: String
    let subtitle: String
    let height: CGFloat
    let tag: String
    var tagColor: Color = AppTheme.Color.brandInk
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶注标签
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Spacer()

                Text(tag)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tagColor.opacity(0.12), in: Capsule())
            }

            // 仿真贴底 Sheet 容器
            ZStack(alignment: .top) {
                content()

                // 系统原生把手
                Capsule()
                    .fill(Color.secondary.opacity(0.30))
                    .frame(width: 36, height: 4.5)
                    .padding(.top, 8)
            }
            .frame(width: 360, height: height)
            .background(AppTheme.Color.pageBg)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.large,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: AppTheme.Radius.large,
                style: .continuous
            ))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: AppTheme.Radius.large,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: AppTheme.Radius.large,
                    style: .continuous
                )
                .stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
        }
        .padding(14)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }
}

/// 仿真真机 1:1 独立弹窗贴底视口 (不截断、带遮罩)
struct UsageLimitSpecDeviceFrame<Content: View>: View {
    let sheetHeight: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        sheetHeight: CGFloat = 365,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sheetHeight = sheetHeight
        self.content = content
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 宿主背景
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack {
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
                    Spacer()
                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Spacer()
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        )
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 14)

                Spacer()
            }

            // 暖调遮罩
            AppTheme.Color.scrimOverlay
                .ignoresSafeArea()

            // 贴底弹窗
            ZStack(alignment: .top) {
                content()

                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .frame(width: 393, height: sheetHeight)
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
// MARK: - 4. 交互式沙箱实验室 (UsageLimitSpecLab)
// =====================================================================

struct UsageLimitSpecLab: View {
    @State private var selectedState: UsageLimitSpecState = .limitReached
    @State private var ctaStyle: UsageLimitCTAColorStyle = .solidCharcoal
    @State private var dynamicCount: Double = 5
    @State private var isOffline: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    private var currentSheetHeight: CGFloat {
        if selectedState == .offlineEmpty { return 295 }
        if selectedState == .loadingState { return 260 }
        let count = Int(dynamicCount)
        if count >= 5 {
            return isOffline ? 395 : 365
        } else {
            return 260
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 控制面板
            VStack(spacing: 12) {
                // 1. 状态选择胶囊
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(UsageLimitSpecState.allCases) { state in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    selectedState = state
                                    if let c = state.usedCount { dynamicCount = Double(c) }
                                    isOffline = state.isFailed
                                }
                            } label: {
                                Text(state.shortTag)
                                    .font(.system(size: 11.5, weight: selectedState == state ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedState == state ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                    .foregroundStyle(selectedState == state ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedState == state ? AppTheme.Color.brandTint : AppTheme.Color.border,
                                            lineWidth: 0.8
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // 2. 按钮颜色选择胶囊 (重点走查)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CTA 按钮颜色选型走查:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                        Spacer()
                        Text(ctaStyle.badgeText)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.brandInk)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(UsageLimitCTAColorStyle.allCases) { style in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        ctaStyle = style
                                    }
                                } label: {
                                    Text(style.badgeText)
                                        .font(.system(size: 11, weight: ctaStyle == style ? .bold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(ctaStyle == style ? AppTheme.Color.settingsRowText : AppTheme.Color.cardBg)
                                        .foregroundStyle(ctaStyle == style ? AppTheme.Color.textOnChip : AppTheme.Color.textSecondary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(AppTheme.Color.border, lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }

                // 3. 滑块与网络切换
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("生成次数: \(Int(dynamicCount)) / 5")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                        Slider(value: $dynamicCount, in: 0...5, step: 1)
                            .tint(Int(dynamicCount) >= 5 ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                    }

                    Divider().frame(height: 28)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isOffline.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isOffline ? "wifi.slash" : "wifi")
                            Text(isOffline ? "离线" : "在线")
                        }
                        .font(.system(size: 11.5, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOffline ? AppTheme.Color.neutralFaint.opacity(0.4) : AppTheme.Color.cardBg)
                        .foregroundStyle(isOffline ? AppTheme.Color.textPrimary : AppTheme.Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
            .padding(.vertical, 10)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) { Divider() }

            // 仿真画板
            ScrollView {
                VStack(spacing: 16) {
                    UsageLimitSpecPlate(
                        title: selectedState.shortTag,
                        subtitle: "当前实机高度: \(Int(currentSheetHeight))pt",
                        height: currentSheetHeight,
                        tag: ctaStyle.badgeText,
                        tagColor: AppTheme.Color.brandInk
                    ) {
                        UsageLimitSpecSheet(
                            state: selectedState,
                            ctaStyle: ctaStyle,
                            customUsedCount: Int(dynamicCount)
                        )
                    }
                    .padding(.top, 16)

                    // 设计选型说明卡
                    VStack(alignment: .leading, spacing: 8) {
                        Text("【当前按钮设计哲学与配色参数】")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                        Text(ctaStyle.rationaleDescription)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: 360, alignment: .leading)
                    .background(AppTheme.Color.settingsCardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.Color.cardBorder, lineWidth: 0.8))
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }
}

// =====================================================================
// MARK: - 5. Xcode Canvas Previews (全状态及按钮专项走查矩阵)
// =====================================================================

// ── 00 · 重点：4 种 CTA 按钮配色方案横向对比走查 ──
#Preview("00 · 【按钮专项】4 种 CTA 按钮配色方案实机横向走查") {
    ScrollView(.horizontal, showsIndicators: true) {
        HStack(alignment: .top, spacing: 20) {
            ForEach(UsageLimitCTAColorStyle.allCases) { style in
                VStack(alignment: .leading, spacing: 10) {
                    UsageLimitSpecPlate(
                        title: style.badgeText,
                        subtitle: "高度: 365pt · 满额展开态",
                        height: 365,
                        tag: style == .solidCharcoal ? "★ 推荐选型" : "对比选型",
                        tagColor: style == .solidCharcoal ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary
                    ) {
                        UsageLimitSpecSheet(
                            state: .limitReached,
                            ctaStyle: style
                        )
                    }

                    // 说明卡片
                    VStack(alignment: .leading, spacing: 6) {
                        Text(style.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                        Text(style.rationaleDescription)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(width: 360, alignment: .leading)
                    .background(AppTheme.Color.settingsCardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.Color.cardBorder, lineWidth: 0.8))
                }
            }
        }
        .padding(24)
    }
    .background(Color(white: 0.93))
}

// ── 01 · 方案 A 规范下的全部 7 种状态平铺总览 ──
#Preview("01 · 【全态画板】方案 A 规范下的全部 7 种状态平铺总览") {
    ScrollView(.horizontal, showsIndicators: true) {
        HStack(alignment: .top, spacing: 20) {
            ForEach(UsageLimitSpecState.allCases) { state in
                UsageLimitSpecPlate(
                    title: state.shortTag,
                    subtitle: "\(Int(state.sheetHeight))pt · 方案 A 规范",
                    height: state.sheetHeight,
                    tag: "方案 A",
                    tagColor: AppTheme.Color.brandInk
                ) {
                    UsageLimitSpecSheet(
                        state: state,
                        ctaStyle: .solidCharcoal
                    )
                }
            }
        }
        .padding(24)
    }
    .background(Color(white: 0.92))
}

// ── 02 · 单机真机：状态 02 在线满额达标 (推荐焦墨实心胶囊 · 365pt) ──
#Preview("02 · 【真机视口】状态 02 在线满额达标 (推荐焦墨实心胶囊 · 365pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 365) {
        UsageLimitSpecSheet(
            state: .limitReached,
            ctaStyle: .solidCharcoal
        )
    }
}

// ── 03 · 单机真机：状态 02 在线满额达标 (纯净暖白描边胶囊 · 365pt) ──
#Preview("03 · 【真机视口】状态 02 在线满额达标 (纯净暖白描边胶囊 · 365pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 365) {
        UsageLimitSpecSheet(
            state: .limitReached,
            ctaStyle: .borderedWarmWhite
        )
    }
}

// ── 04 · 单机真机：状态 01 正常在线未达标 (2/5 · 260pt) ──
#Preview("04 · 【真机视口】状态 01 正常在线未达标 (2/5 · 260pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 260) {
        UsageLimitSpecSheet(
            state: .normalOnline,
            ctaStyle: .solidCharcoal
        )
    }
}

// ── 05 · 单机真机：状态 04 离线满额带缓存 (5/5 · 395pt) ──
#Preview("05 · 【真机视口】状态 04 离线满额带缓存 (5/5 · 395pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 395) {
        UsageLimitSpecSheet(
            state: .offlineCacheReached,
            ctaStyle: .solidCharcoal
        )
    }
}

// ── 06 · 单机真机：状态 05 冷启动离线空态 (–/5 · 295pt) ──
#Preview("06 · 【真机视口】状态 05 冷启动离线空态 (–/5 · 295pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 295) {
        UsageLimitSpecSheet(
            state: .offlineEmpty,
            ctaStyle: .solidCharcoal
        )
    }
}

// ── 07 · 单机真机：状态 07 网络加载过渡态 (包裹菊花 · 260pt) ──
#Preview("07 · 【真机视口】状态 07 网络加载过渡态 (包裹菊花 · 260pt)") {
    UsageLimitSpecDeviceFrame(sheetHeight: 260) {
        UsageLimitSpecSheet(
            state: .loadingState,
            ctaStyle: .solidCharcoal
        )
    }
}

// ── 08 · 交互式动态沙箱 ──
#Preview("08 · 【动态沙箱】全功能交互式沙箱 (支持滑动次数/离线模式/一键切按钮颜色)") {
    UsageLimitSpecLab()
}

#endif
