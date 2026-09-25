import SwiftUI

/// More 列表行内预设图（2026-09-22 视觉回归 main 基线 §2.2）：只有「暖粉渐变底 +
/// 居中图标」两层——不是 CategoryPresetArtView 的缩小版，84pt 宽下光晕会糊成
/// 一坨、橙点会变成脏点，所以刻意不放光晕、不放橙点（取自
/// `git show main:AIEnglishApp/Mine/Components/RowPresetThumb.swift`）；
/// 图标 path 复用 `PresetIconShape` 的同一处真相。
///
/// main 另有区分「纯查词行」的 `faint` variant；查证刀 6b 现状（`Tab2ActivityRow`
/// 调用点、`Tab2MoreRow.Opacity` 无 `wordsOnlyRow` token）确认本分支 More 行不再
/// 区分该状态——查词行与有活动行共用同一套缩略图。faint 一套没有消费者，本刀
/// 不引入（交付报告已注明查证结论）。
struct RowPresetThumb: View {
    let category: SceneCategory

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Color.tab2MoreRowPresetGradientTop,
                    AppTheme.Color.tab2MoreRowPresetGradientBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            PresetIconShape(paths: category.tab2HeroPresetPaths)
                .stroke(
                    AppTheme.Color.tab2MoreRowPresetIcon.opacity(AppTheme.Tab2MoreRow.Opacity.presetIcon),
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
}

#if DEBUG
#Preview("Row preset thumb") {
    RowPresetThumb(category: .workStudy)
        .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth,
               height: AppTheme.Tab2MoreRow.Layout.rowHeight)
        .clipped()
        .padding(AppTheme.Space.paddingPage)
        .background(AppTheme.Color.pageBg)
}
#endif
