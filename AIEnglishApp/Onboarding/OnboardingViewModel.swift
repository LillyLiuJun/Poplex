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
            if let card = selectedCard {
                // 用卡片 bundle 图发 AI，体验与用户自拍照一致；bundle 图缺失时降级为文字 prompt
                let cardImage = UIImage(named: card.imageName)
                envelope = try await service.generate(
                    text: cardImage == nil ? card.generationPrompt : nil,
                    image: cardImage,
                    context: nil,
                    presetCardId: card.id,
                    source: "onboarding"
                )
            } else if let image = selectedImage {
                envelope = try await service.generate(text: nil, image: image, context: nil, presetCardId: nil, source: "onboarding")
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
