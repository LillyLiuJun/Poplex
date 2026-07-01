import SwiftUI

struct S2GrammarCardView: View {
    let content: GrammarContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(content.chineseTranslation)
                .font(.callout)
                .foregroundStyle(AppTheme.Color.textSecondary)

            if let grammar = content.grammarAnalysis {
                Text(grammar)
                    .font(.body)
            }

            if let polish = content.nativePolish {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text("更地道的说法")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text(polish)
                        .font(.body.bold())
                        .foregroundStyle(AppTheme.Color.textAccent)
                }
            }

            if let kp = content.keyPhrase {
                HStack(alignment: .top, spacing: AppTheme.Space.paddingS) {
                    Text(kp.phrase)
                        .font(.callout.bold())
                    Text("·")
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text(kp.note)
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
