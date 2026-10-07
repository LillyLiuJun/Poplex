import SwiftUI

extension View {
    /// 整个 App 的字号封顶：系统字号超过 `AppTheme.Typography.appMaxDynamicTypeSize`（超大）时，
    /// App 里的字停在这一档，不再随「无障碍字号」继续放大；普通范围不受影响。
    ///
    /// 为什么封顶：无障碍那 5 档的正文是默认字号的 2～3 倍，会把封面标签、按钮、活动胶囊撑坏。
    /// 产品决定先不支持这几档（2026-10-06），待有用户反馈或上架要求时再放开——删掉 WindowGroup 上
    /// 这一处调用即可。
    ///
    /// 只管 SwiftUI 视图；系统自己画的警告框、菜单、选择器下拉仍跟随系统字号。
    /// 想在测试 / 调试页里单独看无障碍字号，用 `.environment(\.dynamicTypeSize, ...)` 在更内层覆盖。
    func appDynamicTypeCap() -> some View {
        dynamicTypeSize(...AppTheme.Typography.appMaxDynamicTypeSize)
    }
}

/// 窗口层面的封顶（2026-10-06）：把窗口的 UIKit 字号特征压在上限，之后窗口里的一切——
/// SwiftUI 视图、弹出的 sheet / fullScreenCover、直接用 UIFontMetrics 算尺寸的代码——
/// 看到的都是封顶后的字号。SwiftUI 的 dynamicTypeSize 本来就是从 UIKit 特征派生的。
/// 只有一个根视图上的 `.dynamicTypeSize(...)` 是封不住 sheet 的（实测），所以需要这一层。
/// 封顶是否正在生效，以及上限（UIKit 档位）。由 `App.init` 里的 `activate()` 置位——单元测试以 App
/// 为宿主，所以测试进程里它**也是生效的**。它只影响直接用 UIFontMetrics 算尺寸的代码（目前是 Tab2
/// 胶囊度量）；用 `.environment(\.dynamicTypeSize, ...)` 测无障碍字号的 SwiftUI 测试不受影响。
/// 要测「封顶没生效」时的行为，在测试里临时把 `activeCategory` 置 nil 并在结束时还原。
enum AppDynamicTypeLimit {
    /// 与 AppTheme.Typography.appMaxDynamicTypeSize 对应的 UIKit 档位。
    static let maxCategory: UIContentSizeCategory = .extraExtraExtraLarge

    nonisolated(unsafe) static var activeCategory: UIContentSizeCategory?

    /// 立刻让封顶「已生效」。必须在第一个视图渲染之前调用（App.init）：有的组件算一次度量后会跳过
    /// 没变化的重绘，晚于第一次渲染才置位，它们就一直按未封顶的字号算。
    static func activate() { activeCategory = maxCategory }

    /// 把一个字号档位压在上限之内；封顶没生效时原样返回。
    static func clamped(_ category: UIContentSizeCategory) -> UIContentSizeCategory {
        guard let limit = activeCategory, category > limit else { return category }
        return limit
    }
}

@MainActor
enum AppDynamicTypeCapInstaller {
    /// 系统设置里的字号（不受窗口覆盖影响，所以用屏幕的特征读）。
    private static var systemCategory: UIContentSizeCategory {
        UIScreen.main.traitCollection.preferredContentSizeCategory
    }

    private static var observers: [NSObjectProtocol] = []

    /// 在 App 启动后调用一次；之后系统字号变化、新窗口出现时自动重新套用。
    static func install() {
        AppDynamicTypeLimit.activate()
        guard observers.isEmpty else { apply(); return }
        let center = NotificationCenter.default
        for name in [UIContentSizeCategory.didChangeNotification, UIWindow.didBecomeKeyNotification, UIScene.didActivateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { apply() }
            })
        }
        apply()
    }

    static func apply() {
        let overLimit = systemCategory > AppDynamicTypeLimit.maxCategory
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if overLimit {
                    window.traitOverrides.preferredContentSizeCategory = AppDynamicTypeLimit.maxCategory
                } else if window.traitOverrides.contains(UITraitPreferredContentSizeCategory.self) {
                    window.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
                }
            }
        }
    }
}
