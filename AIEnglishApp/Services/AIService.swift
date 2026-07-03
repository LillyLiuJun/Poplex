import Foundation
import UIKit

protocol AIServicing {
    func generate(text: String) async throws -> AIEnvelope
    func generate(image: UIImage) async throws -> AIEnvelope
}

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
    case imageEncodingFailed
}

struct LiveAIService: AIServicing {
    func generate(text: String) async throws -> AIEnvelope {
        let body = try JSONEncoder().encode(["text": text])
        return try await call(body: body)
    }

    func generate(image: UIImage) async throws -> AIEnvelope {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw AIServiceError.imageEncodingFailed
        }
        let base64 = jpeg.base64EncodedString()
        let body = try JSONEncoder().encode([
            "image_base64": base64,
            "mime_type": "image/jpeg"
        ])
        return try await call(body: body)
    }

    private func call(body: Data) async throws -> AIEnvelope {
        var request = URLRequest(url: SupabaseConfig.generateFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
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
    func generate(text: String) async throws -> AIEnvelope { try await mockResult() }
    func generate(image: UIImage) async throws -> AIEnvelope { try await mockResult() }

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
