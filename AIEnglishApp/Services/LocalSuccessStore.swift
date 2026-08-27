import Foundation
import UIKit

/// 本地成功增量记录（杀 app 不丢）：生成/落库成功的「气泡 + 卡片」。
///
/// 为什么需要它：`LocalCache.messages` 只在 `loadHistory` 全量拉取成功后更新——
/// 刚生成的内容不在那份快照里，没有本记录，冷启动只能等网络几秒。
/// 本记录是「生成成功时刻」留下的本地底稿，直到服务端全量历史把它覆盖（届时按幂等键清除）。
struct LocalSuccessRecord: Codable, Identifiable {
    let id: UUID
    /// 本次生成的幂等键：与服务端历史去重（服务器已有正本 → 本地副本可删）。
    let requestId: UUID
    /// 服务端 user / assistant 消息行 ID（Tab1 路径可拿到；onboarding 路径拿不到，为 nil）。
    /// 非空时用作注入条目的 TimelineEntry id → 与服务端回放同 ID，对齐时零重排。
    let userMessageId: UUID?
    let assistantMessageId: UUID?
    /// 气泡的写作时刻：注入时按它归位（与失败行同规则）。
    let createdAt: Date
    /// 文本发送的原文（照片 / 预设卡为 nil）。
    let text: String?
    /// 照片发送的本地 JPEG（Documents 下）；预设卡为 nil。
    let photoFileName: String?
    /// 预设卡的内置 asset 图名。
    let presetImageName: String?
    /// 卡片内容 JSON（contextRepresentation 编码；只存 .card，error 卡不持久化）。
    let cardData: Data
}

/// 本地成功增量存储：记录 JSON 存 UserDefaults，照片 JPEG 写 Documents。
/// 结构与 PendingRetryStore 同族（统一 attempt 抽象的「成功侧」）。
/// 单例供 App 使用；init(defaults:documentsDir:) 供单测隔离。
///
/// 线程安全（审查发现 #4）：所有「读-改-写」操作经 NSLock 串行化——`load()` 读出数组、
/// 改一条、`persist()` 写回这个非原子序列，若并发跑（回前台刷新 + 生成成功同时发生），
/// 后写者会覆盖先写者的新记录，造成「记录凭空消失」。
final class LocalSuccessStore {
    static let shared = LocalSuccessStore(
        defaults: .standard,
        documentsDir: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    )

    private static let recordsKey = "local_success_records"

    private let defaults: UserDefaults
    private let documentsDir: URL
    private let metadataWriter: (Data) throws -> Void
    /// 读改写互斥锁。注意：withLock 不可重入——锁内只调 readRecords/writeRecords
    /// 与文件操作（不碰带锁的 load()）。
    private let lock = NSLock()

    init(
        defaults: UserDefaults,
        documentsDir: URL,
        metadataWriter: ((Data) throws -> Void)? = nil
    ) {
        self.defaults = defaults
        self.documentsDir = documentsDir
        self.metadataWriter = metadataWriter ?? { data in
            defaults.set(data, forKey: Self.recordsKey)
            guard defaults.data(forKey: Self.recordsKey) == data else {
                throw NSError(
                    domain: "LocalSuccessStore",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "metadata persist failed"]
                )
            }
        }
    }

    // MARK: - Save

    /// Tab1 发送成功（文字或照片）：服务端消息行 ID 可拿到，存作注入条目的稳定 ID。
    /// 同 requestId 幂等：已存在则跳过（重试复用同一幂等键，不产生第二条）。
    /// 照片 JPEG 落盘失败/元数据持久化失败抛错（调用方 try? 静默，不打断成功体验）。
    func saveTab1(
        text: String?, image: UIImage?, requestId: UUID,
        userMessageId: UUID?, assistantMessageId: UUID?,
        createdAt: Date, card: AICard
    ) throws {
        try lock.withLock {
            var records = readRecords()
            guard !records.contains(where: { $0.requestId == requestId }) else { return }
            // 先编码卡片再落照片文件（审查发现 #6a）：编码失败（error 卡不持久化）时
            // 文件尚未写入，不需要回滚路径。
            let cardData = try Self.encodeCard(card)
            let fileName = try savePhotoFileIfNeeded(image)
            records.append(LocalSuccessRecord(
                id: UUID(), requestId: requestId,
                userMessageId: userMessageId, assistantMessageId: assistantMessageId,
                createdAt: createdAt, text: text, photoFileName: fileName,
                presetImageName: nil, cardData: cardData
            ))
            do {
                try writeRecords(records)
            } catch {
                removeFileIfNeeded(fileName)
                throw error
            }
        }
    }

    /// Onboarding 预设卡落库成功：内置 asset 图 + 静态卡（无服务端消息行 ID）。
    /// 同 requestId 幂等。
    func saveOnboardingPreset(imageName: String, requestId: UUID, createdAt: Date, card: AICard) {
        lock.withLock {
            var records = readRecords()
            guard !records.contains(where: { $0.requestId == requestId }) else { return }
            guard let cardData = try? Self.encodeCard(card) else { return }
            records.append(LocalSuccessRecord(
                id: UUID(), requestId: requestId,
                userMessageId: nil, assistantMessageId: nil,
                createdAt: createdAt, text: nil, photoFileName: nil,
                presetImageName: imageName, cardData: cardData
            ))
            try? writeRecords(records)
        }
    }

    /// Onboarding 照片生成成功：本地 JPEG + AI 卡。虽然服务端消息行 ID 多数时候拿不到，
    /// 但契约上透传（审查发现 #8）：注入时气泡/卡片用服务端 ID 当条目身份证，
    /// 与回放对齐零重排。同 requestId 幂等。
    func saveOnboardingPhoto(
        _ image: UIImage, requestId: UUID, createdAt: Date,
        userMessageId: UUID? = nil, assistantMessageId: UUID? = nil,
        card: AICard
    ) throws {
        try lock.withLock {
            var records = readRecords()
            guard !records.contains(where: { $0.requestId == requestId }) else { return }
            let cardData = try Self.encodeCard(card)
            let fileName = try savePhotoFileIfNeeded(image)
            records.append(LocalSuccessRecord(
                id: UUID(), requestId: requestId,
                userMessageId: userMessageId, assistantMessageId: assistantMessageId,
                createdAt: createdAt, text: nil, photoFileName: fileName,
                presetImageName: nil, cardData: cardData
            ))
            do {
                try writeRecords(records)
            } catch {
                removeFileIfNeeded(fileName)
                throw error
            }
        }
    }

    // MARK: - Load / Remove

    func load() -> [LocalSuccessRecord] {
        lock.withLock { readRecords() }
    }

    /// 按 id 移除记录（含照片文件）。
    /// 先持久化元数据、成功后才删照片文件（审查发现 #6b）：写不进去时保留文件——
    /// 删错一边比「多一个孤儿文件」严重得多（照片仍在而记录没了 → 内容消失；
    /// 记录仍在而照片没了 → 只是缺图）。
    /// 清空所有成功记录及其照片文件——仅用于注销 / 删除账号。
    /// 同 PendingRetryStore：逐条走 `remove(id:)` 以连带删除 Documents 里的图片。
    /// - Returns: 清理后仍残留的**记录**数。
    ///
    /// 只对自己的索引负责。`remove(id:)` 先写元数据、再 `try?` 删照片文件，
    /// 所以「记录没了但 JPEG 还在」是可能的——**照片文件级的残留由
    /// `LocalUserData` 统一扫 Documents 目录兜底**，不在这里重复实现
    /// （两个 store 共用同一个 Documents 根目录，各扫各的会互删对方的文件）。
    @discardableResult
    func clearAll() -> Int {
        for record in load() { remove(id: record.id) }
        return load().count
    }

    func remove(id: UUID) {
        lock.withLock {
            var records = readRecords()
            guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
            let fileName = records[idx].photoFileName
            records.remove(at: idx)
            do {
                try writeRecords(records)
            } catch {
                return   // 元数据没写成 → 文件不动，两边状态一致
            }
            removeFileIfNeeded(fileName)
        }
    }

    // MARK: - Content

    /// 记录内嵌卡片：contextRepresentation 编码 → 包成 envelope 形状解码回 AICard。
    func card(for record: LocalSuccessRecord) -> AICard? {
        guard let dict = try? JSONSerialization.jsonObject(with: record.cardData) as? [String: Any],
              let payload = try? JSONSerialization.data(withJSONObject: [
                  "card_type": "card",
                  "card_content": dict
              ]),
              let envelope = try? JSONDecoder().decode(AIEnvelope.self, from: payload),
              case .card(let content) = envelope.card
        else { return nil }
        return .card(content)
    }

    /// 气泡图：预设卡取内置 asset，照片读本地 JPEG。
    func bubbleImage(for record: LocalSuccessRecord) -> UIImage? {
        if let name = record.presetImageName {
            return UIImage(named: name)
        }
        if let fileName = record.photoFileName {
            return UIImage(contentsOfFile: documentsDir.appendingPathComponent(fileName).path)
        }
        return nil
    }

    // MARK: - Helpers

    /// 卡片内容编码：只有 .card 是耐久的学内容；error 卡不持久化（重试/换图是唯一前进路径）。
    static func encodeCard(_ card: AICard) throws -> Data {
        guard case .card = card else {
            throw NSError(
                domain: "LocalSuccessStore",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "error card is not durable content"]
            )
        }
        return try JSONSerialization.data(withJSONObject: card.contextRepresentation)
    }

    private func savePhotoFileIfNeeded(_ image: UIImage?) throws -> String? {
        guard let image else { return nil }
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "LocalSuccessStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
        }
        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: documentsDir.appendingPathComponent(fileName))
        return fileName
    }

    private func removeFileIfNeeded(_ fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(
            at: documentsDir.appendingPathComponent(fileName)
        )
    }

    /// 逐条有损解码（审查发现 #6c）：任何一条记录损坏只丢那一条，不影响其他记录；
    /// 抢救结果写回自愈。必须在锁内调用。
    private func readRecords() -> [LocalSuccessRecord] {
        guard let data = defaults.data(forKey: Self.recordsKey) else { return [] }
        // 整体解码成功 = 常态快路径
        if let all = try? JSONDecoder().decode([LocalSuccessRecord].self, from: data) {
            return all
        }
        // 有损抢救：逐条解码，活一条留一条
        guard let fragments = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        var survivors: [LocalSuccessRecord] = []
        for fragment in fragments {
            guard let elementData = try? JSONSerialization.data(withJSONObject: fragment),
                  let record = try? JSONDecoder().decode(LocalSuccessRecord.self, from: elementData)
            else { continue }
            survivors.append(record)
        }
        try? writeRecords(survivors)   // 自愈写回：下次启动不再走抢救路径
        return survivors
    }

    /// 元数据落盘（锁内调用）。
    private func writeRecords(_ records: [LocalSuccessRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try metadataWriter(data)
    }
}
