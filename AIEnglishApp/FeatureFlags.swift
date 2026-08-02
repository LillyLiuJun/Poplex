/// Central feature gate — flip a flag here to enable/disable a feature for a release build.
/// Set to `true` only when the feature is ready to ship.
enum FeatureFlags {
    /// Conversation (Talk) feature — voice-based dialogue practice.
    /// `false` → entry point shows "Coming soon" toast; all conversation code stays compiled.
    /// `true`  → navigates to ConversationView as normal.
    static let conversationEnabled = false
}
