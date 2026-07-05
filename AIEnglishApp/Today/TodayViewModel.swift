import Foundation
import UIKit

@Observable
final class TodayViewModel {
    var entries: [TimelineEntry] = []
    var isLoading = false
    var pendingImage: UIImage?
    let session = ConversationSession()

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        guard !trimmed.isEmpty || image != nil else { return }

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed
        entries.append(TimelineEntry.userBubble(text: textToSend, image: image))
        pendingImage = nil

        let loadingEntry = TimelineEntry.aiLoading()
        entries.append(loadingEntry)
        isLoading = true

        do {
            let envelope = try await service.generate(
                text: textToSend,
                image: image,
                context: session.currentContext
            )
            replace(loadingEntry.id, with: .aiCard(envelope.card))
            // 更新上下文：纯图片时 userContent 用 "[photo]"，其余用原文
            let userContent = textToSend ?? (image != nil ? "[photo]" : nil)
            if let userContent {
                session.onAIResponseReceived(
                    userContent: userContent,
                    cardType: envelope.card.cardTypeName,
                    cardContent: envelope.card.contextRepresentation
                )
            }
        } catch {
            replace(loadingEntry.id, with: .aiError(message: "Something went wrong. Please try again."))
        }
        isLoading = false
    }

    private func replace(_ id: UUID, with content: TimelineEntry.Content) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx] = TimelineEntry(id: id, createdAt: entries[idx].createdAt, content: content)
    }
}
