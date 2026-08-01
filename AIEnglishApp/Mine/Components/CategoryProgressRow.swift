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

    /// 根据分类场景自动映射 SF Symbol 图标
    private var categoryIcon: String {
        let key = category.sceneCategory.lowercased()
        if key.contains("tech") || key.contains("数码") || key.contains("科技") { return "laptopcomputer" }
        if key.contains("leisure") || key.contains("休闲") || key.contains("娱乐") { return "film" }
        if key.contains("social") || key.contains("社交") { return "person.2.fill" }
        if key.contains("routine") || key.contains("日常") { return "sun.max.fill" }
        if key.contains("food") || key.contains("餐饮") || key.contains("食") { return "fork.knife" }
        if key.contains("travel") || key.contains("旅游") || key.contains("出行") { return "airplane" }
        if key.contains("work") || key.contains("工作") || key.contains("职场") { return "briefcase.fill" }
        if key.contains("health") || key.contains("健康") { return "heart.fill" }
        if key.contains("study") || key.contains("学习") { return "book.fill" }
        return "tag.fill"
    }

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
                // 第一行：分类图标 + 分类标题 + 动态计数 + 折叠箭头
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isHighlighted || category.wordCount >= targetCount ? AppTheme.Color.brandStrong : AppTheme.Color.brandStrong.opacity(0.75))
                        .frame(width: 20, alignment: .center)

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
                    .frame(width: max(geo.size.width * progress, 4), height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Expanded word list

    @ViewBuilder
    private var wordList: some View {
        if isLoadingWords {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, AppTheme.Space.paddingM)
                Spacer()
            }
        } else if words.isEmpty {
            Text("No words in this topic yet.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.vertical, AppTheme.Space.paddingS)
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                ForEach(words) { word in
                    WordRow(entry: word)
                }
            }
            .padding(.vertical, AppTheme.Space.paddingS)
        }
    }

    private func fetchWords() {
        isLoadingWords = true
        Task {
            let result = await loadWords()
            await MainActor.run {
                self.words = result
                self.isLoadingWords = false
            }
        }
    }
}

// MARK: - Single word item

private struct WordRow: View {
    let entry: Tab2WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.displayForm ?? entry.lemma)
                    .font(AppTheme.Font.keyPhrase)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                if let pos = entry.pos, !pos.isEmpty {
                    Text(pos)
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }

                Spacer()
            }

            if let exp = entry.nativeMeaning, !exp.isEmpty {
                Text(exp)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            if let ex = entry.sampleSentence, !ex.isEmpty {
                Text(ex)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
