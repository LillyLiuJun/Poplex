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

        let records: [MessageRecord]
        do {
            records = try await fetchMessageRecords()
        } catch {
            print("[TodayVM] loadHistory error:", error)
            return
        }

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

        print("[TodayVM] loaded \(records.count) records → \(result.count) entries")
        // 如果 send() 已经在运行（isLoading）或已添加过条目，说明用户在历史加载完成前就发了消息。
        // 此时内存里的顺序是正确的，不能用数据库结果覆盖，否则会因 Promise.all 的时间戳竞争导致顺序错乱。
        guard !isLoading, entries.isEmpty else { return }
        entries = result
    }

    // MARK: - Send

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        guard !trimmed.isEmpty || image != nil else { return }

        let textToSend: String? = trimmed.isEmpty ? nil : trimmed

        // 若最后一条分隔符不是 "Today"，插入今天的分隔符
        let today = Self.dayLabel(for: .now)
        let lastSeparator = entries.last(where: {
            if case .dateSeparator = $0.content { return true }
            return false
        })
        let alreadyHasToday: Bool
        if case .dateSeparator(let label) = lastSeparator?.content {
            alreadyHasToday = (label == today)
        } else {
            alreadyHasToday = false
        }
        if !alreadyHasToday {
            entries.append(TimelineEntry(
                id: UUID(), createdAt: .now,
                content: .dateSeparator(today)
            ))
        }

        let bubbleText = textToSend ?? (image != nil ? "Describe this image" : nil)
        entries.append(TimelineEntry.userBubble(text: bubbleText, image: image))
        pendingImage = nil

        let loadingEntry = TimelineEntry.aiLoading()
        entries.append(loadingEntry)
        isLoading = true

        do {
            let envelope = try await service.generate(
                text: textToSend,
                image: image,
                context: session.currentContext,
                presetCardId: nil,
                source: "tab1"
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
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[TodayVM] HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }

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

        do {
            return try decoder.decode([MessageRecord].self, from: data)
        } catch {
            print("[TodayVM] decode error:", error)
            throw error
        }
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
