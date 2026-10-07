#if DEBUG
import SwiftUI
import UIKit

// 旧方案（预设浅底单色深字，2026-10-06 已废弃）的墨色。线上 Token 已删除，本历史预览自带一份，保持画面不变。
private let legacyPresetLabelInk = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255)  // #8A4A20
private let legacyReasonInkOnLightArt = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255).opacity(0.72)

// MARK: - Tab2 胶囊尺寸与材质精细化探索画布 (Tab2 Activity Capsule Refinement Sandbox)
// 🎯 探索目标与解决痛点：
//   针对当前生产中活动胶囊（Activity Chips）“尺寸偏大（Hero 31pt/More 27pt 像主操作按钮）、
//   底色过实偏重（primary100 实色块破坏卡片留白）”的问题，在保持卡片排版和业务逻辑 100% 不变的前提下，
//   提供【维度 1：尺寸瘦身】与【维度 2：材质轻量化】的方案 A 与方案 B 对照实验：
//
//   - 【基线标尺 (Baseline)】：当前生产现状（Hero 31pt / More 27pt，实色 primary100 #FFF3EB 无边框）；
//   - 【方案 A (Option A)】：尺寸瘦身（Hero 25pt / More 22pt）+ 极浅暖纸微底（primary50 #FFF8F4）+ 0.5pt 暖柔发丝边；
//   - 【方案 B (Option B)】：尺寸瘦身（Hero 25pt / More 22pt）+ 幽灵半透底（primary100 @ 30%）+ 0.5pt 细线框；
//   - 【三方案纵向堆叠对照 (Comparison)】：将三张卡片直接垂直排布，一眼看清呼吸感与层次差异。

private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0
        )
    }
}

struct Tab2CapsuleRefinementPreviewView: View {
    @State private var viewMode: ViewMode = .optionA
    @State private var previewScenario: PreviewScenario = .presetArtHero
    @State private var selectedCategory: SceneCategory = .dailyRoutines
    @State private var showTopBarShell: Bool = false
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case optionA    = "方案 A (瘦身+暖纸微边)"
        case optionB    = "方案 B (瘦身+幽灵微透)"
        case baseline   = "当前生产 (31pt 实色大药丸)"
        case comparison = "三方案同屏纵向对照"
    }

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case presetArtHero  = "晨曦预设图态"
        case photoCoverHero = "照片实拍封面态"
        case quietState     = "久未记录态"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 控制面板
            controlPanel

            Divider().opacity(0.15)

            // 画布主内容
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewMode == .comparison {
                        comparisonView
                    } else {
                        singleModeView(mode: viewMode)
                    }

                    footerSignoff
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                }
                .padding(.top, showTopBarShell ? 56 : AppTheme.Space.paddingPage)
                .background(alignment: .bottom) {
                    BottomAuraFooter()
                }
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
            .overlay(alignment: .top) {
                if showTopBarShell {
                    floatingTopBar
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
                    toastOverlay(text: toast)
                }
            }
        }
    }

    // MARK: - 顶端交互控制台

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tab2 胶囊尺寸与材质精细化调优")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Toggle("模拟顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            // 模式选择器
            Picker("视图模式", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 场景与分类走查
            HStack(spacing: 12) {
                Picker("场景", selection: $previewScenario) {
                    ForEach(PreviewScenario.allCases) { sc in
                        Text(sc.rawValue).tag(sc)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Color.brandStrong)

                Picker("分类", selection: $selectedCategory) {
                    ForEach(SceneCategory.allCases, id: \.self) { cat in
                        Text(cat.englishLabel).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Color.textSecondary)

                Spacer()
            }
            .font(AppTheme.Font.statusNote)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 单模式视图

    @ViewBuilder
    private func singleModeView(mode: ViewMode) -> some View {
        let heroData = RefinementMockStore.hero(scenario: previewScenario, category: selectedCategory)
        let moreData = RefinementMockStore.moreCategories(excluding: selectedCategory)

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // ── Talk about today 页面大标题与 Hero 卡片（100% 对齐生产 MineView 结构与 token）──
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Talk about today")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                RefinedHeroCard(
                    category: heroData,
                    styleMode: mode,
                    onTalk: { triggerAction("Tapped Hero: \(heroData.englishLabel)") }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // More to talk about 列表
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More to talk about")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(moreData) { cat in
                        RefinedActivityRow(
                            category: cat,
                            styleMode: mode,
                            onTap: { triggerAction("Selected More: \(cat.englishLabel)") }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
    }

    // MARK: - 三方案纵向对比视图

    @ViewBuilder
    private var comparisonView: some View {
        let heroData = RefinementMockStore.hero(scenario: previewScenario, category: selectedCategory)

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
            VStack(alignment: .leading, spacing: 4) {
                Text("三方案同屏纵向对照")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text("保持卡片外壳 100% 生产同原位，对比胶囊尺寸瘦身与材质轻量化效果")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingPage)

            // 1. 方案 A 卡片
            VStack(alignment: .leading, spacing: 8) {
                badgeHeader(
                    title: "方案 A · 瘦身尺寸 (25pt) + 极浅暖纸微底 + 0.5pt 发丝边",
                    color: Color(hex: 0xC2410C),
                    note: "推荐：消除色块压迫感，找回如书籍压印般的精致优雅"
                )
                RefinedHeroCard(category: heroData, styleMode: .optionA, onTalk: {})
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 2. 方案 B 卡片
            VStack(alignment: .leading, spacing: 8) {
                badgeHeader(
                    title: "方案 B · 瘦身尺寸 (25pt) + 幽灵半透底 (Ghost Tag)",
                    color: Color(hex: 0x965832),
                    note: "极轻质感：30% 微透底透出卡底暖白，视觉重量降至最低"
                )
                RefinedHeroCard(category: heroData, styleMode: .optionB, onTalk: {})
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 3. 当前基线卡片
            VStack(alignment: .leading, spacing: 8) {
                badgeHeader(
                    title: "当前基准 (Baseline) · 31pt 偏大胶囊 + 实色 primary100 无边框",
                    color: AppTheme.Color.textSecondary,
                    note: "现状标尺：色块厚重，尺寸接近底部 CTA 按钮"
                )
                RefinedHeroCard(category: heroData, styleMode: .baseline, onTalk: {})
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func badgeHeader(title: String, color: Color, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTheme.Font.statusNoteSerif)
                .foregroundStyle(color)
            Text(note)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    // MARK: - 辅助组件 (顶栏/Toast/收尾)

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton { triggerAction("Settings") }
                    .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
                Spacer()
                UsageLimitButton { triggerAction("Quota") }
                    .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background { TopBarProgressiveMask() }
    }

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(capHeight: 12.5, style: .mono(AppTheme.Color.textMuted), showsPeriod: true)
            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.tab2FooterTop)
    }

    private func triggerAction(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if toastMessage == message { withAnimation { toastMessage = nil } }
        }
    }

    private func toastOverlay(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Color.brandStrong)
            Text(text)
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
        .clipShape(Capsule())
        .cardShadow()
        .padding(.bottom, 24)
    }
}

// MARK: - 精细化 Hero 卡片组件

private struct RefinedHeroCard: View {
    let category: Tab2CategoryData
    let styleMode: Tab2CapsuleRefinementPreviewView.ViewMode
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }
    private var onLightArt: Bool { display.photoCover == nil }

    var body: some View {
        Button(action: onTalk) {
            VStack(spacing: 0) {
                topArt
                    .overlay(alignment: .topLeading) {
                        photoTopRow
                            .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                            .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    }

                bottomContent
                    .offset(y: AppTheme.Tab2Hero.Layout.artTextOverlap)
                    .padding(.bottom, AppTheme.Tab2Hero.Layout.artTextOverlap)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.Color.warmGlassSurface)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
        .buttonStyle(RefinedCardPressStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var topArt: some View {
        if let cover = display.photoCover {
            Tab2HeroPhotoArt(cover: cover)
        } else {
            CategoryPresetArtView(category: sceneCategory)
        }
    }

    private var photoTopRow: some View {
        HStack(spacing: 8) {
            Text(category.englishLabel)
                .font(AppTheme.Font.tab2HeroChipCategory)
                .foregroundStyle(onLightArt ? legacyPresetLabelInk : AppTheme.Color.tab2HeroPhotoOverlayText)
                .lineLimit(1)
                .shadow(
                    color: photoTextShadowColor,
                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                    x: 0,
                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                )

            let state = Tab2CardLabels.reasonPillState(
                lastMaterialAt: category.lastMaterialAt,
                newMaterialCount: category.newMaterialCount
            )
            Text(state.text)
                .font(AppTheme.Font.tab2ReasonPill)
                .foregroundStyle(onLightArt ? legacyReasonInkOnLightArt : AppTheme.Color.tab2ReasonPillOnPhotoText)
                .lineLimit(1)
                .shadow(
                    color: photoTextShadowColor,
                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                    x: 0,
                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                )
        }
    }

    private var photoTextShadowColor: Color {
        onLightArt
            ? AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.transparent)
            : AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow)
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            activitySection
                .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

            footRow
                .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
        }
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
        .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
            Text("Recent activities")
                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Color.textMuted)

            if display.showsActivities {
                RefinedCapsuleGroupView(
                    activities: display.valid,
                    activityCount: category.activityCount,
                    blockedCount: display.blockedCount,
                    styleMode: styleMode,
                    surface: .hero
                )
            } else {
                Tab2OnlyWordsLine()
            }
        }
    }

    private var footRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
            Text(Tab2CardLabels.words(category.wordCount))
                .font(AppTheme.Font.tab2HeroFootrowWords)
                .foregroundStyle(AppTheme.Color.textMuted)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Spacer(minLength: 0)

            ctaPill
        }
    }

    private var ctaPill: some View {
        HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
            Text("Start talking")
            Image(systemName: "arrow.right").imageScale(.small)
        }
        .font(AppTheme.Font.tab2HeroCTA)
        .foregroundStyle(AppTheme.Color.textOnChip)
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
        .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
        .background(
            AppTheme.Color.interactive,
            in: RoundedRectangle(cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius, style: .continuous)
        )
    }
}

// MARK: - 精细化 More 列表行组件

private struct RefinedActivityRow: View {
    let category: Tab2CategoryData
    let styleMode: Tab2CapsuleRefinementPreviewView.ViewMode
    let onTap: () -> Void

    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }
    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 左侧 76pt 缩略图
                Color.clear
                    .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                    .overlay(RowPresetThumb(category: sceneCategory))
                    .clipped()
                    .accessibilityHidden(true)

                // 右侧信息区
                VStack(alignment: .leading, spacing: 0) {
                    hatRow
                        .padding(.trailing, AppTheme.Space.paddingPage)

                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            if display.valid.isEmpty {
                                Tab2OnlyWordsLine()
                                    .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)
                                wordsLine
                                    .padding(.top, AppTheme.Tab2MoreRow.Layout.emptyLineToWords)
                            } else {
                                RefinedCapsuleGroupView(
                                    activities: display.valid,
                                    activityCount: category.activityCount,
                                    blockedCount: display.blockedCount,
                                    styleMode: styleMode,
                                    surface: .more
                                )
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)

                                wordsLine
                                    .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                            }
                        }
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                        Image(systemName: "arrow.right")
                            .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .padding(.trailing, AppTheme.Space.paddingPage)
                    }
                }
                .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
                .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
                .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
            }
            .frame(minHeight: display.valid.isEmpty ? 0 : AppTheme.Tab2MoreRow.Layout.rowHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Color.warmGlassSurface)
            .compositingGroup()
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
        .buttonStyle(RefinedCardPressStyle())
    }

    private var hatRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(category.englishLabel)
                .font(AppTheme.Font.tab2MoreRowCategory)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: AppTheme.Space.paddingS)

            if let timeline = timelineText {
                Text(timeline)
                    .font(AppTheme.Font.tab2MoreRowTimeline)
                    .foregroundStyle(AppTheme.Color.neutralFaint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
    }

    private var timelineText: String? {
        Tab2CardLabels.timeLine(lastMaterialAt: category.lastMaterialAt)
    }

    private var wordsLine: some View {
        Text(Tab2CardLabels.words(category.wordCount))
            .font(AppTheme.Font.tab2MoreRowMeta)
            .foregroundStyle(AppTheme.Color.textMuted)
            .monospacedDigit()
            .lineLimit(1)
    }
}

// MARK: - 精细化胶囊群 (核心尺寸与色彩实现)

private struct RefinedCapsuleGroupView: View {
    enum Surface { case hero, more }

    let activities: [Tab2ActivityDisplay.ValidActivity]
    let activityCount: Int
    let blockedCount: Int
    let styleMode: Tab2CapsuleRefinementPreviewView.ViewMode
    let surface: Surface

    // 几何度量方案
    private var config: CapsuleGeometryConfig {
        switch styleMode {
        case .baseline:
            surface == .hero ? .heroBaseline : .moreBaseline
        case .optionA, .optionB, .comparison:
            surface == .hero ? .heroSlim : .moreSlim
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let fit = Tab2CapsuleFit.fit(
                valid: activities,
                activityCount: activityCount,
                blockedCount: blockedCount,
                width: proxy.size.width,
                metrics: config.metrics
            )

            VStack(alignment: .leading, spacing: config.rowGap) {
                // 第一行
                HStack(spacing: config.rowGap) {
                    ForEach(fit.row1, id: \.self) { name in
                        capsulePill(name: name)
                    }
                    if let more1 = fit.moreInRow1 {
                        moreText(count: more1)
                    }
                }
                .frame(height: config.rowHeight)

                // 第二行
                HStack(spacing: config.rowGap) {
                    ForEach(fit.row2, id: \.self) { name in
                        capsulePill(name: name)
                    }
                    if let more2 = fit.moreInRow2 {
                        moreText(count: more2)
                    }
                }
                .frame(height: config.rowHeight)
            }
        }
        .frame(height: config.rowHeight * 2 + config.rowGap)
    }

    private func capsulePill(name: String) -> some View {
        Text(name)
            .font(config.font)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, config.paddingH)
            .frame(height: config.rowHeight)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay {
                if let border = borderColor {
                    Capsule()
                        .strokeBorder(border, lineWidth: 0.5)
                }
            }
    }

    private func moreText(count: Int) -> some View {
        Text(" +\(count) more")
            .font(config.moreFont)
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
            .frame(height: config.rowHeight)
    }

    // 色彩材质切换
    private var backgroundColor: Color {
        switch styleMode {
        case .baseline:
            AppTheme.Color.tab2ActivityChipBg // 生产 primary100 #FFF3EB
        case .optionA:
            Color(hex: 0xFFF8F4) // 极浅暖纸微底 (primary50)
        case .optionB:
            Color(hex: 0xFFF3EB).opacity(0.30) // 幽灵微透底 (30% 透光)
        case .comparison:
            Color(hex: 0xFFF8F4)
        }
    }

    private var borderColor: Color? {
        switch styleMode {
        case .baseline:
            nil
        case .optionA:
            Color(hex: 0x965832).opacity(0.12) // 0.5pt 暖柔微发丝边
        case .optionB:
            Color(hex: 0x965832).opacity(0.20) // 0.5pt 幽灵细描边
        case .comparison:
            Color(hex: 0x965832).opacity(0.12)
        }
    }

    private var textColor: Color {
        switch styleMode {
        case .baseline:
            AppTheme.Color.tab2ActivityChipText // neutral900 #211811
        case .optionA:
            Color(hex: 0x2A221B) // 次级暖深炭墨，柔和融入纸面
        case .optionB:
            Color(hex: 0x211811) // 主文字
        case .comparison:
            Color(hex: 0x2A221B)
        }
    }
}

// MARK: - 几何度量配置

private struct CapsuleGeometryConfig {
    let font: SwiftUI.Font
    let moreFont: SwiftUI.Font
    let rowHeight: CGFloat
    let paddingH: CGFloat
    let rowGap: CGFloat
    let metrics: Tab2ActivityCapsuleMetrics

    // 1. Hero 生产现状基准 (31pt)
    static let heroBaseline: CapsuleGeometryConfig = {
        let m = Tab2ActivityCapsuleMetrics.hero()
        return CapsuleGeometryConfig(
            font: AppTheme.Font.tab2HeroCapsuleName,
            moreFont: AppTheme.Font.tab2HeroCapsuleMore,
            rowHeight: 31,
            paddingH: 13,
            rowGap: 7,
            metrics: m
        )
    }()

    // 2. Hero 瘦身精美方案 (25pt) —— 压降 6pt 高度，内边距收紧 4pt，字号 13.5pt
    static let heroSlim: CapsuleGeometryConfig = {
        let uifont = UIFont(name: "Charter", size: 13.5)!
        let scaledName = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: uifont)
        let moreUI = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: UIFont(name: AppTheme.Font.SansWeight.regular.postScriptName, size: 12)!)

        let m = Tab2ActivityCapsuleMetrics(
            nameBaseUIFont: uifont,
            nameUIFont: scaledName,
            moreUIFont: moreUI,
            baseRowHeight: 25,
            rowGap: 6,
            namePaddingH: 9,
            morePaddingH: 5
        )

        return CapsuleGeometryConfig(
            font: SwiftUI.Font.custom("Charter", size: 13.5, relativeTo: .subheadline),
            moreFont: SwiftUI.Font.custom(AppTheme.Font.SansWeight.regular.postScriptName, size: 12, relativeTo: .footnote),
            rowHeight: 25,
            paddingH: 9,
            rowGap: 6,
            metrics: m
        )
    }()

    // 3. More 生产现状基准 (27pt)
    static let moreBaseline: CapsuleGeometryConfig = {
        let m = Tab2ActivityCapsuleMetrics.more()
        return CapsuleGeometryConfig(
            font: AppTheme.Font.tab2MoreRowCapsuleName,
            moreFont: AppTheme.Font.tab2MoreRowCapsuleMore,
            rowHeight: 27,
            paddingH: 11,
            rowGap: 6,
            metrics: m
        )
    }()

    // 4. More 瘦身精美方案 (22pt) —— 压降 5pt 高度，字号 12pt
    static let moreSlim: CapsuleGeometryConfig = {
        let uifont = UIFont(name: "Charter", size: 12)!
        let scaledName = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: uifont)
        let moreUI = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont(name: AppTheme.Font.SansWeight.regular.postScriptName, size: 11)!)

        let m = Tab2ActivityCapsuleMetrics(
            nameBaseUIFont: uifont,
            nameUIFont: scaledName,
            moreUIFont: moreUI,
            baseRowHeight: 22,
            rowGap: 5,
            namePaddingH: 8,
            morePaddingH: 4
        )

        return CapsuleGeometryConfig(
            font: SwiftUI.Font.custom("Charter", size: 12, relativeTo: .footnote),
            moreFont: SwiftUI.Font.custom(AppTheme.Font.SansWeight.regular.postScriptName, size: 11, relativeTo: .caption2),
            rowHeight: 22,
            paddingH: 8,
            rowGap: 5,
            metrics: m
        )
    }()
}

private struct RefinedCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppTheme.Tab2Hero.Motion.pressedScale : 1)
            .animation(.spring(response: AppTheme.Tab2Hero.Motion.pressResponse, dampingFraction: AppTheme.Tab2Hero.Motion.pressDamping), value: configuration.isPressed)
    }
}

// MARK: - 真实 Mock 数据中心

private enum RefinementMockStore {
    static func hero(scenario: Tab2CapsuleRefinementPreviewView.PreviewScenario, category: SceneCategory) -> Tab2CategoryData {
        let catKey = category.rawValue

        switch scenario {
        case .presetArtHero:
            return Tab2CategoryData(
                sceneCategory: catKey,
                wordCount: 47,
                unlocked: true,
                notSpokenCount: 47,
                lastTalkedAt: nil,
                lastMaterialAt: Date(),
                newMaterialCount: 3,
                activityCount: 7,
                activities: [
                    Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 3, cover: nil),
                    Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Watering plants", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Tidying bedroom", occurrenceCount: 1)
                ]
            )

        case .photoCoverHero:
            return Tab2CategoryData(
                sceneCategory: catKey,
                wordCount: 52,
                unlocked: true,
                notSpokenCount: 52,
                lastTalkedAt: nil,
                lastMaterialAt: Date(),
                newMaterialCount: 2,
                activityCount: 6,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Fixing a device",
                        occurrenceCount: 4,
                        cover: Tab2Activity.Cover(
                            materialId: "m-hero-1",
                            imageUrl: "https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Coffee brewing", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Setting desk", occurrenceCount: 1)
                ]
            )

        case .quietState:
            let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
            return Tab2CategoryData(
                sceneCategory: catKey,
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 38,
                lastTalkedAt: nil,
                lastMaterialAt: fiveDaysAgo,
                newMaterialCount: 0,
                activityCount: 4,
                activities: [
                    Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 2, cover: nil),
                    Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Plant care", occurrenceCount: 1)
                ]
            )
        }
    }

    static func moreCategories(excluding current: SceneCategory) -> [Tab2CategoryData] {
        let pool: [SceneCategory] = [.food, .workStudy, .shopping, .gettingAround].filter { $0 != current }
        return pool.prefix(2).enumerated().map { index, cat in
            Tab2CategoryData(
                sceneCategory: cat.rawValue,
                wordCount: 24 + index * 10,
                unlocked: true,
                notSpokenCount: 24 + index * 10,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -(index * 3 + 2), to: Date()),
                newMaterialCount: index == 0 ? 1 : 0,
                activityCount: 3 + index,
                activities: [
                    Tab2Activity(
                        sceneDetail: cat == .food ? "Making breakfast" : "Team sync",
                        occurrenceCount: 2,
                        cover: nil
                    ),
                    Tab2Activity(
                        sceneDetail: cat == .food ? "Coffee run" : "Code review",
                        occurrenceCount: 1
                    )
                ]
            )
        }
    }
}

// MARK: - Xcode Canvas 预览入口

#Preview("Tab2 胶囊尺寸与材质精细化探索") {
    Tab2CapsuleRefinementPreviewView()
}
#endif
