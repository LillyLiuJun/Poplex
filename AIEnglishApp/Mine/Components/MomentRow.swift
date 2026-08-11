import SwiftUI

/// 单条 moment 行：两行布局（Scene Label + Content），Photo Moment 用缩略图，Text Moment 用场景图标。
/// 供 Tab2HeroCard 与 Tab2CategoryRow 共用，取代各自原有的 QuoteRow。
struct MomentRow: View {
    let scene: Tab2SubScene
    let category: SceneCategory

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            iconView
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(scene.sceneDetail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if scene.occurrenceCount > 1 {
                        Text("+\(scene.occurrenceCount)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }

                if let q = lineContent {
                    Text(q)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Icon
    // 紧凑行不展示实际缩略图（32×32 太小看不清，视觉乱）。
    // 大图体验只留给 featured 顶部区域；Photo Moment 在此用 photo 图标标识来源。

    @ViewBuilder
    private var iconView: some View {
        let symbolName = scene.isPhotoMoment ? "photo" : category.momentIconName
        Image(systemName: symbolName)
            .symbolVariant(.fill)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.42))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Line 2 content

    private var lineContent: String? {
        if let q = scene.quote, !q.isEmpty { return q }
        if let te = scene.targetExpression, !te.isEmpty { return te }
        return nil
    }
}

// MARK: - Moment-specific icon mapping
// 独立于 SceneCategory.iconName（Topics 行使用），不影响已有组件。

extension SceneCategory {
    var momentIconName: String {
        switch self {
        case .homeFamily:    return "house"
        case .workStudy:     return "briefcase"
        case .dailyRoutines: return "bed.double"
        case .food:          return "fork.knife"
        case .shopping:      return "bag"
        case .gettingAround: return "car"
        case .healthFitness: return "figure.run"
        case .leisure:       return "tv"
        case .tech:          return "laptopcomputer"
        case .weather:       return "cloud.sun"
        case .social:        return "bubble.left.and.bubble.right"
        case .other:         return "tag"
        }
    }
}
