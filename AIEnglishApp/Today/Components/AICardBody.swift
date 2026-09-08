import SwiftUI

/// 统一学习卡（Tab1 输入输出卡片设计交付 v2）
/// · word 卡：大词条 → 音标+词性同行 → 释义 → 例句区块 → 形式说明区块（仅 comprehend）
/// · sentence 卡：
///   - 修正场景（comprehend 且有修正）：原句+译文（弱化）→ Polish 润色区块（小标+修正句主角）→ 语法说明（仅 comprehend）；
///   - 无修正场景（comprehend 正确句）：原句为主表达（主角）→ 紧跟译文 → 语法说明；
///   - express/图场景：母语在前（小灰）→ 目标语在后（主角）；
/// · passage 卡：逐行双语对照 + 折叠/展开 → 说明区块（仅 comprehend）
/// · 说明区块（Note）在所有卡片类型中都排在最后
struct AICardBody: View {
    let content: CardContent
    @State private var passageExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var expandArrowSize: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            CardTypeChip(label: cardTypeLabel)

            if content.isWord {
                wordMainBlock
                if !content.examples.isEmpty { examplesSection }
                if let note = content.displayableGrammarNote { noteSection(note: note) }
            } else if content.isPassage {
                passageContent
                if let note = content.displayableGrammarNote { noteSection(note: note) }
            } else {
                sentenceContent
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.large, fillColor: AppTheme.Color.cardBg)
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

    // 当前应渲染的行（收起态取前 passageCollapsedLimit 句，展开态取全部），带原始序号
    private var visiblePassageLines: [(offset: Int, element: PassageLine)] {
        let lines = content.passageLines
        let slice = passageExpanded ? lines : Array(lines.prefix(passageCollapsedLimit))
        return Array(slice.enumerated())
    }

    // MARK: - Passage: 逐行双语对照 + 折叠/展开（无横线，16pt 留白分组）
    private var passageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 双语分句对之间 16pt，分句与对应译文 4pt
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                ForEach(visiblePassageLines, id: \.offset) { _, line in
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

            // 展开/收起按钮：仅当句子对数超过收起态预览上限时显示；正文到按钮 12pt
            if content.passageLines.count > passageCollapsedLimit {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        passageExpanded.toggle()
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

