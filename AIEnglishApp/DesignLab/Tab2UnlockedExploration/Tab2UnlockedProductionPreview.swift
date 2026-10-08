#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Unlocked 生产全真正版画布 (Tab2 Unlocked Production Baseline)
// ⚠️ 规则：【正版以线上生产代码为准——本画布只镜像生产、不做探索改动；
//    生产变了（如刀 6a 三标题同档、More topics to explore 探索区），画布随之同步】
// 🎯 100% 严格直接对齐线上生产代码架构与视觉设计（绝不改动任何标题、字段或排布）：
//   1. 视图外壳与框架：
//      - 顶栏：TopBarProgressiveMask 渐进遮罩 + SettingsMenuButton + TopTabSelector (选中 Library) + UsageLimitButton
//      - 背景基底：AppTheme.Color.pageBg (#FBF8F5 暖纸底色)
//      - 顶部预留：topInset 避让浮动顶栏，内容向上平滑滚入毛玻璃遮罩
//   2. 线上原版四大区块体系（原汁原味）：
//      - 第 1 区块大标题：Talk about today (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary)
//      - 第 2 区块大标题：More to talk about (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary——刀 6a 三标题同档)
//      - 第 3 区块大标题：Topics in progress (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary)
//      - 第 4 区块大标题：More topics to explore (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary——全真 3+1 / 两排流式胶囊)
//   3. 线上原版组件调用：
//      - Hero：Tab2HeroCard (含封面、理由、Recent activities 胶囊组、47 words 与 CTA)
//      - More：Tab2ActivityRow (含缩略图、帽子、活动胶囊组、38 words)
//      - Topics：CategoryProgressRow (含类别图标、进度条、WordsPill 胶囊与手风琴展开)
//      - Explore：Tab2MoreTopicsSection (未开始分类探索区)
//      - 底部：PoplexWordmarkMono + tagline + BottomAuraFooter
//   4. 胶囊优化专属工具：
//      - 支持一键开启「胶囊透视检视 (Capsule Focus)」，高亮标注 Activity 胶囊与 Words 胶囊的当前生产尺寸与 Token

struct Tab2UnlockedProductionPreviewView: View {
    @State private var previewScenario: PreviewScenario = .activeUser
    @State private var showTopBarShell: Bool = true
    @State private var highlightCapsules: Bool = false
    @State private var showMetricsCard: Bool = false
    @State private var expandedCategoryId: String? = nil
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case activeUser = "典型活跃态 (完整 4 大区)"
        case expandedAccordion = "手风琴展开态 (查看 WordsPill)"
        case singleTopic = "单话题解锁 (无 More 区)"
        case quietState = "久未记录 (Quiet 状态)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端控制台 (仅供切换场景、外壳与胶囊检视)
            controlPanel

            Divider().opacity(0.15)

            // 胶囊透视信息浮条（在开启检视时展开）
            if highlightCapsules || showMetricsCard {
                capsuleMetricsBanner
            }

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
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("Tab2 Unlocked 生产像素级基线")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                // 胶囊检视开关
                Toggle("检视胶囊", isOn: $highlightCapsules)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(highlightCapsules ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)
                    .labelsHidden()
                Text(highlightCapsules ? "胶囊透视 ON" : "胶囊透视 OFF")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(highlightCapsules ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)

                Divider().frame(height: 14)

                Toggle("模拟顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

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

    // MARK: - 胶囊当前生产规格参数展示条

    private var capsuleMetricsBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Text("当前生产胶囊度量规格 (Target Tokens)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showMetricsCard.toggle()
                    }
                } label: {
                    Text(showMetricsCard ? "收起参数" : "展开详细参数")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
            }

            if showMetricsCard {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("① Activity 胶囊 (Hero)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                        Text("Charter 13.5pt · 高 25pt · 内距 9pt · 间距 7pt · 边框 0.5pt (#E2D9CC)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    GridRow {
                        Text("② Activity 胶囊 (More)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                        Text("Charter 12pt · 高 22pt · 内距 8pt · 间距 6pt · 边框 0.5pt (#E2D9CC)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    GridRow {
                        Text("③ Words 胶囊 (WordsPill)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Color.interactive)
                        Text("12pt tabular · 内距 H:8 V:3 · 箭头 8pt · 背景 #F2ECE4 · 边框 0.5pt (#E5DDD2)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 8)
        .background(AppTheme.Color.brandStrong.opacity(0.06))
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
    // 严格直接对齐 MineView.swift 的 contentSections 架构：
    // 每个区块自主管理其大标题 (sectionTitleSerif) + 卡片组，区块之间以 paddingBetweenSections (28pt) 分隔

    @ViewBuilder
    private func contentSections(_ proxy: ScrollViewProxy) -> some View {
        let scenarioData = currentScenarioData

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt
            // ── 1. Talk about today (Hero 区块) ──
            if let hero = scenarioData.hero {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    HStack {
                        Text("Talk about today")
                            .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        if highlightCapsules {
                            Text("Activity 胶囊 × Words")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.Color.brandStrong)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    Tab2HeroCard(
                        category: hero,
                        onTalk: {
                            triggerAction("Start conversation: \(hero.englishLabel)")
                        }
                    )
                    .overlay {
                        if highlightCapsules {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                .strokeBorder(AppTheme.Color.brandStrong.opacity(0.35), lineWidth: 1.5)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 2. More to talk about (推荐行) —— 刀 6a：三标题同档 24pt 衬线 ──
            if !scenarioData.moreCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    HStack {
                        Text("More to talk about")
                            .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        if highlightCapsules {
                            Text("Activity 胶囊 (More)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.Color.brandStrong)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 推荐列表行
                    VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) { // 12pt
                        ForEach(scenarioData.moreCategories) { category in
                            Tab2ActivityRow(
                                category: category,
                                onTap: {
                                    triggerAction("Selected topic: \(category.englishLabel)")
                                }
                            )
                            .overlay {
                                if highlightCapsules {
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                        .strokeBorder(AppTheme.Color.brandStrong.opacity(0.25), lineWidth: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 3. Topics in progress (手风琴进度卡片) —— 核心包含 WordsPill ──
            if !scenarioData.inProgressCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    HStack {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        if highlightCapsules {
                            Text("WordsPill 核心胶囊")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.Color.interactive)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Color.interactive.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 进度卡片磨砂玻璃容器
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
                    .overlay {
                        if highlightCapsules {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                .strokeBorder(AppTheme.Color.interactive.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // ── 4. More topics to explore (2026-10-03 新增探索区) ──
            // 与待解锁页同一组件，贯穿解锁前后；解锁后不带注脚（规则用户已知）
            let unstarted = SceneCategory.unstarted(given: scenarioData.allCategories)
            if !unstarted.isEmpty {
                Tab2MoreTopicsSection(topics: unstarted, footnote: nil, resetToken: nil)
            }
        }
        .padding(.top, AppTheme.Space.tab2ContentTop)
    }

    // MARK: - 底部收尾

    private var footerSignoff: some View {
        VStack(spacing: AppTheme.Space.tab2FooterBrandToTagline) {
            HStack(spacing: AppTheme.Space.tab2FooterMarkSpacing) {
                PoplexSproutMark(
                    height: AppTheme.Size.tab2FooterSproutHeight,
                    tintColor: AppTheme.Color.textMuted
                )

                PoplexWordmarkMono(
                    capHeight: AppTheme.Size.tab2FooterWordmarkCapHeight,
                    color: AppTheme.Color.textMuted
                )
            }

            Text(MineView.footerTagline())
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
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
        return ProductionMockStore.words(for: category)
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
        case .quietState:
            let hero = ProductionMockStore.quietHero
            let more = ProductionMockStore.quietMoreCategories
            let inProgress = ProductionMockStore.inProgressCategories
            return (
                hero: hero,
                moreCategories: more,
                inProgressCategories: inProgress,
                allCategories: [hero] + more + inProgress
            )
        }
    }
}

// MARK: - 真实高保真生产 Mock 数据中心 (完全对应线上字段)

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

    static var quietHero: Tab2CategoryData {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        return Tab2CategoryData(
            sceneCategory: "日常起居",
            wordCount: 42,
            unlocked: true,
            notSpokenCount: 42,
            lastTalkedAt: nil,
            lastMaterialAt: threeDaysAgo,
            newMaterialCount: 0,
            activityCount: 5,
            activities: [
                Tab2Activity(
                    sceneDetail: "Fixing a device",
                    occurrenceCount: 2,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-quiet",
                        imageUrl: "https://images.unsplash.com/photo-1517404215738-15263e9f9178?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Cleaning room", occurrenceCount: 1)
            ]
        )
    }

    static var activeMoreCategories: [Tab2CategoryData] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -8, to: Date())!

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
                    Tab2Activity(sceneDetail: "Grocery shopping", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Brewing tea", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Baking bread", occurrenceCount: 1)
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
                    Tab2Activity(sceneDetail: "Cycling home", occurrenceCount: 1, cover: nil),
                    Tab2Activity(sceneDetail: "Walking to station", occurrenceCount: 1, cover: nil)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "工作与学业",
                wordCount: 22,
                unlocked: true,
                notSpokenCount: 22,
                lastTalkedAt: nil,
                lastMaterialAt: lastWeek,
                newMaterialCount: 0,
                activityCount: 6,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Team meeting",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-work-1",
                            imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Writing report", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Code review", occurrenceCount: 1)
                ]
            )
        ]
    }

    static var quietMoreCategories: [Tab2CategoryData] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let oneMonthAgo = Calendar.current.date(byAdding: .day, value: -35, to: Date())!

        return [
            Tab2CategoryData(
                sceneCategory: "饮食",
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 38,
                lastTalkedAt: nil,
                lastMaterialAt: twoWeeksAgo,
                newMaterialCount: 0,
                activityCount: 4,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Dining out",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-food-q",
                            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80"
                        )
                    )
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "休闲娱乐",
                wordCount: 24,
                unlocked: true,
                notSpokenCount: 24,
                lastTalkedAt: nil,
                lastMaterialAt: oneMonthAgo,
                newMaterialCount: 0,
                activityCount: 3,
                activities: [
                    Tab2Activity(sceneDetail: "Watching movie", occurrenceCount: 1, cover: nil)
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

#Preview("Tab2 · 生产正版基线 (像素级还原)") {
    Tab2UnlockedProductionPreviewView()
}
#endif
