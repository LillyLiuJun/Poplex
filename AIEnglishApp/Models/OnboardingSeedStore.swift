import Foundation

/// One-shot in-process handoff: OnboardingView writes seed entries here;
/// TodayViewModel reads and clears them on the first loadHistory() call.
/// Lives in memory only — not persisted.
/// Preset-card path: [userBubble(asset image) + aiCard] injected when server has nothing.
/// Own-photo path: server already has the record; seed is left empty.
/// `requestId` 是 seed 卡片的幂等键：弱网下服务器其实已落库（响应迟到被误判失败）
/// 时，loadHistory 用它把 seed 与服务端记录去重，避免首屏同一张卡出现两次。
final class OnboardingSeedStore {
    static let shared = OnboardingSeedStore()
    var entries: [TimelineEntry] = []
    var requestId: UUID?
    private init() {}
}
