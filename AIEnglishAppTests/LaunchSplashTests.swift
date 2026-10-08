import Testing
import Foundation
import CoreGraphics
@testable import AIEnglishApp

/// 开屏动画：时间轴的「停住等后台确认」规则，以及几个关键帧的几何。
@MainActor
struct LaunchSplashTests {
    private typealias M = AppTheme.Motion.Launch

    // iPhone 16 Pro 全屏尺寸与安全区上沿
    private let layout = LaunchSplashLayout(screen: CGSize(width: 402, height: 874))

    // MARK: 时间轴

    @Test func timelineStopsAtHoldPointUntilResolved() {
        let hold = M.holdPoint
        #expect(LaunchSplashController.timelinePosition(elapsed: 0.5, holdPoint: hold, resumedAfter: nil) == 0.5)
        #expect(LaunchSplashController.timelinePosition(elapsed: 3.0, holdPoint: hold, resumedAfter: nil) == hold)
    }

    @Test func timelineContinuesFromHoldPointAfterLateResolution() {
        let hold = M.holdPoint
        // 第 2.5s 才确认：之前一直停在停留点，之后从停留点继续走
        #expect(LaunchSplashController.timelinePosition(elapsed: 2.0, holdPoint: hold, resumedAfter: 2.5) == hold)
        #expect(abs(LaunchSplashController.timelinePosition(elapsed: 2.8, holdPoint: hold, resumedAfter: 2.5) - (hold + 0.3)) < 1e-9)
    }

    @Test func timelineNeverStallsWhenResolvedEarly() {
        let hold = M.holdPoint
        // 停留点之前就确认了：恢复点 = 停留点本身，时间轴连续不停
        #expect(LaunchSplashController.timelinePosition(elapsed: 0.6, holdPoint: hold, resumedAfter: hold) == 0.6)
        #expect(abs(LaunchSplashController.timelinePosition(elapsed: hold + 0.2, holdPoint: hold, resumedAfter: hold) - (hold + 0.2)) < 1e-9)
    }

    @Test func clockStartsWhenFirstFrameIsOnScreen() {
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        let now = Date()
        // 首帧上屏之前，无论过了多久都还在第 0 帧（生长段不能被系统启动屏「吃掉」）
        #expect(controller.time(at: now.addingTimeInterval(1)) == 0)
        controller.begin(now: now)
        #expect(abs(controller.time(at: now.addingTimeInterval(0.4)) - 0.4) < 1e-6)
    }

    @Test func resolutionBeforeFirstFrameStillPlaysFromZero() {
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        let start = Date()
        controller.resolve(.onboarding, now: start.addingTimeInterval(-0.3))
        controller.begin(now: start)
        #expect(controller.resumeOffset == M.holdPoint)
        #expect(controller.time(at: start) == 0)
    }

    @Test func firstLaunchGatesScreen1UntilTheSplashExits() {
        let first = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        #expect(first.destination == nil)
        #expect(!first.screen1Ready)

        let daily = LaunchSplashController(kind: .daily, reduceMotion: false)
        #expect(daily.destination == .home)
        #expect(daily.screen1Ready)
    }

    // MARK: 定时交接（真实时间，留足余量防负载抖动）

    /// 把第 0 帧放到「停留点之前 2s」，resolve 时已过停留点 → 收尾立即开始，
    /// 定时动作都在几百毫秒内发生。
    private func startedLongAgo(_ controller: LaunchSplashController) -> Date {
        let now = Date()
        controller.begin(now: now.addingTimeInterval(-(controller.holdPoint + 2)))
        return now
    }

    @Test func newUserHandoffReleasesScreen1ThenFinishes() async throws {
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        let now = startedLongAgo(controller)
        controller.resolve(.onboarding, now: now)
        #expect(!controller.screen1Ready)           // 收尾刚开始，S1 还没放行
        #expect(!controller.isFinished)
        try await Task.sleep(for: .seconds(1))
        #expect(controller.screen1Ready)
        #expect(controller.isFinished)
    }

    @Test func returningUserHandoffFinishesWithoutWaitingForScreen1() async throws {
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        let now = startedLongAgo(controller)
        controller.resolve(.home, now: now)
        try await Task.sleep(for: .seconds(1))
        #expect(controller.isFinished)
        #expect(controller.screen1Ready)            // finish 兜底放行，删号回到 onboarding 时 S1 能入场
    }

    @Test func dailyLaunchSettlesTheMainScreenAndFinishes() async throws {
        // 日常打开在创建时就有去向，begin 即开始计时（不等停留点），完整播放 dailyTotal = 1.2s
        let controller = LaunchSplashController(kind: .daily, reduceMotion: false)
        #expect(!controller.contentSettled)
        controller.begin()
        #expect(!controller.isFinished)
        try await Task.sleep(for: .seconds(AppTheme.Motion.Launch.dailyTotal + 0.8))
        #expect(controller.contentSettled)
        #expect(controller.isFinished)
    }

    @Test func unresolvedFirstLaunchNeverFinishesOnItsOwn() async throws {
        // 去向只由 resolve 决定：没收到就停在居中组合，不会自行收尾（RootView 保证一定会 resolve）
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        _ = startedLongAgo(controller)
        try await Task.sleep(for: .seconds(0.5))
        #expect(!controller.isFinished)
        #expect(controller.time(at: Date()) == controller.holdPoint)
    }

    @Test func onlyTheFirstResolutionCounts() {
        let controller = LaunchSplashController(kind: .firstLaunch, reduceMotion: false)
        controller.resolve(.onboarding)
        controller.resolve(.home)
        #expect(controller.destination == .onboarding)
        // 日常打开在创建时就定了去向，RootView 再调 resolve(.home) 是无害的空操作
        let daily = LaunchSplashController(kind: .daily, reduceMotion: false)
        daily.resolve(.onboarding)
        #expect(daily.destination == .home)
    }

    // MARK: 关键帧几何

    @Test func firstFrameIsBlankPaper() {
        let frame = layout.frame(at: 0, kind: .firstLaunch, reduceMotion: false)
        #expect(frame.backgroundOpacity == 1)
        #expect(frame.reveal == 0)
        #expect(frame.center == layout.growingCenter)
        // 第 0 帧主干还没开始长（stemStart > 0），与纯暖纸系统启动屏一致
        #expect(launchProgress(0, M.stemStart, M.stemDuration, LaunchSplashCurve.grow) == 0)
    }

    @Test func holdPointShowsFullLockupCentered() {
        let frame = layout.frame(at: M.holdPoint, kind: .firstLaunch, reduceMotion: false)
        #expect(frame.reveal == 1)
        #expect(frame.scale == layout.settledScale)
        #expect(abs(frame.center.x - layout.settledCenter.x) < 0.001)
        #expect(frame.backgroundOpacity == 1)
    }

    @Test func firstLaunchExitsInPlaceRatherThanFlyingToTheCorner() {
        // 收尾全程停在屏幕中间：只上移 exitRise，不缩放、不往角落走（视线要交给 S1 中间的标题）
        let mid = layout.frame(at: M.holdPoint + M.exitDuration / 2, kind: .firstLaunch, reduceMotion: false)
        #expect(mid.scale == layout.settledScale)
        #expect(abs(mid.center.x - layout.settledCenter.x) < 0.001)
        #expect(mid.center.y < layout.settledCenter.y)
        #expect(mid.center.y >= layout.settledCenter.y - M.exitRise)

        let end = layout.frame(at: M.holdPoint + M.backgroundFadeDuration, kind: .firstLaunch, reduceMotion: false)
        #expect(end.lockupOpacity == 0)
        #expect(end.backgroundOpacity == 0)
        #expect(abs(end.center.y - (layout.settledCenter.y - M.exitRise)) < 0.001)
    }

    @Test func dailyLaunchEntersSoftlyWithSproutLeadingTheWordmark() {
        let first = layout.frame(at: 0, kind: .daily, reduceMotion: false)
        #expect(first.sproutOpacity == 0)
        #expect(first.wordOpacity == 0)
        #expect(first.backgroundOpacity == 1)
        // 字标晚 dailyWordInStart 跟上：同一时刻嫩芽总比字标更实
        let early = layout.frame(at: 0.15, kind: .daily, reduceMotion: false)
        #expect(early.sproutOpacity > early.wordOpacity)
        #expect(early.scale < layout.settledScale)          // 还在从 97% 放大
        let entered = layout.frame(at: M.dailyWordInStart + M.dailyInDuration, kind: .daily, reduceMotion: false)
        #expect(entered.sproutOpacity == 1)
        #expect(entered.wordOpacity == 1)
        #expect(entered.reveal == 1)
        #expect(entered.growthTime >= M.budStart + M.budDuration)   // 图形是长全的
    }

    @Test func dailyLaunchKeepsDriftingWhileHolding() {
        // 停留期间缓慢前推：越往后越大，且始终围绕可见组合的中心
        let a = layout.frame(at: 0.5, kind: .daily, reduceMotion: false)
        let b = layout.frame(at: 0.75, kind: .daily, reduceMotion: false)
        #expect(b.scale > a.scale)
        #expect(abs(b.center.x - layout.lockupCenterX(scale: b.scale)) < 0.001)
        #expect(a.lockupOpacity == 1)
        #expect(b.lockupOpacity == 1)
    }

    @Test func dailyLaunchExitsInLayers() {
        // 组合先退，暖纸底晚一步才开始退
        let t = M.dailyLockupOutStart + 0.05
        let f = layout.frame(at: t, kind: .daily, reduceMotion: false)
        #expect(f.lockupOpacity < 1)
        #expect(f.backgroundOpacity == 1)
        #expect(M.dailyBackgroundOutStart > M.dailyLockupOutStart)

        let end = layout.frame(at: M.dailyTotal, kind: .daily, reduceMotion: false)
        #expect(end.lockupOpacity == 0)
        #expect(end.backgroundOpacity == 0)
        #expect(abs(end.center.y - (layout.settledCenter.y - M.dailyExitRise)) < 0.001)
        #expect(abs(M.dailyTotal - 1.2) < 1e-9)
    }

    @Test func dailyLaunchHoldsTheMainScreenSlightlySmallUntilTheExit() {
        let daily = LaunchSplashController(kind: .daily, reduceMotion: false)
        #expect(!daily.contentSettled)
        #expect(LaunchSplashController(kind: .daily, reduceMotion: true).contentSettled)
        #expect(LaunchSplashController(kind: .firstLaunch, reduceMotion: false).contentSettled)
    }

    @Test func reducedMotionDailyLaunchShowsNoMark() {
        let frame = layout.frame(at: 0.05, kind: .daily, reduceMotion: true)
        #expect(frame.lockupOpacity == 0)
    }
}
