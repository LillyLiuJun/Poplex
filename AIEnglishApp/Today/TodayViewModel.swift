import Foundation
import UIKit

@Observable
final class TodayViewModel {
    var entries: [TimelineEntry] = []
    var isLoading = false
    var isLoadingHistory = false
    var pendingImage: UIImage?
    let session = ConversationSession()

    private let service: AIServicing

    init(service: AIServicing = LiveAIService()) {
        self.service = service
    }

    // MARK: - History

    func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        guard let records = try? await fetchMessageRecords() else { return }

        var result: [TimelineEntry] = []
        var lastDayLabel: String?

        for record in records {
            let dayLabel = Self.dayLabel(for: record.createdAt)
            if dayLabel != lastDayLabel {
                result.append(TimelineEntry(
                    id: UUID(), createdAt: record.createdAt,
                    content: .dateSeparator(dayLabel)
                ))
                lastDayLabel = dayLabel
            }
            if let entry = record.asTimelineEntry() {
                result.append(entry)
            }
        }

        entries = result
    }

    // MARK: - Send

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        guard !trimmed.isEmpty || image != nil else { return }

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed

        // 今天第一条消息时，若最近的非分隔符条目不是今天，插入 "Today" 分隔符
        let today = Self.dayLabel(for: .now)
        let lastNonSeparatorDate = entries.last(where: {
            if case .dateSeparator = $0.content { return false }
            return true
        })?.createdAt
        let needsSeparator = lastNonSeparatorDate.map {
            Self.dayLabel(for: $0) != today
        } ?? (entries.isEmpty ? false : true)
        if needsSeparator || entries.isEmpty {
            entries.append(TimelineEntry(
                id: UUID(), createdAt: .now,
                content: .dateSeparator(today)
            ))
        }

        entries.append(TimelineEntry.userBubble(text: textToSend, image: image))
        pendingImage = nil

        let loadingEntry = TimelineEntry.aiLoading()
        entries.append(loadingEntry)
        isLoading = true

        do {
            let envelope = try await service.generate(
                text: textToSend,
                image: image,
                context: session.currentContext
            )
            replace(loadingEntry.id, with: .aiCard(envelope.card))
            let userContent = textToSend ?? (image != nil ? "[photo]" : nil)
            if let userContent {
                session.onAIResponseReceived(
                    userContent: userContent,
                    cardType: envelope.card.cardTypeName,
                    cardContent: envelope.card.contextRepresentation,
                    image: image
                )
            }
        } catch {
            replace(loadingEntry.id, with: .aiError(message: "Something went wrong. Please try again."))
        }
        isLoading = false
    }

    // MARK: - Private

    private func replace(_ id: UUID, with content: TimelineEntry.Content) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx] = TimelineEntry(id: id, createdAt: entries[idx].createdAt, content: content)
    }

    private func fetchMessageRecords() async throws -> [MessageRecord] {
        var request = URLRequest(url: SupabaseConfig.messagesFunctionURL)
        request.httpMethod = "GET"
        try await SupabaseManager.setAuthHeaders(on: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MessageRecord].self, from: data)
    }

    private static func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
