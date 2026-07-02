import SwiftUI

struct VocabBookView: View {
    let vocabCount: Int
    @State private var vocabs: [Material] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                ScrollView {
                    LazyVStack(spacing: AppTheme.Space.paddingCard) {
                        ForEach(vocabs) { material in
                            if case .vocabulary(let vocab) = material.rawContent {
                                VocabCardRow(vocab: vocab)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.vertical, AppTheme.Space.paddingCard)
                }
            }
        }
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadVocabs() }
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
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

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
