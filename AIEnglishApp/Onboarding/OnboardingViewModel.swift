import Foundation

@Observable
final class OnboardingViewModel {
    var selectedCard: PresetCard?
    var generationResult: AICard?
    var isLoading = false
    var errorMessage: String?
    var retryCount = 0

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    func retry() async {
        await generate()
    }

    func reset() {
        selectedCard = nil
        generationResult = nil
        isLoading = false
        errorMessage = nil
        retryCount = 0
    }

    func generate() async {
        guard let prompt = selectedCard?.generationPrompt else { return }
        isLoading = true
        errorMessage = nil
        generationResult = nil

        do {
            let envelope = try await service.generate(text: prompt)
            generationResult = envelope.card
            retryCount = 0
        } catch {
            retryCount += 1
            errorMessage = "Something went wrong. Want to try again?"
        }
        isLoading = false
    }
}
