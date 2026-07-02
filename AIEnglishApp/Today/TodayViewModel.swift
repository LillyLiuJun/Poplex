import Foundation

@Observable
final class TodayViewModel {
    var entries: [TimelineEntry] = []
    var isLoading = false
    var errorMessage: String?

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        entries.append(TimelineEntry.userBubble(text: trimmed))
        isLoading = true
        errorMessage = nil

        do {
            let envelope = try await service.generate(text: trimmed)
            entries.append(TimelineEntry.aiCard(envelope.card))
        } catch {
            errorMessage = "生成失败，请重试"
        }
        isLoading = false
    }
}
