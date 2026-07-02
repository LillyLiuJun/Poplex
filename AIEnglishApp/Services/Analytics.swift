import Foundation

enum Analytics {
    static func track(_ event: String, properties: [String: Any] = [:]) {
        Task { await send(event: event, properties: properties) }
    }

    private static func send(event: String, properties: [String: Any]) async {
        guard let body = try? JSONSerialization.data(withJSONObject: [
            "event_name": event,
            "properties": properties
        ]) else { return }
        var req = URLRequest(url: SupabaseConfig.logEventFunctionURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = body
        _ = try? await URLSession.shared.data(for: req)
    }
}
