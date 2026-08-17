import Foundation
import UIKit

protocol AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String?, requestId: UUID?, source: String?) async throws -> AIEnvelope
}

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
    case imageEncodingFailed
    case bodySerializationFailed
    case contentBlocked
}

extension UIImage {
    func compressedForUpload() -> UIImage {
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

struct LiveAIService: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String? = nil, requestId: UUID? = nil, source: String? = nil) async throws -> AIEnvelope {
        let bodyData = try Self.requestBody(
            text: text,
            image: image,
            context: context,
            presetCardId: presetCardId,
            requestId: requestId,
            source: source
        )
        return try await call(body: bodyData)
    }

    /// 生成 HTTP 请求体的纯构造 seam，供契约测试验证传给 Edge Function 的 JSON。
    static func requestBody(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String?, requestId: UUID?, source: String?) throws -> Data {
        var body: [String: Any] = [:]
        if let text, !text.isEmpty {
            body["text"] = text
        }
        if let presetCardId {
            body["preset_card_id"] = presetCardId
        }
        if let requestId {
            body["request_id"] = requestId.uuidString
        }
        if let source {
            body["source"] = source
        }
        if let image {
            let compressed = image.compressedForUpload()
            guard let jpeg = compressed.jpegData(compressionQuality: 0.6) else {
                throw AIServiceError.imageEncodingFailed
            }
            body["image_base64"] = jpeg.base64EncodedString()
            body["mime_type"] = "image/jpeg"
        }
        if let ctx = context {
            var cardWithType = ctx.cardContent
            cardWithType["card_type"] = ctx.cardType
            var contextPayload: [String: Any] = [
                "user": ctx.userContent,
                "card_content": cardWithType,
            ]
            // 重发上一轮图片：让 AI 在 follow-up 时真正"看"到历史图片，
            // 而不只是依赖文字描述的 card_content
            if let img = ctx.image,
               let jpeg = img.compressedForUpload().jpegData(compressionQuality: 0.75) {
                contextPayload["image_base64"] = jpeg.base64EncodedString()
                contextPayload["mime_type"] = "image/jpeg"
            }
            body["context"] = contextPayload
        }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw AIServiceError.bodySerializationFailed
        }
        return bodyData
    }

    private func call(body: Data) async throws -> AIEnvelope {
        var request = URLRequest(url: SupabaseConfig.generateFunctionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60   // AI generation can take up to ~30 s; other endpoints use 10 s
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await SupabaseManager.setAuthHeaders(on: &request)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.requestFailed
        }
        return try Self.decodeResponse(statusCode: http.statusCode, data: data)
    }

    /// 把 HTTP 响应分类为「解码后的 AIEnvelope」或抛出对应 AIServiceError。
    /// 从 call() 抽出为纯函数，好让 422/content_blocked、非 2xx、坏 JSON 三条
    /// 分支不经真实网络就能单元测试。
    /// - 422 且 body 为 {"error":"content_blocked"} → .contentBlocked（服务端安全过滤命中）
    /// - 其余非 2xx → .requestFailed
    /// - 2xx 但无法解码 → .decodingFailed
    static func decodeResponse(statusCode: Int, data: Data) throws -> AIEnvelope {
        if statusCode == 422,
           let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
           errorBody["error"] == "content_blocked" {
            throw AIServiceError.contentBlocked
        }
        guard (200..<300).contains(statusCode) else {
            throw AIServiceError.requestFailed
        }
        do {
            return try JSONDecoder().decode(AIEnvelope.self, from: data)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }
}

struct MockAIService: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String? = nil, requestId: UUID? = nil, source: String? = nil) async throws -> AIEnvelope {
        try await mockResult()
    }

    private func mockResult() async throws -> AIEnvelope {
        try await Task.sleep(for: .milliseconds(800))
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "chinese_original": "今天地铁挤死了。",
                "native_translation": "The subway was absolutely packed this morning.",
                "key_phrase": {"phrase": "absolutely packed", "note": "比 very crowded 更有力的表达"},
                "scene_trigger": "Packed commutes are the worst. Do you deal with this every day?"
            }
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(AIEnvelope.self, from: json)
    }
}
