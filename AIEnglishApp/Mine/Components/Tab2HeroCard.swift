import SwiftUI

/// Tab2 首页 hero 卡——展示已解锁分类的用户原话引文，尺寸与 Secondary 已解锁卡片完全固定一致（315 x 215）。
struct Tab2HeroCard: View {
    let category: Tab2CategoryData
    let isFirstUnlock: Bool
    let onTalk: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTalk()
        } label: {
            cardContent
        }
        .buttonStyle(HeroCardPressStyle())
    }

    // MARK: - Card layout

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ① 分类标头（大写分类名 + 词数）
            HStack(alignment: .center) {
                Text(category.englishLabel.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                
                Spacer()
                
                Text("\(category.wordCount) words")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Spacer(minLength: 10)

            // ② 引文行 or 降级展示
            quoteSection

            Spacer(minLength: 12)

            // ③ 探底对齐的主 CTA 按钮
            ctaButton
        }
        .padding(20)
        .frame(width: 315, height: 215, alignment: .topLeading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 14,
            x: 0,
            y: 4
        )
    }

    /// 引文行区域：最多展示 2 条精致引文，保证固定高度下绝对不溢出
    @ViewBuilder
    private var quoteSection: some View {
        let scenes = displayScenes
        if scenes.isEmpty {
            let words = category.previewWords.prefix(4)
            if !words.isEmpty {
                Text(words.joined(separator: "  ·  "))
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(scenes) { scene in
                    QuoteRow(scene: scene)
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .bold))
            Text("Start talking")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.Color.brandStrong)
        .clipShape(Capsule())
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.25),
            radius: 8,
            x: 0,
            y: 3
        )
    }

    // MARK: - Display scenes selection

    private func effectiveQuote(_ scene: Tab2SubScene) -> String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }

    private var goodScenes: [Tab2SubScene] {
        category.subScenes
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .filter { effectiveQuote($0).count >= 4 }
    }

    /// 固定卡片高度下精致展示 2 条引文
    private var displayScenes: [Tab2SubScene] {
        Array(goodScenes.prefix(2))
    }
}

// MARK: - Press style

private struct HeroCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Quote row (极简无框对话引文)

private struct QuoteRow: View {
    let scene: Tab2SubScene

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("“")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundStyle(AppTheme.Color.brandStrong.opacity(0.6))
                .offset(y: -2)

            Text(quoteText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quoteText: String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }
}
