import SwiftUI

/// Tab2 首页 hero 卡——展示已解锁分类的用户原话引文，拥有专属柔和暖光流彩背景与精致微描边，突出 Hero 推荐权重。
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
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                
                Spacer()
                
                Text("\(category.wordCount) words")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Spacer(minLength: 12)

            // ② 引文行 + "+N more moments"
            quoteSection

            Spacer(minLength: 14)

            // ③ 探底对齐的主 CTA 按钮
            ctaButton
        }
        .padding(22)
        .frame(width: 335, height: 295, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Color.brandSubtleBg.opacity(0.65),
                    AppTheme.Color.cardBg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .strokeBorder(AppTheme.Color.brandStrong.opacity(0.12), lineWidth: 1)
        )
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.08),
            radius: 16,
            x: 0,
            y: 6
        )
    }

    /// 引文行区域：展示前 3 条精选原话，多于 3 条时自动附带 "+N more moments"
    @ViewBuilder
    private var quoteSection: some View {
        let scenes = displayScenes
        if scenes.isEmpty {
            let words = category.previewWords.prefix(5)
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

                let remaining = goodScenes.count - scenes.count
                if remaining > 0 {
                    Text("+\(remaining) more moments")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.top, 2)
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
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.Color.brandStrong)
        .clipShape(Capsule())
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.3),
            radius: 10,
            x: 0,
            y: 4
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
        Array(goodScenes.prefix(3))
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
        HStack(alignment: .top, spacing: 8) {
            Text("“")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(AppTheme.Color.brandStrong.opacity(0.6))
                .offset(y: -2)

            Text(quoteText)
                .font(.system(size: 15, weight: .regular))
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
