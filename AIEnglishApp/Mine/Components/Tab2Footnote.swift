import SwiftUI

/// Tab2 区块下方的微缩注脚：前置小图标 + 11pt 次级灰说明句。
/// 图标与首行文字按基线对齐；文字折行时第二行与第一行文字左对齐（图标独占左列）。
struct Tab2Footnote: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Tab2ExploreTopics.Layout.footnoteIconToText) {
            Image(systemName: iconName)
                // 与注脚同一字体 token：图标随 Dynamic Type 与文字同步缩放。
                .font(AppTheme.Font.metaNote)
                .accessibilityHidden(true)

            Text(text)
                .font(AppTheme.Font.metaNote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.footnote)
    }
}
