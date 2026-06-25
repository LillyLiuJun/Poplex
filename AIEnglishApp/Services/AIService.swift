import Foundation

// AI 服务的抽象接口。界面只依赖这个协议，不关心背后是真后端还是假数据——
// 这样测试可以注入假实现，开发期也能先用 Mock 看界面。
protocol AIServicing {
    func generate(text: String) async throws -> AIResponse
}

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
}

// 真实实现：POST 到 Supabase Edge Function，由它在服务器端带 Key 调用 Gemini。
struct LiveAIService: AIServicing {
    func generate(text: String) async throws -> AIResponse {
        var request = URLRequest(url: SupabaseConfig.generateFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIServiceError.requestFailed
        }
        do {
            return try JSONDecoder().decode(AIResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }
}

// 假实现：返回写死的数据，不发网络请求。开发期看界面、单元测试时用。
struct MockAIService: AIServicing {
    func generate(text: String) async throws -> AIResponse {
        try await Task.sleep(for: .seconds(1))
        return AIResponse(
            reply: "Here's a natural way to say it:\n\"The meeting got pushed back to this afternoon.\"",
            intent: .init(language: "zh", isMeaningful: true, isCompliant: true, hasClearScene: true),
            material: .init(sceneTag: "work", level: "sentence",
                            english: "The meeting got pushed back to this afternoon.")
        )
    }
}
