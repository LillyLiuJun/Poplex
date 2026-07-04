import SwiftUI

struct VocabBookView: View {
    let vocabCount: Int
    @State private var vocabs: [Material] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastDeletedVocab: Material? = nil
    @State private var undoTimer: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
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
                                        deleteVocab(material)
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

    private func deleteVocab(_ material: Material) {
        vocabs.removeAll { $0.id == material.id }
        lastDeletedVocab = material
        undoTimer?.cancel()
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            lastDeletedVocab = nil
        }
        Analytics.track("material_deleted", properties: [
            "material_id": material.id.uuidString,
            "material_type": "vocabulary"
        ])
        Task { await callEndpoint(SupabaseConfig.deleteMaterialFunctionURL, id: material.id) }
    }

    private func restoreVocab() async {
        guard let material = lastDeletedVocab else { return }
        undoTimer?.cancel()
        lastDeletedVocab = nil
        await callEndpoint(SupabaseConfig.restoreMaterialFunctionURL, id: material.id)
        await loadVocabs()
    }

    private func callEndpoint(_ url: URL, id: UUID) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await SupabaseManager.setAuthHeaders(on: &req)
        req.httpBody = try? JSONEncoder().encode(["id": id.uuidString])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func loadVocabs() async {
        isLoading = true
        errorMessage = nil
        do {
            vocabs = try await fetchVocabs()
        } catch {
            errorMessage = "Failed to load, please retry"
        }
        isLoading = false
    }

    private func fetchVocabs() async throws -> [Material] {
        var req = URLRequest(url: SupabaseConfig.getVocabsFunctionURL)
        try await SupabaseManager.setAuthHeaders(on: &req)

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
