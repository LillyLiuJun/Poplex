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

    init(defaults: UserDefaults, documentsDir: URL) {
        self.defaults = defaults
        self.documentsDir = documentsDir
    }

    // MARK: - Save

    /// 预设卡：只记元数据，图片用内置 asset（无需落盘）。
    func savePreset(cardId: String, imageName: String) {
        var records = load()
        records.removeAll { $0.source == .presetCard && $0.presetCardId == cardId }  // 幂等
        records.append(PendingRetryRecord(
            id: UUID(), source: .presetCard,
            presetCardId: cardId, presetImageName: imageName,
            photoFileName: nil, createdAt: .now
        ))
        persist(records)
    }

    /// 照片：JPEG 落盘 + 记元数据。失败抛错（调用方决定是否提示）。
    func savePhoto(_ image: UIImage) throws {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "PendingRetryStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
        }
        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: documentsDir.appendingPathComponent(fileName))
        var records = load()
        records.append(PendingRetryRecord(
            id: UUID(), source: .photo,
            presetCardId: nil, presetImageName: nil,
            photoFileName: fileName, createdAt: .now
        ))
        persist(records)
    }

    // MARK: - Load / Remove

    func load() -> [PendingRetryRecord] {
        guard let data = defaults.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([PendingRetryRecord].self, from: data)
        else { return [] }
        return records
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
        persist(records)
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

    private func persist(_ records: [PendingRetryRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.recordsKey)
        }
    }
}
