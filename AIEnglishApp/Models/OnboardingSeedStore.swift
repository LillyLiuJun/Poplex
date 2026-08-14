import Foundation

/// One-shot in-process handoff: OnboardingView writes seed entries here;
/// TodayViewModel reads and clears them on the first loadHistory() call.
/// Lives in memory only — not persisted.
/// Preset-card path: [userBubble(asset image) + aiCard] injected when server has nothing.
/// Own-photo path: server already has the record; seed is left empty.
final class OnboardingSeedStore {
    static let shared = OnboardingSeedStore()
    var entries: [TimelineEntry] = []
    private init() {}
}
