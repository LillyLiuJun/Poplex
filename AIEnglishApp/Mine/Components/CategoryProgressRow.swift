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
            HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(category.englishLabel)
                            .font(AppTheme.Font.englishPrimary)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Spacer()
                        Text("\(category.wordCount) of \(targetCount)")
                            .font(AppTheme.Font.sectionLabel)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }

                    progressBar

                    if !isExpanded {
                        previewLine
                    }
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHighlighted ? AppTheme.Color.brandStrong : Color(.systemGray3))
                    .frame(
                        width: geo.size.width * min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0),
                        height: 4
                    )
                    .animation(.easeOut(duration: 0.4), value: category.wordCount)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Collapsed preview (3 words + +N)

    private var previewLine: some View {
        let preview = Array(category.previewWords.prefix(3))
        let rest    = max(0, category.wordCount - preview.count)
        let label   = preview.joined(separator: " · ") + (rest > 0 ? " · +\(rest)" : "")
        return Text(label)
            .font(AppTheme.Font.pos)
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
    }

    // MARK: - Expanded word list

    @ViewBuilder
    private var wordList: some View {
        if isLoadingWords {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            ForEach(words) { entry in
                WordEntryRow(entry: entry)
            }
        }
    }

    // MARK: - Async fetch

    private func fetchWords() {
        guard !isLoadingWords, words.isEmpty else { return }
        isLoadingWords = true
        Task {
            words = await loadWords()
            isLoadingWords = false
        }
    }
}

// MARK: - Expanded single-word row

private struct WordEntryRow: View {
    let entry: Tab2WordEntry

    var body: some View {
        HStack(spacing: 10) {
            leftSlot
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayForm ?? entry.lemma)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    if let abbr = entry.kindAbbrev {
                        Text(abbr)
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }
                rightLabel
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = entry.imageUrl, !urlStr.isEmpty {
            CachedRemoteImage(signedUrl: urlStr, stableKey: urlStr) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Color.imagePlaceholderBg)
                    .frame(width: 46, height: 34)
            }
            .frame(width: 46, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: entry.sourceIconName)
                .imageScale(.medium)
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 46, height: 34)
        }
    }

    @ViewBuilder
    private var rightLabel: some View {
        if entry.sourceTag == .word {
            Text("looked up")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        } else if let sample = entry.displaySample {
            Text(sample.displayTruncated())
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(1)
        }
    }
}

// MARK: - Model helpers

private extension Tab2WordEntry {
    var sourceIconName: String {
        switch sourceTag {
        case .word:     return "magnifyingglass"
        case .sentence: return "text.bubble"
        case .passage:  return "doc.text"
        case .dialogue: return "waveform"
        }
    }

    var kindAbbrev: String? {
        if let k = entryKind, !k.isEmpty { return k }
        if let p = pos, !p.isEmpty { return p }
        return nil
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
