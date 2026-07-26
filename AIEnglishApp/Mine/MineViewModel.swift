import Foundation

@Observable
final class MineViewModel {
    var scenes: [Material] = []
    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?
    var selectedCategory: String? = nil   // nil = "全部"

    private var lastLoadedAt: Date = .distantPast

    // 上次成功加载的场景数，用于骨架屏占位数量；第一次默认 3
    var skeletonCount: Int {
        let cached = UserDefaults.standard.integer(forKey: "mine_last_scene_count")
        return cached > 0 ? cached : 3  // 首次无记录时默认 3，之后用实际条数
    }

    // 软删除撤销状态：存最近一次删除的素材，4 秒内可撤销
    private(set) var lastDeletedMaterial: Material? = nil
    private var lastDeletedIndex: Int? = nil   // 删除时的位置，撤销时插回原位
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
        // 首次加载交给 .task（loadScenes）负责——冷启动时 .task 与本方法（onAppear）
        // 几乎同时触发，若都发请求会重复打两遍 get-materials/get-vocabs、加剧冷启动拥堵。
        // lastLoadedAt 仍是初始值即「从未成功加载过」，直接让路给 .task。
        guard lastLoadedAt != .distantPast else { return }
        guard Date().timeIntervalSince(lastLoadedAt) > 30 else { return }
        Analytics.track("tab2_opened", properties: [
            "scene_count": scenes.count,
            "vocab_count": vocabCount
        ])
        await loadScenes()
    }

    func loadScenes() async {
        // 1. 先读本地缓存立即渲染（有缓存就不再是骨架），用墓碑过滤已删条目
        if scenes.isEmpty,
           let cached = await LocalCache.shared.load(key: .scenes),
           let decoded = try? Self.decodeMaterials(from: cached) {
            let tombstones = await LocalCache.shared.tombstones(for: .scenes)
            scenes = decoded.filter { !tombstones.contains($0.id.uuidString) }
        }

        isLoading = true
        errorMessage = nil
        do {
            async let dataResult  = fetchMaterialsData()
            async let countResult = fetchVocabCount()
            let data   = try await dataResult
            vocabCount = (try? await countResult) ?? 0

            // 请求成功：落盘、清墓碑、更新列表
            await LocalCache.shared.save(data, key: .scenes)
            await LocalCache.shared.clearTombstones(for: .scenes)
            scenes = (try? Self.decodeMaterials(from: data)) ?? scenes
            lastLoadedAt = Date()
            toastMessage = nil
            UserDefaults.standard.set(scenes.count, forKey: "mine_last_scene_count")
        } catch {
            if scenes.isEmpty {
                errorMessage = "Failed to load, please retry"
            } else {
                toastMessage = "Couldn't update — showing saved content"
            }
        }
        isLoading = false
    }

    private func fetchVocabCount() async throws -> Int {
        var req = URLRequest(url: SupabaseConfig.getVocabsFunctionURL)
        req.timeoutInterval = 10
        try await SupabaseManager.setAuthHeaders(on: &req)
        let (data, _) = try await URLSession.shared.data(for: req)
        let array = try JSONSerialization.jsonObject(with: data) as? [Any]
        return array?.count ?? 0
    }

    // 乐观删除：先从列表移除 + 立即写入墓碑（防幽灵素材），再调后端，4 秒撤销窗口
    func deleteMaterial(_ material: Material) async {
        lastDeletedIndex = scenes.firstIndex { $0.id == material.id }
        scenes.removeAll { $0.id == material.id }
        await LocalCache.shared.addTombstone(material.id, key: .scenes)
        lastDeletedMaterial = material

        undoTimer?.cancel()
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            lastDeletedMaterial = nil
            lastDeletedIndex = nil
        }

        Analytics.track("material_deleted", properties: [
            "material_id": material.id.uuidString,
            "material_type": "scene"
        ])
        await callMaterialEndpoint(SupabaseConfig.deleteMaterialFunctionURL, id: material.id)
    }

    // 乐观撤销：先把素材插回原位置（UI 秒回），墓碑移除与服务器恢复放后台；
    // 不再整表 loadScenes——本地已有数据，下次自然刷新时与服务器对齐。
    func restoreMaterial() async {
        guard let material = lastDeletedMaterial else { return }
        undoTimer?.cancel()
        let index = min(lastDeletedIndex ?? scenes.count, scenes.count)
        scenes.insert(material, at: index)
        lastDeletedMaterial = nil
        lastDeletedIndex = nil
        await LocalCache.shared.removeTombstone(material.id, key: .scenes)
        await callMaterialEndpoint(SupabaseConfig.restoreMaterialFunctionURL, id: material.id)
    }

    private func callMaterialEndpoint(_ url: URL, id: UUID) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await SupabaseManager.setAuthHeaders(on: &req)
        req.httpBody = try? JSONEncoder().encode(["id": id.uuidString])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func fetchMaterialsData() async throws -> Data {
        var req = URLRequest(url: SupabaseConfig.getMaterialsFunctionURL)
        req.timeoutInterval = 10
        try await SupabaseManager.setAuthHeaders(on: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            print("[MineVM] HTTP \(http.statusCode)")
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// 网络返回的字节和缓存读出的字节走同一条解析路径
    static func decodeMaterials(from data: Data) throws -> [Material] {
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
