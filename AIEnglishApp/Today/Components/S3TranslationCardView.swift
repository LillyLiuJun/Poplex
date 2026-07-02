import SwiftUI

struct S3TranslationCardView: View {
    let content: TranslationContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                    Text(content.chineseConcept)
                        .font(.title3.bold())
                    Text("→")
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text(content.englishTranslation)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.Color.textAccent)
                }
                HStack(spacing: AppTheme.Space.paddingS) {
                    Text(content.pos)
                    Text(content.phonetic)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text("\u{201C}\(content.example.en)\u{201D}")
                    .font(.callout)
                Text(content.example.zh)
                    .font(.callout)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            CardSceneTrigger(text: content.sceneTrigger)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
