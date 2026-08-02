import Foundation

// MARK: - Response types (start / turn)

struct DialogueStartResponse: Decodable {
    let sessionId: String
    let reply: String
    let suggestions: [DialogueSuggestionDTO]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case reply
        case suggestions
    }
}

struct DialogueTurnResponse: Decodable {
    let reply: String
    let suggestions: [DialogueSuggestionDTO]
    let sceneDetail: String?

    enum CodingKeys: String, CodingKey {
        case reply
        case suggestions
        case sceneDetail = "scene_detail"
    }
}

struct DialogueSuggestionDTO: Decodable {
    let lemma: String
    let hint: String
}

// MARK: - Response types (fallback)

struct FallbackResponseDTO: Decodable {
    let translation: String
    let keyWords: [FallbackKeyWordDTO]
    let hint: String

    enum CodingKeys: String, CodingKey {
        case translation
        case keyWords = "key_words"
        case hint
    }
}

struct FallbackKeyWordDTO: Decodable {
    let word: String
    let phonetic: String
}

// MARK: - Errors

enum DialogueError: Error {
    case notAuthenticated
    case serverError(Int)
    case decodingError
}

// MARK: - Service

enum DialogueService {
    static func start(sceneCategory: String) async throws -> DialogueStartResponse {
        var request = URLRequest(url: SupabaseConfig.dialogueFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await SupabaseManager.setAuthHeaders(on: &request)

        let body: [String: String] = ["action": "start", "scene_category": sceneCategory]
        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequest(request, as: DialogueStartResponse.self)
    }

    static func turn(
        sessionId: String,
        turnId: String,
        text: String
    ) async throws -> DialogueTurnResponse {
        var request = URLRequest(url: SupabaseConfig.dialogueFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await SupabaseManager.setAuthHeaders(on: &request)

        let body: [String: String] = [
            "action": "turn",
            "session_id": sessionId,
            "turn_id": turnId,
            "text": text,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequest(request, as: DialogueTurnResponse.self)
    }

    static func fallback(sessionId: String, text: String) async throws -> FallbackResponseDTO {
        var request = URLRequest(url: SupabaseConfig.dialogueFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await SupabaseManager.setAuthHeaders(on: &request)

        let body: [String: String] = [
            "action": "fallback",
            "session_id": sessionId,
            "text": text,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequest(request, as: FallbackResponseDTO.self)
    }

    // MARK: - Private

    private static func performRequest<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DialogueError.serverError(0) }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[DialogueService] HTTP \(http.statusCode): \(body)")
            throw DialogueError.serverError(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[DialogueService] decode error:", error, "body:", String(data: data, encoding: .utf8) ?? "")
            throw DialogueError.decodingError
        }
    }
}
