import SwiftUI

struct S1VocabCardView: View {
    let content: VocabContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                Text(content.pos)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                Text(content.word)
                    .font(.title3.bold())
                Text(content.phonetic)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            Text(content.definition)
                .font(.body)
                .foregroundStyle(AppTheme.Color.textAccent)

            if let example = content.examples.first {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text("\u{201C}\(example.en)\u{201D}")
                        .font(.callout)
                    Text(example.zh)
                        .font(.callout)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
            }

            CardSceneTrigger(text: content.sceneTrigger)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
