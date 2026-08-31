import Foundation

/// 12 个固定场景分类的中英映射（与 Supabase `_shared/constants.ts` SCENE_CATEGORIES 保持同步）。
/// DB 存中文枚举值，UI 全程用英文标签（CLAUDE.md 硬约束：产品 UI 一律英文）。
/// 映射在此集中维护，组件只引用 SceneCategory.englishLabel，不得硬编码英文字符串。
enum SceneCategory: String, CaseIterable {
    case homeFamily    = "家庭与人际"
    case workStudy     = "工作与学业"
    case dailyRoutines = "日常起居"
    case food          = "饮食"
    case shopping      = "购物消费"
    case gettingAround = "出行交通"
    case healthFitness = "运动健康"
    case leisure       = "休闲娱乐"
    case tech          = "科技数码"
    case weather       = "天气环境"
    case social        = "情绪社交"
    case other         = "其他"

    /// 产品 UI 展示用英文标签
    var englishLabel: String {
        switch self {
        case .homeFamily:    return "Home & people"
        case .workStudy:     return "Work & study"
        case .dailyRoutines: return "Daily routines"
        case .food:          return "Food"
        case .shopping:      return "Shopping"
        case .gettingAround: return "Getting around"
        case .healthFitness: return "Health & fitness"
        case .leisure:       return "Leisure"
        case .tech:          return "Tech & gadgets"
        case .weather:       return "Weather"
        case .social:        return "Social"
        case .other:         return "Other"
        }
    }

    /// 从数据库返回的中文枚举值转 SceneCategory；
    /// 未知值（含旧数据中的"其他"）落到 .other。
    static func from(_ rawValue: String?) -> SceneCategory {
        guard let raw = rawValue else { return .other }
        return SceneCategory(rawValue: raw) ?? .other
    }

    /// Topics 行的类别图标（SF Symbol 名，线性风）。类别区分靠图标形状，
    /// 徽章底色统一浅橘单色（M2 方案），不按类别换色。
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
