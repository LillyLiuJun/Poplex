import Foundation
import UIKit

/// 待重试记录的来源：断网未落库的预设卡 / 断网生成失败的照片。
enum PendingRetrySource: String, Codable {
    case presetCard
    case photo
}

/// 带未成功内容离开 onboarding 时持久化的待重试记录（杀 app 不丢）。
struct PendingRetryRecord: Codable, Identifiable {
    let id: UUID
    let source: PendingRetrySource
    /// 同一张照片跨重试、跨启动复用的幂等键。optional 保持旧 JSON 可解码。
    let requestId: UUID?
    let presetCardId: String?     // source == .presetCard
    let presetImageName: String?  // 内置 asset 图名（展示用）
    let photoFileName: String?    // source == .photo（图片文件在 Documents 下）
    let createdAt: Date
}

/// 待重试记录存储：记录 JSON 存 UserDefaults，照片 JPEG 写 Documents。
/// 单例供 App 使用；init(defaults:documentsDir:) 供单测隔离。
final class PendingRetryStore {
    static let shared = PendingRetryStore(
        defaults: .standard,
        documentsDir: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    )

    private static let recordsKey = "pending_retry_records"

    private let defaults: UserDefaults
    private let documentsDir: URL
    private let metadataWriter: (Data) throws -> Void

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

    /// 预设卡：只记元数据，图片用内置 asset（无需落盘）。
    func savePreset(cardId: String, imageName: String) {
        var records = load()
        records.removeAll { $0.source == .presetCard && $0.presetCardId == cardId }  // 幂等
        records.append(PendingRetryRecord(
            id: UUID(), source: .presetCard,
            requestId: nil,
            presetCardId: cardId, presetImageName: imageName,
            photoFileName: nil, createdAt: .now
        ))
        try? persist(records)
    }

    /// 照片：JPEG 落盘 + 记元数据。失败抛错（调用方决定是否提示）。
    func savePhoto(_ image: UIImage, requestId: UUID) throws {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "PendingRetryStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
        }
        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: documentsDir.appendingPathComponent(fileName))
        var records = load()
        records.append(PendingRetryRecord(
            id: UUID(), source: .photo,
            requestId: requestId,
            presetCardId: nil, presetImageName: nil,
            photoFileName: fileName, createdAt: .now
        ))
        do {
            try persist(records)
        } catch {
            try? FileManager.default.removeItem(
                at: documentsDir.appendingPathComponent(fileName)
            )
            throw error
        }
    }

    // MARK: - Load / Remove

    func load() -> [PendingRetryRecord] {
        guard let data = defaults.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([PendingRetryRecord].self, from: data)
        else { return [] }
        return records
    }

    /// 为旧版 photo 记录补上稳定的幂等键。已有键时直接复用；新键持久化成功后才返回。
    /// 调用方必须在此方法成功后才能发起生成请求，避免未落盘的 ID 被服务端看见。
    func ensureRequestId(for recordId: UUID) throws -> PendingRetryRecord {
        var records = load()
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
            createdAt: record.createdAt
        )
        records[index] = upgraded
        try persist(records)
        return upgraded
    }

    func remove(id: UUID) {
        var records = load()
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        if let fileName = records[idx].photoFileName {
            try? FileManager.default.removeItem(
                at: documentsDir.appendingPathComponent(fileName)
            )
        }
        records.remove(at: idx)
        try? persist(records)
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

    private func persist(_ records: [PendingRetryRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try metadataWriter(data)
    }
}
