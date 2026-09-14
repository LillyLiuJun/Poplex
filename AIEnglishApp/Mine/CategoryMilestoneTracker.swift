import Foundation

struct CategoryMilestoneSnapshot: Equatable {
    let categoryID: String
    let count: Int
}

struct CategoryMilestonePresentation: Equatable, Identifiable {
    let categoryID: String
    let previousCount: Int
    let currentCount: Int

    var id: String { categoryID }
}

/// Detects observed `<20 → ≥20` crossings and remembers them per account.
/// The first observation is only a baseline, so an app update never replays
/// celebrations for categories that were already unlocked beforehand.
final class CategoryMilestoneTracker {
    private let defaults: UserDefaults
    private let threshold: Int
    private let keyPrefix = "tab2_category_milestones_v1"

    init(defaults: UserDefaults = .standard, threshold: Int = 20) {
        self.defaults = defaults
        self.threshold = threshold
    }

    /// 历史记录里的旧中文 categoryID 归一化为当前英文键。
    /// 场景分类英文 Key 改造（2026-09）之前，counts/achieved 里存的是中文键；
    /// 不归一化会让同一分类换键后 previous 查不到 → 已解锁的分类重放里程碑庆祝。
    /// 只改写确定的历史中文键（`SceneCategory.normalizedID`），未知值原样保留——
    /// 保守归一化，避免虚构/未来键被错误合并进 Other 的分类历史。
    private static func normalizedCategoryID(_ key: String) -> String {
        SceneCategory.normalizedID(key)
    }

    func observeBatch(
        _ snapshots: [CategoryMilestoneSnapshot],
        userID: String
    ) -> [CategoryMilestonePresentation] {
        let countsKey = "\(keyPrefix).\(userID).counts"
        let achievedKey = "\(keyPrefix).\(userID).achieved"
        let currentCounts = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.categoryID, $0.count) }
        )

        guard let stored = defaults.dictionary(forKey: countsKey) else {
            defaults.set(currentCounts, forKey: countsKey)
            defaults.set(
                snapshots.filter { $0.count >= threshold }.map(\.categoryID),
                forKey: achievedKey
            )
            return []
        }

        // 归一化后同键合并取 max：改造窗口期中文键（旧值）与英文键（新值）并存，
        // count 单调递增，新值恒 ≥ 旧值，取 max 安全。
        let previousCounts = stored.reduce(into: [String: Int]()) { result, pair in
            if let count = pair.value as? NSNumber {
                let key = Self.normalizedCategoryID(pair.key)
                result[key] = max(result[key] ?? 0, count.intValue)
            }
        }
        var achieved = Set(
            (defaults.stringArray(forKey: achievedKey) ?? []).map(Self.normalizedCategoryID)
        )

        let crossings = snapshots.filter { snapshot in
            let previous = previousCounts[snapshot.categoryID] ?? 0
            return previous < threshold
                && snapshot.count >= threshold
                && !achieved.contains(snapshot.categoryID)
        }

        achieved.formUnion(crossings.map(\.categoryID))
        defaults.set(previousCounts.merging(currentCounts) { _, current in current }, forKey: countsKey)
        defaults.set(Array(achieved).sorted(), forKey: achievedKey)

        return crossings.map { crossing in
            CategoryMilestonePresentation(
                categoryID: crossing.categoryID,
                previousCount: previousCounts[crossing.categoryID] ?? 0,
                currentCount: crossing.count
            )
        }
    }
}
