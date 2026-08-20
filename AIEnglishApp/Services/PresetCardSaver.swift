import Foundation

/// 预设卡轻量落库：把 App 内置的静态文案写成一条服务端消息记录（不调 AI）。
/// 走协议便于 OnboardingViewModel 单测注入 mock。
protocol PresetCardSaving: Sendable {
    /// 成功返回 true；任何失败（断网 / 服务端错误）返回 false——
    /// 失败不阻塞流程，由内存 seed 兜底本次进程的 Tab1 首屏展示。
    /// requestId 是本次尝试的幂等键，同一次尝试的重试必须复用同一个值。
    func save(card: PresetCard, requestId: UUID) async -> Bool
}

struct LivePresetCardSaver: PresetCardSaving {
    func save(card: PresetCard, requestId: UUID) async -> Bool {
        var request = URLRequest(url: SupabaseConfig.savePresetCardFunctionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        do {
            try await SupabaseManager.setAuthHeaders(on: &request)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "request_id": requestId.uuidString,
                "preset_card_id": card.id,
                "static_english": card.staticEnglish,
                "static_chinese": card.staticChinese,
                "image_name": card.imageName,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            print("[PresetCardSaver] save failed (seed covers this session):", error)
            return false
        }
    }
}
