import SwiftUI

struct VocabBookView: View {
    let vocabCount: Int
    @State private var vocabs: [Material] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var lastDeletedVocab: Material? = nil
    @State private var lastDeletedIndex: Int? = nil   // 删除时的位置，撤销时插回原位
    @State private var undoTimer: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if isLoading && vocabs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage, vocabs.isEmpty {
                ContentUnavailableView(
                    "Failed to load",
                    systemImage: "wifi.slash",
                    description: Text(err)
                )
            } else if vocabs.isEmpty {
                ContentUnavailableView(
                    "No vocabulary yet",
                    systemImage: "character.book.closed",
                    description: Text("Words you look up will be saved here.")
                )
            } else {
                List {
                    ForEach(vocabs) { material in
                        if case .vocabulary(let vocab) = material.rawContent {
                            VocabCardRow(vocab: vocab)
                                .onTapGesture {
                                    Analytics.track("vocab_card_tapped", properties: ["material_id": material.id.uuidString])
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await deleteVocab(material) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: AppTheme.Space.paddingCard / 2,
                        leading: AppTheme.Space.paddingPage,
                        bottom: AppTheme.Space.paddingCard / 2,
                        trailing: AppTheme.Space.paddingPage
                    ))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $toastMessage, systemImage: "exclamationmark.triangle")
        .task { await loadVocabs() }
        .overlay(alignment: .bottom) {
            if lastDeletedVocab != nil {
                UndoToast(message: "Deleted") { Task { await restoreVocab() } }
                    .padding(.bottom, AppTheme.Space.paddingPage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lastDeletedVocab != nil)
    }

    // 墓碑必须先 await 落盘再进入撤销窗口——否则秒撤销时 removeTombstone 会跑在
    // addTombstone 之前，留下永不清除的墓碑，下次冷启动该词条被静默过滤。
    private func deleteVocab(_ material: Material) async {
        lastDeletedIndex = vocabs.firstIndex { $0.id == material.id }
        vocabs.removeAll { $0.id == material.id }
        await LocalCache.shared.addTombstone(material.id, key: .vocabs)
        lastDeletedVocab = material
        undoTimer?.cancel()
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            lastDeletedVocab = nil
            lastDeletedIndex = nil
        }
        Analytics.track("material_deleted", properties: [
            "material_id": material.id.uuidString,
            "material_type": "vocabulary"
        ])
        Task { await callEndpoint(SupabaseConfig.deleteMaterialFunctionURL, id: material.id) }
    }

    // 乐观撤销：先把词条插回原位置（UI 秒回），墓碑移除与服务器恢复放后台；
    // 不再整表 loadVocabs——之前要等两个串行网络请求（~3s）词才回列表。
    private func restoreVocab() async {
        guard let material = lastDeletedVocab else { return }
        undoTimer?.cancel()
        let index = min(lastDeletedIndex ?? vocabs.count, vocabs.count)
        vocabs.insert(material, at: index)
        lastDeletedVocab = nil
        lastDeletedIndex = nil
        await LocalCache.shared.removeTombstone(material.id, key: .vocabs)
        await callEndpoint(SupabaseConfig.restoreMaterialFunctionURL, id: material.id)
    }

    private func callEndpoint(_ url: URL, id: UUID) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await SupabaseManager.setAuthHeaders(on: &req)
        req.httpBody = try? JSONEncoder().encode(["id": id.uuidString])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func loadVocabs() async {
        // 先读缓存立即渲染，用墓碑过滤已删条目
        if vocabs.isEmpty,
           let cached = await LocalCache.shared.load(key: .vocabs),
           let decoded = try? MineViewModel.decodeMaterials(from: cached) {
            let tombstones = await LocalCache.shared.tombstones(for: .vocabs)
            vocabs = decoded.filter { !tombstones.contains($0.id.uuidString) }
        }

        isLoading = true
        errorMessage = nil
        do {
            let data = try await fetchVocabsData()
            await LocalCache.shared.save(data, key: .vocabs)
            await LocalCache.shared.clearTombstones(for: .vocabs)
            vocabs = (try? MineViewModel.decodeMaterials(from: data)) ?? vocabs
            toastMessage = nil
        } catch {
            if vocabs.isEmpty {
                errorMessage = "Failed to load, please retry"
            } else {
                toastMessage = "Couldn't update — showing saved content"
            }
        }
        isLoading = false
    }

    private func fetchVocabsData() async throws -> Data {
        var req = URLRequest(url: SupabaseConfig.getVocabsFunctionURL)
        req.timeoutInterval = 10
        try await SupabaseManager.setAuthHeaders(on: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
