import SwiftUI

struct S4SceneCardView: View {
    let content: SceneContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            if let original = content.chineseOriginal {
                Text(original)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textFaint)
                    .padding(.trailing, 72)
            } else if let guess = content.aiSceneGuess {
                Text(guess)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textFaint)
                    .padding(.trailing, 72)
            }

            Text(content.nativeTranslation)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)

            if let kp = content.keyPhrase {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text(kp.phrase)
                        .font(AppTheme.Font.keyPhrase)
                        .foregroundStyle(AppTheme.Color.accentBuddy)
                    Text(kp.note)
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.textMuted)
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
            CardTypeChip(label: "Moment", color: AppTheme.Color.chipMoment)
                .padding(AppTheme.Space.paddingCard)
        }
    }
}
