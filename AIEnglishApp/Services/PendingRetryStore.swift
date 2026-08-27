import Foundation
import UIKit

/// 待重试记录的来源：断网未落库的预设卡 / 断网生成失败的照片 / Tab1 生成失败的发送。
/// 三类共用一个记录类型与一个 store（统一 attempt 抽象）：
/// requestId 是唯一持久化的幂等键来源，跨启动不丢。
enum PendingRetrySource: String, Codable {
    case presetCard
    case photo
    case tab1   // Tab1 发送失败（文字或照片）：重启后以「气泡 + 失败行」按写作时刻归位
}

/// 待重试记录（杀 app 不丢）。三类来源共用一个类型。
struct PendingRetryRecord: Codable, Identifiable {
    let id: UUID
    let source: PendingRetrySource
    /// 本次尝试的幂等键，跨重试、跨启动复用。optional 保持旧 JSON 可解码。
    let requestId: UUID?
    let presetCardId: String?     // source == .presetCard
    let presetImageName: String?  // 内置 asset 图名（展示用）
    let photoFileName: String?    // source == .photo / .tab1 照片（图片文件在 Documents 下）
    let text: String?             // source == .tab1 文字发送的原文
    /// source == .tab1 时 = 气泡的原始写作时刻（方案丙：重试按它落库，重启后原位稳定）；
    /// 其余来源 = 记录写入时刻。
    let createdAt: Date
}

/// 待重试记录存储：记录 JSON 存 UserDefaults，照片 JPEG 写 Documents。
/// 单例供 App 使用；init(defaults:documentsDir:) 供单测隔离。
///
/// 线程安全（审查发现 #4）：与 LocalSuccessStore 同一类 bug——所有「读-改-写」操作经
/// NSLock 串行化，避免并发写回互相覆盖造成「记录凭空消失」。
final class PendingRetryStore {
    static let shared = PendingRetryStore(
        defaults: .standard,
        documentsDir: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    )

    private static let recordsKey = "pending_retry_records"

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
                    domain: "PendingRetryStore",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "metadata persist failed"]
                )
            }
        }
    }

    // MARK: - Save

    /// 预设卡：只记元数据，图片用内置 asset（无需落盘）。requestId 是本次尝试的幂等键。
    func savePreset(cardId: String, imageName: String, requestId: UUID) {
        lock.withLock {
            var records = readRecords()
            records.removeAll { $0.source == .presetCard && $0.presetCardId == cardId }  // 幂等
            records.append(PendingRetryRecord(
                id: UUID(), source: .presetCard,
                requestId: requestId,
                presetCardId: cardId, presetImageName: imageName,
                photoFileName: nil, text: nil, createdAt: .now
            ))
            try? writeRecords(records)
        }
    }

    /// 照片：JPEG 落盘 + 记元数据。失败抛错（调用方决定是否提示）。
    func savePhoto(_ image: UIImage, requestId: UUID) throws {
        try lock.withLock {
            guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "PendingRetryStore", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
            }
            let fileName = UUID().uuidString + ".jpg"
            try jpeg.write(to: documentsDir.appendingPathComponent(fileName))
            var records = readRecords()
            records.append(PendingRetryRecord(
                id: UUID(), source: .photo,
                requestId: requestId,
                presetCardId: nil, presetImageName: nil,
                photoFileName: fileName, text: nil, createdAt: .now
            ))
            do {
                try writeRecords(records)
            } catch {
                try? FileManager.default.removeItem(
                    at: documentsDir.appendingPathComponent(fileName)
                )
                throw error
            }
        }
    }

    /// Tab1 发送失败：持久化本次尝试（文字或照片 + 写作时刻 + 幂等键）。
    /// 同 requestId 已存在时直接跳过（重试再失败不产生第二条记录——幂等）。
    /// 照片与 savePhoto 同一套落盘机制；失败抛错（调用方决定是否提示）。
    func saveTab1(text: String?, image: UIImage?, requestId: UUID, createdAt: Date) throws {
        try lock.withLock {
            var records = readRecords()
            guard !records.contains(where: { $0.source == .tab1 && $0.requestId == requestId }) else {
                return
            }
            var fileName: String? = nil
            if let image {
                guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "PendingRetryStore", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
                }
                fileName = UUID().uuidString + ".jpg"
                try jpeg.write(to: documentsDir.appendingPathComponent(fileName!))
            }
            records.append(PendingRetryRecord(
                id: UUID(), source: .tab1,
                requestId: requestId,
                presetCardId: nil, presetImageName: nil,
                photoFileName: fileName, text: text, createdAt: createdAt
            ))
            do {
                try writeRecords(records)
            } catch {
                if let fileName {
                    try? FileManager.default.removeItem(
                        at: documentsDir.appendingPathComponent(fileName)
                    )
                }
                throw error
            }
        }
    }

    // MARK: - Load / Remove

    func load() -> [PendingRetryRecord] {
        lock.withLock { readRecords() }
    }

    /// 为旧版 photo 记录补上稳定的幂等键。已有键时直接复用；新键持久化成功后才返回。
    /// 调用方必须在此方法成功后才能发起生成请求，避免未落盘的 ID 被服务端看见。
    func ensureRequestId(for recordId: UUID) throws -> PendingRetryRecord {
        try lock.withLock {
            var records = readRecords()
            guard let index = records.firstIndex(where: { $0.id == recordId }) else {
                throw NSError(
                    domain: "PendingRetryStore",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "pending retry record not found"]
                )
            }
            if records[index].requestId != nil {
                return records[index]
            }

            let record = records[index]
            let upgraded = PendingRetryRecord(
                id: record.id,
                source: record.source,
                requestId: UUID(),
                presetCardId: record.presetCardId,
                presetImageName: record.presetImageName,
                photoFileName: record.photoFileName,
                text: record.text,
                createdAt: record.createdAt
            )
            records[index] = upgraded
            try writeRecords(records)
            return upgraded
        }
    }

    /// 按 id 移除记录（含照片文件）。
    /// 先持久化元数据、成功后才删照片文件（审查发现 #6b）：写不进去时保留文件——
    /// 删错一边比「多一个孤儿文件」严重得多（照片仍在而记录没了 → 内容消失；
    /// 记录仍在而照片没了 → 只是缺图）。
    /// 清空所有待重试记录及其照片文件——仅用于注销 / 删除账号。
    /// 逐条走 `remove(id:)` 而不是直接清 UserDefaults：记录关联的 JPEG 落在
    /// Documents 里，只清索引会留下永远不会被引用的孤儿文件。
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
            if let fileName {
                try? FileManager.default.removeItem(
                    at: documentsDir.appendingPathComponent(fileName)
                )
            }
        }
    }

    /// Tab1 重试成功后按幂等键清除持久化记录（含照片文件）。
    /// 只清 .tab1 来源——onboarding 记录的移除由 retryPending 的按 id 移除负责。
    func removeTab1ByRequestId(_ requestId: UUID) {
        lock.withLock {
            var records = readRecords()
            guard let idx = records.firstIndex(where: { $0.source == .tab1 && $0.requestId == requestId })
            else { return }
            let fileName = records[idx].photoFileName
            records.remove(at: idx)
            do {
                try writeRecords(records)
            } catch {
                return   // 元数据没写成 → 文件不动，两边状态一致
            }
            if let fileName {
                try? FileManager.default.removeItem(
                    at: documentsDir.appendingPathComponent(fileName)
                )
            }
        }
    }

    /// 照片记录的本地图片；预设卡记录返回 asset 图（两者都供 UI 展示）。
    func photoImage(for record: PendingRetryRecord) -> UIImage? {
        if record.source == .presetCard, let name = record.presetImageName {
            return UIImage(named: name)
        }
        if let fileName = record.photoFileName {
            return UIImage(contentsOfFile: documentsDir.appendingPathComponent(fileName).path)
        }
        return nil
    }

    /// 逐条有损解码（审查发现 #6c）：任何一条记录损坏只丢那一条，不影响其他记录；
    /// 抢救结果写回自愈。必须在锁内调用。
    private func readRecords() -> [PendingRetryRecord] {
        guard let data = defaults.data(forKey: Self.recordsKey) else { return [] }
        // 整体解码成功 = 常态快路径
        if let all = try? JSONDecoder().decode([PendingRetryRecord].self, from: data) {
            return all
        }
        // 有损抢救：逐条解码，活一条留一条
        guard let fragments = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        var survivors: [PendingRetryRecord] = []
        for fragment in fragments {
            guard let elementData = try? JSONSerialization.data(withJSONObject: fragment),
                  let record = try? JSONDecoder().decode(PendingRetryRecord.self, from: elementData)
            else { continue }
            survivors.append(record)
        }
        try? writeRecords(survivors)   // 自愈写回：下次启动不再走抢救路径
        return survivors
    }

    /// 元数据落盘（锁内调用）。
    private func writeRecords(_ records: [PendingRetryRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try metadataWriter(data)
    }
}
