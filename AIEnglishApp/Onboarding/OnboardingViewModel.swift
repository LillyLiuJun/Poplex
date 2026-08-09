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
            if let card = selectedCard {
                // 预设卡使用静态样本，保留 1.2 秒 loading 动画以保持 AI 生成的仪式感与平滑过渡，零 API 消耗
                try await Task.sleep(for: .milliseconds(1200))
                generationResult = card.staticCard
                retryCount = 0
            } else if let image = selectedImage {
                // 自选拍照/相册依然走实时 AI API
                let envelope = try await service.generate(text: nil, image: image, context: nil, presetCardId: nil, source: "onboarding")
                generationResult = envelope.card
                retryCount = 0
            } else {
                isLoading = false
                return
            }
        } catch {
            retryCount += 1
            errorMessage = "Something went wrong. Want to try again?"
        }
        isLoading = false
    }
}
