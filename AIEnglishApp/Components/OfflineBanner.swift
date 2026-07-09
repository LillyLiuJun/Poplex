import SwiftUI

/// 离线提示条：断网且本地有缓存内容时展示，告知用户看到的是已保存内容。
/// 跨 Tab 复用（Tab1 历史 / 将来 Tab2 素材），样式统一走 AppTheme token。
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Image(systemName: "wifi.slash")
                .imageScale(.small)
            Text("You're offline")
                .font(AppTheme.Font.pos)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.inputBg)
    }
}

#Preview {
    OfflineBanner()
}
