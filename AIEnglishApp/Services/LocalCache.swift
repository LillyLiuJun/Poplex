import Foundation

/// 通用本地读缓存：把服务器返回的原始 JSON 字节（Data）按 key 存到本地，
/// 读取时用现有 decoder 还原——写=落盘响应体、读=喂给现成解析器，零侵入现有模型。
///
/// 存储位置选 Application Support 而非 Caches：
///   - Caches 在手机存储紧张时会被系统自动清空，无法兑现「永久缓存」；
///   - Application Support 系统绝不自动清、且在 App 沙盒内，无需任何权限。
/// 文件标记「排除 iCloud 备份」：本地只是服务器数据的镜像（服务器为正本），
///   不必占用用户的备份空间，丢了也能联网重新拉取。
final class LocalCache {
    static let shared = LocalCache()

    /// 缓存条目 key —— 每个来源一个文件
    enum Key: String {
        case messages   // Tab1 历史对话（get-messages）
        case scenes     // Tab2 场景素材（后续切片）
        case vocabs     // Tab2 生词（后续切片）
    }

    private let dir: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("local_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        excludeFromBackup(dir)
    }

    /// 写入：成功请求后把原始响应体落盘
    func save(_ data: Data, key: Key) {
        let url = fileURL(for: key)
        do {
            try data.write(to: url, options: .atomic)
            excludeFromBackup(url)
        } catch {
            print("[LocalCache] save \(key.rawValue) failed:", error)
        }
    }

    /// 读取：返回上次落盘的原始字节，交给调用方用现有 decoder 解码
    func load(key: Key) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    /// 清除单个缓存（预留：素材被删除等场景）
    func remove(key: Key) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    // MARK: - Tombstones（软删除同步：防止缓存里的旧条目在服务器删除后重新出现）

    /// 乐观删除时立即标记：下次读缓存会过滤掉此 ID，不管缓存字节是否已更新。
    func addTombstone(_ id: UUID, key: Key) {
        var set = tombstones(for: key)
        set.insert(id.uuidString)
        UserDefaults.standard.set(Array(set), forKey: tombstoneKey(for: key))
    }

    /// 撤销恢复时移除标记，让该 ID 重新出现在缓存视图里。
    func removeTombstone(_ id: UUID, key: Key) {
        var set = tombstones(for: key)
        set.remove(id.uuidString)
        UserDefaults.standard.set(Array(set), forKey: tombstoneKey(for: key))
    }

    /// 成功拉取服务器最新数据后调用：服务器数据为正本，已不含被删条目，墓碑可清空。
    func clearTombstones(for key: Key) {
        UserDefaults.standard.removeObject(forKey: tombstoneKey(for: key))
    }

    func tombstones(for key: Key) -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: tombstoneKey(for: key)) ?? []
        return Set(arr)
    }

    private func tombstoneKey(for key: Key) -> String { "cache_tombstone_\(key.rawValue)" }

    private func fileURL(for key: Key) -> URL {
        dir.appendingPathComponent(key.rawValue + ".json")
    }

    private func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
