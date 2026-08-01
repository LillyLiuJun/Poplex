import SwiftUI

/// Tab2 首页 Hero 卡片——今日主推已解锁场景卡（高权重：用户真实引文 + 全宽主 CTA + 淡光感衬底）
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
        VStack(alignment: .leading, spacing: 16) {
            // ① 统一标头：分类名（大写粗体） + 词数（右侧灰字）
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

            // ② 首次解锁专属句（只出现一次）
            if isFirstUnlock {
                Text("You've got enough here to talk about it now.")
                    .font(AppTheme.Font.keyPhrase)
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }

            // ③ 引文行（故事性内容）
            quoteSection

            // ④ 全宽主 CTA 按钮
            ctaButton
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.Color.brandSubtleBg.opacity(0.4), AppTheme.Color.cardBg],
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

    /// 引文行区域：有有效引文 → 逐行展示；否则 → 预览词降级
    @ViewBuilder
    private var quoteSection: some View {
        let scenes = displayScenes
        if scenes.isEmpty {
            let words = category.previewWords.prefix(5)
            if !words.isEmpty {
                Text(words.joined(separator: "  ·  "))
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(scenes) { scene in
                    QuoteRow(scene: scene)
                }
            }
            let more = goodScenes.count - scenes.count
            if more > 0 {
                Text("+\(more) more moments")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Primary Hero CTA Button

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

// MARK: - Quote row (无边框轻量对话引文)

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
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quoteText: String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }
}
