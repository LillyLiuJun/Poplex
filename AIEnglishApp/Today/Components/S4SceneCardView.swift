import SwiftUI

struct S4SceneCardView: View {
    let content: SceneContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            CardTypeChip(label: "Moment")

            if let original = content.chineseOriginal {
                Text(original)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
            } else if let guess = content.aiSceneGuess {
                Text(guess)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Text(content.nativeTranslation)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)

            if let kp = content.keyPhrase {
                HStack(alignment: .top, spacing: AppTheme.Space.paddingM) {
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                        Text(kp.phrase)
                            .font(AppTheme.Font.keyPhrase)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text(kp.note)
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            CardSceneTrigger(text: content.sceneTrigger)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Shadow.cardRadius,
            x: AppTheme.Shadow.cardX,
            y: AppTheme.Shadow.cardY
        )
    }
}
