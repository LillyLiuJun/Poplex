import SwiftUI

/// 统一学习卡（Tab1 输入输出卡片设计交付 v2）
/// · word 卡：大词条 → 音标+词性同行 → 释义 → 例句区块 → 形式说明区块（仅 comprehend）
/// · sentence 卡：双行（comprehend: 目标语在前；express/图: 母语在前）；
///   revision 场景：原句弱化 → 译文（先看懂原意）→ 标签 → 修正/润色句（仅此一句，后不跟译文）；
///   语法说明区块仅 comprehend
/// · passage 卡：逐行双语对照 + 折叠/展开 → 说明区块（仅 comprehend）
/// · 说明区块（Note）在所有卡片类型中都排在最后
struct AICardBody: View {
    let content: CardContent
    @State private var passageExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            CardTypeChip(label: cardTypeLabel)

            if content.isWord {
                wordMainBlock
                if !content.examples.isEmpty { examplesSection }
                if let note = content.displayableGrammarNote { noteSection(note: note) }
            } else if content.isPassage {
                passageContent
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

    // MARK: - Word: 词条 → 音标+词性同行 → 释义
    private var wordMainBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text(content.displayTarget)
                .font(AppTheme.Font.wordTitle)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if content.phonetic != nil || !content.pos.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                    if let phonetic = content.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(AppTheme.Font.phonetic)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                    if !content.pos.isEmpty {
                        Text(content.pos.joined(separator: " / "))
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }
            }

            if let meaning = content.nativeMeaning, !meaning.isEmpty {
                Text(meaning)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    // MARK: - Passage: 逐行双语对照 + 折叠/展开
    private var passageContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            // 收起态预览前 N 句、展开态全量——两态都用完整双语对照，不再截断单句
            ForEach(visiblePassageLines, id: \.offset) { index, line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.en)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(line.zh)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if index < visiblePassageLines.count - 1 {
                    Divider()
                        .overlay(AppTheme.Color.textMuted.opacity(0.15))
                }
            }

            // 展开/收起按钮：仅当句子对数超过收起态预览上限时显示
            if content.passageLines.count > passageCollapsedLimit {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        passageExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(passageExpanded ? "Collapse" : "Expand full text")
                            .font(AppTheme.Font.pos)
                        Image(systemName: passageExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.Color.textMuted)
                }
                .buttonStyle(.plain)
            }

            // grammar_note（如有；仅 comprehend——express 的提示词不生成）
            if let note = content.displayableGrammarNote {
                noteSection(note: note)
            }
        }
    }
    private var sentenceContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            sentenceMainBlock
            // 语法说明区块：仅 comprehend（express 不生成 grammar_note），
            // 统一放在表达与译文之后（正文优先、说明后置，与 word 卡一致）
            if let note = content.displayableGrammarNote {
                noteSection(note: note)
            }
        }
    }

    // MARK: - Sentence: 原句 → 译文 →（revision 时）标签 → 修正句（原文↔译文顺序由方向决定）
    private var sentenceMainBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            if content.isComprehend {
                let label = revisionLabel
                if let label {
                    // revision 场景：原句弱化在前、译文紧跟（先看懂原意），
                    // 标签 + 修正句在后——修正句仅此一句，后面不再跟译文
                    if let original = content.userOriginal, !original.isEmpty {
                        Text(original)
                            .font(AppTheme.Font.englishPrimary)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let meaning = content.nativeMeaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(AppTheme.Font.chineseBody)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(label)
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
                // 主表达：无修正时是原句本身、有修正时是修正句（近黑主内容）
                Text(content.displayTarget)
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                // 译文：无修正时跟在主表达后；revision 场景已提前到原句之下，不重复
                if label == nil, let meaning = content.nativeMeaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // express / 纯图: 母语在前（小灰）、目标语在后（近黑主内容）
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

    // MARK: - 例句区块（word 专属）
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            CardSectionLabel("Examples")
            ForEach(Array(content.examples.prefix(2).enumerated()), id: \.offset) { _, ex in
                VStack(alignment: .leading, spacing: 3) {
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

    // MARK: - 形式/语法说明区块
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

    // sentence+comprehend 有修正时的提示文字（无「有意义的修正」时不出现，见 hasMeaningfulRevision）
    private var revisionLabel: String? {
        guard content.hasMeaningfulRevision else { return nil }
        switch content.revisionType {
        case "error":  return "A clearer way to say it"
        case "polish": return "You could also say"
        default:       return nil
        }
    }

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
