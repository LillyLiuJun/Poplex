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
            VStack(alignment: .leading, spacing: 14) {
                // 第一行：分类大标题 + 词量
                HStack(alignment: .center) {
                    Text(category.englishLabel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    Text("\(category.wordCount) words")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                // 第二行：子场景标签
                HStack(alignment: .center, spacing: 6) {
                    ForEach(subSceneTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // 第三行：右对齐高权重 Talk 按钮
                HStack {
                    Spacer()
                    talkCapsule
                }
            }
            .padding(20)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 14,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Talk capsule

    private var talkCapsule: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .bold))
            Text("Start talking")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(AppTheme.Color.brandStrong)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.Color.brandStrong.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Description tags

    /// 子场景前 2 名 + "+N more" 离散微标签列表。
    private var subSceneTags: [String] {
        if !category.subScenes.isEmpty {
            let sorted = category.subScenes.sorted { $0.occurrenceCount > $1.occurrenceCount }
            var tags = Array(sorted.prefix(2).map(\.sceneDetail))
            let rest = sorted.count - tags.count
            if rest > 0 { tags.append("+\(rest) more") }
            return tags
        }
        var tags = Array(category.previewWords.prefix(2))
        let rest = category.wordCount - tags.count
        if rest > 0 { tags.append("+\(rest) more") }
        return tags
    }
}
