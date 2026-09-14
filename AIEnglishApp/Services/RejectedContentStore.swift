import Foundation

/// 被拒终态备忘：一次被服务端内容审核拦截的尝试（content_blocked）。
///
/// 为什么独立于 PendingRetryStore：被拒的尝试永远不会出现在服务器历史里，
/// 不存在「拿幂等键去服务器核对」的场景。不存 requestId、不参与 stale/pending
/// 二元扫描——从数据结构层面切断关联，比「约定不放进待重试清单」更可靠
/// （上一轮诈尸 bug 的根因正是终态被当成了待重试内容）。
///
/// 不存内容、只存事实：不存图片像素（第一步已删除）、不存原文字符串——
/// 被拒内容不留底。wasImage + 时刻足以在重启后还原「这里发生过一次拦截」。
struct RejectedContentMemo: Codable, Identifiable {
    let id: UUID          // 复用作时间线条目 id——注入幂等键
    let wasImage: Bool    // 曾含图片被拒——渲染时给占位块（图标+文案，不含真实像素）
    let createdAt: Date   // 被拒条目的时间线时刻，决定重启后插入位置
}

/// 被拒备忘存储：索引 JSON 存 UserDefaults，NSLock 串行化
/// （与 PendingRetryStore / LocalSuccessStore 同款风格）。
/// 无文件层（不存照片），因此读时清理只管索引本身。
final class RejectedContentStore {
    static let shared = RejectedContentStore(defaults: .standard)

    /// 备忘保留期：3 天。过期后在 load() 中惰性清除（写回磁盘），无需后台任务。
    /// 到期自然消失，不向用户提示「已清理」——与「看过一次、认知完成」的原则一致。
    static let retention: TimeInterval = 3 * 24 * 60 * 60

    private static let recordsKey = "rejected_content_memos"

    private let defaults: UserDefaults
    private let metadataWriter: (Data) throws -> Void
    /// 读改写互斥锁。注意：withLock 不可重入——锁内只调 readRecords/writeRecords。
    private let lock = NSLock()

    init(
        defaults: UserDefaults,
        metadataWriter: ((Data) throws -> Void)? = nil
    ) {
        self.defaults = defaults
        self.metadataWriter = metadataWriter ?? { data in
            defaults.set(data, forKey: Self.recordsKey)
            guard defaults.data(forKey: Self.recordsKey) == data else {
                throw NSError(
                    domain: "RejectedContentStore",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "metadata persist failed"]
                )
            }
        }
    }

    // MARK: - Save / Load / Clear

    /// 写入备忘。幂等：同 id 已存在则跳过（同一条目不会写两条）。
    func save(id: UUID, wasImage: Bool, createdAt: Date) {
        lock.withLock {
            var records = readRecords()
            guard !records.contains(where: { $0.id == id }) else { return }
            records.append(RejectedContentMemo(id: id, wasImage: wasImage, createdAt: createdAt))
            try? writeRecords(records)
        }
    }

    /// 读取有效备忘，读时惰性清理：过期记录过滤掉并写回磁盘。
    /// 写回失败静默——下次读取再过滤一次即可，最多多读一条过期记录，无副作用。
    func load() -> [RejectedContentMemo] {
        lock.withLock {
            let records = readRecords()
            let cutoff = Date.now.addingTimeInterval(-Self.retention)
            let live = records.filter { $0.createdAt > cutoff }
            if live.count != records.count {
                try? writeRecords(live)
            }
            return live
        }
    }

    /// 清空全部备忘——注销 / 删除账号时调用（LocalUserData.clearAll）。
    /// - Returns: 清理后仍残留的记录数。
    @discardableResult
    func clearAll() -> Int {
        lock.withLock {
            let records = readRecords()
            guard !records.isEmpty else { return 0 }
            do {
                try writeRecords([])
                return 0
            } catch {
                return records.count
            }
        }
    }

    // MARK: - Private

    /// 整体解码（必须锁内调用）。备忘无文件层、无照片关联：索引损坏时
    /// 直接返回空即可——损失只是「被拒事实」的展示，不涉及用户内容，
    /// 无需 PendingRetryStore 那套逐条抢救。
    private func readRecords() -> [RejectedContentMemo] {
        guard let data = defaults.data(forKey: Self.recordsKey) else { return [] }
        return (try? JSONDecoder().decode([RejectedContentMemo].self, from: data)) ?? []
    }

    /// 元数据落盘（锁内调用）。
    private func writeRecords(_ records: [RejectedContentMemo]) throws {
        let data = try JSONEncoder().encode(records)
        try metadataWriter(data)
    }
}
