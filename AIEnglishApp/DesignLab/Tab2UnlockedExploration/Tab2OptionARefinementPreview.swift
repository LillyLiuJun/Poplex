#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Topics「方案 1 与方案 2：Icon 下移居中与尺寸精调」画布
// 🎯 探索目标与解决痛点：
//   针对用户提出的“把 icon 下移并调整至居中位置，大小合适”的核心诉求：
//   1. 彻底解决“Icon 孤零零悬在左上角、下方有尴尬凹槽”的结构硬伤：
//      - 采用双列水平咬合架构（左侧 Icon / 底托，右侧 VStack 承载 [标题+胶囊] 与 [进度微轨]）；
//      - 使 Icon 自然下移，与右侧整体内容**在垂直方向严格居中对齐**，消灭 L 型悬空缺口！
//   2. 尺寸与光学平衡精调（大小合适）：
//      - 【方案 1 · 纯线条】：尺寸增至 15pt，字重提升为 .medium（与无衬线 Medium 13.5pt 粗细分量 1:1 光学校准），不再单薄发飘；
//      - 【方案 2 · 微凹方块】：26pt 连续圆角方块（Squircle 7pt，无描边），内嵌 13pt .medium 图标，比例饱满，居中稳定；
//   3. 提供【居中模式切换】：支持对比“下移整行居中”vs“仅顶部首行对齐”，一键看清下移前后的视觉重心变化。

struct Tab2OptionARefinementPreviewView: View {
    @State private var viewMode: ViewMode = .opt2Centered
    @State private var showTopBarShell: Bool = false
    @State private var toastMessage: String?
    @State private var expandedCategoryId: String? = nil

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case opt2Centered  = "方案 2 · 微凹方块 (下移居中)"
        case opt1Centered  = "方案 1 · 纯线条 (下移居中)"
        case opt2TopLine   = "对照 · 方案 2 仅顶行对齐"
        case opt1TopLine   = "对照 · 方案 1 仅顶行对齐"
        case comparison    = "全方案同屏对比"
    }

    var body: some View {
        VStack(spacing: 0) {
            controlPanel
            Divider().opacity(0.15)

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

    // MARK: - 控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Icon 下移居中与尺寸校准画布")
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

            Picker("方案", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 单模式主视图

    @ViewBuilder
    private func singleModeView(mode: ViewMode) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // 1. Hero 卡片
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Talk about today")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                Tab2HeroCard(
                    category: OptionAMockStore.heroCategory,
                    onTalk: { triggerAction("Talk about: Hobbies & Leisure") }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 2. More to talk about 列表
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More to talk about")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(OptionAMockStore.moreCategories) { category in
                        Tab2ActivityRow(
                            category: category,
                            onTap: { triggerAction("Selected topic: \(category.englishLabel)") }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 3. 🎯 核心测试区：Topics in progress
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    Text(modeBadgeText(mode))
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Color.brandWash.opacity(0.35), in: Capsule())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                topicsContainer(mode: mode)
            }
        }
    }

    // MARK: - 全方案同屏对比

    private var comparisonView: some View {
        VStack(alignment: .leading, spacing: 32) {
            sectionHeader(
                "方案 2：微凹方块 · 下移整行垂直居中 (🌟强烈推荐)",
                note: "26pt 微凹方块下移居中，与右侧[标题+微轨]整体高度咬合，重心极度平稳，彻底消除悬空"
            )
            topicsContainer(mode: .opt2Centered)

            sectionHeader(
                "方案 1：纯线条 · 下移整行垂直居中 (通透极简)",
                note: "15pt .medium 线条下移居中，右侧微轨自然收拢于文字下方，呼吸感与通透感拉满"
            )
            topicsContainer(mode: .opt1Centered)

            sectionHeader(
                "对比组：方案 2 仅顶行对齐 (下移前)",
                note: "旧版结构：Icon 挂在左上角，下方微轨缩进导致左下角悬空"
            )
            topicsContainer(mode: .opt2TopLine)

            sectionHeader(
                "对比组：方案 1 仅顶行对齐 (下移前)",
                note: "旧版结构：纯线条在顶行飘浮，缺乏对整行的视觉锚定"
            )
            topicsContainer(mode: .opt1TopLine)
        }
        .padding(.vertical, AppTheme.Space.paddingPage)
    }

    private func sectionHeader(_ title: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Font.tab2TopicLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Text(note)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func modeBadgeText(_ mode: ViewMode) -> String {
        switch mode {
        case .opt2Centered: return "方案 2 · 微凹方块(下移居中)"
        case .opt1Centered: return "方案 1 · 纯线条(下移居中)"
        case .opt2TopLine:  return "对照 · 方块顶行对齐"
        case .opt1TopLine:  return "对照 · 纯线条顶行对齐"
        case .comparison:   return "全方案同屏对比"
        }
    }

    // MARK: - 容器分发（全部保持大盒容器）

    @ViewBuilder
    private func topicsContainer(mode: ViewMode) -> some View {
        let categories = OptionAMockStore.inProgress5Categories

        VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                rowForMode(mode: mode, category: cat)

                if index < categories.count - 1 {
                    Divider()
                        .opacity(0.12)
                        .padding(.leading, dividerLeading(for: mode))
                        .padding(.trailing, AppTheme.Space.paddingPage)
                }
            }
        }
        .padding(.vertical, AppTheme.Space.paddingXS)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func dividerLeading(for mode: ViewMode) -> CGFloat {
        switch mode {
        case .opt2Centered, .opt2TopLine: return 54
        case .opt1Centered, .opt1TopLine: return 48
        case .comparison: return 54
        }
    }

    @ViewBuilder
    private func rowForMode(mode: ViewMode, category: Tab2CategoryData) -> some View {
        let isExpanded = expandedCategoryId == category.id
        let toggle = { toggleExpand(category.id) }
        let words = OptionAMockStore.words(for: category.sceneCategory)

        switch mode {
        case .opt2Centered:
            CenteredOptionARow(
                category: category,
                isExpanded: isExpanded,
                onToggle: toggle,
                words: words,
                hasBadgePlate: true,
                isRowCentered: true
            )
        case .opt1Centered:
            CenteredOptionARow(
                category: category,
                isExpanded: isExpanded,
                onToggle: toggle,
                words: words,
                hasBadgePlate: false,
                isRowCentered: true
            )
        case .opt2TopLine:
            CenteredOptionARow(
                category: category,
                isExpanded: isExpanded,
                onToggle: toggle,
                words: words,
                hasBadgePlate: true,
                isRowCentered: false
            )
        case .opt1TopLine:
            CenteredOptionARow(
                category: category,
                isExpanded: isExpanded,
                onToggle: toggle,
                words: words,
                hasBadgePlate: false,
                isRowCentered: false
            )
        case .comparison:
            CenteredOptionARow(
                category: category,
                isExpanded: isExpanded,
                onToggle: toggle,
                words: words,
                hasBadgePlate: true,
                isRowCentered: true
            )
        }
    }

    private func toggleExpand(_ id: String) {
        withAnimation(AppTheme.Motion.categoryWordsReveal) {
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
            try? await Task.sleep(for: .seconds(2.0))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    // MARK: - 辅助组件

    private var floatingTopBar: some View {
        HStack {
            Text("Poplex")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
            Circle()
                .fill(AppTheme.Color.brandStrong.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(
            AppTheme.Color.pageBg.opacity(0.88)
                .background(.ultraThinMaterial)
        )
    }

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            Text("Poplex · Practice & Growth")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.7))
            Text("Every topic grows from your life.")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.pageFooterTop)
    }

    private func toastOverlay(text: String) -> some View {
        Text(text)
            .font(AppTheme.Font.statusNote)
            .foregroundStyle(AppTheme.Color.cardBg)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Color.interactive, in: Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - 🎯 核心校准行组件 (CenteredOptionARow)

private struct CenteredOptionARow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let onToggle: () -> Void
    let words: [Tab2WordEntry]
    let hasBadgePlate: Bool
    let isRowCentered: Bool

    private var sceneCat: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private let targetCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            } label: {
                if isRowCentered {
                    // 🌟 方案核心架构：双列水平咬合，Icon 垂直居中于整行高度
                    HStack(alignment: .center, spacing: hasBadgePlate ? 10 : 10) {
                        iconView

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center) {
                                Text(category.englishLabel)
                                    .font(titleFont)
                                    .foregroundStyle(AppTheme.Color.textPrimary)

                                Spacer()

                                GhostWordsPill(count: category.wordCount, isExpanded: isExpanded)
                            }

                            microProgressBar
                        }
                    }
                    .padding(.vertical, 9.5)
                } else {
                    // 对照结构：原两行堆叠（Icon 仅在顶行）
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center, spacing: hasBadgePlate ? 10 : 10) {
                            iconView

                            Text(category.englishLabel)
                                .font(titleFont)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            Spacer()

                            GhostWordsPill(count: category.wordCount, isExpanded: isExpanded)
                        }

                        HStack(spacing: 0) {
                            Color.clear.frame(width: hasBadgePlate ? 36 : 30)
                            microProgressBar
                        }
                    }
                    .padding(.vertical, 10.5)
                }
            }
            .buttonStyle(.plain)

            // 展开词汇列表
            if isExpanded {
                expandedWordList(words: words)
                    .padding(.top, AppTheme.Space.paddingXS)
                    .padding(.bottom, AppTheme.Space.paddingS)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // 精致 13.5pt 标题
    private var titleFont: SwiftUI.Font {
        FontLoader.registerCustomFonts()
        return SwiftUI.Font.custom(AppTheme.Font.SansWeight.medium.postScriptName, size: 13.5, relativeTo: .subheadline)
    }

    // 🎯 Icon 组件：下移居中与尺寸精修
    @ViewBuilder
    private var iconView: some View {
        if hasBadgePlate {
            // 方案 2: 微凹方块 (26×26pt 平滑微圆角 7pt，内嵌 13pt .medium 图标，居中稳定)
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(AppTheme.Color.iconTileBg.opacity(0.85)) // 极淡微凹底，与卡片背景自然融合
                    .frame(width: 26, height: 26)

                Image(systemName: sceneCat.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .offset(y: 0.2) // 光学校准中心微调
            }
        } else {
            // 方案 1: 纯线条 (15pt .medium，字重与字体 1:1 匹配，居中无飘浮)
            Image(systemName: sceneCat.iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 20, height: 20)
                .offset(y: 0.3) // 光学微调向下对准字高中心
        }
    }

    // 1.5pt 超纤细微轨
    private var microProgressBar: some View {
        let progress = min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0)
        return Capsule()
            .fill(AppTheme.Color.progressTrack.opacity(0.8))
            .frame(height: 1.5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.progressFill)
                    .scaleEffect(x: max(progress, 0.02), anchor: .leading)
            }
    }
}

// MARK: - 幽灵半透胶囊（严格对齐已定稿规范：无 /20）

private struct GhostWordsPill: View {
    let count: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(Tab2CardLabels.words(count))
                .font(AppTheme.Font.tab2ProgressCount)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textSecondary)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7.5))
                .foregroundStyle(AppTheme.Color.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ActivityChipBorder, lineWidth: 0.5))
    }
}

// MARK: - 共享手风琴展开词汇列表

private func expandedWordList(words: [Tab2WordEntry]) -> some View {
    VStack(spacing: AppTheme.Space.paddingS) {
        ForEach(words) { entry in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayForm ?? entry.lemma)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(.system(.caption))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }
                Spacer()
            }
        }
    }
    .padding(.leading, 36)
    .padding(.vertical, 4)
    .transition(.opacity.combined(with: .offset(y: 4)))
}

// MARK: - 模拟数据仓库

private enum OptionAMockStore {
    static var heroCategory: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.leisure.rawValue,
            wordCount: 27,
            unlocked: true,
            notSpokenCount: 27,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            newMaterialCount: 0,
            activityCount: 4,
            activities: [
                Tab2Activity(sceneDetail: "Vacation", occurrenceCount: 3),
                Tab2Activity(sceneDetail: "Watching sports", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Reading news", occurrenceCount: 1),
                Tab2Activity(sceneDetail: "Board games", occurrenceCount: 1)
            ]
        )
    }

    static var moreCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: SceneCategory.food.rawValue,
                wordCount: 20,
                unlocked: true,
                notSpokenCount: 20,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                newMaterialCount: 1,
                activityCount: 3,
                activities: [
                    Tab2Activity(sceneDetail: "Making breakfast", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Coffee run", occurrenceCount: 1)
                ]
            )
        ]
    }

    static var inProgress5Categories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: SceneCategory.shopping.rawValue,
                wordCount: 14,
                unlocked: false,
                notSpokenCount: 14,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                newMaterialCount: 1,
                activityCount: 2,
                activities: [Tab2Activity(sceneDetail: "Grocery haul", occurrenceCount: 1)]
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.workStudy.rawValue,
                wordCount: 9,
                unlocked: false,
                notSpokenCount: 9,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [Tab2Activity(sceneDetail: "Team sync", occurrenceCount: 1)]
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.gettingAround.rawValue,
                wordCount: 6,
                unlocked: false,
                notSpokenCount: 6,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [Tab2Activity(sceneDetail: "Subway commute", occurrenceCount: 1)]
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.healthFitness.rawValue,
                wordCount: 3,
                unlocked: false,
                notSpokenCount: 3,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [Tab2Activity(sceneDetail: "Morning jog", occurrenceCount: 1)]
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.weather.rawValue,
                wordCount: 1,
                unlocked: false,
                notSpokenCount: 1,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [Tab2Activity(sceneDetail: "Sunny walk", occurrenceCount: 1)]
            )
        ]
    }

    static func words(for category: String) -> [Tab2WordEntry] {
        [
            Tab2WordEntry(
                lemma: "grocery",
                displayForm: "groceries",
                entryKind: "word",
                pos: "n.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "I need to pick up some groceries tonight.",
                nativeMeaning: "日用杂货，食品",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "checkout",
                displayForm: "checkout",
                entryKind: "word",
                pos: "n.",
                granularity: "word",
                sourceType: "material",
                sampleSentence: nil,
                nativeMeaning: "收银结账台",
                imageUrl: nil
            )
        ]
    }
}

// MARK: - Xcode Canvas 预览入口

#Preview("Tab2 Topics Icon下移居中与尺寸校准") {
    Tab2OptionARefinementPreviewView()
}
#endif
