import SwiftUI

/// Tab2 首页 hero 卡——展示已解锁分类的用户原话引文，整张卡点击进入对话页。
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
            // Accent stripe — 品牌橙顶部细线，由 clipShape 负责圆角
            AppTheme.Color.brandStrong.frame(height: 3)

            VStack(alignment: .leading, spacing: 0) {
                // ① 分类名（小字全大写，品牌橙）
                Text(category.englishLabel.uppercased())
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.bottom, AppTheme.Space.paddingS)

                // ② 首次解锁专属句（只出现一次）
                if isFirstUnlock {
                    Text("You've got enough here to talk about it now.")
                        .font(AppTheme.Font.keyPhrase)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.bottom, AppTheme.Space.paddingM)
                }

                // ③ 引文行 or 降级展示
                quoteSection

                // ④ CTA
                Spacer().frame(height: AppTheme.Space.paddingCard)
                ctaButton
            }
            .padding(AppTheme.Space.paddingCard)
        }
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Shadow.cardRadius,
            x: AppTheme.Shadow.cardX,
            y: AppTheme.Shadow.cardY
        )
    }

    /// 引文行区域：有有效引文 → 逐行展示；否则 → 预览词降级
    @ViewBuilder
    private var quoteSection: some View {
        let scenes = displayScenes
        if scenes.isEmpty {
            // 无有效引文时用 previewWords 兜底，至少让卡片有内容
            let words = category.previewWords.prefix(5)
            if !words.isEmpty {
                Text(words.joined(separator: "  ·  "))
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, AppTheme.Space.paddingS)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(scenes) { scene in
                    QuoteRow(scene: scene)
                }
            }
            let more = goodScenes.count - scenes.count
            if more > 0 {
                Text("+\(more) more")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.top, AppTheme.Space.paddingS)
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Image(systemName: "mic.fill")
                .imageScale(.small)
            Text("Start talking")
                .font(AppTheme.Font.ctaLabel)
        }
        .foregroundStyle(AppTheme.Color.cardBg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(AppTheme.Color.brandStrong)
        .clipShape(Capsule())
    }

    // MARK: - Display scenes selection

    /// 有效引文 = quote ≥6 字，或 sceneDetail ≥4 字（避免显示「呼喊」等短标签）
    private func effectiveQuote(_ scene: Tab2SubScene) -> String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }

    /// 所有通过长度筛选的子场景，按出现次数降序
    private var goodScenes: [Tab2SubScene] {
        category.subScenes
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .filter { effectiveQuote($0).count >= 4 }
    }

    /// 实际展示（最多 3 条）
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

// MARK: - Quote row

private struct QuoteRow: View {
    let scene: Tab2SubScene

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leftSlot
            Text(quoteText)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 有图 → 缩略图；无图 → 固定槽位（不为空）
    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = scene.imageUrl, !urlStr.isEmpty {
            CachedRemoteImage(signedUrl: urlStr, stableKey: urlStr) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Color.imagePlaceholderBg)
                    .frame(width: 46, height: 34)
            }
            .frame(width: 46, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "quote.bubble.fill")
                .imageScale(.medium)
                .foregroundStyle(AppTheme.Color.brandStrong.opacity(0.35))
                .frame(width: 46, height: 34)
        }
    }

    /// 有有效 quote（≥6 字）→ 显示 quote；否则降为子场景名
    private var quoteText: String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }
}
