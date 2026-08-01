import SwiftUI

/// Tab2 首页 Secondary 已解锁分类卡片——展示已解锁场景，与 Hero 卡片共享【统一标头】，通过【微标签 + 次级 CTA】拉开权重区分。
struct Tab2CategoryRow: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTalk()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // ① 统一标头：分类名（大写粗体，与 Hero 卡完全一致） + 词数（右侧灰字）
                HStack(alignment: .center) {
                    Text(category.englishLabel.uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    Text("\(category.wordCount) words")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                // ② 第二行：子场景离散微标签（轻量预览，区别于 Hero 卡的详细引文）
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

                // ③ 第三行：次级 CTA 按钮（右对齐淡彩胶囊，区别于 Hero 卡的全宽实心按钮）
                HStack {
                    Spacer()
                    talkCapsule
                }
            }
            .padding(20)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary Talk capsule

    private var talkCapsule: some View {
        HStack(spacing: 5) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .bold))
            Text("Start talking")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(AppTheme.Color.brandStrong)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.Color.brandSubtleBg)
        .clipShape(Capsule())
    }

    // MARK: - Description tags

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
