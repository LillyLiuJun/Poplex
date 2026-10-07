import SwiftUI

/// Hero 卡封面左上角的标签行：类别名 + 理由（可无）。
///
/// 一行放得下就并排；放不下（大字号）改成上下两行，理由不再被截成 "Nothing new sinc…"。
/// 上下两行时理由最多两行、类别名也允许折行，极端字号（无障碍 5）也不丢字。
/// 视觉：照片底 = 纯白裸字 + 柔焦阴影；预设底（浅杏色）= 深棕字、无阴影（白字在浅底上只有 ~1.2:1）。
/// 并排那一支沿用拆组件前的排法；字体与字色以 `tab2HeroChipCategory` / 上面两种底色的 token 为准
/// （2026-10-06 起类别名为 13pt 常规，不再是拆组件时的 11.5pt 中粗）。
struct Tab2HeroCoverLabels: View {
    let categoryName: String
    /// nil = 不显示理由。例如空时间的 "Only words so far"：卡身的空态说明行已经说过一遍，封面不重复。
    let reasonText: String?
    /// true = 底是浅杏色预设图（深棕字、无阴影）；false = 照片底（白字 + 阴影）。
    var onPresetArt: Bool = false

    /// 两种封面底各自的字色与阴影。视图只读这一处，单测按两种底逐项锁定——
    /// 防止深棕 / 白字的分流被改反（改反后布局不变，高度类测试看不出来）。
    struct Palette: Equatable {
        let category: Color
        let reason: Color
        let hasShadow: Bool
    }

    static func palette(onPresetArt: Bool) -> Palette {
        onPresetArt
            ? Palette(category: AppTheme.Color.tab2HeroPresetLabelText,
                      reason: AppTheme.Color.tab2HeroPresetReasonText,
                      hasShadow: false)
            : Palette(category: AppTheme.Color.tab2HeroPhotoOverlayText,
                      reason: AppTheme.Color.tab2ReasonPillOnPhotoText,
                      hasShadow: true)
    }

    private var palette: Palette { Self.palette(onPresetArt: onPresetArt) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.Tab2Hero.Layout.coverLabelGap) {
                categoryLabel(lineLimit: 1)
                reasonLabel(lineLimit: 1)
            }
            VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.coverLabelStackGap) {
                categoryLabel(lineLimit: 2)
                reasonLabel(lineLimit: 2)
            }
        }
    }

    private func categoryLabel(lineLimit: Int) -> some View {
        Text(categoryName)
            .font(AppTheme.Font.tab2HeroChipCategory)
            .foregroundStyle(palette.category)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(CoverTextShadow(enabled: palette.hasShadow))
    }

    @ViewBuilder
    private func reasonLabel(lineLimit: Int) -> some View {
        if let reasonText {
            Text(reasonText)
                .font(AppTheme.Font.tab2ReasonPill)
                .foregroundStyle(palette.reason)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(CoverTextShadow(enabled: palette.hasShadow))
        }
    }
}

/// 图上文字的柔焦微阴影（近黑 50%，半径 6、下移 1）。
private struct CoverTextShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.shadow(
            color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(enabled ? AppTheme.Tab2Hero.Opacity.photoTextShadow : 0),
            radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
            x: 0,
            y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
        )
    }
}
