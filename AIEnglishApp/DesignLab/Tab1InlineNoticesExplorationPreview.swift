#if DEBUG
import SwiftUI
import UIKit
import Combine

// =====================================================================
// MARK: - Tab1 行内提示全景对比画板 (Tab1 Inline Notices Full Panorama)
// =====================================================================
// 🎯 核心原则：
//   1. 尊重现网布局与对齐习惯：发送失败严格保持【右对齐 (Trailing)】，合规说明保持【居中 (Center)】。
//   2. 绝不遗漏：全面完整展示全网全部真实出现的 6 个行内情况分支。
//   3. 极克制微优化：去纯红报警色、去施工三角感叹号、文案单行化，保持结构 100% 不变。

/// 6 种真实行内场景枚举
enum Tab1InlineScenario: String, CaseIterable, Identifiable {
    case sendFailedText = "01 · 纯文字发送失败 (SendFailedRow · Text)"
    case sendFailedImage = "02 · 带图发送失败 (SendFailedRow · Image)"
    case pendingRetry = "03 · 断网暂存待重试 (PendingRetryRow · Photo)"
    case rejectedText = "04-A · 纯文本敏感合规拦截 (UserRejected · Text Only)"
    case rejectedImage = "04-B · 图片敏感违规拦截 (UserRejected · Image Blocked)"
    case limitReached = "05 · 每日额度用尽横幅 (InputBar · Limit Banner)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .sendFailedText: return "01 · 纯文字发送失败"
        case .sendFailedImage: return "02 · 带图发送失败"
        case .pendingRetry: return "03 · 断网暂存待重试"
        case .rejectedText: return "04-A · 纯文本合规拦截"
        case .rejectedImage: return "04-B · 图片合规拦截"
        case .limitReached: return "05 · 每日额度用尽横幅"
        }
    }

    var alignmentRule: String {
        switch self {
        case .sendFailedText, .sendFailedImage, .pendingRetry:
            return "👉 严格右对齐 (Trailing) · 紧贴用户气泡右下"
        case .rejectedText, .rejectedImage:
            return "👉 气泡靠右，说明文字统一右对齐 (Trailing) · 贴合气泡下沿 (现网原版为居中)"
        case .limitReached:
            return "🔝 居中全宽悬挂 (Center) · 悬浮于 InputBar 顶部"
        }
    }

    var triggerDetails: String {
        switch self {
        case .sendFailedText:
            return "【触发时机】用户输入文字发送后，因断网或超时未收到卡片（走 TodayViewModel:816 catch）。\n【现网代码】Today/Components/MessageRow.swift -> SendFailedRow"
        case .sendFailedImage:
            return "【触发时机】用户拍摄/选取照片并发送，网络中断导致图文均未送达。\n【现网代码】Today/Components/MessageRow.swift -> SendFailedRow (前置用户图片)"
        case .pendingRetry:
            return "【触发时机】断网时拍摄的照片暂存在本地 SQLite 队列中，冷启动拉取历史时被注入时间线。\n【现网代码】Today/Components/MessageRow.swift -> PendingRetryRow"
        case .rejectedText:
            return "【触发时机】纯文本触发 AI 敏感拦截（AIServiceError.contentBlocked）。文字保留在黑色气泡中，无灰色方块！\n【现网代码】Today/Components/MessageRow.swift -> UserRejectedRow (wasImage == false)"
        case .rejectedImage:
            return "【触发时机】上传的照片被 AI 视觉安全模型拦截。原图片抹去转为 120x120 浅灰方块，下方带居中说明。\n【现网代码】Today/Components/MessageRow.swift -> UserRejectedRow (wasImage == true)"
        case .limitReached:
            return "【触发时机】当日 5 次生成额度用光（返回 429），InputBar 锁定置灰，顶部挂出微横幅导向设置页。\n【现网代码】Today/Components/InputBar.swift -> InputBarLimitBanner"
        }
    }
}

// =====================================================================
// MARK: - 基础原子组件 (1:1 现网原版 vs 微优化版)
// =====================================================================

/// 模拟用户拍摄的照片原图 (真图渲染，100% 对齐现网 UserBubble 原图呈现，非占位灰块)
struct MockUserPhotoThumbnail: View {
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.86, green: 0.80, blue: 0.72), Color(red: 0.70, green: 0.62, blue: 0.54)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // 逼真的拉花咖啡日常照片细节 (证明这是用户的真实原图)
            Circle()
                .fill(Color(red: 0.96, green: 0.93, blue: 0.88))
                .frame(width: size * 0.72, height: size * 0.72)
            Circle()
                .fill(Color(red: 0.46, green: 0.32, blue: 0.20))
                .frame(width: size * 0.48, height: size * 0.48)
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.18))
                .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

/// 1 & 2. 发送失败行 (SendFailedRow) —— 坚决右对齐
struct SendFailedRowUnit: View {
    let isRefined: Bool
    var onRetry: () -> Void = {}

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: AppTheme.Space.paddingXS) {
                if isRefined {
                    // 🌟 微优化版：温润顺时针小箭头 + 保持原色 (danger) + 完整连贯单句 (明确网络归因与行动)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Check your connection and try again.")
                        .font(AppTheme.Font.chineseFaint)
                } else {
                    // 🔴 现网线上版：纯红 + 感叹号旋转标
                    Image(systemName: "exclamationmark.arrow.circlepath")
                        .imageScale(.small)
                    Text("No connection — tap to retry.")
                        .font(AppTheme.Font.chineseFaint)
                }
            }
            .foregroundStyle(AppTheme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .trailing) // 👈 严格右对齐
            .padding(.vertical, AppTheme.Space.paddingXS)
        }
        .buttonStyle(.plain)
    }
}

/// 3. 断网待重试行 (PendingRetryRow) —— 坚决右对齐
struct PendingRetryRowUnit: View {
    let isRefined: Bool
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingXS) {
            // 上方右侧 120x120 用户真实照片原图 + "Describe this image" 气泡 (对齐现网)
            VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
                MockUserPhotoThumbnail(size: 120)

                Text("Describe this image")
                    .font(AppTheme.Font.englishBody)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.Color.bubbleUserBg)
                    .foregroundStyle(AppTheme.Color.bubbleUserText)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }

            // 下方失败行 (严格右对齐)
            Button(action: onRetry) {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    if isRefined {
                        // 🌟 微优化版：统一文案 + 完整连贯单句 + 明确网络归因 (与发送失败完全一致)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Check your connection and try again.")
                            .font(AppTheme.Font.chineseFaint)
                    } else {
                        // 🔴 现网线上版：纯红 + 57字符易挤压折行
                        Image(systemName: "exclamationmark.arrow.circlepath")
                            .imageScale(.small)
                        Text("You were offline, so this wasn't generated. Tap to retry.")
                            .font(AppTheme.Font.chineseFaint)
                    }
                }
                .foregroundStyle(AppTheme.Color.danger)
                .frame(maxWidth: .infinity, alignment: .trailing) // 👈 严格右对齐
                .padding(.vertical, AppTheme.Space.paddingXS)
            }
            .buttonStyle(.plain)
        }
    }
}

/// 4-A & 4-B. 内容合规拦截 (UserRejectedRow) —— 气泡/方块在右，文字整行居中
struct UserRejectedRowUnit: View {
    let isRefined: Bool
    let wasImage: Bool
    let text: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
            // 文本原样保留在深色气泡中 (靠右)
            if let text, !text.isEmpty {
                HStack {
                    Spacer(minLength: AppTheme.Space.paddingHero)
                    Text(text)
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.bubbleUserText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Color.bubbleUserBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
            }

            // 违规图片抹除转为 120x120 浅灰方块 (仅当 wasImage == true 时出现，靠右)
            // 100% 复用线上生产 ImageLoadFailedPlaceholder 原版样式：无文字，纯粹小三角 (16pt)
            if wasImage {
                HStack {
                    Spacer()
                    ImageLoadFailedPlaceholder()
                        .frame(width: 120, height: 120)
                }
            }

            // 下方单行轻提示 (微优化版：仅保留前半句客观陈述 + 统一右对齐紧贴气泡)
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "info.circle")
                    .imageScale(.small)
                Text(isRefined ? "This content can't be processed." : "This content can't be processed. Try another one.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: isRefined ? .trailing : .center) // 👈 微优化版右对齐，现网原版居中
        }
    }
}

/// 5. 每日额度横幅 (InputBarLimitBanner) —— 居中悬挂
struct LimitBannerUnit: View {
    let isRefined: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandInk)

                // 微优化版仅保留事实状态，删掉后半句冗长动作引导
                Text(isRefined ? "Daily limit reached (5/5)" : "Daily limit reached (5/5) · Request invite code")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: AppTheme.Space.paddingXS) {
                    Text("Settings")
                        .font(AppTheme.Font.metaNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: isRefined ? 8 : 40, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isRefined ? 8 : 40, style: .continuous)
                    .stroke(AppTheme.Color.border, lineWidth: 0.6)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// =====================================================================
// MARK: - 场景单项深度卡片 (展示在全景长卷中)
// =====================================================================

struct InlineScenarioPanoramaCard: View {
    let scenario: Tab1InlineScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 场景标题栏与对齐标签
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.shortTitle)
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(scenario.alignmentRule)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandInk)
                }
                Spacer()
            }

            // 触发说明信息条
            Text(scenario.triggerDetails)
                .font(AppTheme.Font.chineseFaint)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Color.pillNeutralBg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            // 上下竖排真实渲染区 (Top: 现网原版 -> Bottom: 微优化版，拥有 100% 完整屏幕宽度，彻底告别折行挤压)
            VStack(alignment: .leading, spacing: 14) {
                // 1. 上层：现网线上原版 (拥有全宽视口)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🔴 现网线上原版 (Production)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.danger)
                        Spacer()
                        Text("刺眼纯红 · 叹号旋转标 · 57字符长句")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }

                    scenarioContent(for: scenario, isRefined: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Color.pageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                }

                // 2. 下层：微优化建议版 (拥有全宽视口)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🌟 微优化建议版 (Refined)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandInk)
                        Spacer()
                        Text("保持右对齐 · 保持原色 danger · 清爽顺时针标 · 单行客观")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.brandInk)
                    }

                    scenarioContent(for: scenario, isRefined: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Color.pageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Color.brandInk.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Color.border, lineWidth: 0.6))
        .shadow(color: AppTheme.Shadow.cardColor, radius: 4, y: 2)
    }

    @ViewBuilder
    private func scenarioContent(for scenario: Tab1InlineScenario, isRefined: Bool) -> some View {
        switch scenario {
        case .sendFailedText:
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Spacer(minLength: 20)
                    Text("想形容街角咖啡馆里那只柴犬的毛色")
                        .font(AppTheme.Font.englishBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.Color.bubbleUserBg)
                        .foregroundStyle(AppTheme.Color.bubbleUserText)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                SendFailedRowUnit(isRefined: isRefined)
            }

        case .sendFailedImage:
            VStack(alignment: .trailing, spacing: AppTheme.Space.paddingXS) {
                // 上方用户真实照片原图 (100% 对齐现网 UserBubble 原图呈现)
                MockUserPhotoThumbnail(size: 96)
                HStack {
                    Spacer(minLength: 20)
                    Text("刚刚在公园拍下的落叶")
                        .font(AppTheme.Font.englishBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.Color.bubbleUserBg)
                        .foregroundStyle(AppTheme.Color.bubbleUserText)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                SendFailedRowUnit(isRefined: isRefined)
            }

        case .pendingRetry:
            PendingRetryRowUnit(isRefined: isRefined)

        case .rejectedText:
            UserRejectedRowUnit(
                isRefined: isRefined,
                wasImage: false,
                text: "一段包含敏感关键词的文本测试"
            )

        case .rejectedImage:
            UserRejectedRowUnit(
                isRefined: isRefined,
                wasImage: true,
                text: "看看这张照片能不能识别"
            )

        case .limitReached:
            LimitBannerUnit(isRefined: isRefined)
        }
    }
}

// =====================================================================
// MARK: - 整机全场景时间线连续流 (用于双机大对比)
// =====================================================================

struct Tab1FullTimelineFlowMock: View {
    let isRefined: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 顶栏 Header
                HStack {
                    Text("Wednesday, Sep 9")
                        .font(AppTheme.Font.pageTitleSerif)
                    Spacer()
                    Text(isRefined ? "🌟 微优化版" : "🔴 现网原版")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isRefined ? AppTheme.Color.brandWash : Color.red.opacity(0.12))
                        .foregroundStyle(isRefined ? AppTheme.Color.brandInk : AppTheme.Color.danger)
                        .clipShape(Capsule())
                }
                .padding(.top, 10)

                // 1. 纯文字发送失败 (右对齐)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Spacer(minLength: 40)
                        Text("想形容咖啡馆里的那只柴犬")
                            .font(AppTheme.Font.englishBody)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.Color.bubbleUserBg)
                            .foregroundStyle(AppTheme.Color.bubbleUserText)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    SendFailedRowUnit(isRefined: isRefined)
                }

                // 2. 带图发送失败 (用户原图 + 文字气泡 + 右对齐重试)
                VStack(alignment: .trailing, spacing: 4) {
                    MockUserPhotoThumbnail(size: 100)
                    HStack {
                        Spacer(minLength: 40)
                        Text("公园拍到的银杏叶")
                            .font(AppTheme.Font.englishBody)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.Color.bubbleUserBg)
                            .foregroundStyle(AppTheme.Color.bubbleUserText)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    SendFailedRowUnit(isRefined: isRefined)
                }

                // 3. 断网待重试行 (右对齐)
                PendingRetryRowUnit(isRefined: isRefined)

                // 4-A. 纯文本合规拦截 (文字在右，说明居中)
                UserRejectedRowUnit(
                    isRefined: isRefined,
                    wasImage: false,
                    text: "包含敏感违规词汇的内容"
                )

                // 4-B. 图片违规拦截 (方块在右，说明居中)
                UserRejectedRowUnit(
                    isRefined: isRefined,
                    wasImage: true,
                    text: "审核不通过的照片"
                )

                // 5. 额度达标微横幅 (居中悬浮)
                LimitBannerUnit(isRefined: isRefined)
                    .padding(.top, 10)
            }
            .padding(16)
        }
        .background(AppTheme.Color.pageBg)
    }
}

// =====================================================================
// MARK: - Previews 画板 (3 大核心视角，100% 展开所有情况)
// =====================================================================

/// 1. 🌟 全景完整大画板：全部 6 种情况逐项完整展开 (无需手动切换，一览无余！)
#Preview("🌟 全部 6 种情况全景完整画板 (逐项展开)") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Tab1 全部行内提示 (Inline Notices) 6 种情况全景大展开")
                    .font(AppTheme.Font.pageTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text("100% 覆盖线上真实代码分支 · 严格保持右对齐与居中规则 · 逐一并排对比")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingPage)

            // 6 张大卡片依次罗列
            ForEach(Tab1InlineScenario.allCases) { scenario in
                InlineScenarioPanoramaCard(scenario: scenario)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
        .padding(.bottom, 40)
    }
    .background(Color(white: 0.94))
}

/// 2. ⚖️ 双机完整时间线大对比：现网纯红版 vs 微优化克制版 (横屏真机全景流)
#Preview("⚖️ 双机完整时间线大对比 (全场景连续流)", traits: .landscapeLeft) {
    HStack(spacing: 24) {
        // 左机：现网线上版 (全部 6 种情况连续渲染)
        VStack(spacing: 8) {
            HStack {
                Text("🔴 现网线上版全流 (Production)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Color.danger)
                Spacer()
                Text("纯红报警 · 三角感叹号 · 冗长被动句")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(.horizontal, 10)

            Tab1FullTimelineFlowMock(isRefined: false)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.black.opacity(0.15), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .frame(width: 400, height: 740)

        // 右机：微优化版 (全部 6 种情况连续渲染)
        VStack(spacing: 8) {
            HStack {
                Text("🌟 微优化建议版全流 (Refined)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandInk)
                Spacer()
                Text("保持右对齐 · 保持原色 danger · 单行客观")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandInk)
            }
            .padding(.horizontal, 10)

            Tab1FullTimelineFlowMock(isRefined: true)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.black.opacity(0.15), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .frame(width: 400, height: 740)
    }
    .padding(24)
    .background(Color(white: 0.92))
}

#endif
