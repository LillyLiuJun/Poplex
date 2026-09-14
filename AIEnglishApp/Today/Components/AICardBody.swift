import SwiftUI

enum PassageTimelineLayout {
    static let topEdgeFadeFlag: UInt8 = 1 << 0
    static let bottomEdgeFadeFlag: UInt8 = 1 << 1

    static func expandedViewportHeight(contentHeight: CGFloat) -> CGFloat {
        min(max(0, contentHeight), AppTheme.Size.passageExpandedViewportMaxHeight)
    }

    static func contentTrailingInset(isExpanded: Bool) -> CGFloat {
        isExpanded ? AppTheme.Size.passageScrollIndicatorGutter : 0
    }

    enum ToggleMotion: Equatable {
        case standard
        case reduced

        var animation: Animation {
            switch self {
            case .standard:
                AppTheme.Motion.accordionToggle
            case .reduced:
                AppTheme.Motion.accordionReducedToggle
            }
        }
    }

    static func toggleMotion(reduceMotion: Bool) -> ToggleMotion {
        reduceMotion ? .reduced : .standard
    }

    static func edgeVisibility(
        contentMinY: CGFloat,
        contentMaxY: CGFloat,
        viewportHeight: CGFloat
    ) -> UInt8 {
        var visibility: UInt8 = 0
        if contentMinY < -0.5 { visibility |= topEdgeFadeFlag }
        if contentMaxY > viewportHeight + 0.5 { visibility |= bottomEdgeFadeFlag }
        return visibility
    }
}

enum PassageReadingLifecycle {
    /// 空 viewport 代表外层时间线尚未完成首轮布局，此时不能误判为离开。
    static func isCompletelyOutside(cardFrame: CGRect, viewport: CGRect) -> Bool {
        guard viewport.width > 0, viewport.height > 0 else { return false }
        return cardFrame.maxY <= viewport.minY || cardFrame.minY >= viewport.maxY
    }
}

struct PassageResetSignal: Equatable {
    let tabGeneration: Int
    let visibilityGeneration: Int
}

private struct PassageScrollViewport<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var edgeVisibility: UInt8 = 0

    var body: some View {
        ScrollView(.vertical) {
            content()
                .onGeometryChange(for: UInt8.self) { proxy in
                    let frame = proxy.frame(in: .scrollView(axis: .vertical))
                    return PassageTimelineLayout.edgeVisibility(
                        contentMinY: frame.minY,
                        contentMaxY: frame.maxY,
                        viewportHeight: height
                    )
                } action: { newVisibility in
                    edgeVisibility = newVisibility
                }
        }
        .frame(height: height)
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .top) {
            PassageScrollEdgeScrim(edge: .top)
                .opacity(edgeVisibility & PassageTimelineLayout.topEdgeFadeFlag != 0 ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            PassageScrollEdgeScrim(edge: .bottom)
                .opacity(edgeVisibility & PassageTimelineLayout.bottomEdgeFadeFlag != 0 ? 1 : 0)
        }
        .animation(AppTheme.Motion.timelinePassiveFollow, value: edgeVisibility)
    }
}

private struct PassageScrollEdgeScrim: View {
    let edge: VerticalEdge

    var body: some View {
        LinearGradient(
            colors: [AppTheme.Color.cardBg, AppTheme.Color.cardBg.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: AppTheme.Size.passageScrollEdgeFadeHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 统一学习卡（Tab1 输入输出卡片设计交付 v2）
/// · word 卡：大词条 → 音标+词性同行 → 释义 → 例句区块 → 形式说明区块（仅 comprehend）
/// · sentence 卡：
///   - 修正场景（comprehend 且有修正）：原句+译文（弱化）→ Polish 润色区块（小标+修正句主角）→ 语法说明（仅 comprehend）；
///   - 无修正场景（comprehend 正确句）：原句为主表达（主角）→ 紧跟译文 → 语法说明；
///   - express/图场景：母语在前（小灰）→ 目标语在后（主角）；
/// · passage 卡：逐行双语对照 + 折叠/展开 → 说明区块（仅 comprehend）
/// · 说明区块（Note）在所有卡片类型中都排在最后
struct AICardBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: CardContent
    var onCollapse: (() -> Void)? = nil
    var passageResetSignal = PassageResetSignal(tabGeneration: 0, visibilityGeneration: 0)
    @State private var passageExpanded = false
    @State private var expandedPassageContentHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .caption2) private var expandArrowSize: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTypeChip(label: cardTypeLabel)
                .padding(.bottom, content.isWord ? AppTheme.Space.paddingM : AppTheme.Space.paddingCard)

            if content.isWord {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    wordMainBlock
                    if !content.examples.isEmpty { examplesSection }
                    if let note = content.displayableGrammarNote { noteSection(note: note) }
                }
            } else if content.isPassage {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    passageContent
                    if let note = content.displayableGrammarNote { noteSection(note: note) }
                }
            } else {
                sentenceContent
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.large, fillColor: AppTheme.Color.cardBg)
        .onChange(of: passageResetSignal) {
            guard passageExpanded else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                passageExpanded = false
            }
        }
    }

    private var cardTypeLabel: String {
        if content.isWord { return "Word" }
        if content.isPassage { return "Passage" }
        return "Sentence"
    }

    // MARK: - Word: 词条 → 音标+词性 → 释义
    private var hasPhoneticOrPos: Bool {
        (content.phonetic != nil && !content.phonetic!.isEmpty) || !content.pos.isEmpty
    }

    private var wordMainBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.displayTarget)
                .font(AppTheme.Font.wordTitle)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if hasPhoneticOrPos {
                phoneticAndPosView
                    .padding(.top, AppTheme.Space.paddingXS)

                if let meaning = content.nativeMeaning, !meaning.isEmpty {
                    meaningLabel(meaning)
                }
            } else if let meaning = content.nativeMeaning, !meaning.isEmpty {
                // 无音标／词性时，单词直接到释义留 8pt
                meaningLabel(meaning)
            }
        }
    }

    private func meaningLabel(_ meaning: String) -> some View {
        Text(meaning)
            .font(AppTheme.Font.chineseBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppTheme.Space.paddingS)
    }

    /// 音标与词性自适应布局：
    /// - 空间足够时同行、基线对齐，水平间距 8pt；
    /// - 空间不足时，词性整体移到音标下方，左对齐，垂直间距 4pt；
    /// - 不缩小字号、不截断文字以强行保持同行。
    private var phoneticAndPosView: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                phoneticLabel
                posLabel
            }
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                phoneticLabel
                posLabel
            }
        }
    }

    @ViewBuilder
    private var phoneticLabel: some View {
        if let phonetic = content.phonetic, !phonetic.isEmpty {
            Text(phonetic)
                .font(AppTheme.Font.phonetic)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    @ViewBuilder
    private var posLabel: some View {
        if !content.pos.isEmpty {
            Text(content.pos.joined(separator: " / "))
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    // 收起态最多预览的句子对数（min/max：≤ 此数则整段全展示、无按钮；> 此数只预览前 N 句 + 展开按钮）
    private let passageCollapsedLimit = 2

    // MARK: - Passage: 逐行双语对照 + 折叠/展开（无横线，16pt 留白分组）
    private var passageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if passageExpanded {
                PassageScrollViewport(height: PassageTimelineLayout.expandedViewportHeight(
                    contentHeight: expandedPassageContentHeight
                )) {
                    passageLineList(content.passageLines)
                        .padding(.trailing, PassageTimelineLayout.contentTrailingInset(isExpanded: true))
                }
            } else {
                passageLineList(Array(content.passageLines.prefix(passageCollapsedLimit)))
                    .padding(.trailing, PassageTimelineLayout.contentTrailingInset(isExpanded: false))
            }

            // 展开/收起按钮：仅当句子对数超过收起态预览上限时显示；正文到按钮 12pt
            if content.passageLines.count > passageCollapsedLimit {
                Button {
                    let willCollapse = passageExpanded
                    // onCollapse 现在直接同步调用 TodayView 里的 proxy.scrollTo（不再
                    // 经 ViewModel 状态 + onChange 中转，理由见 TodayView 里 onCollapse
                    // 闭包的注释）。放进和本地 passageExpanded 折叠同一个 withAnimation
                    // 闭包内，两处状态变化共享同一个事务/曲线，折叠和滚动同帧起播——
                    // 与 Tab2 分类手风琴（MineView.toggleExpand）的写法保持一致。
                    withAnimation(PassageTimelineLayout.toggleMotion(reduceMotion: reduceMotion).animation) {
                        passageExpanded.toggle()
                        if willCollapse {
                            onCollapse?()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(passageExpanded ? "Collapse" : "Expand")
                            .font(AppTheme.Font.pos)
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: expandArrowSize))
                            .rotationEffect(.degrees(passageExpanded ? 180 : 0))
                    }
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, AppTheme.Space.paddingM)
            }
        }
        .background(alignment: .topLeading) {
            // 仅在可展开的收起态提前量出全文高度。background 不参与外层 VStack
            // 的子项计数，因此不会凭空制造上下各一段可见间距；展开时复用已测高度，
            // 也不再重复排版一份屏外全文。
            if !passageExpanded, content.passageLines.count > passageCollapsedLimit {
                passageLineList(content.passageLines)
                    // 预量尺寸必须与展开态使用相同正文宽度，否则安全通道引起的
                    // 换行差异会在展开后再次改变视口高度。
                    .padding(.trailing, PassageTimelineLayout.contentTrailingInset(isExpanded: true))
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        expandedPassageContentHeight = newHeight
                    }
                    .hidden()
            }
        }
    }

    /// 双语分句对统一渲染：分句对之间 16pt、分句与译文 4pt（无横线）。
    /// 展开态、收起态与隐藏高度测量共用同一实现，保证三者换行与高度一致。
    private func passageLineList(_ lines: [PassageLine]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text(line.en)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(line.zh)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Sentence 容器
    /// 架构说明：内部兄弟区块（sentenceOriginalBlock、polishSection、noteSection）之间的 16pt 间距，
    /// 依赖外层 `VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard)` 对 @ViewBuilder 平铺视图的调度。
    /// 若后续重构包裹额外容器，须注意显式维持 16pt 间距。
    @ViewBuilder
    private var sentenceContent: some View {
        if content.hasMeaningfulRevision {
            // 场景 A：有修正场景（sentence + comprehend 触发了 revision）
            // 第一层：原句 + 4pt + 译文
            sentenceOriginalBlock
            // 第二层：POLISH 润色区块（小标 + 4pt + 修正句）
            polishSection
        } else {
            // 场景 B（comprehend 无修正）与 场景 C（express / 纯图）
            sentenceMainBlock
        }

        // 语法说明区块：统一放在表达与译文之后（正文优先、说明后置）
        if let note = content.displayableGrammarNote {
            noteSection(note: note)
        }
    }

    // MARK: - 原输入与译文区块（sentence + comprehend 且有修正时：用户原句到紧随译文 4pt）
    // 原句与修正句保持同字体、同字号、同深色、常规字重。原句不灰色弱化。
    private var sentenceOriginalBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            if let original = content.userOriginal, !original.isEmpty {
                Text(original)
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let meaning = content.nativeMeaning, !meaning.isEmpty {
                Text(meaning)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 润色/修正区块（sentence + comprehend 且有修正时：POLISH 小标到修正句 4pt）
    private var polishSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            CardSectionLabel("Polish")
            Text(content.displayTarget)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sentence 主内容区块（无修正的 comprehend 或 express / 纯图：双语间距统一为 4pt）
    private var sentenceMainBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            if content.isComprehend {
                // 场景 B：无修正场景（用户写得完全正确）
                // 原句深色常规字重，下方 4pt 紧跟中文译文（textMuted）
                Text(content.displayTarget)
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let meaning = content.nativeMeaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // 场景 C：express / 纯图
                // 母语输入在上（小灰字），下方 4pt 紧跟英文翻译（深色主角）
                if let native = expressNativeRow {
                    Text(native)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(content.displayTarget)
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 例句区块（word 专属：EXAMPLES 小标到首条例句 8pt，例句间 12pt，分句译文 4pt）
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            CardSectionLabel("Examples")
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                ForEach(Array(content.examples.prefix(2).enumerated()), id: \.offset) { _, ex in
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                        Text(ex.en)
                            .font(AppTheme.Font.chineseBody)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !ex.zh.isEmpty {
                            Text(ex.zh)
                                .font(AppTheme.Font.chineseFaint)
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 形式/语法说明区块（所有卡片共用：NOTE 小标到正文 4pt）
    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            CardSectionLabel("Note")
            Text(note)
                .font(AppTheme.Font.chineseBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Derived

    // express 场景下的「母语行」：有用户原文时用原文；纯图片 user_original=nil 时用 native_meaning
    private var expressNativeRow: String? {
        if let original = content.userOriginal, !original.isEmpty { return original }
        if let meaning = content.nativeMeaning, !meaning.isEmpty { return meaning }
        return nil
    }
}

// MARK: - 区块小标（例句 / 形式说明 / 语法说明）
private struct CardSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Font.sectionLabel)
            .tracking(0.6)
            .foregroundStyle(AppTheme.Color.textMuted)
    }
}

#Preview("Sentence - Revision") {
    VStack(spacing: AppTheme.Space.paddingM) {
        AICardBody(content: CardContent(
            granularity: "sentence",
            direction: "comprehend",
            revisionType: "error",
            userOriginal: "I am very sleep today",
            targetExpression: "I'm very sleepy today",
            nativeMeaning: "我今天很困",
            grammarNote: "sleepy is the adjective for that drowsy feeling; sleep is the noun/verb."
        ))
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}

#Preview("Sentence - No Revision") {
    VStack(spacing: AppTheme.Space.paddingM) {
        AICardBody(content: CardContent(
            granularity: "sentence",
            direction: "comprehend",
            userOriginal: "I'm heading out now.",
            targetExpression: "I'm heading out now.",
            nativeMeaning: "我现在出门了。"
        ))
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}

#Preview("Sentence - Express") {
    VStack(spacing: AppTheme.Space.paddingM) {
        AICardBody(content: CardContent(
            granularity: "sentence",
            direction: "express",
            userOriginal: "我打算下周请假两天",
            targetExpression: "I'm planning to take two days off next week."
        ))
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}

#Preview("Word - Full") {
    VStack(spacing: AppTheme.Space.paddingM) {
        AICardBody(content: CardContent(
            granularity: "word",
            direction: "comprehend",
            targetExpression: "procrastinate",
            nativeMeaning: "拖延；耽搁",
            phonetic: "/prəˈkræstɪneɪt/",
            pos: ["v."],
            examples: [
                BilingualExample(en: "I always procrastinate when it comes to doing taxes.", zh: "一到报税我就总是拖拖拉拉。"),
                BilingualExample(en: "Stop procrastinating and get to work.", zh: "别再拖延了，快去干活。")
            ],
            grammarNote: "Derived from Latin procrastinare, meaning 'to defer till tomorrow'."
        ))
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}

#Preview("Passage") {
    VStack(spacing: AppTheme.Space.paddingM) {
        AICardBody(content: CardContent(
            granularity: "passage",
            direction: "comprehend",
            targetExpression: "Morning light filtered through the blinds.\nA cool breeze stirred the curtain.",
            nativeMeaning: "晨光透过百叶窗洒了进来。\n一阵凉风吹拂着窗帘。",
            grammarNote: "Notice the poetic phrasing of 'filtered through' and 'stirred'.",
            passageLines: [
                PassageLine(en: "Morning light filtered through the blinds.", zh: "晨光透过百叶窗洒了进来。"),
                PassageLine(en: "A cool breeze stirred the curtain.", zh: "一阵凉风吹拂着窗帘。"),
                PassageLine(en: "The city outside was slowly waking up.", zh: "外面的城市正缓缓苏醒。")
            ]
        ))
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}

