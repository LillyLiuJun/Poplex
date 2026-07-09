import SwiftUI

/// 首启身份检查失败时的全屏态：本地无引导标记 + 连不上服务器 → 不猜身份、不误入引导，
/// 明确告知需要网络并提供重试。此 App 的首次启动（引导含 AI 生成）天然依赖网络。
struct ConnectionRetryView: View {
    let onRetry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't connect", systemImage: "wifi.slash")
        } description: {
            Text("Please check your connection and try again.")
        } actions: {
            Button("Retry") {
                Task { await onRetry() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Color.interactive)
        }
    }
}

#Preview {
    ConnectionRetryView { }
}
