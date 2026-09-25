import SwiftUI

/// §2.3 候选对照图（视觉回归 main 基线，2026-09-22）：活动胶囊底色去灰泥。
///
/// **已选定 A · primary100**（2026-09-22，项目所有者拍板）。生产实现见
/// `Theme.swift` 的 `AppTheme.Color.tab2ActivityChipBg`/`tab2ActivityChipText`
/// （`Primitive.primary100` / `Primitive.neutral900`）；旧 `chipSurface`/`chipInk`
/// 已随之孤立删除。本文件保留作候选对照的历史记录，不是生产代码。
///
/// 问题不是色相（原 chipSurface #F4EFE8 本身是暖色），是明度差 × 面积——胶囊压在
/// 卡底 warmWhite #FFFDFB 上明度差只有 3~4%，叠加两行、约 60% 卡面积后整片发脏。
///
/// 四个候选底色**只能从 main 既有 primitive 里选**（CLAUDE.md：组件禁止裸色值，
/// 语义层必须引用 primitive；候选阶段直接标注色值仅为对照图打标，不代表生产实现
/// 会绕过 token 层）：
/// - **A · primary100 #FFF3EB（已选定）**（More 行 regular 缩略图渐变顶同色，§2.2 已用）
/// - B · primary200 #FFEADE
/// - C · neutral100 #F0EDE6（用户气泡 / 图片占位底同色）
/// - D · neutral50  #FCF8F3（暖纸页面 pageBg 同色——最保守，几乎不提亮）
///
/// 字色固定用 `AppTheme.Color.textPrimary`（= neutral900 #211811），不随候选变化。
private enum ChipColorCandidate: CaseIterable {
    case primary100, primary200, neutral100, neutral50

    var label: String {
        switch self {
        case .primary100: "A · primary100 #FFF3EB"
        case .primary200: "B · primary200 #FFEADE"
        case .neutral100: "C · neutral100 #F0EDE6"
        case .neutral50:  "D · neutral50  #FCF8F3"
        }
    }

    var bg: Color {
        switch self {
        case .primary100: Color(hex: 0xFFF3EB)
        case .primary200: Color(hex: 0xFFEADE)
        case .neutral100: Color(hex: 0xF0EDE6)
        case .neutral50:  Color(hex: 0xFCF8F3)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

private struct CandidateCapsuleGroup: View {
    let bg: Color
    let metrics: Tab2ActivityCapsuleMetrics

    private let names = ["Fixing a device", "Morning coffee", "Watering plants",
                          "Walking the dog", "Weekend cleaning"]

    var body: some View {
        GeometryReader { geo in
            let fit = Tab2CapsuleFit.fit(
                valid: names.map {
                    Tab2ActivityDisplay.ValidActivity(name: $0, occurrenceCount: 1, cover: nil)
                },
                activityCount: 7,
                blockedCount: 0,
                width: geo.size.width,
                metrics: metrics
            )
            VStack(alignment: .leading, spacing: metrics.rowGap) {
                row(fit.row1, more: fit.moreInRow1)
                if !fit.row2.isEmpty || fit.moreInRow2 != nil {
                    row(fit.row2, more: fit.moreInRow2)
                }
            }
            .frame(width: geo.size.width, height: metrics.twoRowHeight, alignment: .topLeading)
        }
        .frame(height: metrics.twoRowHeight)
    }

    private func row(_ names: [String], more: Int?) -> some View {
        HStack(spacing: metrics.rowGap) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(AppTheme.Font.tab2HeroCapsuleName)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, metrics.namePaddingH)
                    .frame(height: metrics.rowHeight)
                    .background(Capsule().fill(bg))
            }
            if let more {
                Text(" +\(more) more")
                    .font(AppTheme.Font.tab2HeroCapsuleMore)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, metrics.morePaddingH)
                    .frame(height: metrics.rowHeight)
            }
        }
        .frame(height: metrics.rowHeight)
    }
}

/// 一张候选卡：真实卡片材质（warmWhite 底 + cardBorder 描边 + cardShadow）+
/// 「Recent activities」小标题 + 满载两行胶囊组，让明度差在真实面积下可判断。
private struct CandidateCard: View {
    let candidate: ChipColorCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(candidate.label)
                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                .foregroundStyle(AppTheme.Color.textSecondary)

            VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
                Text("Recent activities")
                    .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                    .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Color.textMuted)

                CandidateCapsuleGroup(bg: candidate.bg, metrics: .hero())
            }
            .padding(AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Color.warmGlassSurface)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
    }
}

/// 供 `ScreenshotHarness` 截图验收复用的入口（非 private，其余全部私有）。
struct Tab2ActivityChipColorCandidatesView: View {
    var body: some View {
        VStack(spacing: AppTheme.Space.paddingSection) {
            Text("活动胶囊底色候选 · 字色固定 textPrimary #211811")
                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                .foregroundStyle(AppTheme.Color.textMuted)

            ForEach(ChipColorCandidate.allCases, id: \.self) { candidate in
                CandidateCard(candidate: candidate)
            }
        }
    }
}

#if DEBUG
#Preview("§2.3 活动胶囊底色候选对照") {
    ScrollView {
        Tab2ActivityChipColorCandidatesView()
            .padding(AppTheme.Space.paddingPage)
    }
    .background(AppTheme.Color.pageBg)
}
#endif
