import SwiftUI

struct S1VocabCardView: View {
    let content: VocabContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                Text(content.pos)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(content.word)
                    .font(AppTheme.Font.englishPrimary)
                Text(content.phonetic)
                    .font(AppTheme.Font.phonetic)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(.trailing, 72)

            Text(content.definition)
                .font(AppTheme.Font.chineseBody)
                .foregroundStyle(AppTheme.Color.textSecondary)

            if let example = content.examples.first {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text("\u{201C}\(example.en)\u{201D}")
                        .font(AppTheme.Font.englishBody)
                    Text(example.zh)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
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
            CardTypeChip(label: "Word", color: AppTheme.Color.chipWord)
                .padding(AppTheme.Space.paddingCard)
        }
    }
}
