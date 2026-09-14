import SwiftUI

/// Toast 两元语义层级（纯粹两元，坚决不使用任何红色报警色）
enum AppToastSemantic: Sendable, Equatable {
    /// 积极确认（晨曦暖橙底、焦墨橙字）
    case positive
    /// 动作受阻（沉静暖纸灰底、炭黑文字、素铅灰图标）
    case blocked

    var backgroundColor: Color {
        switch self {
        case .positive: AppTheme.Color.toastPositiveBg
        case .blocked:  AppTheme.Color.toastBlockedBg
        }
    }

    var borderColor: Color {
        switch self {
        case .positive: AppTheme.Color.brandInk.opacity(0.18)
        case .blocked:  AppTheme.Color.border
        }
    }

    var iconColor: Color {
        switch self {
        case .positive: AppTheme.Color.brandStrong.opacity(0.88)
        case .blocked:  AppTheme.Color.textSecondary.opacity(0.72)
        }
    }

    var textColor: Color {
        // 成功态与受阻态均采用沉静高级的炭黑墨水字，彻底告别偏红偏暗字体的报错焦虑感
        AppTheme.Color.textPrimary
    }

    var shadowColor: Color {
        switch self {
        case .positive: AppTheme.Color.brandStrong.opacity(0.06)
        case .blocked:  AppTheme.Shadow.cardColor.opacity(0.55)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .positive: 6
        case .blocked:  8
        }
    }
}

/// 统一的 Toast 呈现项（支持动态绑定消息、图标与语义）
struct AppToastItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let systemImage: String?
    let semantic: AppToastSemantic
    let lifetime: Duration

    init(
        id: UUID = UUID(),
        message: String,
        systemImage: String? = nil,
        semantic: AppToastSemantic = .blocked,
        lifetime: Duration = AppTheme.Motion.toastLifetime
    ) {
        self.id = id
        self.message = message
        self.systemImage = systemImage
        self.semantic = semantic
        self.lifetime = lifetime
    }
}

/// 微圆角（R8）藏书票/便签风格 Toast 视图
struct AppToast: View {
    let message: String
    var systemImage: String? = nil
    var semantic: AppToastSemantic = .blocked

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        message: String,
        systemImage: String? = nil,
        semantic: AppToastSemantic = .blocked
    ) {
        self.message = message
        self.systemImage = systemImage
        self.semantic = semantic
    }

    /// 辅助功能大字号（AX1~AX5）双模开关：普通字号锁死 328pt 等宽单行藏书票；
    /// AX 档解除宽度与单行限制，文案折行、卡片随内容增高，保证提示一字不落。
    private var isAccessibility: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        HStack(alignment: isAccessibility ? .top : .center, spacing: AppTheme.Space.paddingS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .foregroundStyle(semantic.iconColor)
                    .rotationEffect(systemImage.contains("paperplane") ? .degrees(-10) : .degrees(0))
            }
            Text(message)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(semantic.textColor)
                .lineLimit(isAccessibility ? 3 : 1)
                .fixedSize(horizontal: !isAccessibility, vertical: isAccessibility)
        }
        .padding(.vertical, isAccessibility ? AppTheme.Size.toastAccessibilityVPad : AppTheme.Space.paddingS)
        .padding(.horizontal, isAccessibility ? AppTheme.Space.paddingM : 0)
        // 普通字号：min=max=328 锁死等宽藏书票；AX 档：0～撑满，随内容自适应
        .frame(
            minWidth: isAccessibility ? 0 : AppTheme.Size.toastFixedWidth,
            maxWidth: isAccessibility ? .infinity : AppTheme.Size.toastFixedWidth
        )
        .padding(.horizontal, isAccessibility ? AppTheme.Space.paddingCard : 0)
        .background(semantic.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(semantic.borderColor, lineWidth: 0.6)
        )
        .shadow(
            color: semantic.shadowColor,
            radius: semantic.shadowRadius,
            x: 0,
            y: 3
        )
    }
}

/// 具备自动消失与无障碍广播能力的 Toast 视图（支持嵌入自定义 overlay）
struct AutoDismissingAppToast: View {
    @Binding var message: String?
    var systemImage: String? = nil
    var semantic: AppToastSemantic = .blocked
    var lifetime: Duration = AppTheme.Motion.toastLifetime

    init(
        message: Binding<String?>,
        systemImage: String? = nil,
        semantic: AppToastSemantic = .blocked,
        lifetime: Duration = AppTheme.Motion.toastLifetime
    ) {
        self._message = message
        self.systemImage = systemImage
        self.semantic = semantic
        self.lifetime = lifetime
    }

    var body: some View {
        if let currentMessage = message {
            AppToast(message: currentMessage, systemImage: systemImage, semantic: semantic)
                .modifier(ToastPresentationModifier(
                    message: currentMessage,
                    lifetime: lifetime,
                    taskId: currentMessage,
                    onClear: { self.message = nil }
                ))
        }
    }
}

enum AppToastPlacement: Sendable {
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
    /// 统一的 AppToast 呈现修饰器（推荐强类型项绑定）
    func appToast(
        item: Binding<AppToastItem?>,
        placement: AppToastPlacement = .bottom,
        extraBottomOffset: CGFloat = 0
    ) -> some View {
        modifier(ToastItemModifier(
            item: item,
            placement: placement,
            extraBottomOffset: extraBottomOffset
        ))
    }

    /// 统一的 AppToast 呈现修饰器（基于 String? 绑定）
    func appToast(
        message: Binding<String?>,
        systemImage: String? = nil,
        semantic: AppToastSemantic = .blocked,
        lifetime: Duration = AppTheme.Motion.toastLifetime,
        placement: AppToastPlacement = .bottom,
        extraBottomOffset: CGFloat = 0
    ) -> some View {
        modifier(ToastStringModifier(
            message: message,
            systemImage: systemImage,
            semantic: semantic,
            lifetime: lifetime,
            placement: placement,
            extraBottomOffset: extraBottomOffset
        ))
    }
}

/// 共享的 Toast 呈现行为：过渡动画 + 无障碍播报 + 到时自动消失。
/// AutoDismissingAppToast / ToastItemModifier / ToastStringModifier 三处共用，
/// 改 toast 动效只动这一处。
private struct ToastPresentationModifier: ViewModifier {
    let message: String
    let lifetime: Duration
    let taskId: AnyHashable
    let onClear: () -> Void

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.95)
                        .combined(with: .opacity)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8)),
                    removal: .opacity.animation(.easeInOut(duration: 0.25))
                )
            )
            .onAppear {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            .task(id: taskId) {
                try? await Task.sleep(for: lifetime)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    onClear()
                }
            }
    }
}

private struct ToastItemModifier: ViewModifier {
    @Binding var item: AppToastItem?
    let placement: AppToastPlacement
    var extraBottomOffset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: placement.alignment) {
            content
            if let current = item {
                AppToast(
                    message: current.message,
                    systemImage: current.systemImage,
                    semantic: current.semantic
                )
                .modifier(ToastPresentationModifier(
                    message: current.message,
                    lifetime: current.lifetime,
                    taskId: current.id,
                    onClear: { self.item = nil }
                ))
                .padding(
                    placement.paddingEdge,
                    placement == .bottom
                        ? AppTheme.Space.paddingSection + extraBottomOffset
                        : AppTheme.Space.paddingSection
                )
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: item != nil)
    }
}

private struct ToastStringModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String? = nil
    var semantic: AppToastSemantic = .blocked
    let lifetime: Duration
    let placement: AppToastPlacement
    var extraBottomOffset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: placement.alignment) {
            content
            if let currentMessage = message {
                AppToast(
                    message: currentMessage,
                    systemImage: systemImage,
                    semantic: semantic
                )
                .modifier(ToastPresentationModifier(
                    message: currentMessage,
                    lifetime: lifetime,
                    taskId: currentMessage,
                    onClear: { self.message = nil }
                ))
                .padding(
                    placement.paddingEdge,
                    placement == .bottom
                        ? AppTheme.Space.paddingSection + extraBottomOffset
                        : AppTheme.Space.paddingSection
                )
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message != nil)
    }
}
