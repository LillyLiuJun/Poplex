import SwiftUI

struct TimelineRow: View {
    let entry: TimelineEntry
    var onImageTap: ((UIImage, CGRect) -> Void)? = nil
    var onRetry: ((_ text: String?, _ image: UIImage?, _ entryId: UUID) -> Void)? = nil

    var body: some View {
        switch entry.content {
        case .userBubble(let text, let image, let imageUrl, let imageStableKey):
            UserBubble(text: text, image: image, imageUrl: imageUrl, imageStableKey: imageStableKey, onImageTap: onImageTap)
        case .aiLoading:
            AILoadingCard()
        case .aiCard(let card):
            AICardView(card: card)
        case .aiError(let message):
            ErrorBanner(message: message)
        case .sendFailed(let text, let image):
            SendFailedRow { onRetry?(text, image, entry.id) }
        case .dateSeparator(let label):
            DateSeparatorView(label: label)
        }
    }
}

// MARK: - Send failed (tap to retry)
private struct SendFailedRow: View {
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .imageScale(.small)
                Text("Couldn't send. Tap to retry.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, AppTheme.Space.paddingXS)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User bubble (right-aligned, image above text)
private struct UserBubble: View {
    let text: String?
    let image: UIImage?
    let imageUrl: String?
    let imageStableKey: String?
    var onImageTap: ((UIImage, CGRect) -> Void)?

    @State private var imageFrame: CGRect = .zero
    private let imageSize = UIScreen.main.bounds.width * 0.3

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
            if let img = image {
                HStack {
                    Spacer()
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.bubble))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { imageFrame = $0 }
                        .onTapGesture { onImageTap?(img, imageFrame) }
                }
            } else if let urlStr = imageUrl {
                HStack {
                    Spacer()
                    CachedRemoteImage(signedUrl: urlStr, stableKey: imageStableKey ?? urlStr) {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.bubble)
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView().scaleEffect(0.7))
                    }
                    .frame(width: imageSize, height: imageSize)
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
            .font(AppTheme.Font.chineseFaint)
            .foregroundStyle(AppTheme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(AppTheme.Space.paddingCard)
    }
}

// MARK: - Date separator
private struct DateSeparatorView: View {
    let label: String

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Rectangle()
                .fill(AppTheme.Color.textSecondary.opacity(0.25))
                .frame(height: 0.5)
            Text(label)
                .font(AppTheme.Font.date)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize()
            Rectangle()
                .fill(AppTheme.Color.textSecondary.opacity(0.25))
                .frame(height: 0.5)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
    }
}
