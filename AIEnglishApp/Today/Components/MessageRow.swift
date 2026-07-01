import SwiftUI

struct TimelineRow: View {
    let entry: TimelineEntry

    var body: some View {
        switch entry.content {
        case .userBubble(let text):
            UserBubble(text: text)
        case .aiCard(let card):
            AICardView(card: card)
        case .aiError(let message):
            ErrorBanner(message: message)
        }
    }
}

// MARK: - User bubble (right-aligned)
private struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: AppTheme.Space.paddingHero)
            Text(text)
                .padding(AppTheme.Space.paddingCard)
                .background(AppTheme.Color.bubbleUserBg)
                .foregroundStyle(AppTheme.Color.bubbleUserText)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.bubble))
        }
    }
}

// MARK: - Routes to the correct card view
private struct AICardView: View {
    let card: AICard

    var body: some View {
        switch card {
        case .s1(let c):    S1VocabCardView(content: c)
        case .s2(let c):    S2GrammarCardView(content: c)
        case .s3(let c):    S3TranslationCardView(content: c)
        case .s4(let c):    S4SceneCardView(content: c)
        case .chat(let c):  ChatBubbleView(content: c)
        case .error(let c): ErrorBanner(message: c.message)
        }
    }
}

// MARK: - Inline error message
struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(AppTheme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(AppTheme.Space.paddingCard)
    }
}
