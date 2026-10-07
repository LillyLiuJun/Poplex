import SwiftUI

/// More 列表行内预设图（2026-10-04 方案 A 定稿）：不单独手画，从 Hero 预设图
/// （`PresetArtwork`）的同一画面生成——左侧细条原位保留，右侧主物体整体左移
/// 贴近细条，再裁出细条附近一块等比缩小。12 张缩略图与对应 Hero 永远一致。
///
/// 为什么要左移：Hero 画面里细条与主物体之间隔着约 55pt，直接裁 76pt 宽会只剩
/// 一根细条和主物体的一条窄边，认不出是什么（设计稿自查时实测过）。
struct RowPresetThumb: View {
    let category: SceneCategory

    // 以下为 Hero 画面绘图坐标（同 `PresetArtwork` 的 path 数据），不是界面间距。
    /// 裁取窗口：细条约在窗口左 1/4 处，宽高比 ≈ 76 : 119（行高下限现为 121，Canvas 按短边铺满，差异可忽略）。
    private static let cropWindow = CGRect(x: 114, y: 10, width: 120, height: 188)
    /// 分界线：其右侧（主物体与辅物）整体左移 `mainObjectShift`，左侧（细条）不动。
    private static let splitX: CGFloat = 170
    private static let mainObjectShift: CGFloat = 40

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(AppTheme.Color.tab2PresetArtBackground))

            let window = Self.cropWindow
            let scale = max(size.width / window.width, size.height / window.height)
            context.translateBy(x: (size.width - window.width * scale) / 2,
                                y: (size.height - window.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -window.minX, y: -window.minY)

            let farLeft: CGFloat = -1_000, span: CGFloat = 2_000
            var mainLayer = context
            mainLayer.translateBy(x: -Self.mainObjectShift, y: 0)
            mainLayer.clip(to: Path(CGRect(x: Self.splitX, y: farLeft, width: span, height: span)))
            PresetArtwork.draw(category, in: mainLayer)

            var accentLayer = context
            accentLayer.clip(to: Path(CGRect(x: farLeft, y: farLeft,
                                             width: Self.splitX - farLeft, height: span)))
            PresetArtwork.draw(category, in: accentLayer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Row preset thumbs · 12 categories") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(AppTheme.Tab2MoreRow.Layout.thumbnailWidth)), count: 4)) {
        ForEach(SceneCategory.allCases, id: \.self) { category in
            RowPresetThumb(category: category)
                .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth,
                       height: AppTheme.Tab2MoreRow.Layout.rowHeight)
                .clipped()
        }
    }
    .padding(AppTheme.Space.paddingPage)
    .background(AppTheme.Color.pageBg)
}
#endif
