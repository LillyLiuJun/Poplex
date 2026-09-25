#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Topics 进度卡视觉轻量化与信息密度重构画布 (Tab2 Topics Refinement Sandbox)
// 🎯 探索目标与解决痛点：
//   针对当前生产中「Topics in progress」卡片“与上方 Hero / More 卡片信息密度不协调、整体内容偏重、
//   类似封闭大闷罐与 KPI 进度报表”的视觉断层问题，在保持底层业务与手风琴展开能力 100% 兼容的前提下，
//   提供 3 种不同维度的视觉减重与排版重塑方案，并配备 5 组丰富连续生活场景数据，全面检验多行真实密度：
//
//   - 【基线标尺 (Baseline)】：当前生产现状（通栏硬灰进度条 + 实色灰胶囊 + 36pt 粗框 + 密闭大箱子）；
//   - 【思路 A (Option A · 轻量行内微轨)】：保留容器，进度条退为 1.5pt 微轨且内缩对齐 + 胶囊升级为方案 B 幽灵微底 + 0.5pt 发丝边；
//   - 【思路 B (Option B · 舒展呼吸卡片)】：解构密闭大盒子，采用与 More 同族的独立呼吸轻卡片（间距 10pt，底纸穿透）；
//   - 【思路 C (Option C · 静音陪伴降维)】：彻底摘掉侵入式横向进度横杠，改用单行静音刻度胶囊，减重 60%，杂志陪伴感；
//   - 【全方案同屏纵向对照 (Comparison)】：同屏排列 4 组卡片，一眼评判视觉呼吸与密度差异。

struct Tab2TopicsRefinementPreviewView: View {
    @State private var viewMode: ViewMode = .optionA
    @State private var showTopBarShell: Bool = false
    @State private var toastMessage: String?
    @State private var selectedTab: AppTab = .mine
    @State private var expandedCategoryId: String? = nil

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case optionA    = "思路 A (轻量微轨+幽灵胶囊)"
        case optionB    = "思路 B (呼吸卡片·解构大盒)"
        case optionC    = "思路 C (静音陪伴·极简降维)"
        case baseline   = "当前现状 (粗轨+封闭大盒)"
        case comparison = "全方案同屏对比"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 控制面板
            controlPanel

            Divider().opacity(0.15)

            // 画布主视口
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

    // MARK: - 顶端控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Topics 卡片减重与密度重塑画布")
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

            // 方案切换器
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

    // MARK: - 单模式主视图 (包含 Hero + More + Topics 完整节奏)

    @ViewBuilder
    private func singleModeView(mode: ViewMode) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // 1. 页面大标题与 Hero 卡片
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Talk about today")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                Tab2HeroCard(
                    category: TopicsMockStore.heroCategory,
                    onTalk: { triggerAction("Talk about: Hobbies & Leisure") }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 2. More to talk about 列表 (最新生产 16pt 右对齐)
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More to talk about")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(TopicsMockStore.moreCategories) { category in
                        Tab2ActivityRow(
                            category: category,
                            onTap: { triggerAction("Selected topic: \(category.englishLabel)") }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 3. 🎯 核心测试区：Topics in progress (多方案落地)
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

                // 具体的 Topics 呈现
                topicsContainer(mode: mode)
            }
        }
    }

    // MARK: - 全方案同屏对比视图

    private var comparisonView: some View {
        VStack(alignment: .leading, spacing: 32) {
            sectionHeader("方案 A：轻量行内微轨 (Airy Inline)", note: "纤细 1.5pt 微轨内缩对齐 + 方案 B 幽灵胶囊，保留大盒但内部极其透气")
            topicsContainer(mode: .optionA)

            sectionHeader("方案 B：舒展呼吸卡片 (Breathing Structure)", note: "彻底解构大盒子，改为与 More 同族的独立呼吸轻卡片，底纸穿透")
            topicsContainer(mode: .optionB)

            sectionHeader("方案 C：静音陪伴降维 (Quiet Companion)", note: "彻底移除横向横杠，单行静音刻度胶囊，消除任务清单考核感，减重 60%")
            topicsContainer(mode: .optionC)

            sectionHeader("基线标尺：当前生产现状 (Baseline)", note: "通栏粗硬灰线 + 实色灰胶囊 + 紧密密闭大箱子")
            topicsContainer(mode: .baseline)
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
        case .optionA: return "思路 A · 幽灵胶囊+微轨"
        case .optionB: return "思路 B · 独立呼吸卡"
        case .optionC: return "思路 C · 静音微刻度"
        case .baseline: return "当前基线 · 封闭粗轨"
        case .comparison: return "同屏对比"
        }
    }

    // MARK: - Topics 容器派发

    @ViewBuilder
    private func topicsContainer(mode: ViewMode) -> some View {
        let categories = TopicsMockStore.inProgress5Categories

        switch mode {
        case .optionA:
            // 思路 A：保留大卡片，内部元素全面轻量化
            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                    OptionARow(
                        category: cat,
                        isExpanded: expandedCategoryId == cat.id,
                        onToggle: { toggleExpand(cat.id) },
                        words: TopicsMockStore.words(for: cat.sceneCategory)
                    )

                    if index < categories.count - 1 {
                        Divider()
                            .opacity(0.12)
                            .padding(.leading, 56) // 沿文字左缘对齐轻柔分隔
                            .padding(.trailing, AppTheme.Space.paddingPage)
                    }
                }
            }
            .padding(.vertical, AppTheme.Space.paddingXS)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)

        case .optionB:
            // 思路 B：解构大盒子，每项为独立呼吸轻卡片 (间距 10pt，与 More 形成同族节奏)
            VStack(spacing: 10) {
                ForEach(categories) { cat in
                    OptionBCard(
                        category: cat,
                        isExpanded: expandedCategoryId == cat.id,
                        onToggle: { toggleExpand(cat.id) },
                        words: TopicsMockStore.words(for: cat.sceneCategory)
                    )
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

        case .optionC:
            // 思路 C：静音陪伴，彻底移除横向横杠，单行极简高雅排印
            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                    OptionCRow(
                        category: cat,
                        isExpanded: expandedCategoryId == cat.id,
                        onToggle: { toggleExpand(cat.id) },
                        words: TopicsMockStore.words(for: cat.sceneCategory)
                    )

                    if index < categories.count - 1 {
                        Divider()
                            .opacity(0.12)
                            .padding(.leading, 56)
                            .padding(.trailing, AppTheme.Space.paddingPage)
                    }
                }
            }
            .padding(.vertical, AppTheme.Space.paddingXS)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)

        case .baseline, .comparison:
            // 基线：100% 生产现状
            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                    CategoryProgressRow(
                        category: cat,
                        isExpanded: expandedCategoryId == cat.id,
                        onToggle: { toggleExpand(cat.id) },
                        loadWords: { TopicsMockStore.words(for: cat.sceneCategory) },
                        wordsRevision: 0,
                        milestonePresentations: []
                    )
                }
            }
            .padding(.vertical, AppTheme.Space.paddingS)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func toggleExpand(_ id: String) {
        withAnimation(AppTheme.Motion.accordionToggle) {
            expandedCategoryId = (expandedCategoryId == id ? nil : id)
        }
    }

    // MARK: - 辅助与顶栏

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
    }

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(capHeight: 12.5, style: .mono(AppTheme.Color.textMuted), showsPeriod: true)
            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.tab2FooterTop)
    }

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
}

// MARK: - 🎨 思路 A：轻量行内微轨 (OptionARow)
// 🎯 特点：
//   1. 进度条变为 1.5pt 超细微轨，且【不通栏贯穿】，内缩起始于文字左边缘，与文字形成自然组块；
//   2. 胶囊全面升级为与活动胶囊一致的「幽灵半透底 (30%) + 0.5pt 发丝边」，极度通透；
//   3. 图标框由 36pt 优化为 28pt 自然视觉居中，减小色块面积。

private struct OptionARow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let onToggle: () -> Void
    let words: [Tab2WordEntry]

    private var sceneCat: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private let targetCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    // 首行：图标 + 精致小标题 (13.5pt) + 幽灵半透胶囊
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: sceneCat.iconName)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .frame(width: 20, height: 20)

                        Text(category.englishLabel)
                            .font(SwiftUI.Font.custom(AppTheme.Font.SansWeight.medium.postScriptName, size: 13.5, relativeTo: .subheadline))
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        GhostWordsPill(count: category.wordCount, isExpanded: isExpanded)
                    }

                    // 第二行：超纤细 1.5pt 进度微轨（内缩 30pt，对齐文字起始线，不割裂图标）
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 30) // 内缩避开左侧图标 (20 + 10)
                        microProgressBar
                    }
                }
                .padding(.vertical, 11)
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

    private var microProgressBar: some View {
        let progress = min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0)
        return Capsule()
            .fill(AppTheme.Color.progressTrack.opacity(0.8))
            .frame(height: 1.5) // 超细微轨
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.progressFill)
                    .scaleEffect(x: max(progress, 0.02), anchor: .leading)
            }
    }
}

// MARK: - 🎨 思路 B：舒展呼吸卡片 (OptionBCard)
// 🎯 特点：
//   1. 彻底打破密闭大闷罐，每个正在积累的类目都是【独立的 16pt 圆角轻卡片】；
//   2. 卡片与卡片之间有 10pt 的物理间距，底纸暖色穿透，与上方的 More 列表形成一致的卡片节律；
//   3. 进度条自然收纳在每张独立卡片底部，不再有大容器压抑感。

private struct OptionBCard: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let onToggle: () -> Void
    let words: [Tab2WordEntry]

    private var sceneCat: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private let targetCount = 20

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onToggle()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // 首行：图标 + 标题 + 幽灵胶囊
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: sceneCat.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: 24, height: 24)

                    Text(category.englishLabel)
                        .font(AppTheme.Font.tab2TopicLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    GhostWordsPill(count: category.wordCount, isExpanded: isExpanded)
                }

                // 第二行：进度条（在独立卡片内呼吸舒展）
                let progress = min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0)
                Capsule()
                    .fill(AppTheme.Color.progressTrack)
                    .frame(height: 2.0)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Color.progressFill)
                            .scaleEffect(x: max(progress, 0.02), anchor: .leading)
                    }

                // 展开词汇列表
                if isExpanded {
                    expandedWordList(words: words)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 13)
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
}

// MARK: - 🎨 思路 C：静音陪伴降维 (OptionCRow)
// 🎯 特点：
//   1. 彻底【移除横向横杠进度条】，消灭工业报表与 KPI 任务催促感；
//   2. 视觉减重 60%：单行极简排印，右侧采用「静音微刻度胶囊」，将进度与词数融合为一个安静优雅的辅助信息；
//   3. 真正回归未解锁内容的“低调后台陪伴”属性。

private struct OptionCRow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let onToggle: () -> Void
    let words: [Tab2WordEntry]

    private var sceneCat: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private let targetCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: sceneCat.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: 24, height: 24)

                    Text(category.englishLabel)
                        .font(AppTheme.Font.tab2TopicLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    // 静音微刻度胶囊 (单行优雅整合：词数 + 比例进度点 + 展开角标)
                    QuietProgressBadge(count: category.wordCount, target: targetCount, isExpanded: isExpanded)
                }
                .padding(.vertical, 14)
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
}

// MARK: - 公共精细化微组件

/// 方案 A & B 专用的幽灵半透胶囊（与活动胶囊方案 B 材质完全同族）
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

/// 方案 C 专用的静音微刻度胶囊（无进度条横杠时的极简融合单元）
private struct QuietProgressBadge: View {
    let count: Int
    let target: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 微环形或微进度指示
            Text("\(count)/\(target) words")
                .font(AppTheme.Font.tab2ProgressCount)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textSecondary)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.Color.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4.5)
        .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ActivityChipBorder, lineWidth: 0.5))
    }
}

/// 展开后的词汇列表抽屉
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
    .padding(.leading, 38)
    .padding(.vertical, 4)
    .transition(.opacity.combined(with: .offset(y: 4)))
}

// MARK: - 模拟数据仓库 (5 组丰富连续生活场景)

private enum TopicsMockStore {
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
                Tab2Activity(sceneDetail: "Playing with pets", occurrenceCount: 1)
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
            ),
            Tab2CategoryData(
                sceneCategory: SceneCategory.social.rawValue,
                wordCount: 31,
                unlocked: true,
                notSpokenCount: 31,
                lastTalkedAt: nil,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
                newMaterialCount: 0,
                activityCount: 3,
                activities: [
                    Tab2Activity(sceneDetail: "Sharing thoughts", occurrenceCount: 3),
                    Tab2Activity(sceneDetail: "Catching up", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Taking a walk", occurrenceCount: 1)
                ]
            )
        ]
    }

    /// 🎯 5 组丰富的未解锁积累数据，覆盖高进度、中进度、低进度与起步进度
    static var inProgress5Categories: [Tab2CategoryData] {
        [
            // 1. 高进度接近解锁：14 / 20 (70%)
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
            // 2. 中度活跃积累：9 / 20 (45%)
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
            // 3. 中低进度成长：6 / 20 (30%)
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
            // 4. 初步起步阶段：3 / 20 (15%)
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
            // 5. 刚刚记录开启：1 / 20 (5%)
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

#Preview("Tab2 Topics 进度卡多方案探索画布") {
    Tab2TopicsRefinementPreviewView()
}
#endif
