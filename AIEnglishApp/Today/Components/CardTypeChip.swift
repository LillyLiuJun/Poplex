import SwiftUI

/// 卡片类型标签（温润极简：左上角单色灰 uppercase 文字，作 Meta 描述，不再彩色胶囊）。
/// 放在卡片内容 VStack 首行、左对齐；颜色一律走 token。
struct CardTypeChip: View {
    let label: String

    var body: some View {
        Text(label.uppercased())
            .font(AppTheme.Font.cardTypeChipLabel)
            .tracking(0.8)
            .foregroundStyle(AppTheme.Color.textMuted)
    }
}
