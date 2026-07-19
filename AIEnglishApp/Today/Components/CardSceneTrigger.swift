import SwiftUI

/// AI 追问区（温润极简）：顶部细分割线 + 橘色消息图标 + 主文字，不再整块底色。
/// 对齐参考稿 trigger-clean 的「系统级原生排版」。
struct CardSceneTrigger: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "message")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Color.brandStrong)
                .padding(.top, 2)
            Text(text)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Space.paddingS)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Color.border)
                .frame(height: 0.5)
        }
    }
}
