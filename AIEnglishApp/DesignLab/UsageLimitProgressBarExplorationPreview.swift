#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 方案 2 深度轻量化沙箱 (参考 Settings 极细精工体系)
// =====================================================================
// 🎯 需求进化：
//   1. 锁定【方案 2 (连续微线轨)】为主基调；
//   2. 彻底移除原方案中多余的 “X left” 标签字段（保持字段与业务口径 100% 纯净一致）；
//   3. 参考【Settings 页面】刚刚落地的极细高定精工排印（ExtraLight 200 / Light 300 / #0A0705 深焦黑），
//      重点将「用户使用次数的计数字体」再大幅卸重，消除所有黑块感；
//   4. 进度条轨道进一步压至 2.0pt ~ 2.5pt 极细微线，整体呈现如同高定腕表刻度般的轻盈呼吸感。

// =====================================================================
// MARK: - 方案 2 轻量化梯级枚举 (Proposal2LightOption)
// =====================================================================

enum Proposal2LightOption: String, CaseIterable, Identifiable {
    case option2A_ExtraLight200 = "★ 方案 2-A: ExtraLight 200 焦黑 (强烈推荐 · Settings同款)"
    case option2B_Light300      = "方案 2-B: Light 300 柔和微实 (Settings正文同款)"
    case option2C_CharterMini   = "方案 2-C: Charter 24pt 细衬线微缩版 (降档修身)"
    case option2_Baseline       = "方案 2 原版: Charter 28pt 细衬线 (已去 X left)"
    case baselineHeavyBar       = "现状对照: 34pt粗黑 + 5pt实心粗轨 (偏重基线)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .option2A_ExtraLight200: return "★ 200 极细焦黑"
        case .option2B_Light300:      return "300 柔和轻盈"
        case .option2C_CharterMini:   return "24pt 衬线微缩"
        case .option2_Baseline:       return "方案2 原版"
        case .baselineHeavyBar:       return "现状粗黑"
        }
    }

    /// 数字字号与字体对象
    var numberFont: Font {
        switch self {
        case .option2A_ExtraLight200:
            // 与 Settings 列表行完全同款骨架：Gothic A1 ExtraLight 200 (字干仅 46u)
            return .custom("GothicA1-ExtraLight", size: 28, relativeTo: .title)
        case .option2B_Light300:
            // Gothic A1 Light 300 (字干 60u)
            return .custom("GothicA1-Light", size: 28, relativeTo: .title)
        case .option2C_CharterMini:
            // Charter 细衬线降一档 (从 28pt 缩至 24pt)
            return .custom("Charter", size: 24, relativeTo: .title2)
        case .option2_Baseline:
            // 方案 2 原版：Charter 28pt Regular
            return .custom("Charter", size: 28, relativeTo: .title)
        case .baselineHeavyBar:
            // 生产现状：34pt 粗黑大字
            return AppTheme.Font.quotaHeroNumber
        }
    }

    /// 数字颜色墨度
    var numberColor: Color {
        switch self {
        case .option2A_ExtraLight200:
            // Settings 专用极细深焦黑 #0A0705（以高对比度弥补极细字干的光通量，针管笔精雕感）
            return AppTheme.Color.settingsRowText
        case .option2B_Light300:
            return AppTheme.Color.settingsRowText
        case .option2C_CharterMini, .option2_Baseline:
            return AppTheme.Color.settingsRowText
        case .baselineHeavyBar:
            return AppTheme.Color.textPrimary
        }
    }

    /// 进度条轨道高度
    var barHeight: CGFloat {
        switch self {
        case .option2A_ExtraLight200, .option2C_CharterMini:
            return 2.0 // 极薄 2.0pt 微线
        case .option2B_Light300, .option2_Baseline:
            return 2.5 // 精致 2.5pt 微线
        case .baselineHeavyBar:
            return 5.0 // 粗黑 5.0pt
        }
    }

    /// 进度条填充颜色
    var barFillColor: Color {
        switch self {
        case .option2A_ExtraLight200:
            // 与 Settings 展开箭头同色：中灰 #7C7773，视觉重量彻底退居辅助
            return AppTheme.Color.textMuted
        case .option2B_Light300, .option2C_CharterMini, .option2_Baseline:
            // 柔和暖中灰 #4B4640
            return AppTheme.Color.textSecondary
        case .baselineHeavyBar:
            // 纯深黑
            return AppTheme.Color.settingsRowText
        }
    }

    var explanation: String {
        switch self {
        case .option2A_ExtraLight200:
            return "【★ 方案 2-A · Settings 极细工笔感】：彻底参考 Settings 列表行！数字升级为 Gothic A1 ExtraLight 200 (字干仅 46u) + 极细深焦黑 #0A0705。进度条压薄至 2.0pt，采用箭头同色中灰 #7C7773。极致轻盈通透，告别一切黑块感！"
        case .option2B_Light300:
            return "【方案 2-B · Settings 舒展轻盈感】：数字采用 Gothic A1 Light 300 (字干 60u)，比 200 略微饱满，温和适中。进度条厚度 2.5pt，暖中灰填充，舒适平衡。"
        case .option2C_CharterMini:
            return "【方案 2-C · 细衬线微缩版】：如果希望保留西文衬线，但彻底卸重——将 Charter 从 28pt 压至 24pt，进度条同步收窄至 2.0pt，文质彬彬，不再突兀抢眼。"
        case .option2_Baseline:
            return "【方案 2 原版 · 纯净版】：Charter 28pt 细衬线 + 2.5pt 细线，已彻底删除多余的 X left 字段，保持干净。"
        case .baselineHeavyBar:
            return "【现状粗黑对照】：Charter 34pt 粗黑大数字 + 5pt 粗黑实心条，黑度压迫感严重。"
        }
    }
}

// =====================================================================
// MARK: - 独立卡片组件 (Proposal2CardView - 100% 纯净无 X left)
// =====================================================================

struct Proposal2CardView: View {
    let option: Proposal2LightOption
    let usedCount: Int
    let dailyLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部数字与副文 (已彻底删除多余的 X left 字段！)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(usedCount)")
                    .font(option.numberFont)
                    .foregroundStyle(option.numberColor)

                Text("/ \(dailyLimit) generations today")
                    .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()
            }

            // 极细微线进度轨
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                        .frame(height: option.barHeight)
                    if usedCount > 0 {
                        Capsule()
                            .fill(option.barFillColor)
                            .frame(width: max(geo.size.width * ratio, option.barHeight), height: option.barHeight)
                    }
                }
            }
            .frame(height: option.barHeight)
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
    }
}

// =====================================================================
// MARK: - 方案 2 弹窗呈现视图 (DailyLimitSheetProposal2)
// =====================================================================

struct DailyLimitSheetProposal2: View {
    let option: Proposal2LightOption
    let usedCount: Int
    let dailyLimit: Int

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                // 方案 C 纯净顶栏：句首大写 + 20pt 细衬线 + 移除右上角关闭键
                HStack {
                    Text("Daily limit")
                        .font(AppTheme.Font.settingsDocumentTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Spacer()
                }
                .padding(.top, 4)

                // 纯净用量卡片
                Proposal2CardView(option: option, usedCount: usedCount, dailyLimit: dailyLimit)

                // 脚注：严格 16pt 左对齐出版物注记风
                Text("Your daily generations refresh every day at midnight.")
                    .font(AppTheme.Font.settingsFormIntro)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Space.paddingXS)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.titleToContent)
            .padding(.bottom, AppTheme.Space.paddingPage)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Color.pageBg)
    }
}

// =====================================================================
// MARK: - 方案 2 深度轻量化交互实验室 (DailyLimitProposal2InteractiveLab)
// =====================================================================

struct DailyLimitProposal2InteractiveLab: View {
    @State private var selectedOption: Proposal2LightOption = .option2A_ExtraLight200
    @State private var testCount: Double = 2
    private let limit: Int = 5

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部方案切换控制台 ──
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Proposal2LightOption.allCases) { opt in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedOption = opt
                                }
                            } label: {
                                Text(opt.shortTag)
                                    .font(.system(size: 11.5, weight: selectedOption == opt ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedOption == opt ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                    .foregroundStyle(selectedOption == opt ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedOption == opt ? AppTheme.Color.brandTint : AppTheme.Color.border,
                                            lineWidth: 0.8
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // 动态测试滑块 (0 到 5)
                HStack(spacing: 12) {
                    Text("模拟用量: \(Int(testCount)) / \(limit)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Slider(value: $testCount, in: 0...5, step: 1)
                        .tint(selectedOption.numberColor)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 诊断说明条
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedOption.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text(selectedOption.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) { Divider() }

            // ── 393×852 真机视口呈现 ──
            Proposal2CanvasFrame(sheetHeight: 260) {
                DailyLimitSheetProposal2(
                    option: selectedOption,
                    usedCount: Int(testCount),
                    dailyLimit: limit
                )
            }
            .scaleEffect(0.92, anchor: .top)
            .frame(maxHeight: .infinity)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }
}

// =====================================================================
// MARK: - 方案 2 各梯度同屏垂直并列画廊 (Proposal2SideBySideGallery)
// =====================================================================

struct Proposal2SideBySideGallery: View {
    @State private var sampleCount: Int = 2
    private let limit: Int = 5

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                // 顶部说明
                VStack(alignment: .leading, spacing: 4) {
                    Text("Proposal 2 · Lightness Hierarchy")
                        .font(AppTheme.Font.settingsDocumentTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("完全基于方案 2（连续微线），参考 Settings 极细精工字重深度卸重。已彻底移除多余字段，垂直对比各档字重与轨道粗细。")
                        .font(AppTheme.Font.settingsFormIntro)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                // 各档卡片垂直并列
                VStack(spacing: AppTheme.Space.paddingCard) {
                    galleryRow(
                        title: "★ 方案 2-A: ExtraLight 200 焦黑 (强烈推荐 · Settings同款)",
                        badge: "数字 28pt 极细 200 (46u) · 焦黑 #0A0705 · 轨道 2.0pt · 箭头同色中灰",
                        option: .option2A_ExtraLight200
                    )

                    galleryRow(
                        title: "方案 2-B: Light 300 柔和微实",
                        badge: "数字 28pt Light (60u) · 焦黑 #0A0705 · 轨道 2.5pt 暖中灰",
                        option: .option2B_Light300
                    )

                    galleryRow(
                        title: "方案 2-C: Charter 24pt 细衬线微缩版",
                        badge: "数字降一档至 24pt 细衬线 · 轨道 2.0pt 极细线",
                        option: .option2C_CharterMini
                    )

                    galleryRow(
                        title: "方案 2 原版: Charter 28pt 细衬线 (已去 X left)",
                        badge: "数字 28pt Charter Regular · 轨道 2.5pt 细线",
                        option: .option2_Baseline
                    )

                    galleryRow(
                        title: "现状粗黑对照: 34pt粗黑 + 5pt实心粗轨",
                        badge: "巨大黑方块 + 5pt实心黑条 · 偏重对比基准",
                        option: .baselineHeavyBar,
                        isBaseline: true
                    )
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, 40)
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func galleryRow(title: String, badge: String, option: Proposal2LightOption, isBaseline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isBaseline ? AppTheme.Color.textSecondary : AppTheme.Color.textPrimary)
                Spacer()
            }

            Text(badge)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textMuted)

            Proposal2CardView(option: option, usedCount: sampleCount, dailyLimit: limit)
        }
    }
}

// =====================================================================
// MARK: - 393×852 真机视口仿真画板
// =====================================================================

struct Proposal2CanvasFrame<SheetContent: View>: View {
    let sheetHeight: CGFloat
    @ViewBuilder let sheetContent: () -> SheetContent

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            // 模拟宿主
            VStack(spacing: 0) {
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "line.3.horizontal").font(.system(size: 16, weight: .semibold)))
                        .surfacePill(in: Circle())
                    Spacer()
                    Text("Today").font(AppTheme.Font.sectionTitleSerif)
                    Spacer()
                    UsageGaugeIcon().frame(width: 44, height: 44).surfacePill(in: Circle())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)
                Spacer()
            }

            Color.black.opacity(0.24).ignoresSafeArea()

            ZStack(alignment: .top) {
                sheetContent()

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
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("00 · ★ 方案 2 深度轻量化实验室 (动效滑块 · 动态切换)") {
    DailyLimitProposal2InteractiveLab()
}

#Preview("01 · ★ 方案 2-A: ExtraLight 200 焦黑 (Settings同款 · 极细针管笔)") {
    Proposal2CanvasFrame(sheetHeight: 260) {
        DailyLimitSheetProposal2(
            option: .option2A_ExtraLight200,
            usedCount: 2,
            dailyLimit: 5
        )
    }
}

#Preview("02 · 方案 2-B: Light 300 柔和微实 (28pt Light · 2.5pt微线)") {
    Proposal2CanvasFrame(sheetHeight: 260) {
        DailyLimitSheetProposal2(
            option: .option2B_Light300,
            usedCount: 2,
            dailyLimit: 5
        )
    }
}

#Preview("03 · 方案 2-C: Charter 24pt 细衬线微缩版 (衬线降一档 · 2.0pt极细)") {
    Proposal2CanvasFrame(sheetHeight: 260) {
        DailyLimitSheetProposal2(
            option: .option2C_CharterMini,
            usedCount: 2,
            dailyLimit: 5
        )
    }
}

#Preview("04 · 方案 2 原版: Charter 28pt 细衬线 (已去 X left)") {
    Proposal2CanvasFrame(sheetHeight: 260) {
        DailyLimitSheetProposal2(
            option: .option2_Baseline,
            usedCount: 2,
            dailyLimit: 5
        )
    }
}

#Preview("05 · 现状粗黑对照: 34pt粗黑 + 5pt实心粗轨 (偏重对比基线)") {
    Proposal2CanvasFrame(sheetHeight: 260) {
        DailyLimitSheetProposal2(
            option: .baselineHeavyBar,
            usedCount: 2,
            dailyLimit: 5
        )
    }
}

#Preview("06 · 方案 2 各梯度同屏垂直画廊 (一屏尽览 · 垂直对比)") {
    Proposal2SideBySideGallery()
}

#endif
