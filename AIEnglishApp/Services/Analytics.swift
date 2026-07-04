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
        // 埋点是尽力而为：拿不到 token 就直接放弃，不阻塞、不报错。
        try? await SupabaseManager.setAuthHeaders(on: &req)
        req.httpBody = body
        _ = try? await URLSession.shared.data(for: req)
    }
}
