#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 胶囊尺寸 · 全模块同屏贴身对比画板 (Capsule Sizing Side-by-Side Sandbox)
// 🎯 核心目标：
//   不再通过切换 Picker 猜测视觉差异，而是将【基准】、【方案 A ⭐】、【方案 B】、【方案 C】
//   直接贴身平铺在同一个页面中，按四大内容模块垂直排开，一眼肉眼断优劣！
//
// 🎯 四大同屏对比专区：
//   1. 【纯胶囊物理标尺阶梯】同一文案 4 方案贴身并列，附物理高度/内距标尺；
//   2. 【Hero 卡片 Talk about today】4 张 Hero 卡贴身对比卡身胶囊与图文/CTA 的整体体感；
//   3. 【More 列表行 More to talk about】4 条列表行紧挨着排在一个卡片容器里，对比行内呼吸感；
//   4. 【手风琴进度行 Topics in progress】4 条进度行并列对比 WordsPill 药丸高矮与进度条比例。
//
// 🎯 视觉基线保障：
//   - 配色 100% 锁定【方案 2：轻雾柔霜 · 极简无边框】(neutral900 @ 4% 墨染柔底 + 无边框 + neutral900 高对比黑字)；
//   - 默认字重严格对齐线上生产【Charter 400 Regular 衬线体】，彻底消除误加粗带来的发黑沉重感；
//   - 胶囊文案 100% 完整舒展，绝无省略号截断！

struct Tab2CapsuleSizingExplorationPreviewView: View {
    // 视图模式：全模块同屏贴身对比 (默认) vs 单方案沉浸全页浏览
    @State private var viewMode: CanvasViewMode = .sideBySide
    // 单方案浏览时选中的方案
    @State private var singleProposal: CapsuleSizingProposal = .compactA
    // 字重粗细档位（默认 Charter 400 Regular 线上标准）
    @State private var selectedFontWeight: CapsuleFontWeightOption = .charterRegular
    // 展开的手风琴行 ID
    @State private var expandedCategoryId: String? = nil
    // 胶囊聚光灯辅助高亮
    @State private var showFocusSpotlight: Bool = false
    // 模拟外壳
    @State private var showTopBarShell: Bool = true
    @State private var selectedTab: AppTab = .mine
    @State private var toastMessage: String?

    enum CanvasViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case sideBySide = "全模块同屏贴身对比 ⭐"
        case singleFlow = "单方案全页沉浸体验"
    }

    enum CapsuleSizingProposal: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case baseline = "基准 (线上原大小)"
        case compactA = "方案 A (紧凑瘦身 ⭐ 推荐)"
        case slimB    = "方案 B (纤巧极简)"
        case narrowC  = "方案 C (横向收拢)"

        var shortTitle: String {
            switch self {
            case .baseline: return "基准 (原版)"
            case .compactA: return "方案 A ⭐"
            case .slimB:    return "方案 B"
            case .narrowC:  return "方案 C"
            }
        }

        var badgeColor: Color {
            switch self {
            case .baseline: return AppTheme.Color.textMuted
            case .compactA: return AppTheme.Color.brandStrong
            case .slimB:    return Color(red: 0.22, green: 0.52, blue: 0.72)
            case .narrowC:  return Color(red: 0.52, green: 0.42, blue: 0.72)
            }
        }

        var heroSpecs: String {
            switch self {
            case .baseline: return "高 25pt · 内距 9pt · 字 13.5pt (带边框时代原版尺寸)"
            case .compactA: return "高 23pt (-2pt) · 内距 8pt · 字 13.5pt (去臃肿不缩字 ⭐)"
            case .slimB:    return "高 21.5pt (-3.5pt) · 内距 7.5pt · 字 13pt (纤巧现代微标签)"
            case .narrowC:  return "高 25pt (不变) · 内距 7pt (-2pt) · 字 13.5pt (仅横向收拢耳朵)"
            }
        }

        var moreSpecs: String {
            switch self {
            case .baseline: return "高 22pt · 内距 8pt · 字 12pt"
            case .compactA: return "高 20pt (-2pt) · 内距 7pt · 字 12pt ⭐"
            case .slimB:    return "高 19pt (-3pt) · 内距 6.5pt · 字 11.5pt"
            case .narrowC:  return "高 22pt · 内距 6.5pt · 字 12pt"
            }
        }

        var wordsSpecs: String {
            switch self {
            case .baseline: return "高 22pt · 内距 8pt/3pt · 字 12pt"
            case .compactA: return "高 20pt (-2pt) · 内距 7pt/2.5pt · 字 12pt ⭐"
            case .slimB:    return "高 19pt (-3pt) · 内距 6.5pt/2pt · 字 11.5pt"
            case .narrowC:  return "高 22pt · 内距 6.5pt/3pt · 字 12pt"
            }
        }
    }

    enum CapsuleFontWeightOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case charterRegular = "线上标准 (Charter 400 Regular)"
        case systemLight    = "纤细轻透 (Light 300)"
        case systemMedium   = "之前误用 (Medium 500)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端全局控制面板
            controlHeader

            Divider().opacity(0.15)

            // 主展示画布
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewMode == .sideBySide {
                            // 🌟 模式一：全模块同屏贴身对比视图
                            sideBySideComparisonView
                        } else {
                            // 模式二：单方案全页面流式视图
                            singleProposalFlowView
                        }

                        // 页面底部署名与呼吸留白
                        footerSignoff
                            .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                    }
                    .background(alignment: .bottom) {
                        BottomAuraFooter()
                    }
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .background(AppTheme.Color.pageBg.ignoresSafeArea())
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
                    toastOverlay(text: toast)
                }
            }
        }
    }

    // MARK: - 顶端控制面板

    private var controlHeader: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("胶囊尺寸 · 全模块同屏贴身对比沙盒")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Toggle("聚光灯", isOn: $showFocusSpotlight)
                    .font(AppTheme.Font.pos)
                    .labelsHidden()
                Text(showFocusSpotlight ? "标尺高亮 ON" : "标尺高亮 OFF")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(showFocusSpotlight ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
            }

            // 画板查看模式切换
            Picker("查看模式", selection: $viewMode) {
                ForEach(CanvasViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 字重选择器：彻底锁定 Charter 400 Regular，同时可即时比对 Light 300
            HStack(spacing: 6) {
                Text("胶囊字重:")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Picker("字重", selection: $selectedFontWeight) {
                    ForEach(CapsuleFontWeightOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 单方案模式下的方案选择
            if viewMode == .singleFlow {
                Picker("尺寸方案", selection: $singleProposal) {
                    ForEach(CapsuleSizingProposal.allCases) { prop in
                        Text(prop.rawValue).tag(prop)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 🌟 模式一：全模块同屏贴身对比视图 (Side-by-Side View)

    private var sideBySideComparisonView: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 专区 1：物理标尺微距对比
            ladderSection

            Divider().opacity(0.12).padding(.horizontal, AppTheme.Space.paddingPage)

            // 专区 2：Hero 卡片 Talk about today
            heroComparisonSection

            Divider().opacity(0.12).padding(.horizontal, AppTheme.Space.paddingPage)

            // 专区 3：More 列表行 More to talk about
            moreRowsComparisonSection

            Divider().opacity(0.12).padding(.horizontal, AppTheme.Space.paddingPage)

            // 专区 4：手风琴进度行 Topics in progress (WordsPill)
            progressComparisonSection
        }
        .padding(.top, 16)
    }

    // MARK: - 专区 1：纯胶囊物理标尺微距阶梯

    private var ladderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                tag: "MODULE 01",
                title: "纯胶囊物理微距标尺阶梯",
                subtitle: "同一组词在 4 种方案下的物理高矮、左右内距与字体紧凑度直接对比"
            )

            VStack(spacing: 8) {
                ForEach(CapsuleSizingProposal.allCases) { prop in
                    let metrics = CapsuleSizingMetrics.forProposal(prop)
                    HStack(alignment: .center, spacing: 10) {
                        // 左侧方案标签
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(prop.badgeColor).frame(width: 6, height: 6)
                                Text(prop.shortTitle)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(prop.badgeColor)
                            }
                            Text("高 \(String(format: "%.1f", metrics.heroHeight)) · 距 \(Int(metrics.heroPaddingH))")
                                .font(.system(size: 9.5))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .frame(width: 82, alignment: .leading)

                        // 胶囊样本 1
                        ladderCapsule(
                            text: "Morning routine",
                            height: metrics.heroHeight,
                            padH: metrics.heroPaddingH,
                            fontSize: metrics.heroFontSize,
                            badgeColor: prop.badgeColor
                        )

                        // 胶囊样本 2
                        ladderCapsule(
                            text: "Water plants",
                            height: metrics.heroHeight,
                            padH: metrics.heroPaddingH,
                            fontSize: metrics.heroFontSize,
                            badgeColor: prop.badgeColor
                        )

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                prop == .compactA ? AppTheme.Color.brandStrong.opacity(0.35) : AppTheme.Color.cardBorder,
                                lineWidth: prop == .compactA ? 1.5 : 0.5
                            )
                    )
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func ladderCapsule(text: String, height: CGFloat, padH: CGFloat, fontSize: CGFloat, badgeColor: Color) -> some View {
        Text(text)
            .font(font(for: fontSize))
            .foregroundStyle(AppTheme.Color.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, padH)
            .frame(height: height)
            .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule())
            .overlay {
                if showFocusSpotlight {
                    Capsule().strokeBorder(badgeColor.opacity(0.8), lineWidth: 1)
                }
            }
    }

    // MARK: - 专区 2：Hero 卡片模块 4 方案贴身对比

    private var heroComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                tag: "MODULE 02",
                title: "Talk about today · Hero 卡片 4 方案同屏对比",
                subtitle: "向下滑动，直接对比无边框轻雾胶囊在 4 种尺寸下与 Hero 卡片封面、CTA 的上下呼吸关系"
            )

            VStack(spacing: 20) {
                ForEach(CapsuleSizingProposal.allCases) { prop in
                    VStack(alignment: .leading, spacing: 6) {
                        // 方案指示标签条
                        HStack {
                            Text(prop.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(prop.badgeColor)
                            Spacer()
                            Text(prop.heroSpecs)
                                .font(.system(size: 10.5))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage + 2)

                        // 真实渲染卡片
                        SizingHeroCard(
                            category: SizingMockStore.activeHero,
                            proposal: prop,
                            fontOption: selectedFontWeight,
                            isSpotlight: showFocusSpotlight,
                            onCTA: { triggerAction("CTA Tapped: \(prop.rawValue)") },
                            onCardTap: { triggerAction("Hero Tapped: \(prop.rawValue)") }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 专区 3：More 列表行 4 方案贴身对比

    private var moreRowsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                tag: "MODULE 03",
                title: "More to talk about · 列表行 4 方案贴身对比",
                subtitle: "将 4 个尺寸方案的列表行并列排在一个集合中，肉眼直接对比 68pt 缩略图右侧胶囊的高矮松紧"
            )

            VStack(spacing: 12) {
                ForEach(Array(CapsuleSizingProposal.allCases.enumerated()), id: \.element.id) { index, prop in
                    let category = SizingMockStore.activeMoreCategories[index % SizingMockStore.activeMoreCategories.count]
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(prop.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(prop.badgeColor)
                            Spacer()
                            Text(prop.moreSpecs)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage + 2)

                        SizingActivityRow(
                            category: category,
                            proposal: prop,
                            fontOption: selectedFontWeight,
                            isSpotlight: showFocusSpotlight,
                            onTap: { triggerAction("Tapped Row: \(prop.rawValue)") }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 专区 4：手风琴进度 WordsPill 4 方案贴身对比

    private var progressComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                tag: "MODULE 04",
                title: "Topics in progress · WordsPill 4 方案贴身对比",
                subtitle: "对比右侧 '20 words ▼' 展开药丸在 4 种尺寸下与左侧标题、下方进度条的协调度"
            )

            VStack(spacing: 0) {
                ForEach(Array(CapsuleSizingProposal.allCases.enumerated()), id: \.element.id) { index, prop in
                    let category = SizingMockStore.inProgressCategories[index % SizingMockStore.inProgressCategories.count]
                    let rowKey = "\(prop.id)_\(category.id)"

                    VStack(alignment: .leading, spacing: 0) {
                        // 方案说明细条
                        HStack {
                            Text(prop.rawValue)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(prop.badgeColor)
                            Spacer()
                            Text(prop.wordsSpecs)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.vertical, 4)
                        .background(prop.badgeColor.opacity(0.04))

                        // 进度行组件
                        SizingCategoryProgressRow(
                            category: category,
                            isExpanded: expandedCategoryId == rowKey,
                            proposal: prop,
                            fontOption: selectedFontWeight,
                            isSpotlight: showFocusSpotlight,
                            onToggle: {
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    expandedCategoryId = (expandedCategoryId == rowKey ? nil : rowKey)
                                }
                            }
                        )

                        if index < CapsuleSizingProposal.allCases.count - 1 {
                            Divider().overlay(AppTheme.Color.divider)
                        }
                    }
                }
            }
            .background(AppTheme.Color.cardBg)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    // MARK: - 模式二：单方案全页面流式体验 (用于最终校验整页平衡感)

    private var singleProposalFlowView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // 1. Talk about today (Hero 区)
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Talk about today")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                SizingHeroCard(
                    category: SizingMockStore.activeHero,
                    proposal: singleProposal,
                    fontOption: selectedFontWeight,
                    isSpotlight: showFocusSpotlight,
                    onCTA: { triggerAction("CTA: Start talking") },
                    onCardTap: { triggerAction("Tapped Hero") }
                )
            }

            // 2. More to talk about
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More to talk about")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(SizingMockStore.activeMoreCategories, id: \.sceneCategory) { category in
                        SizingActivityRow(
                            category: category,
                            proposal: singleProposal,
                            fontOption: selectedFontWeight,
                            isSpotlight: showFocusSpotlight,
                            onTap: { triggerAction("Tapped More: \(category.sceneCategory)") }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 3. Topics in progress
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Topics in progress")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 0) {
                    ForEach(Array(SizingMockStore.inProgressCategories.enumerated()), id: \.element.id) { index, category in
                        SizingCategoryProgressRow(
                            category: category,
                            isExpanded: expandedCategoryId == "single_\(category.id)",
                            proposal: singleProposal,
                            fontOption: selectedFontWeight,
                            isSpotlight: showFocusSpotlight,
                            onToggle: {
                                let key = "single_\(category.id)"
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    expandedCategoryId = (expandedCategoryId == key ? nil : key)
                                }
                            }
                        )

                        if index < SizingMockStore.inProgressCategories.count - 1 {
                            Divider()
                                .overlay(AppTheme.Color.divider)
                                .padding(.leading, AppTheme.Size.categoryBadge + AppTheme.Size.categoryRowContentSpacing + AppTheme.Space.paddingPage)
                                .padding(.trailing, AppTheme.Space.paddingPage)
                        }
                    }
                }
                .background(AppTheme.Color.cardBg)
                .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                }
                .cardShadow()
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 4. More topics to explore
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More topics to explore")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        exploreChip("Art & Creativity")
                        exploreChip("Nature & Outdoors")
                        exploreChip("Travel & Places")
                    }
                    HStack(spacing: 8) {
                        exploreChip("Home & Living")
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
        .padding(.top, 16)
    }

    private func exploreChip(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Font.tab2MoreRowCapsuleName)
            .foregroundStyle(AppTheme.Color.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule())
    }

    // MARK: - 辅助组件与格式化

    private func sectionHeader(tag: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(tag)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func font(for size: CGFloat) -> Font {
        switch selectedFontWeight {
        case .charterRegular:
            return Font.custom("Charter", size: size)
        case .systemLight:
            return .system(size: size, weight: .light, design: .serif)
        case .systemMedium:
            return .system(size: size, weight: .medium, design: .serif)
        }
    }

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

    private func triggerAction(_ text: String) {
        toastMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == text {
                toastMessage = nil
            }
        }
    }

    private func toastOverlay(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Color.brandStrong)
            Text(text)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - 尺寸配置规范计算中心 (Capsule Sizing Spec Engine)

private struct CapsuleSizingMetrics {
    let heroHeight: CGFloat
    let heroPaddingH: CGFloat
    let heroFontSize: CGFloat
    let heroGap: CGFloat

    let moreHeight: CGFloat
    let morePaddingH: CGFloat
    let moreFontSize: CGFloat
    let moreGap: CGFloat

    let wordsHeight: CGFloat
    let wordsPaddingH: CGFloat
    let wordsPaddingV: CGFloat
    let wordsFontSize: CGFloat

    static func forProposal(_ prop: Tab2CapsuleSizingExplorationPreviewView.CapsuleSizingProposal) -> CapsuleSizingMetrics {
        switch prop {
        case .baseline:
            // 线上原版大小：带边框时代保留的尺寸
            return CapsuleSizingMetrics(
                heroHeight: AppTheme.Tab2Hero.Layout.activityCapsuleRowHeight, // 25pt
                heroPaddingH: 9,
                heroFontSize: AppTheme.Font.tab2HeroCapsuleNameBaseSize, // 13.5pt
                heroGap: 7,
                moreHeight: AppTheme.Tab2MoreRow.Layout.activityCapsuleRowHeight, // 22pt
                morePaddingH: 8,
                moreFontSize: AppTheme.Font.tab2MoreRowCapsuleNameBaseSize, // 12pt
                moreGap: 6,
                wordsHeight: 22,
                wordsPaddingH: 8,
                wordsPaddingV: 3,
                wordsFontSize: 12
            )

        case .compactA:
            // 方案 A (推荐)：高压低 2pt，内距适度收紧，字号不变，饱满利落
            return CapsuleSizingMetrics(
                heroHeight: 23,
                heroPaddingH: 8,
                heroFontSize: 13.5,
                heroGap: 6,
                moreHeight: 20,
                morePaddingH: 7,
                moreFontSize: 12,
                moreGap: 5,
                wordsHeight: 20,
                wordsPaddingH: 7,
                wordsPaddingV: 2.5,
                wordsFontSize: 12
            )

        case .slimB:
            // 方案 B：高压低 3~3.5pt，字号微缩 0.5pt，纤细极简风
            return CapsuleSizingMetrics(
                heroHeight: 21.5,
                heroPaddingH: 7.5,
                heroFontSize: 13,
                heroGap: 5.5,
                moreHeight: 19,
                morePaddingH: 6.5,
                moreFontSize: 11.5,
                moreGap: 5,
                wordsHeight: 19,
                wordsPaddingH: 6.5,
                wordsPaddingV: 2,
                wordsFontSize: 11.5
            )

        case .narrowC:
            // 方案 C：高度保持原版 25/22pt，仅收拢横向留白耳朵 (-2pt)
            return CapsuleSizingMetrics(
                heroHeight: 25,
                heroPaddingH: 7,
                heroFontSize: 13.5,
                heroGap: 6,
                moreHeight: 22,
                morePaddingH: 6.5,
                moreFontSize: 12,
                moreGap: 5,
                wordsHeight: 22,
                wordsPaddingH: 6.5,
                wordsPaddingV: 3,
                wordsFontSize: 12
            )
        }
    }
}

// MARK: - 尺寸定制版 Hero 卡片组件

private struct SizingHeroCard: View {
    let category: Tab2CategoryData
    let proposal: Tab2CapsuleSizingExplorationPreviewView.CapsuleSizingProposal
    let fontOption: Tab2CapsuleSizingExplorationPreviewView.CapsuleFontWeightOption
    let isSpotlight: Bool
    let onCTA: () -> Void
    let onCardTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }
    private var metrics: CapsuleSizingMetrics { CapsuleSizingMetrics.forProposal(proposal) }

    var body: some View {
        Button {
            onCardTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // 封面图区
                ZStack(alignment: .top) {
                    CachedRemoteImage(
                        signedUrl: display.photoCover?.imageUrl ?? "",
                        stableKey: display.photoCover?.stableImageKey ?? display.photoCover?.imageUrl ?? "",
                        placeholder: { Rectangle().fill(AppTheme.Color.imagePlaceholderBg) }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
                    .clipped()

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.35), Color.clear, Color.black.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)

                    // 封面顶行帽子
                    HStack(spacing: 8) {
                        Text(category.englishLabel)
                            .font(AppTheme.Font.tab2HeroChipCategory)
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .shadow(
                                color: Color.black.opacity(0.5),
                                radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                x: 0,
                                y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                            )

                        Spacer()

                        Text("Added 3 times today")
                            .font(AppTheme.Font.tab2ReasonPill)
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                            .shadow(
                                color: Color.black.opacity(0.5),
                                radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                x: 0,
                                y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                            )
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    .padding(.horizontal, AppTheme.Tab2Hero.Layout.chipTopLeading)
                }

                // 卡身文字区
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
                        HStack {
                            Text("Recent activities")
                                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                                .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(AppTheme.Color.textMuted)

                            if isSpotlight {
                                Text("尺寸对比: \(proposal.rawValue)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                            }
                        }

                        // 活动胶囊组：双行自适应完整展开，绝无省略号！
                        SizingActivityCapsuleGroup(
                            activities: display.valid.map(\.name),
                            moreCount: 1,
                            metrics: metrics,
                            fontOption: fontOption,
                            isHero: true,
                            isSpotlight: isSpotlight
                        )
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

                    // 47 words + CTA
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
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}

// MARK: - 尺寸定制版 More 行组件

private struct SizingActivityRow: View {
    let category: Tab2CategoryData
    let proposal: Tab2CapsuleSizingExplorationPreviewView.CapsuleSizingProposal
    let fontOption: Tab2CapsuleSizingExplorationPreviewView.CapsuleFontWeightOption
    let isSpotlight: Bool
    let onTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }
    private var metrics: CapsuleSizingMetrics { CapsuleSizingMetrics.forProposal(proposal) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 左侧缩略图
                Color.clear
                    .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                    .overlay(thumbnail)
                    .clipped()

                // 右侧内容区
                VStack(alignment: .leading, spacing: 0) {
                    hatRow

                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            SizingActivityCapsuleGroup(
                                activities: display.valid.prefix(2).map(\.name),
                                moreCount: display.valid.count > 1 ? (display.valid.count - 1) : nil,
                                metrics: metrics,
                                fontOption: fontOption,
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
        .padding(.horizontal, AppTheme.Space.paddingPage)
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
        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)
    }
}

// MARK: - 尺寸自适应 Activity 胶囊组 (文字 100% 完整展示，绝无省略号)

private struct SizingActivityCapsuleGroup: View {
    let activities: [String]
    let moreCount: Int?
    let metrics: CapsuleSizingMetrics
    let fontOption: Tab2CapsuleSizingExplorationPreviewView.CapsuleFontWeightOption
    let isHero: Bool
    let isSpotlight: Bool

    var body: some View {
        if isHero {
            // Hero 双行完整展示（首行放前 2 个，第二行放第 3 个 + "+N more"）
            let row1 = Array(activities.prefix(2))
            let row2 = Array(activities.dropFirst(2).prefix(1))
            let hasMore = (moreCount != nil || activities.count > 3)
            let moreNum = (moreCount ?? 0) + max(0, activities.count - 3)

            VStack(alignment: .leading, spacing: metrics.heroGap) {
                HStack(spacing: metrics.heroGap) {
                    ForEach(row1, id: \.self) { name in
                        capsule(name, height: metrics.heroHeight, padH: metrics.heroPaddingH, fontSize: metrics.heroFontSize)
                    }
                }
                if !row2.isEmpty || hasMore {
                    HStack(spacing: metrics.heroGap) {
                        ForEach(row2, id: \.self) { name in
                            capsule(name, height: metrics.heroHeight, padH: metrics.heroPaddingH, fontSize: metrics.heroFontSize)
                        }
                        if hasMore && moreNum > 0 {
                            morePill(" +\(moreNum) more", height: metrics.heroHeight, fontSize: metrics.heroFontSize - 1)
                        }
                    }
                }
            }
            .frame(height: metrics.heroHeight * 2 + metrics.heroGap, alignment: .topLeading)
        } else {
            // More 行单行自适应完整展示
            let firstActivity = activities.first
            let remaining = max(1, activities.count - 1 + (moreCount ?? 0))

            HStack(spacing: metrics.moreGap) {
                if let name = firstActivity {
                    capsule(name, height: metrics.moreHeight, padH: metrics.morePaddingH, fontSize: metrics.moreFontSize)
                }
                if remaining > 0 {
                    morePill(" +\(remaining) more", height: metrics.moreHeight, fontSize: metrics.moreFontSize - 1)
                }
            }
            .frame(height: metrics.moreHeight, alignment: .leading)
        }
    }

    private func capsule(_ name: String, height: CGFloat, padH: CGFloat, fontSize: CGFloat) -> some View {
        Text(name)
            .font(font(for: fontSize))
            .foregroundStyle(AppTheme.Color.textPrimary) // neutral900 高对比黑字
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false) // 关键：绝不压缩出省略号！
            .padding(.horizontal, padH)
            .frame(height: height)
            .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule()) // 统一使用方案 2 配色
            // 方案 2 彻底不加边框
            .overlay {
                if isSpotlight {
                    Capsule().strokeBorder(AppTheme.Color.brandStrong, lineWidth: 1)
                }
            }
    }

    private func font(for size: CGFloat) -> Font {
        switch fontOption {
        case .charterRegular:
            // 线上生产标准：Charter 400 Regular 衬线体
            return Font.custom("Charter", size: size)
        case .systemLight:
            // 纤细轻透版：系统 300 Light 衬线体
            return .system(size: size, weight: .light, design: .serif)
        case .systemMedium:
            // 之前误写版本：系统 500 Medium 衬线体 (偏粗)
            return .system(size: size, weight: .medium, design: .serif)
        }
    }

    private func morePill(_ text: String, height: CGFloat, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, isHero ? 6 : 4)
            .frame(height: height)
    }
}

// MARK: - 尺寸定制版 CategoryProgressRow (注入尺寸定制版 WordsPill)

private struct SizingCategoryProgressRow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let proposal: Tab2CapsuleSizingExplorationPreviewView.CapsuleSizingProposal
    let fontOption: Tab2CapsuleSizingExplorationPreviewView.CapsuleFontWeightOption
    let isSpotlight: Bool
    let onToggle: () -> Void

    private var metrics: CapsuleSizingMetrics { CapsuleSizingMetrics.forProposal(proposal) }

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

                            // 尺寸定制版 WordsPill
                            SizingWordsPill(
                                count: category.wordCount,
                                isExpanded: isExpanded,
                                metrics: metrics,
                                fontOption: fontOption,
                                isSpotlight: isSpotlight
                            )
                        }

                        // 进度条
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
                    ForEach(SizingMockStore.words(for: category.sceneCategory), id: \.lemma) { word in
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

// MARK: - 尺寸定制版 WordsPill 组件

private struct SizingWordsPill: View {
    let count: Int
    let isExpanded: Bool
    let metrics: CapsuleSizingMetrics
    let fontOption: Tab2CapsuleSizingExplorationPreviewView.CapsuleFontWeightOption
    let isSpotlight: Bool

    var body: some View {
        HStack(spacing: 3.5) {
            Text(Tab2CardLabels.words(count))
                .font(wordsFont)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textSecondary)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, metrics.wordsPaddingH)
        .padding(.vertical, metrics.wordsPaddingV)
        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule()) // 统一使用方案 2 配色
        // 方案 2 彻底不加边框
        .overlay {
            if isSpotlight {
                Capsule().strokeBorder(AppTheme.Color.interactive, lineWidth: 1)
            }
        }
    }

    private var wordsFont: Font {
        switch fontOption {
        case .charterRegular:
            return .system(size: metrics.wordsFontSize, weight: .regular)
        case .systemLight:
            return .system(size: metrics.wordsFontSize, weight: .light)
        case .systemMedium:
            return .system(size: metrics.wordsFontSize, weight: .medium)
        }
    }
}

// MARK: - 真实生产 Mock 数据仓库

private enum SizingMockStore {
    static var activeHero: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "Daily Routine",
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 0,
            lastTalkedAt: nil,
            lastMaterialAt: Date().addingTimeInterval(-1800),
            newMaterialCount: 3,
            activityCount: 4,
            activities: [
                Tab2Activity(sceneDetail: "Morning routine", occurrenceCount: 2, cover: Tab2Activity.Cover(materialId: "m1", imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80")),
                Tab2Activity(sceneDetail: "Water plants", occurrenceCount: 1, cover: nil),
                Tab2Activity(sceneDetail: "Coffee & reflection", occurrenceCount: 1, cover: nil),
                Tab2Activity(sceneDetail: "Evening walk", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static var activeMoreCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "Food & Drink",
                wordCount: 34,
                unlocked: true,
                notSpokenCount: 0,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-86400),
                newMaterialCount: 1,
                activityCount: 3,
                activities: [
                    Tab2Activity(sceneDetail: "Cook dinner", occurrenceCount: 2, cover: Tab2Activity.Cover(materialId: "mf1", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80")),
                    Tab2Activity(sceneDetail: "Bakery visit", occurrenceCount: 1, cover: nil),
                    Tab2Activity(sceneDetail: "Order coffee", occurrenceCount: 1, cover: nil)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Work & Study",
                wordCount: 52,
                unlocked: true,
                notSpokenCount: 0,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-172800),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Team sync", occurrenceCount: 2, cover: Tab2Activity.Cover(materialId: "mw1", imageUrl: "https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=600&auto=format&fit=crop&q=80")),
                    Tab2Activity(sceneDetail: "Code review", occurrenceCount: 1, cover: nil)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Shopping",
                wordCount: 28,
                unlocked: true,
                notSpokenCount: 0,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-259200),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Grocery run", occurrenceCount: 1, cover: Tab2Activity.Cover(materialId: "ms1", imageUrl: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=600&auto=format&fit=crop&q=80"))
                ]
            )
        ]
    }

    static var inProgressCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "Social & Feelings",
                wordCount: 20,
                unlocked: false,
                notSpokenCount: 20,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-3600),
                newMaterialCount: 2,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Weekend brunch", occurrenceCount: 1, cover: nil),
                    Tab2Activity(sceneDetail: "Catch up call", occurrenceCount: 1, cover: nil)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Health & Fitness",
                wordCount: 14,
                unlocked: false,
                notSpokenCount: 14,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-7200),
                newMaterialCount: 1,
                activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Morning jog", occurrenceCount: 1, cover: nil)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Travel & Commute",
                wordCount: 8,
                unlocked: false,
                notSpokenCount: 8,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-86400),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Subway ride", occurrenceCount: 1, cover: nil)
                ]
            )
        ]
    }

    static func words(for category: String) -> [Tab2WordEntry] {
        switch category {
        case "social_life":
            return [
                Tab2WordEntry(lemma: "brunch", displayForm: "weekend brunch", nativeMeaning: "周末早午餐"),
                Tab2WordEntry(lemma: "catch up", displayForm: "catch up with friends", nativeMeaning: "叙旧、聊近况"),
                Tab2WordEntry(lemma: "mingle", displayForm: "mingle with guests", nativeMeaning: "社交应酬、交际")
            ]
        case "fitness_health":
            return [
                Tab2WordEntry(lemma: "stretching", displayForm: "dynamic stretching", nativeMeaning: "动态拉伸"),
                Tab2WordEntry(lemma: "hydration", displayForm: "stay hydrated", nativeMeaning: "补水")
            ]
        default:
            return [
                Tab2WordEntry(lemma: "routine", displayForm: "daily routine", nativeMeaning: "日常作息"),
                Tab2WordEntry(lemma: "refreshing", displayForm: "refreshing shower", nativeMeaning: "清爽的淋浴")
            ]
        }
    }
}


// MARK: - Preview Provider

#Preview("Tab2 胶囊尺寸 · 全模块同屏贴身对比沙盒") {
    Tab2CapsuleSizingExplorationPreviewView()
}
#endif
