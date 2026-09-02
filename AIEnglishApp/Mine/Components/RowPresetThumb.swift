import SwiftUI

/// More 列表行内预设图（§5.6）：只有「暖色渐变底 + 居中图标 28」两层。
/// 不是 CategoryPresetArtView 的缩小版——84pt 宽下光晕会糊成一坨、橙点会变成脏点，
/// 所以这里刻意不放光晕、不放橙点；图标 path 复用 PresetIconShape 的同一处真相。
struct RowPresetThumb: View {
    /// 常规 = 有 moment 的行；更淡 = 纯查词行（wordsOnly）。
    enum Variant {
        case regular
        case faint
    }

    let category: SceneCategory
    let variant: Variant

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [gradientTop, gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            PresetIconShape(paths: category.tab2HeroPresetPaths)
                .stroke(
                    AppTheme.Color.tab2MoreRowPresetIcon.opacity(iconOpacity),
                    style: StrokeStyle(
                        lineWidth: AppTheme.Tab2MoreRow.Layout.presetIconStrokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(
                    width: AppTheme.Tab2MoreRow.Layout.presetIconSize,
                    height: AppTheme.Tab2MoreRow.Layout.presetIconSize
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gradientTop: Color {
        switch variant {
        case .regular: AppTheme.Color.tab2MoreRowPresetGradientTop
        case .faint:   AppTheme.Color.tab2MoreRowPresetFaintGradientTop
        }
    }

    private var gradientBottom: Color {
        switch variant {
        case .regular: AppTheme.Color.tab2MoreRowPresetGradientBottom
        case .faint:   AppTheme.Color.tab2MoreRowPresetFaintGradientBottom
        }
    }

    private var iconOpacity: CGFloat {
        switch variant {
        case .regular: AppTheme.Tab2MoreRow.Opacity.presetIcon
        case .faint:   AppTheme.Tab2MoreRow.Opacity.presetIconFaint
        }
    }
}

#if DEBUG
#Preview("Row preset thumb · regular / faint") {
    HStack(spacing: AppTheme.Space.paddingM) {
        RowPresetThumb(category: .workStudy, variant: .regular)
            .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth,
                   height: AppTheme.Tab2MoreRow.Layout.rowHeight)
            .clipped()
        RowPresetThumb(category: .workStudy, variant: .faint)
            .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth,
                   height: AppTheme.Tab2MoreRow.Layout.rowHeight)
            .clipped()
    }
    .padding(AppTheme.Space.paddingPage)
    .background(AppTheme.Color.pageBg)
}
#endif
