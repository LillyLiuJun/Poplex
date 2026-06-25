import SwiftUI

// 时间线里的一条气泡。用户消息靠右、AI 消息靠左。
struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: AppTheme.Space.paddingHero) }

            Text(message.text)
                .padding(AppTheme.Space.paddingCard)
                .background(bubbleColor)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .ai { Spacer(minLength: AppTheme.Space.paddingHero) }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? AppTheme.Color.bubbleUserBg : AppTheme.Color.bubbleAIBg
    }

    private var textColor: Color {
        message.role == .user ? AppTheme.Color.bubbleUserText : AppTheme.Color.textPrimary
    }
}
