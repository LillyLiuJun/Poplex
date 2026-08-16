import Foundation
import UIKit

/// Onboarding 生成失败的三种情境，按「用户能做的动作」区分：
/// 断网可自助恢复（连网重试）、内容被拒需换素材、其余只能重试。
enum OnboardingErrorKind {
    case offline          // 断网
    case contentBlocked   // 内容被服务端安全过滤拦截
    case generic          // 其它（超时/服务器/解码等）

    /// 把一次生成失败翻译成档位。纯函数：不碰网络/单例，便于单测。
    /// 判定顺序：服务端明确信号（contentBlocked）优先；URLError 断网码次之；
    /// NetworkMonitor 真实网络状态兜底；其余归 generic。
    static func classify(error: Error, isConnected: Bool) -> OnboardingErrorKind {
        if case AIServiceError.contentBlocked = error { return .contentBlocked }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return .offline
            default:
                break
            }
        }
        if !isConnected { return .offline }
        return .generic
    }
}

extension OnboardingErrorKind {
    /// 失败态状态条文案（常驻）。被拒不映射——走 toast + 回上传页。
    var failureBarCopy: String? {
        switch self {
        case .offline: return "Network unavailable. Check your network and try again."
        case .generic: return "Something went wrong. Please try again."
        case .contentBlocked: return nil
        }
    }
}

@Observable
final class OnboardingViewModel {
    var selectedCard: PresetCard?
    var selectedImage: UIImage?       // from camera or photo library
    var generationResult: AICard?
    var isLoading = false
    var errorKind: OnboardingErrorKind?
    /// 粘性标记：本次 onboarding 是否曾断网失败。errorKind 是瞬时信号（网络恢复即清，
    /// toast 随之下线），但它会被清掉——离开页面时仍要写待重试记录，靠的是这个标记。
    /// 只在 reset() 时抹掉（用户主动换素材重来）。
    private(set) var offlineFailureOccurred = false
    /// 预设卡已成功落库 → completeOnboarding 不再注入内存 seed（防止与服务端记录重复）。
    /// 落库失败时保持 false，seed 兜底本次进程的 Tab1 首屏。
    private(set) var presetSavedToServer = false

    private let service: AIServicing
    private let presetCardSaver: PresetCardSaving
    /// 是否联网的判定（注入点，便于单测模拟断网）。默认读全局 NetworkMonitor。
    private let isConnected: @Sendable () -> Bool

    init(
        service: AIServicing = LiveAIService(),
        presetCardSaver: PresetCardSaving = LivePresetCardSaver(),
        isConnected: @escaping @Sendable () -> Bool = { NetworkMonitor.shared.isConnected }
    ) {
        self.service = service
        self.presetCardSaver = presetCardSaver
        self.isConnected = isConnected
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
        errorKind = nil
        offlineFailureOccurred = false
        presetSavedToServer = false
    }

    /// 内容被拒：清空选中回上传页（图片不上屏）。errorKind 保留驱动 toast（4s 自动消失）；
    /// offlineFailureOccurred 不动（被拒不是断网失败）。
    func rejectSelection() {
        selectedCard = nil
        selectedImage = nil
        generationResult = nil
        isLoading = false
        presetSavedToServer = false
    }

    func generate() async {
        // 防重入：Try again/Continue 双击防护——loading 期间再触发直接忽略
        guard !isLoading else { return }
        isLoading = true
        errorKind = nil
        generationResult = nil
        presetSavedToServer = false

        do {
            if let card = selectedCard {
                // 预设卡静态样本，零 AI 消耗。与自选图同规则——「真实网络动作的成败」为真相：
                // 预设卡唯一的网络动作就是落库，落库失败即断网档失败态（不展示完整卡片、
                // 显示素材图 + 状态条、写待重试记录）。
                // 始终真实尝试落库、不预判网络：真机飞行模式下 NetworkMonitor 双向不可靠
                // （生产验证：断网时不报断网、恢复时不报恢复），预判会卡死重试路径。
                // 断网时尝试落库 = 一次瞬间失败的轻量请求，代价可忽略。
                async let warmUp: Void = { _ = try? await SupabaseManager.ensureSignedIn() }()
                let saveTask = Task { await presetCardSaver.save(card: card) }
                try await Task.sleep(for: .milliseconds(3000))
                _ = await warmUp
                // 写库带 1.5s 上限竞速：正常网络早已完成；超时按失败处理。
                let saved = (await withTaskGroup(of: Bool?.self) { group in
                    group.addTask { await saveTask.value }
                    group.addTask {
                        try? await Task.sleep(for: .milliseconds(1500))
                        return nil
                    }
                    let first = await group.next()
                    group.cancelAll()
                    return first ?? nil
                }) == true
                presetSavedToServer = saved
                if saved {
                    generationResult = card.staticCard
                } else {
                    errorKind = .offline
                    offlineFailureOccurred = true
                    // 不设 generationResult：落库失败 = 断网档失败态，失败分支显示所选素材图 + 状态条
                }
            } else if let image = selectedImage {
                // 自选拍照/相册依然走实时 AI API
                let envelope = try await service.generate(text: nil, image: image, context: nil, presetCardId: nil, source: "onboarding")
                generationResult = envelope.card
            } else {
                isLoading = false
                return
            }
        } catch {
            let kind = OnboardingErrorKind.classify(error: error, isConnected: isConnected())
            errorKind = kind
            if kind == .offline {
                offlineFailureOccurred = true
            } else if kind == .contentBlocked {
                // 被拒：清选中回空上传区（图片不上屏）。不允许空手进 App——换新图是唯一前进路径。
                rejectSelection()
            }
        }
        isLoading = false
    }
}
