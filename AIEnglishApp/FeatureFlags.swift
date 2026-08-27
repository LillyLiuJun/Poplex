/// Central feature gate — flip a flag here to enable/disable a feature for a release build.
/// Set to `true` only when the feature is ready to ship.
enum FeatureFlags {
    /// Conversation (Talk) feature — voice-based dialogue practice.
    /// `false` → entry point shows "Coming soon" toast; all conversation code stays compiled.
    /// `true`  → navigates to ConversationView as normal.
    ///
    /// ⚠️ **打开这个开关前必须同时加回两条权限声明**，否则 App 会在请求权限时**直接崩溃**
    /// （iOS 对缺少 usage description 的权限请求是终止进程，不是返回失败）：
    ///
    /// ```
    /// INFOPLIST_KEY_NSMicrophoneUsageDescription =
    ///   "Speak out loud to practice English with your AI tutor.";
    /// INFOPLIST_KEY_NSSpeechRecognitionUsageDescription =
    ///   "Your speech is transcribed so your AI tutor can respond to what you say.";
    /// ```
    ///
    /// 这两条在 2026-08-27 被移出 `project.pbxproj`：本版对话功能不上线，
    /// 而**声明了权限却没有对应功能是常见的拒审理由**（Guideline 5.1.1）。
    /// 相机与相册权限不受影响——Tab1 拍照 / 选图一直在用。
    static let conversationEnabled = false
}
