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
            // ① 分类标头（大写分类名 + Word Count 徽章）
            HStack(alignment: .center, spacing: AppTheme.Space.paddingXS) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 6, height: 6)
                    Text(category.englishLabel.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
                
                Spacer()
                
                Text("\(category.wordCount) words")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.brandStrong.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, AppTheme.Space.paddingM)

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
        .background(
            LinearGradient(
                colors: [AppTheme.Color.brandSubtleBg.opacity(0.6), AppTheme.Color.cardBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .strokeBorder(AppTheme.Color.brandStrong.opacity(0.15), lineWidth: 1)
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
                Text("+\(more) more moments")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.top, 4)
                    .padding(.leading, 4)
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
        .padding(.vertical, 15)
        .background(
            LinearGradient(
                colors: [AppTheme.Color.brandStrong, Color(red: 242/255, green: 101/255, blue: 16/255)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(
            color: AppTheme.Color.brandStrong.opacity(0.35),
            radius: 12,
            x: 0,
            y: 5
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

// MARK: - Quote row (对话质感引文胶囊)

private struct QuoteRow: View {
    let scene: Tab2SubScene

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leftSlot
            Text(quoteText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppTheme.Color.brandStrong.opacity(0.08), lineWidth: 1)
        )
    }

    /// 有图 → 缩略图；无图 → 精致温润气泡指示
    @ViewBuilder
    private var leftSlot: some View {
        if let urlStr = scene.imageUrl, !urlStr.isEmpty {
            CachedRemoteImage(signedUrl: urlStr, stableKey: urlStr) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Color.imagePlaceholderBg)
                    .frame(width: 38, height: 38)
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.Color.brandSubtleBg)
                    .frame(width: 28, height: 28)
                Image(systemName: "quote.opening")
                    .font(.system(size: 11, weight: .bold))
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
