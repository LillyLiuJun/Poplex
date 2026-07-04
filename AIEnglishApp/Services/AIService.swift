import Foundation
import UIKit

protocol AIServicing {
    func generate(text: String?, image: UIImage?) async throws -> AIEnvelope
}

enum AIServiceError: Error {
    case requestFailed
    case decodingFailed
    case imageEncodingFailed
}

private extension UIImage {
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
    func generate(text: String?, image: UIImage?) async throws -> AIEnvelope {
        var dict: [String: String] = [:]
        if let text, !text.isEmpty {
            dict["text"] = text
        }
        if let image {
            let compressed = image.compressedForUpload()
            guard let jpeg = compressed.jpegData(compressionQuality: 0.75) else {
                throw AIServiceError.imageEncodingFailed
            }
            dict["image_base64"] = jpeg.base64EncodedString()
            dict["mime_type"] = "image/jpeg"
        }
        let body = try JSONEncoder().encode(dict)
        return try await call(body: body)
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
    func generate(text: String?, image: UIImage?) async throws -> AIEnvelope { try await mockResult() }

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
