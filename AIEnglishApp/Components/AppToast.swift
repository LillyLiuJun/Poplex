import SwiftUI

/// 短暂提示条——默认给整句 4s 阅读时间，短反馈可传独立 lifetime。用 .toast(message:) 挂在任意 View 上。
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

/// 复用 AppToast 的呈现与自动消失逻辑；页面可决定它相对固定控件的位置。
struct AutoDismissingAppToast: View {
    @Binding var message: String?
    var systemImage: String? = nil
    var lifetime: Duration = AppTheme.Motion.toastLifetime

    var body: some View {
        if let message {
            AppToast(message: message, systemImage: systemImage)
                .onAppear {
                    // toast 出现时向读屏播报同一句文案：VoiceOver 用户看不到
                    // 短暂浮现的提示，静默出现 = 反馈不存在（审计发现 ②）。
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
                .task(id: message) {
                    try? await Task.sleep(for: lifetime)
                    guard !Task.isCancelled else { return }
                    self.message = nil
                }
        }
    }
}

enum AppToastPlacement {
    case top
    case bottom

    var alignment: Alignment {
        switch self {
        case .top: .top
        case .bottom: .bottom
        }
    }

    var paddingEdge: Edge.Set {
        switch self {
        case .top: .top
        case .bottom: .bottom
        }
    }
}

extension View {
    func toast(
        message: Binding<String?>,
        systemImage: String? = nil,
        lifetime: Duration = AppTheme.Motion.toastLifetime,
        placement: AppToastPlacement = .bottom
    ) -> some View {
        modifier(ToastModifier(
            message: message,
            systemImage: systemImage,
            lifetime: lifetime,
            placement: placement
        ))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String? = nil
    let lifetime: Duration
    let placement: AppToastPlacement

    func body(content: Content) -> some View {
        ZStack(alignment: placement.alignment) {
            content
            AutoDismissingAppToast(
                message: $message,
                systemImage: systemImage,
                lifetime: lifetime
            )
            .padding(placement.paddingEdge, AppTheme.Space.paddingSection)
        }
    }
}

// MARK: - Global Toast Dispatcher

extension Notification.Name {
    static let showAppToast = Notification.Name("showAppToast")
}

struct AppToastPayload: Sendable {
    let message: String
    let systemImage: String?
    let lifetime: Duration

    init(message: String, systemImage: String? = nil, lifetime: Duration = AppTheme.Motion.toastLifetime) {
        self.message = message
        self.systemImage = systemImage
        self.lifetime = lifetime
    }
}

enum ToastCenter {
    @MainActor
    static func show(_ message: String, systemImage: String? = nil, lifetime: Duration = AppTheme.Motion.toastLifetime) {
        NotificationCenter.default.post(
            name: .showAppToast,
            object: AppToastPayload(message: message, systemImage: systemImage, lifetime: lifetime)
        )
    }
}
