#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Unlocked: 第 4 部分 (More topics to explore) 当前材质下“胶囊高度变低”方案对比
//
// 🎯 核心原则：
// 1. 胶囊颜色与材质 100% 保持当前生产环境不变：
//    - 底色：AppTheme.Tab2ExploreTopics.Color.tagFill (纯正纸白卡片底 cardBg)
//    - 边框：AppTheme.Tab2ExploreTopics.Color.tagBorder (cardBorder.opacity(0.6), 0.8pt)
//    - 投影：AppTheme.Tab2ExploreTopics.Color.tagShadow (black.opacity(0.015), radius 3, y 1)
//    - 图标色：AppTheme.Tab2ExploreTopics.Color.tagIcon (textMuted)
//    - 文字色：AppTheme.Tab2ExploreTopics.Color.tagLabel (textSecondary)
//    - 字体：AppTheme.Font.tab2ExploreTagLabel (12pt / 400 Regular)
// 2. 仅仅把胶囊的高度变低，设置 4 个对比档位，方便找感受：
//    - 方案 H-25 ⭐（高 25pt · 降 13pt · 黄金对齐 · 强烈推荐）: 与已落地的 Activity 胶囊体系呼应，轻盈精致
//    - 方案 H-28（高 28pt · 降 10pt · 适度舒展）: 比当前显著减负，呼吸留白充裕
//    - 方案 H-22（高 22pt · 降 16pt · 极致微型）: 手账小微标，体量极小，完全退居次席
//    - 方案 H-38（高 38pt · 当前生产基线 · 对照参照）: 线上原本的高度，直观感受减薄差异
// 3. 前三个部分严格遵照当前已优化并落地的生产视觉，案例丰富，保证整屏滑动的真实呼吸感。

struct Tab2UnlockedProposal4ComparisonPreviewView: View {
    @State private var selectedHeightScheme: ExploreHeightScheme
    @State private var expandedCategoryId: String? = nil
    @State private var showMetricsDetail: Bool = false
    @State private var isSideBySideMode: Bool = false
    @State private var selectedTab: AppTab = .mine
    @State private var toastMessage: String? = nil

    init(initialScheme: ExploreHeightScheme = .height25) {
        _selectedHeightScheme = State(initialValue: initialScheme)
    }

    enum ExploreHeightScheme: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case height25 = "25pt 轻巧 ⭐"
        case height28 = "28pt 适度"
        case height22 = "22pt 微型"
        case height38 = "38pt 当前基线"

        var height: CGFloat {
            switch self {
            case .height25: 25
            case .height28: 28
            case .height22: 22
            case .height38: 38
            }
        }

        var horizontalInset: CGFloat {
            switch self {
            case .height25: 10
            case .height28: 12
            case .height22: 8
            case .height38: 14
            }
        }

        var iconToLabelSpacing: CGFloat {
            switch self {
            case .height25: 5
            case .height28: 5.5
            case .height22: 4.5
            case .height38: 7
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .height25: 11.5
            case .height28: 12
            case .height22: 11
            case .height38: 13
            }
        }

        var subtitle: String {
            switch self {
            case .height25: "高 25pt · 降 13pt · 与上方 24~25pt 胶囊光学平衡，精致无压（推荐）"
            case .height28: "高 28pt · 降 10pt · 明显轻量化，留白相对舒展"
            case .height22: "高 22pt · 降 16pt · 极致微型标贴，完全退让于卡片后"
            case .height38: "高 38pt · 生产当前高度 · 作为基准参照，感受尺寸差距"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端控制面板 (方案切换、参数展开、快速定位、模式切换)
            topControlBar

            Divider().opacity(0.12)

            if isSideBySideMode {
                // 4 屏横向滚动并排对比模式
                sideBySideOverviewView
            } else {
                // 单屏沉浸真实页面模式
                singleScreenPhoneViewport(selectedHeightScheme)
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                toastOverlay(text: toast)
            }
        }
    }

    // MARK: - 顶端控制条

    private var topControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("More topics to explore 胶囊降高对比")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                // 切换单屏/并排模式
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isSideBySideMode.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSideBySideMode ? "iphone" : "square.split.2x1")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isSideBySideMode ? "返回单屏体验" : "4屏横向并排")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSideBySideMode ? AppTheme.Color.brandStrong.opacity(0.12) : AppTheme.Color.tab2ActivityChipBg)
                    .foregroundStyle(isSideBySideMode ? AppTheme.Color.brandStrong : AppTheme.Color.textPrimary)
                    .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showMetricsDetail.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(showMetricsDetail ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)
                }
            }

            if !isSideBySideMode {
                Picker("高度档位", selection: $selectedHeightScheme) {
                    ForEach(ExploreHeightScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 当前方案规格说明条
            if showMetricsDetail {
                metricsDetailCard
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 8)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 参数说明折叠卡

    private var metricsDetailCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("当前选中：\(selectedHeightScheme.rawValue)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Spacer()
                Text(selectedHeightScheme.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            Divider().opacity(0.1)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                GridRow {
                    Text("材质与颜色").font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.Color.textMuted)
                    Text("100% 保持当前环境不变：白底 cardBg · 浅边 cardBorder(0.6) · 极微投影 black(0.015)").font(.system(size: 10)).foregroundStyle(AppTheme.Color.textSecondary)
                }
                GridRow {
                    Text("胶囊高度").font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.Color.textMuted)
                    Text("\(Int(selectedHeightScheme.height))pt (当前基线为 38pt，降了 \(Int(38 - selectedHeightScheme.height))pt)").font(.system(size: 10, weight: .medium)).foregroundStyle(AppTheme.Color.brandStrong)
                }
                GridRow {
                    Text("内距与图标").font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.Color.textMuted)
                    Text("横向内距 \(Int(selectedHeightScheme.horizontalInset))pt · 图标 \(String(format: "%.1f", selectedHeightScheme.iconSize))pt · 间距 \(String(format: "%.1f", selectedHeightScheme.iconToLabelSpacing))pt").font(.system(size: 10)).foregroundStyle(AppTheme.Color.textSecondary)
                }
            }
        }
        .padding(10)
        .background(AppTheme.Color.brandStrong.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 单屏真实页面视口 (可滚动、体验上下滑动呼吸节奏)

    private func singleScreenPhoneViewport(_ scheme: ExploreHeightScheme) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 顶栏避让
                    Color.clear.frame(height: 16)

                    // 快速直达底部探索区浮动小条
                    quickJumpBar(proxy)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, 12)

                    // 四大完整内容区块
                    fullContentSections(scheme: scheme, proxy: proxy)

                    Spacer(minLength: AppTheme.Space.tab2FooterTop)

                    footerSignoff
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                }
                .background(alignment: .bottom) {
                    BottomAuraFooter()
                }
            }
            .scrollBounceBehavior(.always, axes: .vertical)
        }
    }

    // MARK: - 快速跳转小条

    private func quickJumpBar(_ proxy: ScrollViewProxy) -> some View {
        HStack {
            Text("👇 向下滑动体验整页节奏，或一键直达对比：")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo("section4ExploreAnchor", anchor: .top)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                    Text("直达第 4 部分")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.Color.brandStrong)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 4 屏横向并排概览模式 (Side by Side)

    private var sideBySideOverviewView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("左右滑动查看当前材质下 4 种高度的整屏呼应：")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                    ForEach(ExploreHeightScheme.allCases) { s in
                        VStack(spacing: 6) {
                            HStack {
                                Text(s.rawValue)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                Spacer()
                                Text("高度 \(Int(s.height))pt")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.Color.textMuted)
                            }
                            .padding(.horizontal, 8)

                            // 独立 iPhone 视口外框
                            singleScreenPhoneViewport(s)
                                .frame(width: 360, height: 740)
                                .background(AppTheme.Color.pageBg)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 核心内容四大区块 (前三部分完全落地，仅第 4 部分按高度变化)

    @ViewBuilder
    private func fullContentSections(scheme: ExploreHeightScheme, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt 标准区块间距

            // ── 区块 1：Talk about today (Hero 区块) ──
            // 采用落地后的：字色方案 2 (tab2CapsuleText #6B6259) + 胶囊尺寸方案 A (24pt / 12pt regular)
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                sectionHeader(title: "Talk about today", badge: "第 1 部分 · 落地规范")

                Tab2HeroCard(
                    category: Proposal4MockStore.richHeroData,
                    onTalk: { triggerAction("Tap Hero Practice") }
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // ── 区块 2：More to talk about (更多话题卡片) ──
            // 采用落地后的：字色方案 2 + 尺寸方案 A；案例丰富（4 个完整分类卡片）
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                sectionHeader(title: "More to talk about", badge: "第 2 部分 · 4个案例")

                VStack(spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(Proposal4MockStore.richMoreCategories) { item in
                        Tab2ActivityRow(
                            category: item,
                            onTap: { triggerAction("Tap Category \(item.sceneCategory)") }
                        )
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // ── 区块 3：Topics in progress (进行中分类进度) ──
            // 采用刚 commit 的方案 3-B ⭐（13pt Regular 400 细线排印 + 14pt Regular SF Symbol 图标）
            // 案例丰富（4 个进行中分类，支持手风琴展开查看真实单词卡片）
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                sectionHeader(title: "Topics in progress", badge: "第 3 部分 · 方案 3-B 落地")

                VStack(spacing: 0) {
                    ForEach(Proposal4MockStore.richInProgressCategories) { item in
                        CategoryProgressRow(
                            category: item,
                            isExpanded: expandedCategoryId == item.id,
                            onToggle: {
                                toggleCategory(item.id)
                            },
                            loadWords: {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                return Proposal4MockStore.words(for: item.sceneCategory)
                            },
                            wordsRevision: 1
                        )
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // ── 区块 4：More topics to explore (未开启分类探索区) ──
            // 🌟 颜色材质保持当前环境不变，高度根据所选方案动态渲染！
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("More topics to explore")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    Text("当前材质 · 高度 \(Int(scheme.height))pt")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Tab2ExploreTopics.Layout.titleToTags)

                // 探索区标签集合（双排流式横滑）
                exploreTagsLayout(scheme: scheme)

                // 探索区注脚
                Text("Record moments from your day to start these topics.")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Tab2ExploreTopics.Layout.tagsToFootnote)
            }
            .id("section4ExploreAnchor")
        }
    }

    // MARK: - 区块标题

    private func sectionHeader(title: String, badge: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Spacer()

            Text(badge)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    // MARK: - 第 4 部分探索区排布与胶囊呈现

    @ViewBuilder
    private func exploreTagsLayout(scheme: ExploreHeightScheme) -> some View {
        let rows = Tab2ExploreTagLayout.rows(Proposal4MockStore.richUnstartedTopics)

        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                        ForEach(rows[rowIndex], id: \.self) { topic in
                            exploreTagItem(topic: topic, scheme: scheme)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Tab2ExploreTopics.Shadow.tagRadius)
        }
    }

    @ViewBuilder
    private func exploreTagItem(topic: SceneCategory, scheme: ExploreHeightScheme) -> some View {
        // 🌟 100% 保持当前环境中的材质与颜色：
        // 白底 cardBg + 浅边 cardBorder(0.6) + 微弱羽化阴影
        HStack(spacing: scheme.iconToLabelSpacing) {
            Image(systemName: topic.iconName)
                .font(.system(size: scheme.iconSize, weight: .regular))
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagIcon) // 当前环境中的图标色
                .accessibilityHidden(true)

            Text(topic.englishLabel)
                .font(AppTheme.Font.tab2ExploreTagLabel) // 12pt / 400
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagLabel) // 当前环境中的文字色
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, scheme.horizontalInset)
        .frame(height: scheme.height)
        .background {
            Capsule()
                .fill(AppTheme.Tab2ExploreTopics.Color.tagFill) // 当前环境中的底色 (cardBg 白底)
                .strokeBorder(
                    AppTheme.Tab2ExploreTopics.Color.tagBorder, // 当前环境中的边框色
                    lineWidth: AppTheme.Tab2ExploreTopics.Layout.tagBorderWidth
                )
        }
        .shadow(
            color: AppTheme.Tab2ExploreTopics.Color.tagShadow, // 当前环境中的微弱投影
            radius: AppTheme.Tab2ExploreTopics.Shadow.tagRadius,
            y: AppTheme.Tab2ExploreTopics.Shadow.tagY
        )
    }

    // MARK: - 底部落款

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
        .padding(.top, 24)
    }

    // MARK: - Actions

    private func toggleCategory(_ id: String) {
        withAnimation(AppTheme.Motion.accordionToggle) {
            if expandedCategoryId == id {
                expandedCategoryId = nil
            } else {
                expandedCategoryId = id
            }
        }
    }

    private func triggerAction(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func toastOverlay(text: String) -> some View {
        Text(text)
            .font(AppTheme.Font.pos)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8), in: Capsule())
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - 充实高保真 Mock 数据中心 (案例多一点，找感受)

private enum Proposal4MockStore {

    // ── 1. Hero 丰富案例 (日常起居 · 47 words · 4 个实际活动胶囊) ──
    static var richHeroData: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "Daily Routine",
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 47,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 7,
            activities: [
                Tab2Activity(
                    sceneDetail: "Morning espresso at boutique cafe",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-rich-1",
                        imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Subway commute listening to podcast", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Stretching in the living room", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Picked up fresh sourdough bread", occurrenceCount: 1)
            ]
        )
    }

    // ── 2. More to talk about 丰富案例 (4 个完整分类卡片) ──
    static var richMoreCategories: [Tab2CategoryData] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        return [
            // 案例 1: 餐饮生活
            Tab2CategoryData(
                sceneCategory: "Food & Drink",
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 38,
                lastTalkedAt: nil,
                lastMaterialAt: yesterday,
                newMaterialCount: 2,
                activityCount: 8,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Dinner with old college friends",
                        occurrenceCount: 3,
                        cover: Tab2Activity.Cover(
                            materialId: "m-food-1",
                            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Baking homemade banana bread", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Ordered iced latte at corner shop", occurrenceCount: 1)
                ]
            ),
            // 案例 2: 工作与学业
            Tab2CategoryData(
                sceneCategory: "Work & Study",
                wordCount: 28,
                unlocked: true,
                notSpokenCount: 28,
                lastTalkedAt: nil,
                lastMaterialAt: twoDaysAgo,
                newMaterialCount: 1,
                activityCount: 6,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Presented sprint roadmap to team",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-work-1",
                            imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Reviewed design PR with tech lead", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Sprint retrospective sync", occurrenceCount: 1)
                ]
            ),
            // 案例 3: 购物与日常杂务
            Tab2CategoryData(
                sceneCategory: "Shopping",
                wordCount: 18,
                unlocked: true,
                notSpokenCount: 18,
                lastTalkedAt: nil,
                lastMaterialAt: threeDaysAgo,
                newMaterialCount: 0,
                activityCount: 5,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Bought organic vegetables at farmers market",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-shop-1",
                            imageUrl: "https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Picked up parcel from smart locker", occurrenceCount: 1)
                ]
            ),
            // 案例 4: 城市出行与交通
            Tab2CategoryData(
                sceneCategory: "Travel & Commute",
                wordCount: 22,
                unlocked: true,
                notSpokenCount: 22,
                lastTalkedAt: nil,
                lastMaterialAt: lastWeek,
                newMaterialCount: 0,
                activityCount: 4,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Took express subway into downtown",
                        occurrenceCount: 3,
                        cover: Tab2Activity.Cover(
                            materialId: "m-travel-1",
                            imageUrl: "https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Walked through riverside park in sunset", occurrenceCount: 1)
                ]
            )
        ]
    }

    // ── 3. Topics in progress 丰富案例 (4 个进行中卡片，可交互展开) ──
    static var richInProgressCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "Social & Feelings",
                wordCount: 16,
                unlocked: false,
                notSpokenCount: 16,
                lastTalkedAt: nil,
                lastMaterialAt: Date(),
                newMaterialCount: 3,
                activityCount: 4,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "Health & Fitness",
                wordCount: 12,
                unlocked: false,
                notSpokenCount: 12,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                newMaterialCount: 1,
                activityCount: 3,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "Digital & Tech",
                wordCount: 7,
                unlocked: false,
                notSpokenCount: 7,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                newMaterialCount: 0,
                activityCount: 2,
                activities: []
            ),
            Tab2CategoryData(
                sceneCategory: "Hobbies & Leisure",
                wordCount: 3,
                unlocked: false,
                notSpokenCount: 3,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: []
            )
        ]
    }

    // ── 4. More topics to explore 丰富案例 (9 个未开启生活分类) ──
    static var richUnstartedTopics: [SceneCategory] {
        [
            .homeFamily,
            .weather,
            .other,
            .homeFamily,
            .weather,
            .other,
            .homeFamily,
            .weather,
            .other
        ]
    }

    // 手风琴展开时的详细词汇
    static func words(for category: String) -> [Tab2WordEntry] {
        switch category {
        case "Social & Feelings", "情绪社交":
            return [
                Tab2WordEntry(lemma: "empathize", displayForm: "empathize with", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "I can totally empathize with what you went through.", nativeMeaning: "产生共鸣；感同身受", imageUrl: nil),
                Tab2WordEntry(lemma: "rekindle", displayForm: "rekindling friendship", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "It was so nice rekindling our college friendship.", nativeMeaning: "重温旧谊", imageUrl: nil),
                Tab2WordEntry(lemma: "heartwarming", displayForm: "heartwarming", entryKind: "word", pos: "adj.", granularity: "word", sourceType: "material", sampleSentence: "We had a truly heartwarming conversation today.", nativeMeaning: "暖心的", imageUrl: nil),
                Tab2WordEntry(lemma: "awkward", displayForm: "awkward pause", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "There was an awkward pause before anyone spoke.", nativeMeaning: "尴尬的停顿", imageUrl: nil)
            ]
        case "Health & Fitness", "运动健康":
            return [
                Tab2WordEntry(lemma: "hydrate", displayForm: "stay hydrated", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Make sure to stay hydrated during your workout.", nativeMeaning: "补充水分", imageUrl: nil),
                Tab2WordEntry(lemma: "stretch", displayForm: "morning stretching", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Ten minutes of morning stretching wakes up my muscles.", nativeMeaning: "晨间拉伸", imageUrl: nil),
                Tab2WordEntry(lemma: "core", displayForm: "core strength", entryKind: "phrase", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: "Planks are great for building core strength.", nativeMeaning: "核心力量", imageUrl: nil)
            ]
        case "Digital & Tech", "科技数码":
            return [
                Tab2WordEntry(lemma: "gadget", displayForm: "smart gadgets", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "My desk is covered with all kinds of smart gadgets.", nativeMeaning: "智能小配件", imageUrl: nil),
                Tab2WordEntry(lemma: "reboot", displayForm: "rebooting the router", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Try rebooting the router if Wi-Fi drops.", nativeMeaning: "重启路由器", imageUrl: nil),
                Tab2WordEntry(lemma: "battery", displayForm: "battery drain", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "The latest update caused unusual battery drain.", nativeMeaning: "电量快速消耗", imageUrl: nil)
            ]
        default:
            return [
                Tab2WordEntry(lemma: "acoustic", displayForm: "acoustic guitar", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "I spent an hour practicing on my acoustic guitar.", nativeMeaning: "原声吉他", imageUrl: nil),
                Tab2WordEntry(lemma: "vintage", displayForm: "vintage camera", entryKind: "phrase", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: "I found a vintage 35mm film camera at the flea market.", nativeMeaning: "复古胶片相机", imageUrl: nil)
            ]
        }
    }
}

// MARK: - Xcode Canvas 预览入口 (多高度独立预览 + 并排全景)

#Preview("探索区胶囊 · 25pt 高度 ⭐ (降 13pt · 推荐)") {
    Tab2UnlockedProposal4ComparisonPreviewView(initialScheme: .height25)
}

#Preview("探索区胶囊 · 28pt 高度 (降 10pt · 适度)") {
    Tab2UnlockedProposal4ComparisonPreviewView(initialScheme: .height28)
}

#Preview("探索区胶囊 · 22pt 高度 (降 16pt · 微型)") {
    Tab2UnlockedProposal4ComparisonPreviewView(initialScheme: .height22)
}

#Preview("探索区胶囊 · 38pt 高度 (当前生产基准)") {
    Tab2UnlockedProposal4ComparisonPreviewView(initialScheme: .height38)
}

#endif
