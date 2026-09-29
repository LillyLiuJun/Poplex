#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Settings 分组标题与组内标题 颜色 & 字重 对比探索沙箱
// =====================================================================
// 🎯 需求背景与核心原则：
//   1. 聚焦且单一变量：仅改变第一张图（Settings 设置页）中的：
//      - 【分组标题】（如 My language、Legal、Support、Account、Developer）的颜色与字重；
//      - 【组内标题】（如 Target language、Native language、How AI uses your data、Privacy Policy 等）的颜色与字重；
//   2. 绝对保真度（其他完全不变）：
//      - 保持 Settings 28pt Bold 衬线主标题不变；
//      - 保持右上角圆形悬浮关闭键（SettingsCircleButton.close）不变；
//      - 保持卡片背景（#FFFDF8）、20pt 圆角、0.5pt 细描边与贴地微阴影完全不变；
//      - 保持行前导线性图标、行内 0.5pt 分割线、右侧取值（English / Chinese）与右箭头 Chevron 不变；
//      - 保持系统 Grabber 抓手与暖纸底（#FCF8F3）完全不变。
// =====================================================================

// MARK: - 字体与墨色探索方案枚举

enum SectionTypographyPreset: String, CaseIterable, Identifiable {
    case baseline = "基准现状 · 15 Regular 暖中灰 + 200 极细焦黑"
    case optionA  = "方案 A · 15 Bold 焦黑 + 300 稳重焦黑 (推荐)"
    case optionB  = "方案 B · 15 Regular 焦黑 + 300 柔和暖黑"
    case optionC  = "方案 C · 13.5 无衬线中粗 + 400 标准焦黑"
    case optionD  = "方案 D · 14.5 极弱浅灰 + 200 极细焦黑 (★ 已采纳落地)"
    case optionE  = "方案 E · 15 暖焦褐书标 + 300 暖黑"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .baseline: return "基准现状"
        case .optionA:  return "方案 A · 稳重加黑"
        case .optionB:  return "方案 B · 经典出版"
        case .optionC:  return "方案 C · 现代无衬线"
        case .optionD:  return "★ 方案 D · 极简通透"
        case .optionE:  return "方案 E · 暖焦褐调"
        }
    }

    var badgeText: String {
        switch self {
        case .baseline:
            return "分组: Charter 15 Regular #4B4640 | 行内: Gothic A1 ExtraLight 200 #0A0705"
        case .optionA:
            return "分组: Charter 15 Bold #0A0705 | 行内: Gothic A1 Light 300 #0A0705"
        case .optionB:
            return "分组: Charter 15 Regular #0A0705 | 行内: Gothic A1 Light 300 #211811"
        case .optionC:
            return "分组: Gothic A1 13.5 Medium #4B4640 | 行内: Gothic A1 Regular 400 #0A0705"
        case .optionD:
            return "分组: Charter 14.5 Regular #7C7773 | 行内: Gothic A1 ExtraLight 200 #0A0705"
        case .optionE:
            return "分组: Charter 15 Regular #8C5835 | 行内: Gothic A1 Light 300 #211811"
        }
    }

    var rationale: String {
        switch self {
        case .baseline:
            return "【线上当前表现】：分组标题走 15pt 衬线中灰退到辅助层；行内走 200 极细针管笔字干配高黑度，高对比度。"
        case .optionA:
            return "【推荐 · 章节加重提神】：分组标题 Bold 加粗并提至纯焦黑，形成如书籍章节般的强指引力；行内升至 Light 300，字形扎实不发飘。"
        case .optionB:
            return "【典雅编辑层次】：分组标题保持细体但加深至纯焦黑，行内退至 Warm Editorial 经典暖黑（#211811），层次温和柔韧。"
        case .optionC:
            return "【现代移动工效】：分组标题转为无衬线 Medium 13.5pt，结构干脆现代；行内走 400 标准字干，阅读辨识度最高。"
        case .optionD:
            return "【极致通透轻量】：分组标题降号降灰（#7C7773），近乎隐性标线；行内保留 200 极细针管笔，卡片内容成为绝对主角。"
        case .optionE:
            return "【复古藏书票韵味】：分组标题采用古典暖焦褐色（#8C5835），打破全黑灰冷调；行内搭配温和暖黑，纸质书卷感最浓郁。"
        }
    }

    // MARK: - 分组标题属性 (Section Title)

    var sectionFont: Font {
        FontLoader.registerCustomFonts()
        switch self {
        case .baseline:
            return .custom("Charter", size: 15, relativeTo: .subheadline)
        case .optionA:
            return .custom("Charter-Bold", size: 15, relativeTo: .subheadline)
        case .optionB:
            return .custom("Charter", size: 15, relativeTo: .subheadline)
        case .optionC:
            return .custom("GothicA1-Medium", size: 13.5, relativeTo: .subheadline)
        case .optionD:
            return .custom("Charter", size: 14.5, relativeTo: .subheadline)
        case .optionE:
            return .custom("Charter", size: 15, relativeTo: .subheadline)
        }
    }

    var sectionColor: Color {
        switch self {
        case .baseline:
            return AppTheme.Color.textSecondary // #4B4640 暖中灰
        case .optionA:
            return AppTheme.Color.settingsRowText // #0A0705 极致深焦黑
        case .optionB:
            return AppTheme.Color.settingsRowText // #0A0705 极致深焦黑
        case .optionC:
            return AppTheme.Color.textSecondary // #4B4640 暖中灰
        case .optionD:
            return AppTheme.Color.textMuted // #7C7773 静音浅灰
        case .optionE:
            return Color(red: 0.55, green: 0.35, blue: 0.21) // #8C5835 暖焦褐
        }
    }

    // MARK: - 组内标题属性 (Row Title)

    var rowFont: Font {
        FontLoader.registerCustomFonts()
        switch self {
        case .baseline, .optionD:
            return .custom("GothicA1-ExtraLight", size: 17, relativeTo: .body) // 200 档位
        case .optionA, .optionB, .optionE:
            return .custom("GothicA1-Light", size: 17, relativeTo: .body)      // 300 档位
        case .optionC:
            return .custom("GothicA1-Regular", size: 17, relativeTo: .body)    // 400 档位
        }
    }

    var rowColor: Color {
        switch self {
        case .baseline, .optionA, .optionC, .optionD:
            return AppTheme.Color.settingsRowText // #0A0705 极致深焦黑
        case .optionB, .optionE:
            return AppTheme.Color.textPrimary // #211811 原版温暖纯黑
        }
    }
}

// MARK: - 专属指示箭头组件（与生产 1:1 对齐）

private struct LabChevron: View {
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
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.settingsChevronStroke,
                    lineCap: .round
                )
            )
        }
        .frame(width: glyph, height: glyph)
        .accessibilityHidden(true)
    }
}

// MARK: - 专属卡片组件（仅暴露颜色与字体变量，其余 100% 锁死）

private struct LabSettingsCard<Content: View>: View {
    let title: String?
    let titleFont: Font
    let titleColor: Color
    var fillColor: Color = AppTheme.Color.settingsCardSurface
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            if let title {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            VStack(spacing: 0) {
                content()
            }
            .surfaceCard(
                cornerRadius: AppTheme.Radius.large,
                fillColor: fillColor
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }
}

// MARK: - 专属行组件（严格保持图标、间距、箭头、高亮等要素完全一致）

private struct LabSettingsActionRow: View {
    let icon: SettingsRowIcon
    let label: String
    let labelFont: Font
    let labelColor: Color
    var tint: Color? = nil
    var iconTint: Color = AppTheme.Color.settingsRowIconTint
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingCard) {
            SettingsRowIconView(icon: icon, tint: iconTint)
            Text(label)
                .font(labelFont)
                .foregroundStyle(tint ?? labelColor)
            Spacer()
            if showsChevron {
                LabChevron()
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingCard)
        .contentShape(Rectangle())
    }
}

private struct LabSettingsInfoRow: View {
    let icon: SettingsRowIcon
    let label: String
    let value: String
    let labelFont: Font
    let labelColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Space.paddingCard) {
            SettingsRowIconView(icon: icon, tint: AppTheme.Color.settingsRowIconTint)
            Text(label)
                .font(labelFont)
                .foregroundStyle(labelColor)
            Spacer(minLength: AppTheme.Space.paddingS)
            Text(value)
                .font(labelFont)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 完整真实还原第一张图的单页容器 (SettingsModalScreenReplica)

struct SettingsModalScreenReplica: View {
    let preset: SectionTypographyPreset
    var cardFillColor: Color = AppTheme.Color.settingsCardSurface
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: AppTheme.Space.paddingSection) {
                    // 顶栏留白（避让浮动关闭键与大标题）
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Settings")
                            .font(AppTheme.Font.pageTitleSerif) // Charter 28pt Bold
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.top, 40)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 1. My language 分组
                    LabSettingsCard(
                        title: "My language",
                        titleFont: preset.sectionFont,
                        titleColor: preset.sectionColor,
                        fillColor: cardFillColor
                    ) {
                        LabSettingsInfoRow(
                            icon: .targetLanguage,
                            label: "Target language",
                            value: "English",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                        SettingsRowDivider()
                        LabSettingsInfoRow(
                            icon: .nativeLanguage,
                            label: "Native language",
                            value: "Chinese",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                    }

                    // 2. Legal 分组
                    LabSettingsCard(
                        title: "Legal",
                        titleFont: preset.sectionFont,
                        titleColor: preset.sectionColor,
                        fillColor: cardFillColor
                    ) {
                        LabSettingsActionRow(
                            icon: .aiData,
                            label: "How AI uses your data",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                        SettingsRowDivider()
                        LabSettingsActionRow(
                            icon: .privacy,
                            label: "Privacy Policy",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                        SettingsRowDivider()
                        LabSettingsActionRow(
                            icon: .terms,
                            label: "Terms of Service",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                    }

                    // 3. Support 分组
                    LabSettingsCard(
                        title: "Support",
                        titleFont: preset.sectionFont,
                        titleColor: preset.sectionColor,
                        fillColor: cardFillColor
                    ) {
                        LabSettingsActionRow(
                            icon: .feedback,
                            label: "Send feedback",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor
                        )
                    }

                    // 4. Account 分组
                    LabSettingsCard(
                        title: "Account",
                        titleFont: preset.sectionFont,
                        titleColor: preset.sectionColor,
                        fillColor: cardFillColor
                    ) {
                        LabSettingsActionRow(
                            icon: .delete,
                            label: "Delete account",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor,
                            tint: AppTheme.Color.danger,
                            iconTint: AppTheme.Color.danger,
                            showsChevron: false
                        )
                    }

                    // 5. Developer 分组
                    LabSettingsCard(
                        title: "Developer",
                        titleFont: preset.sectionFont,
                        titleColor: preset.sectionColor,
                        fillColor: cardFillColor
                    ) {
                        LabSettingsActionRow(
                            icon: .reset,
                            label: "Reset Library unlock",
                            labelFont: preset.rowFont,
                            labelColor: preset.rowColor,
                            showsChevron: false
                        )
                    }

                    // 版本号页脚
                    Text("Version 1.0 (1)")
                        .font(AppTheme.Font.settingsVersion)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.bottom, 60)
                }
            }
            .background(AppTheme.Color.pageBg)

            // 顶部系统抓手（Grabber）
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // 右上角浮动圆形关闭键（100% 保持原样）
            HStack {
                Spacer()
                SettingsCircleButton(kind: .close) {
                    onDismiss?()
                }
                .padding(.trailing, AppTheme.Space.paddingPage)
            }
            .padding(.top, AppTheme.Space.titleToContent)
        }
    }
}

// MARK: - 交互式全景控制台 (SettingsSectionTypographyLabView)

struct SettingsSectionTypographyLabView: View {
    @State private var selectedPreset: SectionTypographyPreset = .optionD
    @State private var isFullOpaqueBrightness: Bool = true

    private var activeCardFillColor: Color {
        isFullOpaqueBrightness
            ? AppTheme.Color.warmGlassSurface
            : AppTheme.Color.warmGlassSurface.opacity(0.85)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部参数切换控制栏
                VStack(spacing: 10) {
                    // 1. 方案选择器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SectionTypographyPreset.allCases) { preset in
                                let isSelected = (selectedPreset == preset)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedPreset = preset
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Circle()
                                                .fill(AppTheme.Color.settingsRowText)
                                                .frame(width: 5, height: 5)
                                        }
                                        Text(preset.shortLabel)
                                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected
                                            ? AppTheme.Color.cardBg
                                            : Color.black.opacity(0.04),
                                        in: Capsule()
                                    )
                                    .overlay {
                                        if isSelected {
                                            Capsule()
                                                .stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                                        }
                                    }
                                    .foregroundStyle(
                                        isSelected
                                            ? AppTheme.Color.settingsRowText
                                            : AppTheme.Color.textSecondary
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // 2. 卡片亮度切换条 (100% 对齐 Today vs 85% 旧版发灰)
                    HStack(spacing: 8) {
                        Text("卡片亮度:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isFullOpaqueBrightness = true
                            }
                        } label: {
                            Text("★ 100% 纯暖白 (对齐 Today)")
                                .font(.system(size: 11.5, weight: isFullOpaqueBrightness ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isFullOpaqueBrightness ? AppTheme.Color.cardBg : Color.black.opacity(0.04), in: Capsule())
                                .overlay {
                                    if isFullOpaqueBrightness {
                                        Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                                    }
                                }
                                .foregroundStyle(isFullOpaqueBrightness ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isFullOpaqueBrightness = false
                            }
                        } label: {
                            Text("85% 半透明 (旧版灰暗)")
                                .font(.system(size: 11.5, weight: !isFullOpaqueBrightness ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(!isFullOpaqueBrightness ? AppTheme.Color.cardBg : Color.black.opacity(0.04), in: Capsule())
                                .overlay {
                                    if !isFullOpaqueBrightness {
                                        Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                                    }
                                }
                                .foregroundStyle(!isFullOpaqueBrightness ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 3. 方案公式与意图注记条
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPreset.badgeText + " | 卡片: \(isFullOpaqueBrightness ? "100% 不透明暖白" : "85% 半透明")")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Text(selectedPreset.rationale)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.Color.cardBg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.Color.cardBorder, lineWidth: 0.5)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.vertical, 10)
                .background(AppTheme.Color.pageBg)
                .overlay(alignment: .bottom) {
                    Divider()
                }

                // 下方即时渲染的真实 iPhone 视图
                SettingsModalScreenReplica(
                    preset: selectedPreset,
                    cardFillColor: activeCardFillColor
                )
            }
            .navigationTitle("分组与组内字体调色实验室")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas Previews
// =====================================================================

#Preview("00 · ★ 分组与组内字体交互对比实验室 (支持一键切换)", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsSectionTypographyLabView()
}

#Preview("01 · 基准现状: 15 Regular 暖中灰 + 200 极细焦黑", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .baseline)
}

#Preview("02 · 方案 A: 15 Bold 焦黑 + 300 稳重焦黑 (推荐)", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionA)
}

#Preview("03 · 方案 B: 15 Regular 焦黑 + 300 柔和暖黑", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionB)
}

#Preview("04 · 方案 C: 13.5 无衬线中粗 + 400 标准焦黑", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionC)
}

#Preview("05 · ★ 方案 D: 14.5 极弱浅灰 + 200 极细焦黑 (已采纳)", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionD)
}

#Preview("06 · 方案 E: 15 暖焦褐书标 + 300 暖黑", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionE)
}

#Preview("07 · ★ 卡片亮度对比 · 100% 纯暖白 (对齐 Today · 推荐)", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionD, cardFillColor: AppTheme.Color.warmGlassSurface)
}

#Preview("08 · 卡片亮度对比 · 85% 半透明暖白 (旧版发暗发灰对照)", traits: .fixedLayout(width: 393, height: 852)) {
    SettingsModalScreenReplica(preset: .optionD, cardFillColor: AppTheme.Color.warmGlassSurface.opacity(0.85))
}
#endif

