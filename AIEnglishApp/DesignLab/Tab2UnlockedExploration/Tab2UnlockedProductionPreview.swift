#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Unlocked 生产全真正版画布 (Tab2 Unlocked Production Baseline)
// ⚠️ 规则：【正版以线上生产代码为准——本画布只镜像生产、不做探索改动；
//    生产变了（如刀 6a 三标题同档），画布随之同步】
// 🎯 100% 严格直接对齐线上生产代码架构与视觉设计（绝不改动任何标题、字段或排布）：
//   1. 视图外壳与框架：
//      - 顶栏：TopBarProgressiveMask 渐进遮罩 + SettingsMenuButton + TopTabSelector (选中 Library) + UsageLimitButton
//      - 背景基底：AppTheme.Color.pageBg (#FCF8F3 暖纸底色)
//      - 顶部预留：topInset 避让浮动顶栏，内容向上平滑滚入毛玻璃遮罩
//   2. 线上原版三大区块标题体系（原汁原味）：
//      - 第 1 区块大标题：Talk about today (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary)
//      - 第 2 区块大标题：More to talk about (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary——刀 6a 三标题同档)
//      - 第 3 区块大标题：Topics in progress (AppTheme.Font.sectionTitleSerif, 24pt Charter-Bold, textPrimary)
//   3. 线上原版组件调用：
//      - Hero：Tab2HeroCard
//      - More：Tab2ActivityRow
//      - Topics：CategoryProgressRow
//      - 底部：PoplexWordmark + BottomAuraFooter

struct Tab2UnlockedProductionPreviewView: View {
    @State private var previewScenario: PreviewScenario = .activeUser
    @State private var showTopBarShell: Bool = true
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case activeUser = "高频活跃 (3 解锁 + 3 累积)"
        case singleTopic = "单话题解锁 (无 More 区)"
        case quietState = "久未记录 (Quiet 灰胶囊)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端控制台 (仅供切换场景与顶栏外壳)
            controlPanel

            Divider().opacity(0.15)

            // 主画布视口
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. 页面大标题：Talk about today
                        pageTitleSection

                        // 2. 核心内容区 (Hero / More / Topics)
                        contentSections

                        // 3. 页面底部收尾宣言
                        footerSignoff
                            .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                    }
                    .padding(.top, showTopBarShell ? 64 : AppTheme.Space.paddingPage)
                    .background(alignment: .bottom) {
                        BottomAuraFooter()
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
    }

    // MARK: - 顶端控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tab2 Unlocked 生产正版基线 (永远不动)")
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
            .padding(.top, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingCard)
    }

    // MARK: - 核心内容区块集合 (100% 生产排版)

    @ViewBuilder
    private var contentSections: some View {
        let scenarioData = currentScenarioData

        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt
            // 1. Hero 卡片
            if let hero = scenarioData.hero {
                Tab2HeroCard(
                    category: hero,
                    onTalk: {
                        triggerAction("Start conversation: \(hero.englishLabel)")
                    }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 2. More to talk about (推荐行) —— 刀 6a：眉题改回页面级衬线标题
            if !scenarioData.moreCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt（同 Topics 标题→内容节奏）
                    Text("More to talk about")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold（刀 6a 三标题同档）
                        .foregroundStyle(AppTheme.Color.textPrimary)
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
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }

            // 3. Topics in progress (积累中话题) —— 生产原版 24pt 衬线标题
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
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }
        }
    }

    @State private var expandedCategoryId: String? = nil

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
        try? await Task.sleep(nanoseconds: 200_000_000)
        return ProductionMockStore.words(for: category)
    }

    private var currentScenarioData: (hero: Tab2CategoryData?, moreCategories: [Tab2CategoryData], inProgressCategories: [Tab2CategoryData]) {
        switch previewScenario {
        case .activeUser:
            return (
                hero: ProductionMockStore.activeHero,
                moreCategories: ProductionMockStore.activeMoreCategories,
                inProgressCategories: ProductionMockStore.inProgressCategories
            )
        case .singleTopic:
            return (
                hero: ProductionMockStore.activeHero,
                moreCategories: [],
                inProgressCategories: ProductionMockStore.inProgressCategories
            )
        case .quietState:
            return (
                hero: ProductionMockStore.quietHero,
                moreCategories: ProductionMockStore.quietMoreCategories,
                inProgressCategories: ProductionMockStore.inProgressCategories
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
                    sceneDetail: "Fixing a device",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-1",
                        imageUrl: "https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Watering plants", occurrenceCount: 1),
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
                    Tab2Activity(sceneDetail: "Writing report", occurrenceCount: 1)
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

#Preview("Tab2 · 生产正版基线 (永远不动)") {
    Tab2UnlockedProductionPreviewView()
}
#endif
