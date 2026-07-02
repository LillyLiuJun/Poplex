import Foundation

@Observable
final class MineViewModel {
    var scenes: [Material] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCategory: String? = nil   // nil = "全部"

    private var lastLoadedAt: Date = .distantPast

    // 上次成功加载的场景数，用于骨架屏占位数量；第一次默认 3
    var skeletonCount: Int {
        let cached = UserDefaults.standard.integer(forKey: "mine_last_scene_count")
        return cached > 0 ? cached : 3  // 首次无记录时默认 3，之后用实际条数
    }

    // 软删除撤销状态：存最近一次删除的素材，4 秒内可撤销
    private(set) var lastDeletedMaterial: Material? = nil
    private var undoTimer: Task<Void, Never>? = nil

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

    // Fetched separately by VocabBookView; stored here only for the capsule count badge.
    var vocabCount: Int = 0

    // 切 Tab 时调用：超过 30 秒才真正刷新，避免频繁网络请求
    func loadScenesIfStale() async {
        guard Date().timeIntervalSince(lastLoadedAt) > 30 else { return }
        await loadScenes()
    }

    func loadScenes() async {
        isLoading = true
        errorMessage = nil
        do {
            async let scenesResult = fetchScenes()
            async let countResult  = fetchVocabCount()
            scenes     = try await scenesResult
            vocabCount = (try? await countResult) ?? 0
            lastLoadedAt = Date()
            UserDefaults.standard.set(scenes.count, forKey: "mine_last_scene_count")
        } catch {
            errorMessage = "Failed to load, please retry"
        }
        isLoading = false
    }

    private func fetchVocabCount() async throws -> Int {
        var req = URLRequest(url: SupabaseConfig.getVocabsFunctionURL)
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        let (data, _) = try await URLSession.shared.data(for: req)
        let array = try JSONSerialization.jsonObject(with: data) as? [Any]
        return array?.count ?? 0
    }

    // 乐观删除：先从列表移除，再调后端，4 秒撤销窗口
    func deleteMaterial(_ material: Material) async {
        scenes.removeAll { $0.id == material.id }
        lastDeletedMaterial = material

        undoTimer?.cancel()
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            lastDeletedMaterial = nil
        }

        await callMaterialEndpoint(SupabaseConfig.deleteMaterialFunctionURL, id: material.id)
    }

    func restoreMaterial() async {
        guard let material = lastDeletedMaterial else { return }
        undoTimer?.cancel()
        lastDeletedMaterial = nil
        await callMaterialEndpoint(SupabaseConfig.restoreMaterialFunctionURL, id: material.id)
        await loadScenes()
    }

    private func callMaterialEndpoint(_ url: URL, id: UUID) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONEncoder().encode(["id": id.uuidString])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func fetchScenes() async throws -> [Material] {
        var req = URLRequest(url: SupabaseConfig.getMaterialsFunctionURL)
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey,             forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            print("[MineVM] HTTP \(http.statusCode)")
        }
        print("[MineVM] body: \(String(data: data, encoding: .utf8) ?? "<nil>")")

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
