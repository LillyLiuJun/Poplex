#if DEBUG
import SwiftUI
import UIKit

/// Tab2 解锁态全景视觉实验室 (Tab2 Unlocked Full Visual Lab)
///
/// 严格对齐最新生产代码架构与最新提交 `754d917`:
/// 1. 包含解锁态全部 5 大核心模块：
///    - ① Talk about today (Hero 区块，支持实心预设图、照片封面、空态等多种案例比较)
///    - ② More to talk about (推荐行区块，三标题同档 24pt 衬线，支持 1~4 行容量比较)
///    - ③ Topics in progress (手风琴进度卡片，支持高/中/低多进度梯度与 WordsPill 展开)
///    - ④ More topics to explore (未开始分类探索区，支持 4 种松紧度与体量调优方案)
///    - ⑤ 品牌宣言 (PoplexWordmark + Tagline + BottomAuraFooter 晨曦暖光)
/// 2. 深度落实整页「松紧度均质化」与「96pt 底部呼吸断层」：
///    - 解决探索区胶囊偏小、头重脚轻、上密下疏的矛盾；
///    - 提供 4 种探索区松紧度方案，在整页流中可一键切换，检验整页视网膜体量与呼吸节奏的统一性。
struct Tab2UnlockedFullVisualLabPreview: View {
    @State private var viewMode: ViewMode = .fullPage
    @State private var pageLengthScenario: PageLengthScenario = .exceedsOneScreen
    @State private var footerTopSpaceMode: FooterSpaceOption = .space96Latest
    @State private var exploreDensityMode: ExploreDensityMode = .proposal1_30pt
    @State private var heroCase: HeroCaseOption = .foodSolidPreset
    @State private var moreRowsVolume: MoreVolumeOption = .fourRows
    @State private var inProgressVolume: InProgressVolumeOption = .threeTopics
    @State private var showTopBarShell: Bool = true
    @State private var showSpacingRuler: Bool = false
    @State private var expandedCategoryId: String? = nil
    @State private var selectedTab: AppTab = .mine
    @State private var toastMessage: String?
    @State private var contextAnchorMode: ContextAnchorOption = .withSection3

    enum ContextAnchorOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case withSection3 = "紧贴 Section 3 进度卡对比 ⭐ (推荐)"
        case fullSections123 = "完整前三模块整体承接"
        case pureSection4 = "仅探索区纯享"

        var shortName: String {
            switch self {
            case .withSection3: return "紧贴 S3 进度卡 ⭐"
            case .fullSections123: return "前三模块全景"
            case .pureSection4: return "仅探索区"
            }
        }
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fullPage        = "全真整页流"
        case densityLab      = "松紧度对比 ⭐"
        case sectionCases    = "多案例陈列"
        case spacingLab      = "96pt标尺"

        var title: String { rawValue }

        var subtitle: String {
            switch self {
            case .fullPage:
                return "全真体验 · 探索区松紧度与 96pt 呼吸留白实时联动检验"
            case .densityLab:
                return "探索区 4 方案同屏直接比对 · 根治局促与上密下疏"
            case .sectionCases:
                return "5 大核心模块多案例库 · 检验各场景下的视觉体量与边界情况"
            case .spacingLab:
                return "超过一屏 96pt 呼吸断层专项标尺验证 · commit 754d917 规范还原"
            }
        }
    }

    enum PageLengthScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case exceedsOneScreen = "超出一屏"
        case withinOneScreen  = "不足一屏"

        var shortLabel: String {
            switch self {
            case .exceedsOneScreen: return "超出一屏 (96pt)"
            case .withinOneScreen:  return "不足一屏 (弹性)"
            }
        }
    }

    enum FooterSpaceOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case space96Latest = "96pt (新版)"
        case space72Old    = "72pt (旧版)"

        var shortLabel: String { rawValue }

        var value: CGFloat {
            switch self {
            case .space96Latest: return AppTheme.Space.tab2FooterTop // 96pt
            case .space72Old:    return 72
            }
        }
    }

    enum ExploreDensityMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case baseline25       = "baseline25"
        case proposal1_30pt   = "proposal1_30pt"
        case proposal2_card   = "proposal2_card"
        case proposal3_28pt   = "proposal3_28pt"

        var title: String {
            switch self {
            case .baseline25:     return "基线 · 25pt"
            case .proposal1_30pt: return "方案 1 · 30pt 舒展 ⭐"
            case .proposal2_card: return "方案 2 · 白卡包裹"
            case .proposal3_28pt: return "方案 3 · 28pt 平衡"
            }
        }

        var shortName: String {
            switch self {
            case .baseline25:     return "基线 25pt"
            case .proposal1_30pt: return "方案 1: 30pt ⭐"
            case .proposal2_card: return "方案 2: 白卡"
            case .proposal3_28pt: return "方案 3: 28pt"
            }
        }

        var badgeText: String {
            switch self {
            case .baseline25:     return "高 25pt · 字 12pt"
            case .proposal1_30pt: return "高 30pt · 字 13pt ⭐"
            case .proposal2_card: return "高 29pt · 字 13pt"
            case .proposal3_28pt: return "高 28pt · 字 13pt"
            }
        }

        var subtitle: String {
            switch self {
            case .baseline25:     return "现状基线 · 略显偏小局促"
            case .proposal1_30pt: return "核心推荐 · 对齐 Topics 13pt / 彻底均质化"
            case .proposal2_card: return "全页卡片均质 · 磨砂白卡包裹"
            case .proposal3_28pt: return "紧凑微调平衡 · 稍微增加分量"
            }
        }

        var tagHeight: CGFloat {
            switch self {
            case .baseline25:     return 25
            case .proposal1_30pt: return 30
            case .proposal2_card: return 29
            case .proposal3_28pt: return 28
            }
        }

        var font: Font {
            switch self {
            case .baseline25:     return AppTheme.Font.tab2ExploreTagLabel // 12pt
            case .proposal1_30pt: return AppTheme.Font.tab2TopicLabel      // 13pt Regular (与 Topics in progress 1:1 完全对齐)
            case .proposal2_card: return AppTheme.Font.tab2TopicLabel      // 13pt Regular
            case .proposal3_28pt: return AppTheme.Font.tab2TopicLabel      // 13pt Regular
            }
        }

        var fontDesc: String {
            switch self {
            case .baseline25:     return "12pt Regular (原版)"
            case .proposal1_30pt: return "13pt Regular (对齐 Topics)"
            case .proposal2_card: return "13pt Regular (对齐 Topics)"
            case .proposal3_28pt: return "13pt Regular (对齐 Topics)"
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .baseline25:     return 11.5
            case .proposal1_30pt: return 13.5
            case .proposal2_card: return 13.0
            case .proposal3_28pt: return 12.5
            }
        }

        var hPadding: CGFloat {
            switch self {
            case .baseline25:     return 10
            case .proposal1_30pt: return 13
            case .proposal2_card: return 12
            case .proposal3_28pt: return 11.5
            }
        }

        var iconToText: CGFloat {
            switch self {
            case .baseline25:     return 5
            case .proposal1_30pt: return 6
            case .proposal2_card: return 6
            case .proposal3_28pt: return 5.5
            }
        }

        var tagGap: CGFloat {
            switch self {
            case .baseline25:     return 8
            case .proposal1_30pt: return 9
            case .proposal2_card: return 8
            case .proposal3_28pt: return 8.5
            }
        }

        var titleToTags: CGFloat {
            switch self {
            case .baseline25:     return 12
            case .proposal1_30pt: return 16 // 统一为 paddingCard = 16pt，消除头重脚轻
            case .proposal2_card: return 16
            case .proposal3_28pt: return 14
            }
        }

        var isCardFramed: Bool {
            self == .proposal2_card
        }

        var rationale: String {
            switch self {
            case .baseline25:
                return "【现状基线】胶囊高度 25pt、文字 12pt、图标 11.5pt。在 24pt 粗衬线标题下方显得体量骤降，与上方 Topics 的 13pt 分类名和 14pt 图标割裂，产生头重脚轻感。"
            case .proposal1_30pt:
                return "【核心推荐 ⭐ · 13pt 同频舒展】类别名直升 13pt（与 Topics in progress 1:1 完全同源）；图标提升至 13.5pt；胶囊高度升至 30pt，内边距增至 13pt；标题下距统一至 16pt。胶囊体量自信挺拔，与进行中分类形成平视的兄弟视觉层级，保持裸底轻盈同时彻底消除缩水感。"
            case .proposal2_card:
                return "【全页卡片均质化】采用 13pt 文字与 29pt 胶囊，并将其包裹在完整的磨砂玻璃白卡容器中。整页形成「Hero卡 -> More卡 -> Topics卡 -> Explore卡」4 组等质大卡片，彻底根除上密下悬的断层感。"
            case .proposal3_28pt:
                return "【紧凑微调平衡】文字升至 13pt，图标升至 12.5pt，高度升至 28pt。介于 25pt 与 30pt 之间的折中保守方案，稍微增加分量但保留较小轮廓。"
            }
        }
    }

    enum HeroCaseOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case foodSolidPreset = "Food 实心预设 (餐盘叉匙)"
        case workSolidPreset = "Work 实心预设 (横线纸笔)"
        case travelPhoto     = "Travel 真实照片封面"
        case dailyEmpty      = "Daily 空态 (Only words)"
    }

    enum MoreVolumeOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fourRows = "4 行丰富混排 (多案例)"
        case twoRows  = "2 行典型"
        case oneRow   = "1 行精简"
        case zeroRows = "0 行 (隐藏)"

        var count: Int {
            switch self {
            case .fourRows: return 4
            case .twoRows:  return 2
            case .oneRow:   return 1
            case .zeroRows: return 0
            }
        }
    }

    enum InProgressVolumeOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case threeTopics = "3 梯度全量 (90% / 55% / 20%)"
        case oneTopic    = "1 条精简"
    }

    var body: some View {
        VStack(spacing: 0) {
            topControlBar
            Divider().opacity(0.15)

            switch viewMode {
            case .fullPage:
                fullPageContent
            case .densityLab:
                densityLabContent
            case .sectionCases:
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        sectionCasesContent
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
                .background(AppTheme.Color.pageBg.ignoresSafeArea())
            case .spacingLab:
                spacingLabContent
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                toastOverlay(text: toast)
            }
        }
    }

    // MARK: - 顶部控制栏

    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 一级视图模式切换 (短标题，保证任何机型无截断)
            Picker("视图模式", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 当前模式说明横条
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Text(viewMode.subtitle)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 2)

            if viewMode == .fullPage {
                // 核心松紧度联动控制器
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("探索区松紧度:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandInk)

                        Picker("探索区松紧度", selection: $exploreDensityMode) {
                            ForEach(ExploreDensityMode.allCases) { m in
                                Text(m.shortName).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 8) {
                        Picker("内容长度", selection: $pageLengthScenario) {
                            ForEach(PageLengthScenario.allCases) { sc in
                                Text(sc.shortLabel).tag(sc)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("断层间距", selection: $footerTopSpaceMode) {
                            ForEach(FooterSpaceOption.allCases) { sp in
                                Text(sp.shortLabel).tag(sp)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 12) {
                        Picker("Hero 案例", selection: $heroCase) {
                            ForEach(HeroCaseOption.allCases) { h in
                                Text(h.rawValue).tag(h)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("More 行数", selection: $moreRowsVolume) {
                            ForEach(MoreVolumeOption.allCases) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .pickerStyle(.menu)

                        Spacer()

                        Toggle("标尺", isOn: $showSpacingRuler)
                            .font(AppTheme.Font.metaNote)
                            .toggleStyle(SwitchToggleStyle(tint: AppTheme.Color.brandStrong))

                        Toggle("顶栏", isOn: $showTopBarShell)
                            .font(AppTheme.Font.metaNote)
                            .toggleStyle(SwitchToggleStyle(tint: AppTheme.Color.brandStrong))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 8)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 1. 全真整页流 (Full Page Experience)

    private var fullPageContent: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                let reservedTop: CGFloat = showTopBarShell ? 56 : AppTheme.Space.paddingPage
                let availableHeight = max(geo.size.height - reservedTop, 400)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // 核心 4 大区块
                            unlockedSections(proxy)
                                .fixedSize(horizontal: false, vertical: true)

                            // 关键间距机制：超过一屏为 96pt 呼吸断层，不足一屏则自动撑开弹性沉底
                            Spacer(minLength: footerTopSpaceMode.value)
                                .overlay {
                                    if showSpacingRuler {
                                        rulerIndicator(label: "Spacer(minLength: \(Int(footerTopSpaceMode.value))pt)")
                                    }
                                }

                            // 底部品牌宣言
                            footerSignoffView
                                .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                                .overlay(alignment: .bottom) {
                                    if showSpacingRuler {
                                        bottomRulerIndicator(label: "tab2FooterBottom: 52pt")
                                    }
                                }
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

            // 浮动顶栏
            if showTopBarShell {
                floatingTopBar
            }
        }
    }

    // MARK: - 核心四大区块流水 (严格对齐 MineView contentSections)

    @ViewBuilder
    private func unlockedSections(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt

            // ── ① Talk about today (Hero 区块) ──
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                Text("Talk about today")
                    .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                Tab2HeroCard(
                    category: activeHeroData,
                    onTalk: {
                        triggerToast("Start conversation: \(activeHeroData.englishLabel)")
                    }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            if pageLengthScenario == .exceedsOneScreen {
                // ── ② More to talk about (推荐行区块) —— 刀 6a：三标题同档 24pt ──
                let moreList = Array(allMoreCandidates.prefix(moreRowsVolume.count))
                if !moreList.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                        Text("More to talk about")
                            .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) { // 12pt
                            ForEach(moreList) { category in
                                Tab2ActivityRow(
                                    category: category,
                                    onTap: {
                                        triggerToast("Selected topic: \(category.englishLabel)")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }

                // ── ③ Topics in progress (手风琴进度卡片) ──
                let progressList = inProgressVolume == .threeTopics ? allInProgressCandidates : [allInProgressCandidates[0]]
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) { // 16pt
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif) // 24pt Charter-Bold
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(spacing: 0) {
                        ForEach(progressList) { cat in
                            CategoryProgressRow(
                                category: cat,
                                isExpanded: expandedCategoryId == cat.id,
                                onToggle: {
                                    withAnimation(AppTheme.Motion.accordionToggle) {
                                        expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                    }
                                },
                                loadWords: {
                                    try await loadWordsMock(for: cat.sceneCategory)
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

                // ── ④ More topics to explore (未开始分类探索区 · 支持 4 种松紧度形态) ──
                let unstarted = unstartedTopicsList
                if !unstarted.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        // 在前三个部分底部、第 4 部分顶部直接提供切换胶囊条
                        HStack(spacing: 6) {
                            Text("探索区承接方案:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.Color.brandInk)

                            Picker("承接方案", selection: $exploreDensityMode) {
                                ForEach(ExploreDensityMode.allCases) { m in
                                    Text(m.shortName).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.top, 2)

                        customMoreTopicsSection(topics: unstarted, mode: exploreDensityMode)
                    }
                }
            }
        }
        .padding(.top, AppTheme.Space.tab2ContentTop)
    }

    // MARK: - 可配置的探索区组件 (用于实现 4 种松紧度)

    private func customMoreTopicsSection(
        topics: [SceneCategory],
        mode: ExploreDensityMode,
        isEmbeddedInCard: Bool = false
    ) -> some View {
        let rows = Tab2ExploreTagLayout.rows(topics)
        let horizontalPadding: CGFloat = isEmbeddedInCard ? 0 : AppTheme.Space.paddingPage

        return VStack(alignment: .leading, spacing: 0) {
            Text("More topics to explore")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, mode.titleToTags)

            if mode.isCardFramed {
                // 方案 2: 卡片包裹态 (内部同样支持横滑，绝不撑大外层)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: mode.tagGap) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(spacing: mode.tagGap) {
                                ForEach(rows[index], id: \.self) { topic in
                                    customExploreTag(topic: topic, mode: mode)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, horizontalPadding)
            } else {
                // 裸露流式态 (基线 / 方案1 / 方案3)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: mode.tagGap) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(spacing: mode.tagGap) {
                                ForEach(rows[index], id: \.self) { topic in
                                    customExploreTag(topic: topic, mode: mode)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func customExploreTag(topic: SceneCategory, mode: ExploreDensityMode) -> some View {
        HStack(spacing: mode.iconToText) {
            Image(systemName: topic.iconName)
                .font(.system(size: mode.iconSize, weight: .regular))
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagIcon)

            Text(topic.englishLabel)
                .font(mode.font)
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagLabel)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, mode.hPadding)
        .frame(minHeight: mode.tagHeight)
        .background {
            Capsule()
                .fill(AppTheme.Tab2ExploreTopics.Color.tagFill)
                .strokeBorder(
                    AppTheme.Tab2ExploreTopics.Color.tagBorder,
                    lineWidth: 0.8
                )
        }
        .shadow(
            color: AppTheme.Tab2ExploreTopics.Color.tagShadow,
            radius: 3,
            y: 1
        )
    }

    // MARK: - 底部品牌宣言 (完全对齐 MineView footerSignoff)

    private var footerSignoffView: some View {
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
    }

    // MARK: - 2. 探索区松紧度 4 方案同屏对比 (Density Lab)

    private var densityLabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader(
                    title: "探索区胶囊与整页松紧度调优",
                    subtitle: "直观对比前三个模块底部的承接效果，解决「胶囊偏小、头重脚轻、上密下疏」的视觉割裂"
                )

                // 参照场景切换器
                VStack(alignment: .leading, spacing: 6) {
                    Text("比对参照场景:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandInk)

                    Picker("比对参照场景", selection: $contextAnchorMode) {
                        ForEach(ContextAnchorOption.allCases) { opt in
                            Text(opt.shortName).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if contextAnchorMode == .fullSections123 {
                    // ── 场景 B: 完整前三模块整体承接 ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                        Text("【上方前三模块全景流】")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.Color.brandStrong)

                        // 1. Talk about today
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            Text("Talk about today")
                                .font(AppTheme.Font.sectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Tab2HeroCard(category: activeHeroData, onTalk: {})
                        }

                        // 2. More to talk about
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            Text("More to talk about")
                                .font(AppTheme.Font.sectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Tab2ActivityRow(category: LabMockData.moreShopping, onTap: {})
                        }

                        // 3. Topics in progress
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            Text("Topics in progress")
                                .font(AppTheme.Font.sectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            VStack(spacing: 0) {
                                CategoryProgressRow(
                                    category: LabMockData.inProgressHome,
                                    isExpanded: false,
                                    onToggle: {},
                                    loadWords: { [] },
                                    wordsRevision: 1,
                                    milestonePresentations: []
                                )
                            }
                            .padding(.vertical, AppTheme.Space.paddingS)
                            .surfaceCard(cornerRadius: AppTheme.Radius.large)
                        }

                        // 承接方案即时切换栏
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("当前底部承接方案:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandInk)
                                Spacer()
                                Text(exploreDensityMode.badgeText)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                            }

                            Picker("当前承接方案", selection: $exploreDensityMode) {
                                ForEach(ExploreDensityMode.allCases) { m in
                                    Text(m.shortName).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.top, 6)

                        // 4. More topics to explore (选定方案现场承接)
                        customMoreTopicsSection(
                            topics: [.weather, .social, .other, .gettingAround],
                            mode: exploreDensityMode,
                            isEmbeddedInCard: false
                        )

                        // 底部说明与 96pt 断层
                        Spacer(minLength: footerTopSpaceMode.value)
                        footerSignoffView
                            .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                    }
                    .padding(16)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                } else {
                    // 核心诊断提示卡
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.Color.brandStrong)
                            Text("四模块字号梯队与调优核心目标")
                                .font(AppTheme.Font.keyPhrase)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        }

                        Text("• ① Hero 卡片: 11.5pt SemiBold (帽标签)\n• ② More 列表: 12pt SemiBold (帽标签)\n• ③ Topics in progress: 13pt Regular (主分类名 · tab2TopicLabel)\n• ④ More topics: 原版 12pt Regular (缩水割裂) ➔ 核心推荐 13pt Regular (1:1 同频舒展)")
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))

                    // 4 方案竖向铺开比对 (每个卡片内嵌 Section 3 真实进度卡作为基准参照)
                    ForEach(ExploreDensityMode.allCases) { mode in
                        VStack(alignment: .leading, spacing: 14) {
                            // 头部：标题与规格徽标
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .center) {
                                    Text(mode.title)
                                        .font(AppTheme.Font.compactSectionTitleSerif)
                                        .foregroundStyle(mode == .proposal1_30pt ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary)

                                    Spacer()

                                    Text(mode.badgeText)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(mode == .proposal1_30pt ? AppTheme.Color.brandInk : AppTheme.Color.textMuted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(mode == .proposal1_30pt ? AppTheme.Color.brandTint.opacity(0.5) : AppTheme.Color.pageBg)
                                        .clipShape(Capsule())
                                }

                                Text(mode.subtitle)
                                    .font(AppTheme.Font.metaNote)
                                    .foregroundStyle(mode == .proposal1_30pt ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
                            }

                            Divider().opacity(0.12)

                            if contextAnchorMode == .withSection3 {
                                // 🌟 关键：直接将上方 Section 3 Topics in progress 卡片底端原样作为视觉基准！
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("上方 Section 3 进行中卡片底端参照 (Home & Family)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.Color.textMuted)
                                        Spacer()
                                        Text("字号: 13pt Regular")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.Color.brandInk)
                                    }

                                    // 真实 Section 3 的一行进行中分类
                                    CategoryProgressRow(
                                        category: LabMockData.inProgressHome,
                                        isExpanded: false,
                                        onToggle: {},
                                        loadWords: { [] },
                                        wordsRevision: 1,
                                        milestonePresentations: []
                                    )
                                    .padding(.vertical, AppTheme.Space.paddingS)
                                    .surfaceCard(cornerRadius: AppTheme.Radius.medium)
                                }

                                // 间距标尺
                                HStack(spacing: 8) {
                                    Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.3))
                                    Text("模块标准留白 28pt (paddingBetweenSections)")
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.red.opacity(0.8))
                                    Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.3))
                                }
                                .padding(.vertical, 2)
                            }

                            // 真实渲染视图 (紧随其后承接)
                            customMoreTopicsSection(
                                topics: [.weather, .social, .other, .gettingAround],
                                mode: mode,
                                isEmbeddedInCard: true
                            )

                            // 理由说明
                            Text(mode.rationale)
                                .font(AppTheme.Font.metaNote)
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                                .stroke(mode == .proposal1_30pt ? AppTheme.Color.brandStrong : AppTheme.Color.cardBorder, lineWidth: mode == .proposal1_30pt ? 1.5 : 0.5)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 3. 各区块多案例陈列 (Section Cases Showcase)

    private var sectionCasesContent: some View {
        VStack(alignment: .leading, spacing: 36) {
            sectionHeader(
                title: "解锁态 5 大模块多案例全景陈列",
                subtitle: "逐个模块展开多个真实设计案例，横向纵向对比构图体量与信息层级"
            )

            // 1. Talk about today 案例库
            VStack(alignment: .leading, spacing: 14) {
                caseHeader(badge: "模块 1", title: "Talk about today (Hero 卡 4 种典型案例)")

                VStack(spacing: 18) {
                    caseCard(title: "案例 A · Food & Drink (最新温润白瓷餐具实心预设)") {
                        Tab2HeroCard(category: LabMockData.heroFoodPreset, onTalk: {})
                    }

                    caseCard(title: "案例 B · Work & Study (最新横线纸笔便利贴实心预设)") {
                        Tab2HeroCard(category: LabMockData.heroWorkPreset, onTalk: {})
                    }

                    caseCard(title: "案例 C · Travel & Commute (真实照片封面态 + 裸字 scrim 投影)") {
                        Tab2HeroCard(category: LabMockData.heroTravelPhoto, onTalk: {})
                    }

                    caseCard(title: "案例 D · Daily Routine (空态 Only words so far · 自然矮化单行)") {
                        Tab2HeroCard(category: LabMockData.heroDailyEmpty, onTalk: {})
                    }
                }
            }

            // 2. More to talk about 案例库
            VStack(alignment: .leading, spacing: 14) {
                caseHeader(badge: "模块 2", title: "More to talk about (推荐列表行 4 案例混排)")

                VStack(spacing: 12) {
                    caseCard(title: "案例 1 · Shopping (预设缩略图：购物袋衣架价签 + 64 words)") {
                        Tab2ActivityRow(category: LabMockData.moreShopping, onTap: {})
                    }

                    caseCard(title: "案例 2 · Health & Fitness (预设缩略图：瑜伽垫球拍水瓶 + 47 words)") {
                        Tab2ActivityRow(category: LabMockData.moreHealth, onTap: {})
                    }

                    caseCard(title: "案例 3 · Digital & Tech (预设缩略图：手机数据线通知 + 85 words)") {
                        Tab2ActivityRow(category: LabMockData.moreTech, onTap: {})
                    }

                    caseCard(title: "案例 4 · Hobbies & Leisure (真实照片缩略图 · 暖橙 multiply 调色)") {
                        Tab2ActivityRow(category: LabMockData.moreHobbiesPhoto, onTap: {})
                    }
                }
            }

            // 3. Topics in progress 案例库
            VStack(alignment: .leading, spacing: 14) {
                caseHeader(badge: "模块 3", title: "Topics in progress (手风琴进度卡片 · 3 梯度进度)")

                VStack(spacing: 0) {
                    ForEach(allInProgressCandidates) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isExpanded: expandedCategoryId == cat.id,
                            onToggle: {
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                }
                            },
                            loadWords: {
                                try await loadWordsMock(for: cat.sceneCategory)
                            },
                            wordsRevision: 1,
                            milestonePresentations: []
                        )
                        .id("cases_\(cat.id)")
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
            }

            // 4. More topics to explore 案例库
            VStack(alignment: .leading, spacing: 14) {
                caseHeader(badge: "模块 4", title: "More topics to explore (未开始分类探索区 · 解锁后无注脚)")

                VStack(alignment: .leading, spacing: 16) {
                    Text("当前选定松紧度形态 (\(exploreDensityMode.shortName))：")
                        .font(AppTheme.Font.metaNote)
                        .foregroundStyle(AppTheme.Color.brandInk)

                    customMoreTopicsSection(
                        topics: [.weather, .social, .other, .gettingAround],
                        mode: exploreDensityMode,
                        isEmbeddedInCard: true
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            }

            // 5. 品牌宣言案例
            VStack(alignment: .leading, spacing: 14) {
                caseHeader(badge: "模块 5", title: "品牌宣言与晨曦暖光 (Brand Signoff & Bottom Aura)")

                VStack(spacing: 20) {
                    footerSignoffView
                        .padding(.top, 30)
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                }
                .frame(maxWidth: .infinity)
                .background(alignment: .bottom) {
                    BottomAuraFooter()
                }
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 4. 超过一屏 96pt 间距专项标尺 (Spacing Lab)

    private var spacingLabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader(
                    title: "超过一屏时品牌宣言与上方 96pt 间距验证",
                    subtitle: "最新 commit 754d917 将 tab2FooterTop 从 72pt 提升至 96pt，彻底打破卡片吸附感"
                )

                // 核心指标与设计理由卡
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "ruler.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                        Text("间距设计规范事实 (Sources of Truth)")
                            .font(AppTheme.Font.keyPhrase)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        specItem(label: "上方呼吸断层 (tab2FooterTop)", value: "96pt (Primitive.space96)", note: "卡片下沿到 PoplexWordmark 顶部的留白距离")
                        specItem(label: "下方踏光上浮 (tab2FooterBottom)", value: "52pt (Primitive.space52)", note: "Tagline 下沿到安全区底部的悬浮距离")
                        specItem(label: "对齐机制", value: "Spacer(minLength: 96)", note: "超出一屏时坍缩为 96pt 最小断层；短内容时弹性伸展推到底部")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))

                // 96pt vs 72pt 模拟对比卡
                HStack(spacing: 12) {
                    spacingCompareCard(
                        title: "96pt (最新定稿 ⭐)",
                        subtitle: "Commit 754d917",
                        topSpace: 96,
                        isCurrent: true
                    )

                    spacingCompareCard(
                        title: "72pt (旧版对比)",
                        subtitle: "原紧密版",
                        topSpace: 72,
                        isCurrent: false
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func spacingCompareCard(
        title: String,
        subtitle: String? = nil,
        topSpace: CGFloat,
        isCurrent: Bool
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isCurrent ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(isCurrent ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(isCurrent ? AppTheme.Color.brandTint.opacity(0.35) : AppTheme.Color.pageBg)

            // 模拟上方卡片末端
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Color.cardBg)
                    .frame(height: 50)
                    .overlay(
                        Text("上方最后一个卡片")
                            .font(AppTheme.Font.metaNote)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                // 标尺区域
                VStack(spacing: 2) {
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.6))
                        Text("\(Int(topSpace))pt")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.red)
                        Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.6))
                    }
                }
                .frame(height: topSpace)
                .padding(.horizontal, 12)

                // 底部宣言
                VStack(spacing: 4) {
                    PoplexWordmark(capHeight: 10, style: .mono(AppTheme.Color.textMuted), showsPeriod: true)
                    Text("English from your everyday life.")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
                }
                .padding(.bottom, 48)
            }
            .background(alignment: .bottom) {
                BottomAuraFooter()
            }
        }
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(isCurrent ? AppTheme.Color.brandStrong : AppTheme.Color.cardBorder, lineWidth: isCurrent ? 1.5 : 0.5)
        )
    }

    // MARK: - 辅助组件

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton {
                    triggerToast("Tapped Settings")
                }
                .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)

                Spacer()

                UsageLimitButton {
                    triggerToast("Tapped Quota")
                }
                .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
    }

    private func rulerIndicator(label: String) -> some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.5))
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.85), in: Capsule())
            Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.5))
        }
        .padding(.horizontal, 24)
    }

    private func bottomRulerIndicator(label: String) -> some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(Color.blue.opacity(0.5))
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.blue)
                .padding(.horizontal, 4)
                .background(Color.white.opacity(0.8), in: Capsule())
            Rectangle().frame(height: 1).foregroundStyle(Color.blue.opacity(0.5))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 26)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppTheme.Font.actionNote)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caseHeader(badge: String, title: String) -> some View {
        HStack(spacing: 8) {
            Text(badge)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.brandInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.Color.brandTint.opacity(0.4), in: Capsule())

            Text(title)
                .font(AppTheme.Font.compactSectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
    }

    private func caseCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Font.actionNote)
                .foregroundStyle(AppTheme.Color.textSecondary)

            content()
        }
    }

    private func specItem(label: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(AppTheme.Font.actionNote)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.brandInk)
            }
            Text(note)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.vertical, 2)
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

    private func triggerToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toastMessage == text {
                withAnimation { toastMessage = nil }
            }
        }
    }

    private func loadWordsMock(for category: String) async throws -> [Tab2WordEntry] {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return LabMockData.words(for: category)
    }

    // MARK: - 数据调度

    private var activeHeroData: Tab2CategoryData {
        switch heroCase {
        case .foodSolidPreset: return LabMockData.heroFoodPreset
        case .workSolidPreset: return LabMockData.heroWorkPreset
        case .travelPhoto:     return LabMockData.heroTravelPhoto
        case .dailyEmpty:      return LabMockData.heroDailyEmpty
        }
    }

    private var allMoreCandidates: [Tab2CategoryData] {
        [LabMockData.moreShopping, LabMockData.moreHealth, LabMockData.moreTech, LabMockData.moreHobbiesPhoto]
    }

    private var allInProgressCandidates: [Tab2CategoryData] {
        [LabMockData.inProgressHome, LabMockData.inProgressSocial, LabMockData.inProgressWeather]
    }

    private var unstartedTopicsList: [SceneCategory] {
        [.weather, .social, .other, .gettingAround]
    }
}

// MARK: - 高保真 Mock 数据中心

private enum LabMockData {
    static var heroFoodPreset: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.food.rawValue,
            wordCount: 52,
            unlocked: true,
            notSpokenCount: 12,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 5,
            activities: [
                Tab2Activity(sceneDetail: "Dinner at home", occurrenceCount: 3, cover: nil),
                Tab2Activity(sceneDetail: "Coffee and pastry", occurrenceCount: 2, cover: nil),
                Tab2Activity(sceneDetail: "Late-night ramen", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var heroWorkPreset: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.workStudy.rawValue,
            wordCount: 78,
            unlocked: true,
            notSpokenCount: 20,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            newMaterialCount: 2,
            activityCount: 6,
            activities: [
                Tab2Activity(sceneDetail: "Sprint planning", occurrenceCount: 3, cover: nil),
                Tab2Activity(sceneDetail: "Design review", occurrenceCount: 2, cover: nil),
                Tab2Activity(sceneDetail: "Client email", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var heroTravelPhoto: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.gettingAround.rawValue,
            wordCount: 46,
            unlocked: true,
            notSpokenCount: 15,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 1,
            activityCount: 4,
            activities: [
                Tab2Activity(
                    sceneDetail: "Subway morning commute",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-travel-1",
                        imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Walking old town", occurrenceCount: 2, cover: nil)
            ]
        )
    }

    static var heroDailyEmpty: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.dailyRoutines.rawValue,
            wordCount: 39,
            unlocked: true,
            notSpokenCount: 10,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()),
            newMaterialCount: 0,
            activityCount: 0,
            activities: []
        )
    }

    static var moreShopping: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.shopping.rawValue,
            wordCount: 64,
            unlocked: true,
            notSpokenCount: 14,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            newMaterialCount: 2,
            activityCount: 5,
            activities: [
                Tab2Activity(sceneDetail: "Weekend grocery haul", occurrenceCount: 2, cover: nil),
                Tab2Activity(sceneDetail: "Buying new headphones", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var moreHealth: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.healthFitness.rawValue,
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 11,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            newMaterialCount: 1,
            activityCount: 4,
            activities: [
                Tab2Activity(sceneDetail: "Evening 5k run", occurrenceCount: 2, cover: nil),
                Tab2Activity(sceneDetail: "Core workout session", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var moreTech: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.tech.rawValue,
            wordCount: 85,
            unlocked: true,
            notSpokenCount: 22,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()),
            newMaterialCount: 0,
            activityCount: 6,
            activities: [
                Tab2Activity(sceneDetail: "Testing iOS beta", occurrenceCount: 3, cover: nil),
                Tab2Activity(sceneDetail: "Smart light setup", occurrenceCount: 2, cover: nil)
            ]
        )
    }

    static var moreHobbiesPhoto: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.leisure.rawValue,
            wordCount: 61,
            unlocked: true,
            notSpokenCount: 16,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            newMaterialCount: 0,
            activityCount: 4,
            activities: [
                Tab2Activity(
                    sceneDetail: "Finishing novel chapter",
                    occurrenceCount: 2,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hobbies-photo",
                        imageUrl: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Guitar practice", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var inProgressHome: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.homeFamily.rawValue,
            wordCount: 18,
            unlocked: false,
            notSpokenCount: 18,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 2,
            activityCount: 4,
            activities: []
        )
    }

    static var inProgressSocial: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.social.rawValue,
            wordCount: 11,
            unlocked: false,
            notSpokenCount: 11,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            newMaterialCount: 0,
            activityCount: 3,
            activities: []
        )
    }

    static var inProgressWeather: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.weather.rawValue,
            wordCount: 4,
            unlocked: false,
            notSpokenCount: 4,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()),
            newMaterialCount: 0,
            activityCount: 2,
            activities: []
        )
    }

    static func words(for category: String) -> [Tab2WordEntry] {
        let cat = SceneCategory.from(category)
        switch cat {
        case .homeFamily:
            return [
                Tab2WordEntry(lemma: "living room", displayForm: "living room", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "We spent the evening in the cozy living room.", nativeMeaning: "客厅", imageUrl: nil),
                Tab2WordEntry(lemma: "declutter", displayForm: "decluttering", entryKind: "word", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Weekend is great for decluttering bookshelves.", nativeMeaning: "清理杂物", imageUrl: nil),
                Tab2WordEntry(lemma: "reunion", displayForm: "family reunion", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Everyone flew in for the annual family reunion.", nativeMeaning: "家庭团聚", imageUrl: nil),
                Tab2WordEntry(lemma: "chores", displayForm: "chores", entryKind: "word", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: nil, nativeMeaning: "家务杂事", imageUrl: nil)
            ]
        case .social:
            return [
                Tab2WordEntry(lemma: "catch up", displayForm: "catch up", entryKind: "phrase", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "It was so good to catch up over coffee.", nativeMeaning: "叙旧叙谈", imageUrl: nil),
                Tab2WordEntry(lemma: "empathy", displayForm: "empathy", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Listening with true empathy builds lasting trust.", nativeMeaning: "同理心；共情", imageUrl: nil),
                Tab2WordEntry(lemma: "heartwarming", displayForm: "heartwarming", entryKind: "word", pos: "adj.", granularity: "sentence", sourceType: "material", sampleSentence: "A heartwarming chat with a close teammate.", nativeMeaning: "暖心的", imageUrl: nil)
            ]
        case .weather:
            return [
                Tab2WordEntry(lemma: "drizzle", displayForm: "autumn drizzle", entryKind: "phrase", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "A gentle autumn drizzle covered the pavements.", nativeMeaning: "细雨濛濛", imageUrl: nil),
                Tab2WordEntry(lemma: "crisp", displayForm: "crisp breeze", entryKind: "phrase", pos: "adj.", granularity: "sentence", sourceType: "material", sampleSentence: "The crisp morning air wakes up your senses.", nativeMeaning: "清爽怡人的", imageUrl: nil)
            ]
        default:
            return [
                Tab2WordEntry(lemma: "routine", displayForm: "routines", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "Daily routines keep my life centered.", nativeMeaning: "常规惯例", imageUrl: nil)
            ]
        }
    }
}

#Preview("Tab2 解锁态全景视觉实验室") {
    Tab2UnlockedFullVisualLabPreview()
}
#endif
