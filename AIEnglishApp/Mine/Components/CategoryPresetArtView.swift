import SwiftUI

/// Tab2 Hero 卡顶部预设图（设计方案 §6.3）。
/// 当分类零真实照片（`hero_photos` 为空）时，整块替换拼图。
///
/// 现状为**占位实现**：暖色底 + 分类图标。设计方案 §13.4 规划的 12 张品牌暖橙/暖纸
/// 散点插画尚未产出——资源到位后，只需把下方 `placeholderArt` 换成
/// `Image(category.presetAssetName)` 之类，对外接口（category/label/pops/more）不变。
struct CategoryPresetArtView: View {
    let category: SceneCategory
    let categoryLabel: String
    let popsText: String
    let moreCount: Int

    var body: some View {
        ZStack {
            placeholderArt
            HeroTopOverlay(categoryLabel: categoryLabel, popsText: popsText, moreCount: moreCount)
        }
        .frame(height: 178)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 占位美术（资源到位后整体替换）

    private var placeholderArt: some View {
        ZStack {
            AppTheme.Color.brandSubtleBg
            Image(systemName: category.momentIconName)
                .font(.system(size: 44, weight: .ultraLight))   // glyph 尺寸，豁免字体 token 规则
                .foregroundStyle(AppTheme.Color.textPrimary.opacity(0.16))
        }
    }
}
