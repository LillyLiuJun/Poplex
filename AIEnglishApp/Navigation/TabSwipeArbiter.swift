import SwiftUI

/// 页签左右滑与内部横向滚动区之间的「让路」仲裁（2026-10-05）。
///
/// 背景：`RootTabContainer` 在整个内容区挂了 `simultaneousGesture(DragGesture)` 来切 Tab。
/// "More topics to explore" 是一块会横向滚动的胶囊区，手指在里面往回拨（向右划）时，
/// 胶囊在滚、全局手势也同时算数，松手就把页面切回了 Today。
///
/// 做法：**由横向滚动区自己认领手势**，而不是由容器记录它的屏幕坐标——这块区域的位置不固定
/// （随页面内容、待解锁 / 已解锁、卡片数量上下移动），按坐标判断既要不停更新、又容易错位。
/// 滚动区在手指横向拖动时置位，页签容器松手时先看这个标记，被认领就不切页。
/// 判定是「整段手势归它」，包括胶囊已在最左端的情况：误切页会丢掉用户的滚动位置，代价
/// 远大于「这里右划没切成」（从别处再划一次即可）。
final class TabSwipeArbiter {
    /// 标记在此之后多久还算有效。正常路径下由滚动区的手势结束主动释放；
    /// 这个时限只是兜底——手势被系统取消、拿不到 onEnded 时，标记不会一直卡住挡住下一次切页。
    static let claimLifetime: TimeInterval = 1.5

    private(set) var claimedAt: Date?

    /// 滚动区认领当前这次手势。
    func claim(now: Date = Date()) {
        claimedAt = now
    }

    /// 手势结束（或滚动区消失）时释放。
    func release() {
        claimedAt = nil
    }

    /// 页签容器松手时问一次：这次手势是否已被内部滚动区认领。
    func isClaimed(now: Date = Date()) -> Bool {
        guard let claimedAt else { return false }
        return now.timeIntervalSince(claimedAt) < Self.claimLifetime
    }
}

private struct TabSwipeArbiterKey: EnvironmentKey {
    /// 默认实例：没有页签容器的场景（预览、单页调试）里认领 / 释放都是无害空转。
    static let defaultValue = TabSwipeArbiter()
}

extension EnvironmentValues {
    var tabSwipeArbiter: TabSwipeArbiter {
        get { self[TabSwipeArbiterKey.self] }
        set { self[TabSwipeArbiterKey.self] = newValue }
    }
}

extension RootTabSwipeIntent {
    /// 内部横向滚动区该不该认领这次手势：区域真的能滚动，且已越过 10pt 最低确认门槛、
    /// 方向是明确水平（与页签容器同一把尺子，免得「它认为是横滑、我认为是竖滑」）。
    static func shouldClaim(translation: CGSize, isScrollable: Bool) -> Bool {
        guard isScrollable else { return false }
        guard hypot(translation.width, translation.height) >= 10 else { return false }
        return isHorizontal(translation)
    }
}

private struct ClaimsTabSwipeModifier: ViewModifier {
    let isScrollable: Bool
    @Environment(\.tabSwipeArbiter) private var arbiter

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if RootTabSwipeIntent.shouldClaim(translation: value.translation, isScrollable: isScrollable) {
                            arbiter.claim()
                        }
                    }
                    .onEnded { _ in
                        // 延后一拍释放：同一次触摸结束时，页签容器的 onEnded 与这里的 onEnded
                        // 先后顺序没有保证，同步清掉可能让它读到「已释放」。
                        DispatchQueue.main.async { arbiter.release() }
                    }
            )
            .onChange(of: isScrollable) { _, nowScrollable in
                if !nowScrollable { arbiter.release() }
            }
            .onDisappear { arbiter.release() }
    }
}

extension View {
    /// 声明「这是一块横向滚动区」：用户在其中横向拖动时，页签容器不再把这次手势当作切页。
    /// `isScrollable` 传内容是否真的超出可视宽度——放得下、不能滚动的区域不应抢手势。
    func claimsTabSwipe(isScrollable: Bool) -> some View {
        modifier(ClaimsTabSwipeModifier(isScrollable: isScrollable))
    }
}
