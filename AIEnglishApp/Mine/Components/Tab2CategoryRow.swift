import SwiftUI

/// 已解锁分类卡片——尺寸与 Hero 卡片完全固定一致（315 x 215），保障横向轮播平齐对齐。
struct Tab2CategoryRow: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTalk()
        } label: {
            cardContent
        }
        .buttonStyle(CategoryCardPressStyle())
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

            // ② 用户原话引文行
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

    /// 引文行区域：读取 subScenes 中的 quote 原话引文
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

    private var displayScenes: [Tab2SubScene] {
        Array(goodScenes.prefix(2))
    }
}

// MARK: - Press style

private struct CategoryCardPressStyle: ButtonStyle {
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
