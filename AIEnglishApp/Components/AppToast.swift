import SwiftUI

/// 短暂提示条——自动在 4 s 后消失（时长要够读完一整句文案）。用 .toast(message:) 挂在任意 View 上。
struct AppToast: View {
    let message: String
    /// 前置图标；nil 则不显示。警告类提示传图标提高可扫读性。
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingXS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.Color.brandStrong)   // 品牌橙点缀，警示但不刺眼
            }
            Text(message)
                .foregroundStyle(AppTheme.Color.textOnChip)   // 深底胶囊上的浅色文字 token
        }
        .font(AppTheme.Font.chineseFaint)
        .padding(.horizontal, AppTheme.Space.paddingM)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.textPrimary.opacity(0.82))
        .clipShape(Capsule())
        .shadow(color: AppTheme.Color.textPrimary.opacity(0.25), radius: 12, y: 4)   // 浮起，避免贴在内容上
    }
}

extension View {
    func toast(message: Binding<String?>, systemImage: String? = nil) -> some View {
        modifier(ToastModifier(message: message, systemImage: systemImage))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String? = nil

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                AppToast(message: msg, systemImage: systemImage)
                    .padding(.bottom, AppTheme.Space.paddingSection)
                    .task(id: msg) {
                        // sleep 被 .task(id:) 取消时抛 CancellationError；
                        // try? 把它吞成 nil 而非中断任务，所以必须显式检查取消，
                        // 否则旧任务会继续执行 message = nil，把刚出现的新 toast 清掉。
                        try? await Task.sleep(for: .seconds(4))
                        guard !Task.isCancelled else { return }
                        // 克制：无动画，直接出现/消失
                        message = nil
                    }
            }
        }
    }
}
