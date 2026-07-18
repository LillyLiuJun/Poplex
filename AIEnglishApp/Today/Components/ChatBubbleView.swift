import SwiftUI

struct ChatBubbleView: View {
    let content: ChatContent

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                Text(content.text)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                if let connection = content.sceneConnection {
                    Text(connection)
                        .font(AppTheme.Font.chineseBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .italic()
                }
            }
            .padding(AppTheme.Space.paddingCard)
            .background(AppTheme.Color.bubbleAIBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.bubble))

            Spacer(minLength: AppTheme.Space.paddingHero)
        }
    }
}
