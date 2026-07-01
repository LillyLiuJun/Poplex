import Foundation

@Observable
final class MineViewModel {
    var scenes: [Material] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCategory: String? = nil   // nil = "全部"

    // Only categories that actually have materials (dynamic, not the full fixed list)
    var availableCategories: [String] {
        let cats = scenes.compactMap(\.sceneCategory)
        let unique = Array(Set(cats))
        return unique.sorted()
    }

    var filteredScenes: [Material] {
        guard let cat = selectedCategory else { return scenes }
        return scenes.filter { $0.sceneCategory == cat }
    }

    func loadScenes() async {
        isLoading = true
        errorMessage = nil
        do {
            scenes = try await fetchScenes()
        } catch {
            errorMessage = "加载失败，请重试"
        }
        isLoading = false
    }

    private func fetchScenes() async throws -> [Material] {
        var comps = URLComponents(
            url: SupabaseConfig.projectURL.appending(path: "rest/v1/materials"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "select",        value: "*"),
            URLQueryItem(name: "material_type", value: "eq.scene"),
            URLQueryItem(name: "deleted_at",    value: "is.null"),
            URLQueryItem(name: "order",         value: "created_at.desc"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey,             forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: req)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return try decoder.decode([Material].self, from: data)
    }
}
