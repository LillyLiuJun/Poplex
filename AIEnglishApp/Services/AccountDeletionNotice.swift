import Observation

/// 删号后需要展示给用户、但**必须活过根路由切换**的一次性提示。
///
/// 为什么不能就近放在 `SettingsView` 上：
/// 删号成功后 `LocalUserData.clearAll()` 会把 `onboarding_completed_at` 归 0，
/// `RootView` 随即从 `ContentView` 切到 `OnboardingView` —— **整个 ContentView
/// 子树（含承载 Settings 的 sheet）会被销毁**。挂在 SettingsView 上的 alert
/// 因此没有可靠的宿主，设置了也不会显示。
/// （更早的版本还先 `dismiss()` 再赋值，等于双重保证显示不出来。）
///
/// 所以把提示状态提到根一级：`RootView` 是路由本身，它不会被这次切换销毁。
///
/// 只用于「账号确实删掉了，但有东西没擦干净」这一种提示。
/// 「删除失败」仍留在 SettingsView —— 那种情况页面不会退出，就近提示更合适。
@Observable
final class AccountDeletionNotice {
    static let shared = AccountDeletionNotice()

    /// 非 nil 即在根一级弹出提示。用户确认后由 `RootView` 置回 nil。
    var message: String?

    private init() {}
}
