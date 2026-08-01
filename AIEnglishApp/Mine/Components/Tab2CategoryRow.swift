import SwiftUI

/// 已解锁分类的非 hero 行——分类名 + 子场景描述 + Talk 胶囊。
/// 整行 + Talk 按钮触发同一个 onTalk 动作，无详情页中转。
struct Tab2CategoryRow: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTalk()
        } label: {
            HStack(alignment: .center, spacing: AppTheme.Space.paddingCard) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.englishLabel)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    HStack(spacing: AppTheme.Space.paddingXS) {
                        Text(descriptionLine)
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Text("· \(category.wordCount) words")
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textFaint)
                            .fixedSize()
                    }
                }

                Spacer(minLength: 0)

                talkCapsule
            }
            .padding(.vertical, 14)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Talk capsule

    private var talkCapsule: some View {
        HStack(spacing: 4) {
            Image(systemName: "mic.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Talk")
                .font(AppTheme.Font.sectionLabel)
        }
        .foregroundStyle(AppTheme.Color.brandStrong)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(AppTheme.Color.brandStrong.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Description line

    /// 子场景前 2 名 + "+N more"。
    /// 降级：子场景为空 → 词本身前 2 个 lemma。
    private var descriptionLine: String {
        if !category.subScenes.isEmpty {
            let sorted = category.subScenes.sorted { $0.occurrenceCount > $1.occurrenceCount }
            let top2   = sorted.prefix(2).map(\.sceneDetail)
            let rest   = max(0, sorted.count - top2.count)
            return top2.joined(separator: ", ") + (rest > 0 ? ", +\(rest) more" : "")
        }
        // 降级到 previewWords
        let words = category.previewWords.prefix(2)
        let rest  = max(0, category.wordCount - words.count)
        return words.joined(separator: ", ") + (rest > 0 ? ", +\(rest) more" : "")
    }
}
