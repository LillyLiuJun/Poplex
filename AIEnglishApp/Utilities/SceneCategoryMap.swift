import Foundation

/// 12 固定场景分类。rawValue = 英文 key（新纪录直接写 DB）。
/// 旧数据中的中文 rawValue 由 `SceneCategory.from(_:)` 的 legacyMap 兼容映射。
/// 组件只引用 `SceneCategory.englishLabel`，不得硬编码字符串。
enum SceneCategory: String, CaseIterable {
    case homeFamily    = "Home & Family"
    case workStudy     = "Work & Study"
    case dailyRoutines = "Daily Routine"
    case food          = "Food & Drink"
    case shopping      = "Shopping"
    case gettingAround = "Travel & Commute"
    case healthFitness = "Health & Fitness"
    case leisure       = "Hobbies & Leisure"
    case tech          = "Digital & Tech"
    case weather       = "Weather & Nature"
    case social        = "Social & Feelings"
    case other         = "Other"

    /// 产品 UI 展示用英文标签（rawValue 本身即标签，保留此属性以保持调用侧一致）
    var englishLabel: String { rawValue }

    /// 持久化 Key 的归一化：旧中文键 → 英文键；其余（新英文键、未知值）原样返回。
    /// 与 `from(_:)` 的差异：未知值不落入 `.other`——归一化只应改写确定的历史键，
    /// 否则虚构/未来键（如测试用的占位键）会被错误合并进 Other 的分类历史。
    static func normalizedID(_ key: String) -> String {
        legacyMap[key]?.rawValue ?? key
    }

    /// 从数据库值转 SceneCategory。
    /// 同时支持：
    ///   · 新英文 key（直接 rawValue 匹配）
    ///   · 旧中文 key（legacyMap 兼容映射）
    ///   · 未知值 → .other
    static func from(_ rawValue: String?) -> SceneCategory {
        guard let raw = rawValue else { return .other }
        // 1. 尝试直接匹配英文 rawValue（新数据）
        if let match = SceneCategory(rawValue: raw) { return match }
        // 2. 兼容旧中文 key（历史 DB 行）
        return legacyMap[raw] ?? .other
    }

    /// 旧中文值 → SceneCategory 映射表（方案A向后兼容层）
    private static let legacyMap: [String: SceneCategory] = [
        "家庭与人际": .homeFamily,
        "工作与学业": .workStudy,
        "日常起居":   .dailyRoutines,
        "饮食":       .food,
        "购物消费":   .shopping,
        "出行交通":   .gettingAround,
        "运动健康":   .healthFitness,
        "休闲娱乐":   .leisure,
        "科技数码":   .tech,
        "天气环境":   .weather,
        "情绪社交":   .social,
        "其他":       .other,
    ]

    /// Topics 行的类别图标（SF Symbol 名，线性风）。
    var iconName: String {
        switch self {
        case .homeFamily:    return "house"
        case .workStudy:     return "briefcase"
        case .dailyRoutines: return "sun.horizon"
        case .food:          return "fork.knife"
        case .shopping:      return "bag"
        case .gettingAround: return "tram"
        case .healthFitness: return "figure.run"
        case .leisure:       return "gamecontroller"
        case .tech:          return "laptopcomputer"
        case .weather:       return "cloud.sun"
        case .social:        return "bubble.left.and.bubble.right"
        case .other:         return "ellipsis"
        }
    }
}
