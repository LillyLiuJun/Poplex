#if DEBUG
import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Tab2 胶囊高对比度降重探索画布 (Tab2 High-Contrast Lightweight Capsules Sandbox)
// 🎯 用户关键纠偏与明确指令：
//   1. “我说的高对比是浅色胶囊和文字，而不是胶囊和卡片！”——胶囊与卡片之间必须极其“轻”、干净融和，绝不能用沉重发脏的黄灰厚泥色！
//   2. “你这版本胶囊的颜色很难看，我想要轻的感觉”——彻底回归生产最纯净透亮的晨曦暖底（primary100 微透）或极浅柔光白！
//   3. “你的只有B对比度高，但是B有点弱，可以补充一版本不加边框的，然后你重新改一版本给我看看”——彻底去掉硬边框（No Border），依托极净微底托底，文字保持极高对比度（neutral900 #211811，15:1 对比度）！
//
// 🎯 重新打造的 3 个轻盈、纯净、高对比度、无边框新方案：
//   - 【基线 (当前生产 · 0.5pt描边)】：100% 生产真实配置（primary100@30% 晨曦微底 + 0.5pt 发丝边 + neutral900 黑字）
//   - 【方案 1 (晨曦微风 · 纯净无边框)】⭐：用户点名方向！拿掉硬框，生产同源晨曦微透浅底，与白卡轻若薄雾，文字高对比近黑，字迹如刻刀般清晰！
//   - 【方案 2 (轻雾柔霜 · 极简无边框)】：纯净微透柔白底（无任何暖黄偏色，杂志风纯净浅灰白），无边框，极高文字对比度，极度轻巧！
//   - 【方案 3 (晨曦无边框 + Words纯字)】：Activity 采用方案 1 晨曦无框；Words 胶囊彻底脱壳为纯字「16 words ▾」，列表完全呼吸通透！

struct Tab2CapsulesVisualRefinementPreviewView: View {
    @State private var selectedProposal: CapsuleProposal = .prodNoBorder
    @State private var previewScenario: PreviewScenario = .activeUser
    @State private var showTopBarShell: Bool = true
    @State private var expandedCategoryId: String? = nil
    @State private var showFocusSpotlight: Bool = false
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine

    enum CapsuleProposal: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case baseline     = "基线 (生产真实)"
        case prodNoBorder = "方案 1 (生产无边框)"
        case softMilk     = "方案 2 (轻雾柔霜)"
        case ghostWire    = "方案 3 (幽灵微边)"
        case dawnBreeze   = "方案 4 (晨曦微风)"
    }

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case activeUser = "典型活跃态 (完整 4 大区)"
        case expandedAccordion = "手风琴展开态 (检验 Words)"
        case singleTopic = "单话题解锁 (无 More 区)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端控制面板：方案切换、场景切换、外壳与高亮
            controlPanel

            Divider().opacity(0.15)

            // 当前方案的规格速查条
            proposalSpecBar

            // 主画布视口 (100% 对齐 MineView.swift 的 Tab2UnlockedView)
            ZStack(alignment: .top) {
                GeometryReader { geo in
                    let reservedTop: CGFloat = showTopBarShell ? 56 : AppTheme.Space.paddingPage
                    let availableHeight = max(geo.size.height - reservedTop, 400)

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                contentSections(proxy)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: AppTheme.Space.tab2FooterTop)

                                footerSignoff
                                    .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                            }
                            .frame(minHeight: availableHeight, alignment: .top)
                            .background(alignment: .bottom) {
                                BottomAuraFooter()
                            }
                        }
                        .safeAreaInset(edge: .top, spacing: 0) {
                            Color.clear.frame(height: reservedTop)
                        }
                        .scrollBounceBehavior(.always, axes: .vertical)
                    }
                }
                .background(AppTheme.Color.pageBg.ignoresSafeArea())

                // 全真浮动顶栏
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
        .onChange(of: previewScenario) { _, newScenario in
            if newScenario == .expandedAccordion {
                expandedCategoryId = ProductionMockStore.inProgressCategories.first?.id
            } else if previewScenario != .expandedAccordion {
                expandedCategoryId = nil
            }
        }
    }

    // MARK: - 顶端控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 7, height: 7)
                    Text("胶囊高对比度降重沙盒")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Toggle("聚光灯", isOn: $showFocusSpotlight)
                    .font(AppTheme.Font.pos)
                    .labelsHidden()
                Text(showFocusSpotlight ? "胶囊聚光 ON" : "胶囊聚光 OFF")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(showFocusSpotlight ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)

                Divider().frame(height: 14)

                Toggle("模拟顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            // 方案主分段控制器
            Picker("降重方案", selection: $selectedProposal) {
                ForEach(CapsuleProposal.allCases) { prop in
                    Text(prop.rawValue).tag(prop)
                }
            }
            .pickerStyle(.segmented)

            // 场景切换
            Picker("场景", selection: $previewScenario) {
                ForEach(PreviewScenario.allCases) { sc in
                    Text(sc.rawValue).tag(sc)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    private var badgeColor: Color {
        switch selectedProposal {
        case .baseline: return AppTheme.Color.textMuted
        case .prodNoBorder: return AppTheme.Color.brandStrong
        case .softMilk: return Color(red: 0.25, green: 0.55, blue: 0.75)
        case .ghostWire: return Color(red: 0.55, green: 0.45, blue: 0.75)
        case .dawnBreeze: return Color(red: 0.85, green: 0.45, blue: 0.15)
        }
    }

    // MARK: - 方案参数速查面板

    private var proposalSpecBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(proposalTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(proposalHighlight)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(badgeColor.opacity(0.12), in: Capsule())
                }
                Text(proposalSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.06))
    }

    private var proposalTitle: String {
        switch selectedProposal {
        case .baseline: return "基线 · 生产真实像素级完成"
        case .prodNoBorder: return "方案 1 · 生产同款 · 彻底不放边框 (用户指定)"
        case .softMilk: return "方案 2 · 轻雾柔霜 · 极简无边框"
        case .ghostWire: return "方案 3 · 方案 B (幽灵微边 · 纯线去底) 回归"
        case .dawnBreeze: return "方案 4 · 上个方案 A 晨曦微风颜色视觉"
        }
    }

    private var proposalHighlight: String {
        switch selectedProposal {
        case .baseline: return "0.5pt 细描边"
        case .prodNoBorder: return "生产同底 · 彻底无边框 ⭐"
        case .softMilk: return "极简杂志风"
        case .ghostWire: return "全透去底 + 0.5pt线"
        case .dawnBreeze: return "晨曦暖透 · 柔润无边框 🌅"
        }
    }

    private var proposalSummary: String {
        switch selectedProposal {
        case .baseline:
            return "生产真实：primary100@30%微透底 + 0.5pt发丝边 · 字色 neutral900 · 25/22pt"
        case .prodNoBorder:
            return "完全取自生产 primary100@30% 晨曦底 + 彻底拿掉边框 (0pt) + neutral900 黑字 · 收紧23/20.5pt"
        case .softMilk:
            return "极低彩度 4% 墨染柔白浅底 + 0pt 无边框 + neutral900 黑字，极度干净素雅"
        case .ghostWire:
            return "底色彻底透明全去底 + 0.5pt 精细发丝边 + neutral900 黑字，结构清晰"
        case .dawnBreeze:
            return "晨曦暖透柔润底 (primary100@42%) + 0pt 无边框 + neutral900 黑字，微风暖意视觉"
        }
    }

    // MARK: - 浮动顶栏 (100% 对齐 RootTabContainer)

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton {
                    triggerAction("Tapped Settings")
                }
                .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)

                Spacer()

                UsageLimitButton {
                    triggerAction("Tapped Quota")
                }
                .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
    }

    // MARK: - 核心内容区块集合 (100% 生产排版)

    @ViewBuilder
    private func contentSections(_ proxy: ScrollViewProxy) -> some View {
        let scenarioData = currentScenarioData

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt
            // ── 1. Talk about today (Hero 区块) ──
            if let hero = scenarioData.hero {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("Talk about today")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    RefinedHeroCard(
                        category: hero,
                        proposal: selectedProposal,
                        isSpotlight: showFocusSpotlight,
                        onTalk: {
                            triggerAction("Start conversation: \(hero.englishLabel)")
                        }
                    )
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 2. More to talk about (推荐行) —— 刀 6a：三标题同档 24pt 衬线 ──
            if !scenarioData.moreCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("More to talk about")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 推荐列表行
                    VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) { // 12pt
                        ForEach(scenarioData.moreCategories) { category in
                            RefinedActivityRow(
                                category: category,
                                proposal: selectedProposal,
                                isSpotlight: showFocusSpotlight,
                                onTap: {
                                    triggerAction("Selected topic: \(category.englishLabel)")
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 3. Topics in progress (手风琴进度卡片) —— 核心包含 Words 胶囊 ──
            if !scenarioData.inProgressCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 进度卡片磨砂玻璃容器
                    VStack(spacing: 0) {
                        ForEach(Array(scenarioData.inProgressCategories.enumerated()), id: \.element.id) { index, cat in
                            RefinedCategoryProgressRow(
                                category: cat,
                                isExpanded: expandedCategoryId == cat.id,
                                proposal: selectedProposal,
                                isSpotlight: showFocusSpotlight,
                                onToggle: {
                                    withAnimation(AppTheme.Motion.accordionToggle) {
                                        expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                    }
                                }
                            )
                            .id(cat.id)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 4. More topics to explore (2026-10-03 新增探索区) ──
            let unstarted = SceneCategory.unstarted(given: scenarioData.allCategories)
            if !unstarted.isEmpty {
                Tab2MoreTopicsSection(topics: unstarted, footnote: nil, resetToken: nil)
            }
        }
        .padding(.top, AppTheme.Space.tab2ContentTop)
    }

    // MARK: - 底部收尾

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(
                capHeight: 12.5,
                style: .mono(AppTheme.Color.textMuted),
                showsPeriod: true
            )

            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.tab2FooterTop)
    }

    // MARK: - 交互反馈与 Toast

    private func triggerAction(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toastMessage == message {
                withAnimation { toastMessage = nil }
            }
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var currentScenarioData: (
        hero: Tab2CategoryData?,
        moreCategories: [Tab2CategoryData],
        inProgressCategories: [Tab2CategoryData],
        allCategories: [Tab2CategoryData]
    ) {
        switch previewScenario {
        case .activeUser, .expandedAccordion:
            let hero = ProductionMockStore.activeHero
            let more = ProductionMockStore.activeMoreCategories
            let inProgress = ProductionMockStore.inProgressCategories
            return (
                hero: hero,
                moreCategories: more,
                inProgressCategories: inProgress,
                allCategories: [hero] + more + inProgress
            )
        case .singleTopic:
            let hero = ProductionMockStore.activeHero
            let inProgress = ProductionMockStore.inProgressCategories
            return (
                hero: hero,
                moreCategories: [],
                inProgressCategories: inProgress,
                allCategories: [hero] + inProgress
            )
        }
    }
}

// MARK: - 方案定制版 Hero 卡片 (注入降重胶囊)

private struct RefinedHeroCard: View {
    let category: Tab2CategoryData
    let proposal: Tab2CapsulesVisualRefinementPreviewView.CapsuleProposal
    let isSpotlight: Bool
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }

    var body: some View {
        Button(action: onTalk) {
            VStack(spacing: 0) {
                // 顶部图与标签
                if let cover = display.photoCover {
                    Tab2HeroPhotoArt(cover: cover)
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 8) {
                                Text(category.englishLabel)
                                    .font(AppTheme.Font.tab2HeroChipCategory)
                                    .foregroundStyle(AppTheme.Color.tab2HeroPhotoOverlayText)
                                Text("Added 3 times today")
                                    .font(AppTheme.Font.tab2ReasonPill)
                                    .foregroundStyle(AppTheme.Color.tab2ReasonPillOnPhotoText)
                            }
                            .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                            .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        }
                }

                // 卡身文字区
                VStack(alignment: .leading, spacing: 0) {
                    // Recent activities 区块
                    VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
                        HStack {
                            Text("Recent activities")
                                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                                .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(AppTheme.Color.textMuted)

                            if isSpotlight {
                                Text(proposalBadgeText)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                            }
                        }

                        // 定制活动胶囊流
                        RefinedActivityCapsuleGroup(
                            activities: display.valid.map(\.name),
                            moreCount: 1,
                            proposal: proposal,
                            isHero: true,
                            isSpotlight: isSpotlight
                        )
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

                    // 脚行：47 words + CTA
                    HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                        Text(Tab2CardLabels.words(category.wordCount))
                            .font(AppTheme.Font.tab2HeroFootrowWords)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .monospacedDigit()

                        Spacer(minLength: 0)

                        HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
                            Text("Start talking")
                            Image(systemName: "arrow.right").imageScale(.small)
                        }
                        .font(AppTheme.Font.tab2HeroCTA)
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
                        .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
                        .background(AppTheme.Color.interactive, in: RoundedRectangle(cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius, style: .continuous))
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
                }
                .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
                .offset(y: AppTheme.Tab2Hero.Layout.artTextOverlap)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.artTextOverlap)
            }
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
        .buttonStyle(.plain)
    }

    private var proposalBadgeText: String {
        switch proposal {
        case .baseline: return "基线真实"
        case .prodNoBorder: return "生产同款无框"
        case .softMilk: return "轻雾柔霜无框"
        case .ghostWire: return "幽灵微边纯线"
        case .dawnBreeze: return "晨曦微风暖底"
        }
    }
}

// MARK: - 方案定制版 ActivityRow (注入降重胶囊)

private struct RefinedActivityRow: View {
    let category: Tab2CategoryData
    let proposal: Tab2CapsulesVisualRefinementPreviewView.CapsuleProposal
    let isSpotlight: Bool
    let onTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                    .overlay(thumbnail)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    hatRow
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)

                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            RefinedActivityCapsuleGroup(
                                activities: display.valid.prefix(2).map(\.name),
                                moreCount: display.valid.count > 2 ? (display.valid.count - 2 + 1) : nil,
                                proposal: proposal,
                                isHero: false,
                                isSpotlight: isSpotlight
                            )
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)

                            Text(Tab2CardLabels.words(category.wordCount))
                                .font(AppTheme.Font.tab2MoreRowMeta)
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .monospacedDigit()
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                        }
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                        Image(systemName: "arrow.right")
                            .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                    }
                }
                .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
                .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
                .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
            }
            .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Color.warmGlassSurface)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let cover = display.photoCover {
            CachedRemoteImage(
                signedUrl: cover.imageUrl ?? "",
                stableKey: cover.stableImageKey ?? cover.imageUrl ?? "",
                placeholder: { Rectangle().fill(AppTheme.Color.imagePlaceholderBg) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(
                Rectangle()
                    .fill(AppTheme.Color.tab2MoreRowPhotoToneWarm)
                    .blendMode(.multiply)
                    .opacity(AppTheme.Tab2MoreRow.Opacity.photoToneWarm)
            )
        } else {
            RowPresetThumb(category: sceneCategory)
        }
    }

    private var hatRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(category.englishLabel)
                .font(AppTheme.Font.tab2MoreRowCategory)
                .foregroundStyle(AppTheme.Color.textSecondary)

            Spacer(minLength: AppTheme.Space.paddingS)

            Text("Yesterday")
                .font(AppTheme.Font.tab2MoreRowTimeline)
                .foregroundStyle(AppTheme.Color.neutralFaint)
        }
    }
}

// MARK: - 降重版 Activity 胶囊组渲染组件 (彻底解决省略号，保证文字完整展示)

private struct RefinedActivityCapsuleGroup: View {
    let activities: [String]
    let moreCount: Int?
    let proposal: Tab2CapsulesVisualRefinementPreviewView.CapsuleProposal
    let isHero: Bool
    let isSpotlight: Bool

    var body: some View {
        if isHero {
            // Hero 双行完整展示（首行放前 2 个活动，第二行放第 3 个 + "+N more"）
            let row1 = Array(activities.prefix(2))
            let row2 = Array(activities.dropFirst(2).prefix(1))
            let hasMore = (moreCount != nil || activities.count > 3)
            let moreNum = (moreCount ?? 0) + max(0, activities.count - 3)

            VStack(alignment: .leading, spacing: capsuleGap) {
                HStack(spacing: capsuleGap) {
                    ForEach(row1, id: \.self) { name in
                        capsule(name)
                    }
                }
                if !row2.isEmpty || hasMore {
                    HStack(spacing: capsuleGap) {
                        ForEach(row2, id: \.self) { name in
                            capsule(name)
                        }
                        if hasMore && moreNum > 0 {
                            morePill(" +\(moreNum) more")
                        }
                    }
                }
            }
            .frame(height: height * 2 + capsuleGap, alignment: .topLeading)
        } else {
            // More 行单行自适应完整展示（首个活动英文短语完整展开 + "+N more"，绝不压缩省略）
            let firstActivity = activities.first
            let remaining = max(1, activities.count - 1 + (moreCount ?? 0))

            HStack(spacing: capsuleGap) {
                if let name = firstActivity {
                    capsule(name)
                }
                if remaining > 0 {
                    morePill(" +\(remaining) more")
                }
            }
            .frame(height: height, alignment: .leading)
        }
    }

    private func capsule(_ name: String) -> some View {
        Text(name)
            .font(capsuleFont)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false) // 关键：禁止横向挤压，文字 100% 完整展示，绝无省略号！
            .padding(.horizontal, paddingH)
            .frame(height: height)
            .background(bgFill, in: Capsule())
            .overlay {
                if showsBorder {
                    Capsule().strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.brandStrong, lineWidth: 1)
                }
            }
    }

    private func morePill(_ text: String) -> some View {
        Text(text)
            .font(moreFont)
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, isHero ? 6 : 4)
            .frame(height: height)
    }

    private var height: CGFloat {
        switch proposal {
        case .baseline:
            return isHero ? AppTheme.Tab2Hero.Layout.activityCapsuleRowHeight : AppTheme.Tab2MoreRow.Layout.activityCapsuleRowHeight // 25 / 22
        case .prodNoBorder, .softMilk, .ghostWire, .dawnBreeze:
            return isHero ? 23 : 20.5 // 适度收紧高度 23 / 20.5，精致干练、告别臃肿
        }
    }

    private var paddingH: CGFloat {
        switch proposal {
        case .baseline:
            return isHero ? 9 : 8
        case .prodNoBorder, .softMilk, .ghostWire, .dawnBreeze:
            return isHero ? 8 : 7 // 内边距适度收紧，居中紧致
        }
    }

    private var capsuleGap: CGFloat {
        switch proposal {
        case .baseline:
            return isHero ? 7 : 6
        case .prodNoBorder, .softMilk, .ghostWire, .dawnBreeze:
            return isHero ? 6 : 5
        }
    }

    private var capsuleFont: Font {
        isHero ? AppTheme.Font.tab2HeroCapsuleName : AppTheme.Font.tab2MoreRowCapsuleName
    }

    private var moreFont: Font {
        isHero ? AppTheme.Font.tab2HeroCapsuleMore : AppTheme.Font.tab2MoreRowCapsuleMore
    }

    private var bgFill: some ShapeStyle {
        switch proposal {
        case .baseline:
            // 生产真实基线：primary100 @ 30% 晨曦微透底
            return AppTheme.Color.tab2ActivityChipBg
        case .prodNoBorder:
            // 方案 1：完全取自生产同款晨曦浅底 (primary100 @ 30%)，不加边框
            return AppTheme.Color.tab2ActivityChipBg
        case .softMilk:
            // 方案 2：极简轻雾柔霜（极低彩度 4% 墨染柔底），高级杂志极简风，色调极其清透纯净
            return Color(hex: 0x211811).opacity(0.04)
        case .ghostWire:
            // 方案 3：方案 B 幽灵微边（彻底全透明去底，仅保留细线）
            return Color.clear
        case .dawnBreeze:
            // 方案 4：上个方案 A 晨曦微风颜色视觉（微暖晨曦光泽 primary100 @ 42%）
            return Color(hex: 0xFFF3EB).opacity(0.42)
        }
    }

    private var showsBorder: Bool {
        switch proposal {
        case .baseline, .ghostWire:
            return true // 基线与方案 3 带 0.5pt 边框
        case .prodNoBorder, .softMilk, .dawnBreeze:
            return false // 彻底不加边框（No Border）！
        }
    }

    private var borderWidth: CGFloat {
        switch proposal {
        case .baseline, .ghostWire: return 0.5
        case .prodNoBorder, .softMilk, .dawnBreeze: return 0
        }
    }

    private var borderColor: Color {
        switch proposal {
        case .baseline, .ghostWire:
            return AppTheme.Color.tab2ActivityChipBorder // 生产 presetIconInk @ 16% 细发丝边
        case .prodNoBorder, .softMilk, .dawnBreeze:
            return Color.clear
        }
    }

    private var textColor: Color {
        switch proposal {
        case .baseline:
            return AppTheme.Color.tab2ActivityChipText // 生产标准 neutral900 (#211811)
        case .prodNoBorder, .softMilk, .ghostWire, .dawnBreeze:
            // 极高对比度文字！neutral900 (#211811)，字字清晰挺拔！
            return AppTheme.Color.textPrimary
        }
    }
}

// MARK: - 方案定制版 CategoryProgressRow (注入降重 WordsPill)

private struct RefinedCategoryProgressRow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let proposal: Tab2CapsulesVisualRefinementPreviewView.CapsuleProposal
    let isSpotlight: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
                    // 图标
                    Image(systemName: SceneCategory.from(category.sceneCategory).iconName)
                        .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                    VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                        HStack(alignment: .center) {
                            Text(category.englishLabel)
                                .font(AppTheme.Font.tab2TopicLabel)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            Spacer()

                            // 核心注入：高对比度定制版 WordsPill
                            RefinedWordsPill(
                                count: category.wordCount,
                                isExpanded: isExpanded,
                                proposal: proposal,
                                isSpotlight: isSpotlight
                            )
                        }

                        // 进度微轨
                        GeometryReader { geo in
                            let progress = min(CGFloat(category.wordCount) / 20.0, 1.0)
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.Color.progressTrack.opacity(0.8))
                                Capsule().fill(AppTheme.Color.progressFill)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: AppTheme.Size.progressBarHeight)
                    }
                }
                .padding(.vertical, AppTheme.Space.listRowVertical)
            }
            .buttonStyle(.plain)

            // 展开手风琴单词列表
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(ProductionMockStore.words(for: category.sceneCategory), id: \.lemma) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.displayForm ?? word.lemma)
                                    .font(AppTheme.Font.tab2WordEntryTitle)
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                if let meaning = word.nativeMeaning {
                                    Text(meaning)
                                        .font(AppTheme.Font.tab2WordEntryMeaning)
                                        .foregroundStyle(AppTheme.Color.textMuted)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        Divider().opacity(0.1)
                    }
                }
                .padding(.leading, AppTheme.Size.categoryBadge + AppTheme.Size.categoryRowContentSpacing)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}

// MARK: - 降重版 WordsPill 渲染组件

private struct RefinedWordsPill: View {
    let count: Int
    let isExpanded: Bool
    let proposal: Tab2CapsulesVisualRefinementPreviewView.CapsuleProposal
    let isSpotlight: Bool

    var body: some View {
        switch proposal {
        case .baseline:
            // 生产原版：晨曦微底 + 0.5pt 发丝边
            HStack(spacing: AppTheme.Size.pillHSpacing) {
                Text(Tab2CardLabels.words(count))
                    .font(AppTheme.Font.tab2ProgressCount)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.tab2ActivityChipText)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: AppTheme.Size.expandArrow))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, AppTheme.Size.pillHPad) // 8
            .padding(.vertical, AppTheme.Size.pillVPad)   // 3
            .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
                }
            }

        case .prodNoBorder:
            // 方案 1：生产同款晨曦微底 · 彻底无边框 · 高对比深焦字
            HStack(spacing: 3.5) {
                Text(Tab2CardLabels.words(count))
                    .font(AppTheme.Font.tab2ProgressCount)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
            // 无任何边框
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
                }
            }

        case .softMilk:
            // 方案 2：纯净柔霜底 · 彻底无边框
            HStack(spacing: 3.5) {
                Text(Tab2CardLabels.words(count))
                    .font(AppTheme.Font.tab2ProgressCount)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color(hex: 0x211811).opacity(0.04), in: Capsule())
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
                }
            }

        case .ghostWire:
            // 方案 3：幽灵微边（全透明无底 + 0.5pt 细线）
            HStack(spacing: 3.5) {
                Text(Tab2CardLabels.words(count))
                    .font(AppTheme.Font.tab2ProgressCount)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
                }
            }

        case .dawnBreeze:
            // 方案 4：上个方案 A 晨曦微风颜色视觉（微暖晨曦柔润底 + 无边框）
            HStack(spacing: 3.5) {
                Text(Tab2CardLabels.words(count))
                    .font(AppTheme.Font.tab2ProgressCount)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color(hex: 0xFFF3EB).opacity(0.42), in: Capsule())
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - 真实生产 Mock 数据

private enum ProductionMockStore {
    static var activeHero: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "日常起居",
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 47,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 7,
            activities: [
                Tab2Activity(
                    sceneDetail: "Morning coffee",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-1",
                        imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Watering plants", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Tidying bedroom", occurrenceCount: 1)
            ]
        )
    }

    static var activeMoreCategories: [Tab2CategoryData] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        return [
            Tab2CategoryData(
                sceneCategory: "饮食",
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 38,
                lastTalkedAt: nil,
                lastMaterialAt: yesterday,
                newMaterialCount: 0,
                activityCount: 8,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Cooking dinner",
                        occurrenceCount: 3,
                        cover: Tab2Activity.Cover(
                            materialId: "m-food-1",
                            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Making breakfast", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Grocery shopping", occurrenceCount: 1)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 26,
                unlocked: true,
                notSpokenCount: 26,
                lastTalkedAt: nil,
                lastMaterialAt: threeDaysAgo,
                newMaterialCount: 0,
                activityCount: 4,
                activities: [
                    Tab2Activity(sceneDetail: "Taking subway", occurrenceCount: 4, cover: nil),
                    Tab2Activity(sceneDetail: "Cycling home", occurrenceCount: 1, cover: nil)
                ]
            )
        ]
    }

    static var inProgressCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "科技数码",
                wordCount: 16,
                unlocked: false,
                notSpokenCount: 16,
                lastTalkedAt: nil,
                lastMaterialAt: Date(),
                newMaterialCount: 2,
                activityCount: 3,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "运动健康",
                wordCount: 9,
                unlocked: false,
                notSpokenCount: 9,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                newMaterialCount: 0,
                activityCount: 2,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "休闲娱乐",
                wordCount: 4,
                unlocked: false,
                notSpokenCount: 4,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: []
            )
        ]
    }

    static func words(for category: String) -> [Tab2WordEntry] {
        switch category {
        case "科技数码":
            return [
                Tab2WordEntry(lemma: "gadget", displayForm: "gadgets", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "I have quite a few smart gadgets on my desk.", nativeMeaning: "小配件；小设备", imageUrl: nil),
                Tab2WordEntry(lemma: "thermos", displayForm: "thermos", entryKind: "word", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: nil, nativeMeaning: "保温杯", imageUrl: nil),
                Tab2WordEntry(lemma: "reboot", displayForm: "rebooting", entryKind: "word", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Try rebooting your device before giving up.", nativeMeaning: "重新启动", imageUrl: nil)
            ]
        case "运动健康":
            return [
                Tab2WordEntry(lemma: "hydrate", displayForm: "stay hydrated", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Make sure to stay hydrated throughout your workout.", nativeMeaning: "补充水分", imageUrl: nil),
                Tab2WordEntry(lemma: "stretch", displayForm: "stretching", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Morning stretching helps ease back pain.", nativeMeaning: "拉伸舒展", imageUrl: nil)
            ]
        default:
            return [
                Tab2WordEntry(lemma: "routine", displayForm: "routines", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Building a healthy daily routine takes patience.", nativeMeaning: "日常惯例", imageUrl: nil)
            ]
        }
    }
}

// MARK: - Canvas 预览入口

#Preview("Tab2 · 胶囊高对比度降重 (无边框版)") {
    Tab2CapsulesVisualRefinementPreviewView()
}
#endif
