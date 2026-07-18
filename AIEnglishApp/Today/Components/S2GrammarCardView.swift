import SwiftUI

struct S2GrammarCardView: View {
    let content: GrammarContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(content.chineseTranslation)
                .font(AppTheme.Font.chineseBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(.trailing, 72)

            if let grammar = content.grammarAnalysis {
                Text(grammar)
                    .font(AppTheme.Font.englishBody)
            }

            if let polish = content.nativePolish {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text("A more natural way to say it")
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text(polish)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.accentBuddy)
                }
            }

            if let kp = content.keyPhrase {
                HStack(alignment: .top, spacing: AppTheme.Space.paddingS) {
                    Text(kp.phrase)
                        .font(AppTheme.Font.keyPhrase)
                    Text("·")
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text(kp.note)
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
            CardTypeChip(label: "Polish", color: AppTheme.Color.chipPolish, textColor: AppTheme.Color.textPrimary)
                .padding(AppTheme.Space.paddingCard)
        }
    }
}
