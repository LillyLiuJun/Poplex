import SwiftUI

enum CategoryWordsLoadFailure: Error, Equatable {
    case offline
    case unavailable

    /// 手风琴展开失败态的用户文案：区分断网与服务不可用两种成因。
    /// 无底框重试按钮的新视觉自带 "Try again"，因此文案本身不再带重试提示。
    var displayMessage: String {
        switch self {
        case .offline: "Check your connection and try again."
        case .unavailable: "Couldn't load these words. Try again."
        }
    }

    static func classify(error: Error, isConnected: Bool) -> Self {
        if let failure = error as? Self { return failure }
        if let urlError = error as? URLError,
           [
               .notConnectedToInternet,
               .networkConnectionLost,
               .dataNotAllowed,
               .internationalRoamingOff
           ].contains(urlError.code) {
            return .offline
        }
        return isConnected ? .unavailable : .offline
    }
}

/// 单行手风琴的请求所有者。任务、结果和刷新版本集中在一起，确保旧请求不能更新新状态。
@Observable
@MainActor
final class CategoryWordsLoader {
    private(set) var words: [Tab2WordEntry] = []
    private(set) var isLoading = false
    private(set) var failure: CategoryWordsLoadFailure?

    private var revision: Int?
    private var activeRequestID: UUID?
    private var task: Task<Void, Never>?

    func synchronize(
        isExpanded: Bool,
        revision newRevision: Int,
        loadWords: @escaping () async throws -> [Tab2WordEntry]
    ) {
        if revision != newRevision {
            cancelActiveRequest()
            revision = newRevision
            words = []
            failure = nil
        }

        guard isExpanded else {
            cancelActiveRequest()
            return
        }
        guard words.isEmpty, !isLoading else { return }
        start(loadWords: loadWords)
    }

    func retry(loadWords: @escaping () async throws -> [Tab2WordEntry]) {
        guard !isLoading else { return }
        words = []
        start(loadWords: loadWords)
    }

    func cancel() {
        cancelActiveRequest()
    }

    private func start(loadWords: @escaping () async throws -> [Tab2WordEntry]) {
        cancelActiveRequest()
        failure = nil
        isLoading = true

        let requestID = UUID()
        activeRequestID = requestID
        task = Task { [weak self] in
            do {
                let list = try await loadWords()
                try Task.checkCancellation()
                guard !list.isEmpty else {
                    throw CategoryWordsLoadFailure.unavailable
                }
                guard let self, self.activeRequestID == requestID else { return }
                withAnimation(AppTheme.Motion.categoryWordsReveal) {
                    self.words = list
                    self.isLoading = false
                    self.activeRequestID = nil
                    self.task = nil
                }
            } catch is CancellationError {
                // 正常生命周期取消：只收尾，不产生离线/失败 UI。
                guard let self, self.activeRequestID == requestID else { return }
                self.isLoading = false
                self.activeRequestID = nil
                self.task = nil
            } catch {
                guard let self, self.activeRequestID == requestID else { return }
                withAnimation(AppTheme.Motion.categoryWordsFailure) {
                    self.failure = CategoryWordsLoadFailure.classify(
                        error: error,
                        isConnected: NetworkMonitor.shared.isConnected
                    )
                    self.isLoading = false
                    self.activeRequestID = nil
                    self.task = nil
                }
            }
        }
    }

    private func cancelActiveRequest() {
        task?.cancel()
        task = nil
        activeRequestID = nil
        isLoading = false
    }
}

/// 分类进度行 — 待解锁态 AREAS 区与已解锁态 Still filling up 区共用。
/// 刀 6 起**恒中性**：进度条、类别名、词数胶囊全部走中性 token——暖橙只表示
/// 「今天有新东西」，只出现在 Hero 理由胶囊上（§一）。原「最接近解锁转橙」的
/// isHot / isHighlighted 机制整体删除；里程碑演出保留（数字滚动、scale 强调、
/// 进度更新动画——这些不涉及颜色）。
/// 展开状态由父视图统一持有（单开手风琴）：`isExpanded` 传入、点击回调 `onToggle`。
/// 展开时按需调用 loadWords 拉取全量词条。
struct CategoryProgressRow: View {
    let category: Tab2CategoryData
    let isExpanded: Bool
    let onToggle: () -> Void
    let loadWords: () async throws -> [Tab2WordEntry]
    let wordsRevision: Int
    var milestonePresentations: [CategoryMilestonePresentation] = []

    @State private var wordsLoader = CategoryWordsLoader()
    @State private var milestoneRevealed = false
    @State private var milestoneEmphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let targetCount = 20

    // 里程碑演出只动数字与 scale（不转色——刀 6 全中性）。
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            expandToggle
            if isExpanded {
                wordList
                    .padding(.top, AppTheme.Size.categoryProgressToWords)
                    .padding(.bottom, AppTheme.Space.listRowVertical)
                    .drawingGroup()
                    .clipped()
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .onChange(of: loadContext, initial: true) { _, context in
            wordsLoader.synchronize(
                isExpanded: context.isExpanded,
                revision: context.revision,
                loadWords: loadWords
            )
        }
        .onDisappear { wordsLoader.cancel() }
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onToggle()   // 展开/收起 + 滚动锚定由父视图统一处理（单开手风琴）
        } label: {
            // 🌟 双列水平咬合架构：Icon 自然下移至整行垂直居中，消灭左下角悬空凹槽
            HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
                categoryBadge

                VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                    // 首行：类别标题 + 幽灵半透胶囊（词数 + 展开箭头合并单元）
                    HStack(alignment: .center) {
                        Text(category.englishLabel)
                            .font(AppTheme.Font.tab2TopicLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        WordsPill(
                            count: displayedCount,
                            isExpanded: isExpanded
                        )
                        .scaleEffect(milestoneScale)
                    }

                    // 第二行：超纤细 1.5pt 微轨（自然从文字左缘展开）
                    progressBar
                }
            }
            .padding(.top, AppTheme.Space.listRowVertical)
            .padding(.bottom, isExpanded ? 0 : AppTheme.Space.listRowVertical)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category badge（描边字形 · 14pt regular · 20×20 纯线条垂直居中，方案 3-B 细线轻挺）

    private var categoryBadge: some View {
        Image(systemName: SceneCategory.from(category.sceneCategory).iconName)
            .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)
            .scaleEffect(milestoneScale)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        let progress = min(CGFloat(displayedCount) / CGFloat(targetCount), 1.0)
        // 刀 6 起恒中性 progressFill（#CFC7BC）——「这一行不需要你注意」，
        // 暖橙只留给 Hero 理由胶囊（§一）。进度条已完整表达解锁进度，
        // 不再叠加文字门槛（v11 去掉 "7 / 20"）。
        return Capsule()
            .fill(AppTheme.Color.progressTrack.opacity(0.8))
            .frame(height: AppTheme.Size.progressBarHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.progressFill)
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
        if wordsLoader.isLoading {
            ShimmerWordSkeletonList()
                .transition(.opacity)
        } else if let loadFailure = wordsLoader.failure {
            // haptic 已下沉到 Tab2AccordionNetworkErrorView 组件内部（可复用单元自带触感反馈）
            CategoryWordsFailureView(failure: loadFailure) {
                wordsLoader.retry(loadWords: loadWords)
            }
                .transition(.opacity)
        } else {
            VStack(spacing: AppTheme.Size.categoryWordListSpacing) {
                ForEach(wordsLoader.words) { entry in
                    WordEntryRow(entry: entry)
                }
            }
            // 子项只做一个轻微台阶缩进，和分类头拉出层级但不推太远
            .padding(.leading, AppTheme.Space.paddingCard)
            .transition(.opacity.combined(with: .offset(y: 4)))
        }
    }

    private var loadContext: CategoryWordsLoadContext {
        CategoryWordsLoadContext(isExpanded: isExpanded, revision: wordsRevision)
    }
}

private struct CategoryWordsLoadContext: Equatable {
    let isExpanded: Bool
    let revision: Int
}

private struct CategoryWordsFailureView: View {
    let failure: CategoryWordsLoadFailure
    let onRetry: () -> Void

    var body: some View {
        Tab2AccordionNetworkErrorView(
            message: failure.displayMessage,
            onRetry: onRetry
        )
    }
}

private struct CategoryAccordionPreview: View {
    @State private var isExpanded = false

    private let category = Tab2CategoryData(
        sceneCategory: "工作与学业",
        wordCount: 12,
        unlocked: false
    )

    private let words = [
        Tab2WordEntry(
            lemma: "deadline",
            entryKind: "word",
            granularity: "word",
            nativeMeaning: "截止时间"
        ),
        Tab2WordEntry(
            lemma: "catch up",
            entryKind: "phrase",
            granularity: "sentence",
            sampleSentence: "I need to catch up on my work.",
            nativeMeaning: "赶上进度"
        ),
        Tab2WordEntry(
            lemma: "wrap up",
            entryKind: "phrase",
            granularity: "sentence",
            sampleSentence: "Let’s wrap up for today.",
            nativeMeaning: "收尾"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            CategoryProgressRow(
                category: category,
                isExpanded: isExpanded,
                onToggle: {
                    withAnimation(AppTheme.Motion.accordionToggle) {
                        isExpanded.toggle()
                    }
                },
                loadWords: { words },
                wordsRevision: 0
            )
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        .surfaceCard()
        .padding(AppTheme.Space.paddingPage)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview("Topics Accordion · Interactive") {
    CategoryAccordionPreview()
}

// MARK: - Words pill (半轻灰胶囊：词数 + 展开箭头合并成一个整体单元)

private struct WordsPill: View {
    let count: Int
    let isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppTheme.Size.pillHSpacing) {
            // 刀 6 §六：pops → words 文案（"7 pops" → "7 words"），恒 textSecondary。
            // 不写解锁门槛（不要 "7 / 20"）——进度条已在表达它。
            Text(Tab2CardLabels.words(count))
                .font(AppTheme.Font.tab2ProgressCount)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .foregroundStyle(AppTheme.Color.textSecondary)

            // 展开三角（arrowtriangle.down.fill）：随展开旋转 180°
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: AppTheme.Size.expandArrow))
                .foregroundStyle(AppTheme.Color.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, AppTheme.Size.pillHPad)
        .padding(.vertical, AppTheme.Size.pillVPad)
        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
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
                    .font(AppTheme.Font.tab2WordEntryTitle)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)
                if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(AppTheme.Font.tab2WordEntryMeaning)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        // 扁平行：间距由父容器 categoryWordListSpacing (16pt) 统一定义，消除多层累加
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 统一暖中性单色图标徽章（不再用蓝/黄/绿多色，与暖色系冲突）；类型仍靠图标形状区分
    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = entry.imageUrl, !urlStr.isEmpty {
            if let localImg = UIImage(named: urlStr) {
                Image(uiImage: localImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                    .saturation(0.75)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                            .fill(AppTheme.Color.imageWarmOverlay)
                    )
            } else {
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
            }
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

    // 类型图标：描边 SF Symbol、垂直引用树线（习语/俚语）、开口链环（短语/搭配/句型）。均走暖灰 muted、退后作弱提示。
    @ViewBuilder
    private var badgeGlyphView: some View {
        switch entry.badgeGlyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: AppTheme.Size.entryBadgeGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
        case .quoteBlock:
            quoteBlockGlyphView
        case .linkChain:
            Tab2LinkChainGlyphView()
        }
    }

    /// 垂直引用树线 + 文本行 (Markdown Quote Block) · 专用于习语/俚语
    private var quoteBlockGlyphView: some View {
        HStack(alignment: .center, spacing: 3.5) {
            Capsule(style: .continuous)
                .fill(AppTheme.Color.textMuted)
                .frame(width: 1.8, height: 13)

            VStack(alignment: .leading, spacing: 3.2) {
                Capsule(style: .continuous)
                    .fill(AppTheme.Color.textMuted)
                    .frame(width: 8.5, height: 1.8)

                Capsule(style: .continuous)
                    .fill(AppTheme.Color.textMuted)
                    .frame(width: 5.5, height: 1.8)
            }
        }
        .frame(width: AppTheme.Size.entryBadgeGlyph, height: AppTheme.Size.entryBadgeGlyph)
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

// MARK: - 晨曦微光胶囊条骨架屏 (Shimmer Word Skeleton List)
// 极柔和、悠扬舒缓的暖杏晨光拂掠，与 Warm Editorial 暖纸风格浑然一体

private struct ShimmerWordSkeletonList: View {
    @State private var shimmerPhase: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 3 行长短错落的骨架条，精确对应真实英语单词与中文释义的排版节奏
    private let barConfigs: [(wordWidth: CGFloat, meaningWidth: CGFloat)] = [
        (105, 145),
        (80, 115),
        (125, 155)
    ]

    var body: some View {
        VStack(spacing: AppTheme.Size.categoryWordListSpacing) {
            ForEach(0..<barConfigs.count, id: \.self) { index in
                skeletonRow(
                    wordWidth: barConfigs[index].wordWidth,
                    meaningWidth: barConfigs[index].meaningWidth
                )
            }
        }
        .padding(.leading, AppTheme.Space.paddingCard)
        .onAppear {
            if !reduceMotion {
                withAnimation(AppTheme.Motion.shimmerSkeletonCycle) {
                    shimmerPhase = 1.4
                }
            }
        }
    }

    private func skeletonRow(wordWidth: CGFloat, meaningWidth: CGFloat) -> some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            // 左侧缩略图/图标占位方块（与真实 leftSlot 1:1 像素级协同）
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .fill(AppTheme.Color.pillNeutralBg)
                .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
                .overlay {
                    shimmerOverlay
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            // 右侧单词与释义双层胶囊条
            VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing + 2) {
                // 主单词胶囊条（高度 12pt，圆角 3pt）
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.Color.pillNeutralBg)
                    .frame(width: wordWidth, height: 12)
                    .overlay { shimmerOverlay }
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                // 中文释义胶囊条（高度 8pt，圆角 2pt）
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.Color.pillNeutralBg)
                    .frame(width: meaningWidth, height: 8)
                    .overlay { shimmerOverlay }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 品牌色温润恰当微光层：恰到好处的暖杏晨曦微光（0.24~0.48），配合 4.5pt 柔焦羽化，清晰明朗又温润自然
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: AppTheme.Color.brandWash.opacity(0.24), location: 0.28),
                    .init(color: AppTheme.Color.brandWashLight.opacity(0.48), location: 0.50),
                    .init(color: AppTheme.Color.brandWash.opacity(0.24), location: 0.72),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blur(radius: 4.5)
            .frame(width: w * 1.5)
            .offset(x: (shimmerPhase - 0.5) * w * 2.0)
        }
    }
}
