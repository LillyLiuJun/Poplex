import Foundation
import UIKit

protocol AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String?, source: String?) async throws -> AIEnvelope
}

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
    case imageEncodingFailed
    case bodySerializationFailed
}

extension UIImage {
    func compressedForUpload() -> UIImage {
        let maxDimension: CGFloat = 1600
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

struct LiveAIService: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String? = nil, source: String? = nil) async throws -> AIEnvelope {
        var body: [String: Any] = [:]
        if let text, !text.isEmpty {
            body["text"] = text
        }
        if let presetCardId {
            body["preset_card_id"] = presetCardId
        }
        if let source {
            body["source"] = source
        }
        if let image {
            let compressed = image.compressedForUpload()
            guard let jpeg = compressed.jpegData(compressionQuality: 0.75) else {
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
        return try await call(body: bodyData)
    }

    private func call(body: Data) async throws -> AIEnvelope {
        var request = URLRequest(url: SupabaseConfig.generateFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await SupabaseManager.setAuthHeaders(on: &request)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
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
    func generate(text: String?, image: UIImage?, context: ContextTurn?, presetCardId: String? = nil, source: String? = nil) async throws -> AIEnvelope {
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
