import Foundation

// Tab1 的状态层。@Observable 是 iOS 17+ 的写法（符合 CLAUDE.md），界面会自动跟着这里的数据变化刷新。
@Observable
final class TodayViewModel {
    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(Message(role: .user, text: trimmed))
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.generate(text: trimmed)
            messages.append(Message(role: .ai, text: response.reply))
        } catch {
            errorMessage = "生成失败，请重试"
        }
        isLoading = false
    }
}
