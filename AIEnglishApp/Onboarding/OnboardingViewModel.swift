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
    /// 预设卡已成功落库 → completeOnboarding 不再注入内存 seed（防止与服务端记录重复）。
    /// 落库失败时保持 false，seed 兜底本次进程的 Tab1 首屏。
    private(set) var presetSavedToServer = false

    private let service: AIServicing
    private let presetCardSaver: PresetCardSaving

    init(
        service: AIServicing = LiveAIService(),
        presetCardSaver: PresetCardSaving = LivePresetCardSaver()
    ) {
        self.service = service
        self.presetCardSaver = presetCardSaver
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
        presetSavedToServer = false
    }

    func generate() async {
        isLoading = true
        errorMessage = nil
        generationResult = nil
        presetSavedToServer = false

        do {
            if let card = selectedCard {
                // 预设卡使用静态样本，零 AI 消耗。利用 3s 动画等待并行做两件事：
                // ① 预热登录，确保 completeOnboarding() → markOnboardingComplete()
                //    时 auth session 已就绪；
                // ② 轻量落库：把静态文案写成服务端消息记录，重启后 Tab1 历史
                //    仍能看到这张卡（落库失败则 seed 兜底本次进程）。
                async let warmUp: Void = { _ = try? await SupabaseManager.ensureSignedIn() }()
                let saveTask = Task { await presetCardSaver.save(card: card) }
                try await Task.sleep(for: .milliseconds(3000))
                _ = await warmUp
                // 写库带 1.5s 上限竞速：正常网络早已完成；超时按失败处理。
                let saved = await withTaskGroup(of: Bool?.self) { group in
                    group.addTask { await saveTask.value }
                    group.addTask {
                        try? await Task.sleep(for: .milliseconds(1500))
                        return nil
                    }
                    let first = await group.next()
                    group.cancelAll()
                    return first ?? nil
                }
                presetSavedToServer = saved == true
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
