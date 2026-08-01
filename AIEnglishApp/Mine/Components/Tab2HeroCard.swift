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
            // ① 分类标头（大写分类名 + Word Count 微章）
            HStack(alignment: .center, spacing: AppTheme.Space.paddingXS) {
                Text(category.englishLabel.uppercased())
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                
                Spacer()
                
                Text("\(category.wordCount) words")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.Color.brandStrong.opacity(0.08))
                    .clipShape(Capsule())
            }
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
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .strokeBorder(AppTheme.Color.brandStrong.opacity(0.12), lineWidth: 1)
        )
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.06),
            radius: 12,
            x: 0,
            y: 4
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
            VStack(alignment: .leading, spacing: 12) {
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
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.28),
            radius: 10,
            x: 0,
            y: 4
        )
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
        HStack(alignment: .center, spacing: 10) {
            leftSlot
            Text(quoteText)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 有图 → 缩略图；无图 → 精致温润气泡/竖线指示
    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = scene.imageUrl, !urlStr.isEmpty {
            CachedRemoteImage(signedUrl: urlStr, stableKey: urlStr) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Color.imagePlaceholderBg)
                    .frame(width: 40, height: 30)
            }
            .frame(width: 40, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Color.brandStrong.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: "quote.opening")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }
        }
    }

    /// 有有效 quote（≥6 字）→ 显示 quote；否则降为子场景名
    private var quoteText: String {
        if let q = scene.quote, q.count >= 6 { return q }
        return scene.sceneDetail
    }
}
