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
                wordList
                    .padding(.top, AppTheme.Space.paddingXS)
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
            VStack(alignment: .leading, spacing: 10) {
                // 第一行：类别图标徽章 + 标题 + 动态计数 + 折叠箭头
                HStack(alignment: .center, spacing: AppTheme.Space.paddingM) {
                    categoryBadge

                    Text(category.englishLabel)
                        .font(.system(.callout, weight: isHighlighted || category.wordCount >= targetCount ? .semibold : .medium))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    countLabel

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.20))
                        .padding(.leading, 2)
                }

                // 第二行：通栏进度条（从徽章左缘拉满，参考 Cleo Spending 行式）
                progressBar
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category badge（方案3 · 图标去色：暖灰单色、无底圈）

    private var categoryBadge: some View {
        Image(systemName: SceneCategory.from(category.sceneCategory).iconName)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.32))
            .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)
    }

    // MARK: - Count Label（只留裸数字，去 "of 20"）

    @ViewBuilder
    private var countLabel: some View {
        let isHot = category.wordCount >= targetCount || isHighlighted
        Text("\(category.wordCount)")
            .font(.system(.caption))
            .monospacedDigit()
            .frame(minWidth: 18, alignment: .trailing)
            .foregroundStyle(isHot ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        let progress = min(CGFloat(category.wordCount) / CGFloat(targetCount), 1.0)
        // 不用 GeometryReader：满宽 Capsule 作轨道，填充用 scaleEffect 缩放，避免撑宽
        // 方案3：2.5px 超轻进度条，独自承担行间分隔职责
        return Capsule()
            .fill(AppTheme.Color.progressTrack)
            .frame(height: 2.5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        isHighlighted || category.wordCount >= targetCount
                            ? AppTheme.Color.brandStrong.opacity(0.5)   // 品牌橙半透明，柔和不冲
                            : AppTheme.Color.progressFill
                    )
                    .scaleEffect(x: category.wordCount > 0 ? max(progress, 0.02) : 0, anchor: .leading)
                    .animation(.easeOut(duration: 0.4), value: category.wordCount)
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
            // 子项缩进到类别名左缘（徽章宽 + 间距），和分类头拉出层级
            .padding(.leading, AppTheme.Size.categoryBadge + AppTheme.Space.paddingM)
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

// MARK: - Expanded single-word row (方案一：左右分布 + 右侧微灰胶囊衬底，仅 2 个字段)

private struct WordEntryRow: View {
    let entry: Tab2WordEntry

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            leftSlot

            // 词 + 释义纵向排：释义移到词下方，长词不再把释义挤成右侧空药丸
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayForm ?? entry.lemma)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))  // 英文词=学习内容，走衬线，与 Tab1 词卡呼应
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Color.imagePlaceholderBg)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .saturation(0.75)                                   // 降饱和，弱化图片鲜艳度
            .overlay(                                           // 叠一层暖纸薄蒙版，压低对比、融进暖色系
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Color.pageBg.opacity(0.15))
            )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Color.imagePlaceholderBg)     // 暖中性灰底
                    .frame(width: 32, height: 32)
                Image(systemName: entry.badgeIconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textMuted)   // 灰图标
            }
            .frame(width: 32, height: 32)
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
