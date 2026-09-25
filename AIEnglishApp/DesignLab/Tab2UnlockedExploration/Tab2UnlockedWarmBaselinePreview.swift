#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Unlocked 温暖基线全真画布 (Tab2 Unlocked Warm Baseline DesignLab Sandbox)
// 🎯 核心定位与原则：
//   1. 100% 像素级复原最新优化状态（Commit 007f1f7）：
//      - 绝不手写任何私有组件或转录色值（彻底消灭 WarmHeroCard / WarmActivityRow 副本）；
//      - 100% 直接消费生产同源组件：Tab2HeroCard、Tab2ActivityRow、CategoryProgressRow、Theme.swift；
//      - 生产代码有任何微调，本画布 100% 自动联动生效，杜绝出现“两套真相”。
//   2. 完备的走查与设计演进沙盒：
//      - 支持 4 大核心业务场景一键切换（晨曦预设图、实拍照片、Quiet 沉静态、Only words 空态）；
//      - 支持 12 大 SceneCategory 实时切换，可直接走查每个分类的「手绘细线矢量图标 + 晨曦双光晕」；
//      - 支持模拟浮动顶栏（TopBarProgressiveMask）避让切换；
//      - 在此稳固基准上，可安全、自信地进行下一轮视觉精细化调优。

struct Tab2UnlockedWarmBaselinePreviewView: View {
    @State private var previewScenario: PreviewScenario = .presetArtHero
    @State private var selectedCategory: SceneCategory = .dailyRoutines
    @State private var showTopBarShell: Bool = true
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine
    @State private var timelineAlignment: TimelineAlignmentMode = .aligned
    @State private var showAlignmentGuide: Bool = true
    @State private var expandedCategoryId: String? = nil

    enum TimelineAlignmentMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case aligned  = "优化后 (16pt 统一对齐)"
        case baseline = "基线现状 (39pt 凹陷)"
    }

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case presetArtHero  = "晨曦暖光预设图 (手绘+双光晕+橙点)"
        case photoCoverHero = "真实照片封面态 (实拍图+裸字投影)"
        case quietState     = "久未记录 Quiet 态 (沉静单色理由)"
        case onlyWordsState = "无活动空态 (Only words so far)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端交互控制台 (供设计走查不同场景与分类)
            controlPanel

            Divider().opacity(0.15)

            // 主画布视口 (100% 生产真实视口排版)
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. 页面大标题：Talk about today (24pt Charter-Bold)
                        pageTitleSection

                        // 2. 核心内容区块集合 (Hero / More / Topics)
                        contentSections

                        // 3. 页面底部收尾宣言
                        footerSignoff
                            .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                    }
                    .padding(.top, showTopBarShell ? 56 : AppTheme.Space.paddingPage)
                    .background(alignment: .bottom) {
                        BottomAuraFooter()
                    }
                }
                .background(AppTheme.Color.pageBg.ignoresSafeArea())

                // 浮动顶栏 (全真对齐 RootTabContainer)
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

    // MARK: - 顶端控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tab2 温暖基线全真画布 (最新生产)")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Toggle("模拟外壳顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            // 场景切换器
            Picker("场景", selection: $previewScenario) {
                ForEach(PreviewScenario.allCases) { sc in
                    Text(sc.rawValue).tag(sc)
                }
            }
            .pickerStyle(.segmented)

            // 12 分类切换走查器（便于审查每个分类的手绘线框与晨曦光晕）
            HStack(spacing: 8) {
                Text("走查分类:")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Picker("分类", selection: $selectedCategory) {
                    ForEach(SceneCategory.allCases, id: \.self) { cat in
                        Text(cat.englishLabel).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Color.brandStrong)

                Spacer()
            }

            // 时间标签排布对比走查器
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("时间标签对齐:")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("时间标签对齐", selection: $timelineAlignment) {
                        ForEach(TimelineAlignmentMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Toggle("显示 16pt 右对齐辅助参考线", isOn: $showAlignmentGuide)
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
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

    // MARK: - 页面标题区 (Talk about today)

    private var pageTitleSection: some View {
        Text("Talk about today")
            .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
            .foregroundStyle(AppTheme.Color.textPrimary)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingCard)
    }

    // MARK: - 核心内容区块集合 (100% 调用生产组件)

    @ViewBuilder
    private var contentSections: some View {
        let scenarioData = currentScenarioData

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt
            // 1. Hero 卡片 —— 100% 生产 Tab2HeroCard
            if let hero = scenarioData.hero {
                Tab2HeroCard(
                    category: hero,
                    onTalk: {
                        triggerAction("Start conversation: \(hero.englishLabel)")
                    }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 2. More to talk about (推荐行) —— 支持 16pt 统一对齐走查
            if !scenarioData.moreCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("More to talk about")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 推荐列表行集合
                    VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) { // 12pt
                        ForEach(scenarioData.moreCategories) { category in
                            ExplorationMoreRow(
                                category: category,
                                alignmentMode: timelineAlignment,
                                showGuide: showAlignmentGuide,
                                onTap: {
                                    triggerAction("Selected topic: \(category.englishLabel)")
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // 3. Topics in progress (积累中话题) —— 100% 生产 CategoryProgressRow
            if !scenarioData.inProgressCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 进度卡片容器
                    VStack(spacing: 0) {
                        ForEach(Array(scenarioData.inProgressCategories.enumerated()), id: \.element.id) { index, cat in
                            CategoryProgressRow(
                                category: cat,
                                isExpanded: expandedCategoryId == cat.id,
                                onToggle: {
                                    withAnimation(AppTheme.Motion.accordionToggle) {
                                        expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                    }
                                },
                                loadWords: {
                                    try await loadMockWords(for: cat.sceneCategory)
                                },
                                wordsRevision: 1,
                                milestonePresentations: []
                            )
                            .id(cat.id)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    .overlay(alignment: .trailing) {
                        if showAlignmentGuide {
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(Color.orange.opacity(0.85))
                                .frame(width: 1)
                                .padding(.trailing, AppTheme.Space.paddingPage)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }
        }
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

    private func loadMockWords(for category: String) async throws -> [Tab2WordEntry] {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return WarmBaselineMockStore.words(for: category)
    }

    // MARK: - 场景数据派发 (动态适配选定分类与场景)

    private var currentScenarioData: (hero: Tab2CategoryData?, moreCategories: [Tab2CategoryData], inProgressCategories: [Tab2CategoryData]) {
        let hero = WarmBaselineMockStore.hero(
            scenario: previewScenario,
            category: selectedCategory
        )
        return (
            hero: hero,
            moreCategories: WarmBaselineMockStore.moreCategories(excluding: selectedCategory),
            inProgressCategories: WarmBaselineMockStore.inProgressCategories
        )
    }
}

// MARK: - 真实高保真 Mock 数据中心

private enum WarmBaselineMockStore {
    static func hero(scenario: Tab2UnlockedWarmBaselinePreviewView.PreviewScenario, category: SceneCategory) -> Tab2CategoryData {
        let catKey = category.rawValue

        switch scenario {
        case .presetArtHero:
            // 晨曦暖光预设图态：cover 为 nil，走 CategoryPresetArtView
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
            // 真实照片封面态：第一条带 cover，走 Tab2HeroPhotoArt
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
            // 久未记录 Quiet 态：5 天未记录，理由文案走 quiet
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

        case .onlyWordsState:
            // 无活动空态：activityCount = 0，展现「Only words so far」
            let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
            return Tab2CategoryData(
                sceneCategory: catKey,
                wordCount: 29,
                unlocked: true,
                notSpokenCount: 29,
                lastTalkedAt: nil,
                lastMaterialAt: twoDaysAgo,
                newMaterialCount: 0,
                activityCount: 0,
                activities: []
            )
        }
    }

    static func moreCategories(excluding current: SceneCategory) -> [Tab2CategoryData] {
        let pool: [SceneCategory] = [.food, .workStudy, .shopping, .gettingAround]
            .filter { $0 != current }

        return pool.prefix(2).enumerated().map { index, cat in
            Tab2CategoryData(
                sceneCategory: cat.rawValue,
                wordCount: 20 + index * 12,
                unlocked: true,
                notSpokenCount: 20 + index * 12,
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

    static var inProgressCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: SceneCategory.shopping.rawValue,
                wordCount: 14,
                unlocked: false,
                notSpokenCount: 14,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Grocery haul", occurrenceCount: 1)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.leisure.rawValue,
                wordCount: 8,
                unlocked: false,
                notSpokenCount: 8,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Weekend movie", occurrenceCount: 1)
                ]
            )
        ]
    }

    static func words(for category: String) -> [Tab2WordEntry] {
        [
            Tab2WordEntry(
                lemma: "tinker",
                displayForm: "tinkering",
                entryKind: "word",
                pos: "v.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "I love tinkering with gadgets on weekends.",
                nativeMeaning: "倒腾，琢磨修整",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "device",
                displayForm: "device",
                entryKind: "word",
                pos: "n.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "Fixing a broken device requires patience.",
                nativeMeaning: "设备，器具",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "glitch",
                displayForm: "glitch",
                entryKind: "word",
                pos: "n.",
                granularity: "word",
                sourceType: "material",
                sampleSentence: nil,
                nativeMeaning: "小故障，差错",
                imageUrl: nil
            )
        ]
    }
}

// MARK: - More 行排布探索组件 (ExplorationMoreRow)

private struct ExplorationMoreRow: View {
    let category: Tab2CategoryData
    let alignmentMode: Tab2UnlockedWarmBaselinePreviewView.TimelineAlignmentMode
    let showGuide: Bool
    let onTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }

    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(ExplorationRowPressStyle())
    }

    @ViewBuilder
    private var rowContent: some View {
        switch alignmentMode {
        case .aligned:
            // 🎯 最新生产实现：Tab2ActivityRow 已经落地 16pt 对齐
            Tab2ActivityRow(category: category, onTap: onTap)
                .overlay(alignment: .trailing) {
                    if showGuide {
                        guideLine
                    }
                }

        case .baseline:
            // 标尺基线：旧版生产实现（HStack 将 VStack 与 arrow 并排，导致帽行右侧被挤进 ~39pt）
            LegacyBaselineMoreRow(category: category, onTap: onTap)
                .overlay(alignment: .trailing) {
                    if showGuide {
                        guideLine
                    }
                }
        }
    }

    private var guideLine: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundStyle(Color.orange.opacity(0.85))
            .frame(width: 1)
            .padding(.trailing, AppTheme.Space.paddingPage)
            .allowsHitTesting(false)
    }
}

/// 历史基线对比行（旧版：未通栏横跨，时间标签被推入 ~39pt 处）
private struct LegacyBaselineMoreRow: View {
    let category: Tab2CategoryData
    let onTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                    .overlay(thumbnail)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    hatRow
                    if display.valid.isEmpty {
                        Tab2OnlyWordsLine()
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)
                        wordsLine
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.emptyLineToWords)
                    } else {
                        activityBlock
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)
                        wordsLine
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                    }
                }
                .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
                .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
                .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
                .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                Image(systemName: "arrow.right")
                    .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.trailing, 14)
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
        .buttonStyle(ExplorationRowPressStyle())
    }

    private var thumbnailSlot: some View {
        Color.clear
            .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
            .overlay(thumbnail)
            .clipped()
            .accessibilityHidden(true)
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
            .saturation(AppTheme.Tab2MoreRow.ImageTreatment.photoSaturation)
            .overlay(
                Rectangle()
                    .fill(AppTheme.Color.tab2MoreRowPhotoToneWarm)
                    .blendMode(.multiply)
                    .opacity(AppTheme.Tab2MoreRow.Opacity.photoToneWarm)
                    .allowsHitTesting(false)
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

    private var activityBlock: some View {
        Tab2ActivityCapsuleGroup(
            activities: display.valid,
            activityCount: category.activityCount,
            blockedCount: display.blockedCount,
            metrics: Tab2ActivityCapsuleMetrics.more(),
            nameFont: AppTheme.Font.tab2MoreRowCapsuleName,
            moreFont: AppTheme.Font.tab2MoreRowCapsuleMore
        )
        .equatable()
    }

    private var wordsLine: some View {
        Text(Tab2CardLabels.words(category.wordCount))
            .font(AppTheme.Font.tab2MoreRowMeta)
            .foregroundStyle(AppTheme.Color.textMuted)
            .monospacedDigit()
            .lineLimit(1)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
            .foregroundStyle(AppTheme.Color.textMuted)
            .accessibilityHidden(true)
    }

    private var timelineText: String? {
        Tab2CardLabels.timeLine(lastMaterialAt: category.lastMaterialAt)
    }
}

private struct ExplorationRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppTheme.Tab2MoreRow.Motion.pressedScale : 1)
            .animation(
                .spring(
                    response: AppTheme.Tab2MoreRow.Motion.pressResponse,
                    dampingFraction: AppTheme.Tab2MoreRow.Motion.pressDamping
                ),
                value: configuration.isPressed
            )
    }
}

// MARK: - Xcode Canvas 预览入口

#Preview("Tab2 Unlocked 温暖基线全真画布") {
    Tab2UnlockedWarmBaselinePreviewView()
}
#endif
