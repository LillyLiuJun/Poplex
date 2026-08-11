import SwiftUI

struct Tab2CategoryRow: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }

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
            categoryHeader

            Spacer(minLength: 14)

            momentContent

            Spacer(minLength: 16)

            ctaButton
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Category header（纯文字标签，不放图标）

    private var categoryHeader: some View {
        HStack(alignment: .center) {
            Text(category.englishLabel.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.Color.textSecondary)

            Spacer()

            Text(PopsLabel.format(category.wordCount))
                .font(AppTheme.Font.cardMeta)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
    }

    // MARK: - Moment content

    @ViewBuilder
    private var momentContent: some View {
        let scenes = displayScenes
        if scenes.isEmpty {
            fallbackWords
        } else {
            VStack(alignment: .leading, spacing: 10) {
                featuredMoment(scenes[0])

                if scenes.count > 1 {
                    Divider().opacity(0.4)

                    ForEach(scenes.dropFirst()) { scene in
                        MomentRow(scene: scene, category: sceneCategory)
                    }
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

    // MARK: - Featured moment

    @ViewBuilder
    private func featuredMoment(_ scene: Tab2SubScene) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = scene.imageUrl, let key = scene.stableImageKey {
                CachedRemoteImage(
                    signedUrl: url,
                    stableKey: key,
                    placeholder: RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Color.cardBg)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(AppTheme.Color.textMuted)
                        )
                )
                .saturation(0.88)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(alignment: .firstTextBaseline) {
                if !scene.isPhotoMoment {
                    Image(systemName: sceneCategory.momentIconName)
                        .symbolVariant(.fill)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.42))
                }

                Text(scene.sceneDetail)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()

                if scene.occurrenceCount > 1 {
                    Text("+\(scene.occurrenceCount)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }

            if let q = scene.quote, !q.isEmpty {
                Text(q)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let te = scene.targetExpression, !te.isEmpty {
                Text(te)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Fallback

    @ViewBuilder
    private var fallbackWords: some View {
        let words = category.previewWords.prefix(5)
        if !words.isEmpty {
            Text(words.joined(separator: "  ·  "))
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(2)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Start talking")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.75))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.Color.textPrimary.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Scene selection

    private var goodScenes: [Tab2SubScene] {
        category.subScenes
            .filter { !$0.sceneDetail.isEmpty }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
    }

    private var displayScenes: [Tab2SubScene] {
        let photos = goodScenes.filter { $0.isPhotoMoment }
        let texts  = goodScenes.filter { !$0.isPhotoMoment }

        if let featured = photos.first {
            let rest = Array((photos.dropFirst() + texts)
                .sorted { $0.occurrenceCount > $1.occurrenceCount }
                .prefix(2))
            return [featured] + rest
        } else {
            return Array(texts.prefix(3))
        }
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
