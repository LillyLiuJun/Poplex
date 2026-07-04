import SwiftUI

struct S4SceneCardView: View {
    let content: SceneContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            if let original = content.chineseOriginal {
                Text(original)
                    .font(.callout)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            } else if let guess = content.aiSceneGuess {
                Text(guess)
                    .font(.callout)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            Text(content.nativeTranslation)
                .font(.body.bold())

            if let kp = content.keyPhrase {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                    Text(kp.phrase)
                        .font(.callout.bold())
                        .foregroundStyle(AppTheme.Color.textAccent)
                    Text(kp.note)
                        .font(.caption)
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
