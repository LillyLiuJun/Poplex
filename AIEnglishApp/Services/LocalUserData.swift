import Foundation

/// 「这台设备上属于当前账号的一切」的清理入口——单一真源。
///
/// 为什么需要它：删除账号只清掉服务器，而 App 随后会**静默注册一个新的匿名账号**。
/// 本地残留的缓存 / 待重试记录 / 成长进度若不一并清除，新账号会直接读到上一个账号的
/// 内容——用户看到的是「账号删了，内容还在」。
///
/// 为什么集中在一处：本地状态散落在 4 个存储里（两个 UserDefaults 命名空间、
/// 一个 Application Support 目录、一个 Documents 图片目录）。此前删号只清了 5 个
/// UserDefaults 标志位，其余全部漏掉，因为**没有任何地方列出过完整清单**。
/// 新增本地存储时，唯一要记得的事就是在这里补一行。
///
/// **已经漏过两次**（2026-08-27 code review 发现）：`img_cache` 里的用户照片、
/// `onboarding_sync_pending` 标记。教训是「凭记忆列清单」必然遗漏——
/// 新增任何写 UserDefaults / 写磁盘的存储时，请同时在这里登记。
enum LocalUserData {

    /// 驱动**根路由**的两个标志位：它们决定 App 显示 onboarding 还是主界面。
    ///
    /// 这两个必须**显式写 0**，不能用 `removeObject`。
    /// `RootView` 用 `@AppStorage` 观察它们，而 `@AppStorage` 对「键被移除」
    /// 的响应并不可靠（实测：removeObject 后进程内立即读回仍是旧值，
    /// 界面也不切换；但落盘确实清掉了——即状态在内存与磁盘之间不一致）。
    /// 写 0 会产生一次明确的「值变化」通知，`@AppStorage` 必定收到，
    /// 且 0 正是「未完成引导」的语义，与默认值一致。
    private static let routingFlags = [
        "onboarding_completed_at",     // 引导完成标记 —— 归 0 才会回到首启
        "ai_consent_accepted_at"       // AI 使用同意门
    ]

    /// 其余账号级状态：没有视图直接观察，移除即可。
    private static let accountScopedKeys = [
        Tab2Defaults.permanentlyUnlocked,
        Tab2Defaults.firstUnlockShown,
        "mine_last_scene_count",       // Tab2「新增 N 条」的基线
        ProfileService.onboardingSyncPendingKey  // 引导完成待同步到服务器的标记
    ]

    /// `CategoryMilestoneTracker` 的键前缀。
    /// 它本身按 userID 分键（`<prefix>.<userID>.counts`），不会串到新账号，
    /// 但删号后这些键永远不会再被读取——按前缀清掉，避免无限累积。
    private static let milestoneKeyPrefix = "tab2_category_milestones_v1"

    /// 清空这台设备上属于当前账号的一切。
    ///
    /// 调用时机：删除账号成功之后、注销之后。**顺序无关**，各存储互不依赖。
    /// 失败不抛错：这是尽力而为的清理，任何一项失败都不该阻断「已经删成功」这个事实。
    /// - Returns: `true` 表示确认已清空；`false` 表示有残留。
    ///   **调用方必须据此决定是否向用户宣称「数据已全部删除」** ——
    ///   此前这里所有失败都被 `try?` 吞掉、UI 无条件宣称已清空，
    ///   那是在做一个我们并不知道是否兑现了的隐私承诺。
    @discardableResult
    static func clearAll() async -> Bool {
        var leftovers = 0

        // 1. 服务器数据的本地镜像（Tab1 历史 / Tab2 首页）
        leftovers += await LocalCache.shared.removeAll()

        // 2. 用户上传照片的两级缓存（内存 NSCache + Caches/img_cache 磁盘文件）。
        //    这一项曾被漏掉：里面是用户自己的照片，删号后仍留在设备上。
        leftovers += ImageCache.shared.clearAll()

        // 3. 未完成与已完成的本地生成记录（索引层）
        leftovers += PendingRetryStore.shared.clearAll()
        leftovers += LocalSuccessStore.shared.clearAll()

        // 4. 照片文件层兜底。两个 store 的 `remove(id:)` 先写元数据、再 `try?` 删文件，
        //    所以「索引已清空但 JPEG 还在」完全可能——只回读索引会**谎报清理成功**。
        //    索引损坏 / 丢失产生的孤儿文件同样只有扫目录才找得到。
        leftovers += sweepOrphanPhotos()

        // 5. 全部账号级 UserDefaults 状态
        await clearDefaults(UserDefaults.standard)

        return leftovers == 0
    }

    /// 扫掉 Documents 根目录里残留的照片文件。
    ///
    /// 安全前提：全项目**只有** `PendingRetryStore` / `LocalSuccessStore` 往
    /// Documents 根写文件，且文件名一律是 `<UUID>.jpg`（已 grep 确认）。
    /// 因此按 `.jpg` 后缀清扫不会误伤其它数据。若将来有别的东西往 Documents
    /// 写 jpg，必须改成带前缀的命名，否则这里会误删。
    ///
    /// 放在 `LocalUserData` 而不是各 store 内部：两个 store 共用同一个
    /// Documents 根目录，各扫各的会互删对方的文件。
    /// - Returns: 扫描后仍残留的照片文件数。
    static func sweepOrphanPhotos(
        in directory: URL? = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
    ) -> Int {
        guard let directory else { return 0 }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else {
            // 目录读不出来 → 无法确认是否已空，按「有残留」上报，宁可保守
            return fm.fileExists(atPath: directory.path) ? 1 : 0
        }
        var remaining = 0
        for file in files where file.pathExtension.lowercased() == "jpg" {
            do { try fm.removeItem(at: file) } catch { remaining += 1 }
        }
        return remaining
    }

    /// UserDefaults 部分单独成方法并可注入——这是本文件唯一能脱离单例测试的部分，
    /// 而「路由标志位必须归 0 而不是移除」这条正是最容易被后人改回去的地方。
    static func clearDefaults(_ defaults: UserDefaults) async {
        accountScopedKeys.forEach { defaults.removeObject(forKey: $0) }

        // 根路由标志位：显式归 0（理由见 routingFlags 注释），
        // 并且必须在主线程写——@AppStorage 的观察与视图刷新都在主线程，
        // 从后台线程写会让「值变了」和「界面重算」错开。
        await MainActor.run {
            for key in routingFlags { defaults.set(0.0, forKey: key) }
        }

        // 成长里程碑（按前缀清，覆盖所有历史 userID）
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(milestoneKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
