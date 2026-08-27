import SwiftUI

/// 分类进度行 — 待解锁态 AREAS 区与已解锁态 Still filling up 区共用。
/// isHighlighted=true 时进度条用品牌橙（最接近达标的分类）；否则中性灰。
/// 展开状态由父视图统一持有（单开手风琴）：`isExpanded` 传入、点击回调 `onToggle`。
/// 展开时按需调用 loadWords 拉取全量词条。
struct CategoryProgressRow: View {
    let category: Tab2CategoryData
    let isHighlighted: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let loadWords: () async -> [Tab2WordEntry]
    var milestonePresentations: [CategoryMilestonePresentation] = []

    @State private var words: [Tab2WordEntry] = []
    @State private var isLoadingWords = false
    @State private var milestoneRevealed = false
    @State private var milestoneEmphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let targetCount = 20

    // 进度条承担「连续性」（全部走橙），数字与 icon 承担「里程碑」（只在 hot 时转橙）。
    // hot = 最接近解锁 / 已达标。
    private var isPresentingMilestone: Bool {
        milestonePresentation != nil
    }

    private var milestonePresentation: CategoryMilestonePresentation? {
        milestonePresentations.first { $0.categoryID == category.id }
    }

    static func milestoneScale(
        isPresenting: Bool,
        isEmphasized: Bool,
        reduceMotion: Bool
    ) -> CGFloat {
        guard isPresenting, isEmphasized, !reduceMotion else { return 1.0 }
        return 1.08
    }

    private var milestoneScale: CGFloat {
        Self.milestoneScale(
            isPresenting: isPresentingMilestone,
            isEmphasized: milestoneEmphasized,
            reduceMotion: reduceMotion
        )
    }

    private var displayedCount: Int {
        guard isPresentingMilestone, let milestonePresentation else {
            return category.wordCount
        }
        if reduceMotion { return milestonePresentation.currentCount }
        return milestoneRevealed
            ? milestonePresentation.currentCount
            : milestonePresentation.previousCount
    }

    private var isHot: Bool {
        Self.isHot(
            isPresentingMilestone: isPresentingMilestone,
            milestoneRevealed: milestoneRevealed,
            unlocked: category.unlocked,
            wordCount: category.wordCount,
            targetCount: targetCount,
            isHighlighted: isHighlighted
        )
    }

    /// 分类行是否处于「点亮」态（品牌橙徽标 / 满格进度 / 橙色计数）。
    ///
    /// **点亮 ≠ 已达标。** 三个独立来源都会点亮，注意别把它读成「达标指示器」：
    /// - `unlocked` —— 已解锁的分类常驻点亮。即使 `wordCount` 因口径调整回落到
    ///   `targetCount` 以下也不回退：已解锁不该「变回没解锁的样子」。
    /// - `wordCount >= targetCount` —— 达标。
    /// - `isHighlighted` —— 调用方指定的「最接近解锁」那一行
    ///   （`MineView` 传 `cat.id == closestCategory?.id`），**尚未达标也会橙**，
    ///   用意是把注意力引到「差一点就能开」的那条上。
    ///
    /// 里程碑演出期间**只**听动画的揭示节拍，压过上述全部条件——
    /// 否则一个已达标的分类会在数字还没跑完时就抢先点亮，动效失去意义。
    ///
    /// 抽成静态纯函数是为了可测：条件顺序错一次就会在动画途中提前点亮。
    static func isHot(
        isPresentingMilestone: Bool,
        milestoneRevealed: Bool,
        unlocked: Bool,
        wordCount: Int,
        targetCount: Int,
        isHighlighted: Bool
    ) -> Bool {
        if isPresentingMilestone { return milestoneRevealed }
        return unlocked || wordCount >= targetCount || isHighlighted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            expandToggle
            if isExpanded {
                wordList
                    .padding(.top, AppTheme.Space.paddingXS)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .onChange(of: isExpanded) { _, nowExpanded in
            // 展开（父视图翻转状态）时按需拉词
            if nowExpanded && words.isEmpty { fetchWords() }
        }
        .onChange(of: category.wordCount) { _, _ in
            // word count changed while expanded → invalidate cache and refetch
            if isExpanded {
                words = []
                fetchWords()
            }
        }
        .task(id: milestonePresentations) {
            guard isPresentingMilestone else {
                milestoneRevealed = false
                milestoneEmphasized = false
                return
            }

            milestoneRevealed = false
            milestoneEmphasized = false
            try? await Task.sleep(for: AppTheme.Motion.categoryMilestoneToastLead)
            if reduceMotion {
                withAnimation(AppTheme.Motion.categoryMilestoneReduced) {
                    milestoneRevealed = true
                }
            } else {
                withAnimation(AppTheme.Motion.categoryMilestone) {
                    milestoneRevealed = true
                }
                withAnimation(AppTheme.Motion.categoryMilestoneEmphasisRise) {
                    milestoneEmphasized = true
                }
                try? await Task.sleep(for: AppTheme.Motion.categoryMilestoneEmphasisPeak)
                withAnimation(AppTheme.Motion.categoryMilestoneEmphasisSettle) {
                    milestoneEmphasized = false
                }
            }
        }
    }

    // MARK: - Collapsed header button

    private var expandToggle: some View {
        Button {
            onToggle()   // 展开/收起 + 滚动锚定由父视图统一处理（单开手风琴）
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                // 第一行：类别图标徽章 + 标题 + 半轻灰胶囊（pops 计数 + 展开箭头合并单元）
                HStack(alignment: .center, spacing: AppTheme.Space.paddingM) {
                    categoryBadge

                    Text(category.englishLabel)
                        .font(AppTheme.Font.categoryLabel(isHot: isHot))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    PopsPill(
                        count: displayedCount,
                        isHot: isHot,
                        isExpanded: isExpanded
                    )
                    .scaleEffect(milestoneScale)
                }

                // 第二行：通栏进度条（从徽章左缘拉满，参考 Cleo Spending 行式）
                progressBar
            }
            .padding(.vertical, AppTheme.Space.listRowVertical)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category badge（描边字形 · hot 时转 brandInk，非 hot 走 textMuted）
    // 填充变体（.fill）保留给「激活态」当状态信号，不再当风格选择。

    private var categoryBadge: some View {
        Image(systemName: SceneCategory.from(category.sceneCategory).iconName)
            .font(.system(size: AppTheme.Size.categoryIconGlyph))
            .foregroundStyle(isHot ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
            .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)
            .scaleEffect(milestoneScale)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        let progress = min(CGFloat(displayedCount) / CGFloat(targetCount), 1.0)
        // hot（细线≤24pt 例外）走满饱和 brandStrong；非 hot 改用中性 progressFill。
        // 注意 hot 不等于达标——已解锁、达标、或被调用方标为「最接近解锁」都算
        // （见 isHot 文档）。中性色表达的是「这一行现在不需要你注意」，
        // 把橙留给真正要引导视线的少数几行，橙才还有对比度。
        return Capsule()
            .fill(AppTheme.Color.progressTrack)
            .frame(height: AppTheme.Size.progressBarHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(isHot ? AppTheme.Color.brandStrong : AppTheme.Color.progressFill)
                    .scaleEffect(x: displayedCount > 0 ? max(progress, 0.02) : 0, anchor: .leading)
                    .animation(
                        isPresentingMilestone ? nil : AppTheme.Motion.categoryProgressUpdate,
                        value: category.wordCount
                    )
            }
    }

    // MARK: - Expanded word list

    @ViewBuilder
    private var wordList: some View {
        if isLoadingWords {
            HStack(spacing: AppTheme.Space.paddingS) {
                Spacer()
                ProgressView()
                    .scaleEffect(0.85)
                Text("Loading words...")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Spacer()
            }
            .padding(.vertical, AppTheme.Size.wordListLoadingVPad)
        } else if words.isEmpty {
            Text("No words in this topic yet.")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppTheme.Space.paddingM)
        } else {
            VStack(spacing: AppTheme.Space.paddingS) {
                ForEach(words) { entry in
                    WordEntryRow(entry: entry)
                }
            }
            .padding(.vertical, AppTheme.Space.paddingXS)
            // 子项只做一个轻微台阶缩进，和分类头拉出层级但不推太远
            .padding(.leading, AppTheme.Space.paddingCard)
        }
    }

    // MARK: - Async fetch

    private func fetchWords() {
        guard !isLoadingWords, words.isEmpty else { return }
        isLoadingWords = true
        Task {
            let list = await loadWords()
            words = list
            isLoadingWords = false
        }
    }
}

// MARK: - Pops pill (半轻灰胶囊：pops 计数 + 展开箭头合并成一个整体单元)

private struct PopsPill: View {
    let count: Int
    /// 最接近解锁 / 已达标的 hot 行 —— 计数走品牌橙，其余暖灰 muted，控制橙的用量。
    let isHot: Bool
    let isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppTheme.Size.pillHSpacing) {
            // 数字承担「里程碑」：只在 hot 时转 brandInk（橙文字合规出口 5.09:1），其余暖灰 muted。
            Text(PopsLabel.format(count))
                .font(AppTheme.Font.popsCount)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .foregroundStyle(isHot ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)

            // 展开三角（arrowtriangle.down.fill）：随展开旋转 180°
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: AppTheme.Size.expandArrow))
                .foregroundStyle(AppTheme.Color.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, AppTheme.Size.pillHPad)
        .padding(.vertical, AppTheme.Size.pillVPad)
        .background(AppTheme.Color.pillNeutralBg, in: Capsule())
    }
}

// MARK: - Expanded single-word row (方案一：左右分布 + 右侧微灰胶囊衬底，仅 2 个字段)

private struct WordEntryRow: View {
    let entry: Tab2WordEntry

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            leftSlot

            // 词 + 释义纵向排：释义移到词下方，长词不再把释义挤成右侧空药丸
            VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                Text(entry.displayForm ?? entry.lemma)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)
                if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.system(.caption))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        // 扁平行：去掉每行的白卡与阴影，避免"白卡套白卡"的层叠感
        .padding(.vertical, AppTheme.Space.paddingS)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 统一暖中性单色图标徽章（不再用蓝/黄/绿多色，与暖色系冲突）；类型仍靠图标形状区分
    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = entry.imageUrl, !urlStr.isEmpty {
            let stableKey = entry.stableImageKey ?? urlStr
            CachedRemoteImage(signedUrl: urlStr, stableKey: stableKey) {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Color.imagePlaceholderBg)
            }
            .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            .saturation(0.75)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Color.imageWarmOverlay)
            )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Color.iconTileBg)
                    .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
                badgeGlyphView
            }
            .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
        }
    }

    // 类型图标：描边 SF Symbol，或衬线字母（句中单词）。均走暖灰 muted、退后作弱提示。
    @ViewBuilder
    private var badgeGlyphView: some View {
        switch entry.badgeGlyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: AppTheme.Size.entryBadgeGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
        case .serifLetter(let letter):
            Text(letter)
                .font(AppTheme.Font.iconBadgeLetter)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }
}

// MARK: - String truncation

private extension String {
    /// 单行截断：约 30 个拉丁字符，优先在标点处断，尾部加 …。
    func displayTruncated(limit: Int = 30) -> String {
        guard count > limit else { return self }
        let cut = prefix(limit)
        let punctuation: Set<Character> = ["，", "。", "！", "？", ",", ";", "!", "?", ".", " "]
        if let last = cut.lastIndex(where: { punctuation.contains($0) }) {
            return String(cut[...last]) + "…"
        }
        let idx = index(startIndex, offsetBy: limit)
        return String(self[..<idx]) + "…"
    }
}
