import Foundation
import UIKit

@Observable
final class OnboardingViewModel {
    var selectedCard: PresetCard?
    var selectedImage: UIImage?       // from camera or photo library
    var generationResult: AICard?
    var isLoading = false
    var errorMessage: String?
    var retryCount = 0

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    // Called when user picks a preset card and taps Continue
    func startWithCard(_ card: PresetCard) async {
        selectedCard = card
        selectedImage = nil
        await generate()
    }

    // Called when user picks a photo (camera or library) and taps Continue
    func startWithImage(_ image: UIImage) async {
        selectedImage = image
        selectedCard = nil
        await generate()
    }

    func retry() async {
        await generate()
    }

    func reset() {
        selectedCard = nil
        selectedImage = nil
        generationResult = nil
        isLoading = false
        errorMessage = nil
        retryCount = 0
    }

    func generate() async {
        isLoading = true
        errorMessage = nil
        generationResult = nil

        do {
            let envelope: AIEnvelope
            if let image = selectedImage {
                envelope = try await service.generate(text: nil, image: image)
            } else if let card = selectedCard {
                envelope = try await service.generate(text: card.generationPrompt, image: nil)
            } else {
                isLoading = false
                return
            }
            generationResult = envelope.card
            retryCount = 0
        } catch {
            retryCount += 1
            errorMessage = "Something went wrong. Want to try again?"
        }
        isLoading = false
    }
}
