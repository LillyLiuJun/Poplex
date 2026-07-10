import SwiftUI

struct S3TranslationCardView: View {
    let content: TranslationContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                    Text(content.chineseConcept)
                        .font(AppTheme.Font.englishPrimary)
                    Text("→")
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text(content.englishTranslation)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .padding(.trailing, 72)

                HStack(spacing: AppTheme.Space.paddingS) {
                    Text(content.pos)
                    Text(content.phonetic)
                }
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
            }

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text("\u{201C}\(content.example.en)\u{201D}")
                    .font(AppTheme.Font.englishBody)
                Text(content.example.zh)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            CardSceneTrigger(text: content.sceneTrigger)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Color.border, lineWidth: 0.5)
        )
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Shadow.cardRadius,
            x: AppTheme.Shadow.cardX,
            y: AppTheme.Shadow.cardY
        )
        .overlay(alignment: .topTrailing) {
            CardTypeChip(label: "Translate", color: AppTheme.Color.chipTranslate)
                .padding(AppTheme.Space.paddingCard)
        }
    }
}
