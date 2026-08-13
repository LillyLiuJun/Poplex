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

        let previousCounts = stored.reduce(into: [String: Int]()) { result, pair in
            if let count = pair.value as? NSNumber {
                result[pair.key] = count.intValue
            }
        }
        var achieved = Set(defaults.stringArray(forKey: achievedKey) ?? [])

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
