import SwiftUI

/// 分类进度行 — 待解锁态 AREAS 区与已解锁态 Still filling up 区共用。
/// isHighlighted=true 时进度条用品牌橙（最接近达标的分类）；否则中性灰。
/// 展开时按需调用 loadWords 拉取全量词条。
struct CategoryProgressRow: View {
    let category: Tab2CategoryData
    let isHighlighted: Bool
    let loadWords: () async -> [Tab2WordEntry]

    @State private var isExpanded = false
    @State private var words: [Tab2WordEntry] = []
    @State private var isLoadingWords = false

    private let targetCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            expandToggle
            if isExpanded {
                Divider()
                    .padding(.vertical, AppTheme.Space.paddingS)
                wordList
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .onChange(of: category.wordCount) { _, _ in
            // word count changed while expanded → invalidate cache and refetch
            if isExpanded {
                words = []
                fetchWords()
            }
        }
    }

    // MARK: - Collapsed header button

    private var expandToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            if isExpanded && words.isEmpty { fetchWords() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 第一行：分类标题 + 动态计数 + 折叠箭头
                HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                    Text(category.englishLabel)
                        .font(.system(size: 15, weight: isHighlighted || category.wordCount >= targetCount ? .semibold : .medium))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    countLabel

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.leading, 2)
                }

                // 第二行：平滑高质感的 Capsule 进度条
                progressBar
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Count Label

    @ViewBuilder
    private var countLabel: some View {
        let isReached = category.wordCount >= targetCount
        HStack(spacing: 2) {
            Text("\(category.wordCount)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isReached || isHighlighted ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)
            Text("/ \(targetCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isReached || isHighlighted ? AppTheme.Color.brandStrong.opacity(0.1) : Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.brandStrong.opacity(0.08))
                    .frame(height: 4)
                Capsule()
                    .fill(
                        isHighlighted || category.wordCount >= targetCount
                            ? AppTheme.Color.brandStrong
                            : AppTheme.Color.brandStrong.opacity(0.4)
                    )
                    .frame(
                        width: max(geo.size.width * progress, category.wordCount > 0 ? 4 : 0),
                        height: 4
                    )
                    .animation(.easeOut(duration: 0.4), value: category.wordCount)
            }
        }
        .frame(height: 4)
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
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Spacer()
            }
            .padding(.vertical, 14)
        } else if words.isEmpty {
            Text("No words in this topic yet.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 8) {
                ForEach(words) { entry in
                    WordEntryRow(entry: entry)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Async fetch

    private func fetchWords() {
        guard !isLoadingWords, words.isEmpty else { return }
        isLoadingWords = true
        Task {
            var list = await loadWords()
            // 插入测试长词组与长释义，方便在App上直接测试长度边界表现
            list.append(Tab2WordEntry(
                lemma: "kill two birds with one stone",
                displayForm: "kill two birds with one stone",
                entryKind: "idiom",
                granularity: "sentence",
                nativeMeaning: "一石二鸟，一举两得"
            ))
            list.append(Tab2WordEntry(
                lemma: "unquestionably counterproductive",
                displayForm: "unquestionably counterproductive",
                entryKind: "phrase",
                granularity: "sentence",
                nativeMeaning: "毫无疑问地产生反效果与副作用"
            ))
            words = list
            isLoadingWords = false
        }
    }
}

// MARK: - Expanded single-word row (方案一：左右分布 + 右侧微灰胶囊衬底，仅 2 个字段)

private struct WordEntryRow: View {
    let entry: Tab2WordEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leftSlot

            // 1. 目标语言词/短语 (左侧主视觉加粗)
            Text(entry.displayForm ?? entry.lemma)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.Color.textPrimary)

            Spacer(minLength: 8)

            // 2. 母语释义 (方案 A：右侧微灰胶囊衬底对齐)
            if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                Text(meaning)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = entry.imageUrl, !urlStr.isEmpty {
            let stableKey = entry.stableImageKey ?? urlStr
            CachedRemoteImage(signedUrl: urlStr, stableKey: stableKey) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Color.imagePlaceholderBg)
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(entry.badgeBg)
                    .frame(width: 36, height: 36)
                Image(systemName: entry.badgeIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.badgeIconColor)
            }
            .frame(width: 36, height: 36)
        }
    }
}

// MARK: - Badge color helpers (view-only, color values not testable in unit tests)

private extension Tab2WordEntry {
    var badgeBg: SwiftUI.Color {
        switch sourceTag {
        case .word:     return AppTheme.Color.badgeWordBg
        case .dialogue: return AppTheme.Color.badgeDialogueBg
        case .sentence, .passage:
            switch entryKind {
            case "word":                                return AppTheme.Color.badgeWordBg
            case "phrase", "collocation", "pattern":    return AppTheme.Color.badgePhraseBg
            case "idiom", "slang":                      return AppTheme.Color.badgeIdiomBg
            default:                                    return AppTheme.Color.badgePhraseBg
            }
        }
    }

    var badgeIconColor: SwiftUI.Color {
        switch sourceTag {
        case .word:     return AppTheme.Color.badgeWordIcon
        case .dialogue: return AppTheme.Color.badgeDialogueIcon
        case .sentence, .passage:
            switch entryKind {
            case "word":                                return AppTheme.Color.badgeWordIcon
            case "phrase", "collocation", "pattern":    return AppTheme.Color.badgePhraseIcon
            case "idiom", "slang":                      return AppTheme.Color.badgeIdiomIcon
            default:                                    return AppTheme.Color.badgePhraseIcon
            }
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
