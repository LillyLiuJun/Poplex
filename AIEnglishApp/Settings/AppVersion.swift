import Foundation

extension Bundle {
    /// App 的市场版本号（Xcode 的 Marketing Version / `CFBundleShortVersionString`）。
    ///
    /// 读不到时返回空字符串，**不返回任何兜底数字**：此前两处调用各自硬编码了
    /// `"1.0.0"` 作为 fallback，一旦 Info.plist 读取失败，界面会显示一个与
    /// App Store 上不一致的假版本号，反馈上报也会带着假版本号进库，
    /// 让线上问题无法定位到真实构建。空字符串让调用方自行决定隐藏或省略。
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
