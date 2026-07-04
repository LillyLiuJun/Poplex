import SwiftUI

struct TimelineRow: View {
    let entry: TimelineEntry

    var body: some View {
        switch entry.content {
        case .userBubble(let text, let image):
            UserBubble(text: text, image: image)
        case .aiLoading:
            AILoadingCard()
        case .aiCard(let card):
            AICardView(card: card)
        case .aiError(let message):
            ErrorBanner(message: message)
        }
    }
}

// MARK: - User bubble (right-aligned, image above text)
private struct UserBubble: View {
    let text: String?
    let image: UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
            if let img = image {
                HStack {
                    Spacer(minLength: AppTheme.Space.paddingHero)
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.bubble))
                }
            }
            if let text, !text.isEmpty {
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

// MARK: - AI loading placeholder
private struct AILoadingCard: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppTheme.Space.paddingCard)
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
