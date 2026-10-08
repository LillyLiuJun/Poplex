import SwiftUI

// MARK: - 开屏动画
//
// 系统启动屏是纯暖纸（Config/LaunchScreen.plist 只给底色），开屏从同一幅空白画面起步：
//
//   首次打开：嫩芽按「主干 → 嫩叶 → 芽心」逐部件长出 → 左移让位、字标擦出 → 居中停一拍
//            → 后台身份确认出结果后，组合原地上移淡出：新用户露出 Onboarding S1（标题在中间接上
//              视线），重装的已完成用户露出主界面。不飞去 S1 报头——那会把视线拉到角落，
//              抢走 S1 中间文案的注意力（2026-10-08 PM 反馈）。
//   日常打开（1.2s）：嫩芽、字标错峰浮现 → 停留时缓慢前推 → 组合先淡出上浮、暖纸底随后退，
//            已加载好的主界面同时从 98% 浮上来。全程慢进慢出，不长、不擦。
//   减弱动态效果：不长、不移，暖纸底直接淡出。
//
// 时间参数在 AppTheme.Motion.Launch；时间轴由 TimelineView 按 t 逐帧计算。

// MARK: - 控制器：时间轴 + 与路由的交棒

@MainActor
@Observable
final class LaunchSplashController {
    enum Kind { case firstLaunch, daily }
    enum Destination { case onboarding, home }

    let kind: Kind
    let reduceMotion: Bool
    /// 开屏第 0 帧真正上屏的时刻（`begin()`）。从 App init 起算会把生长段「播」在系统启动屏后面
    /// （模拟器录屏实测：首帧上屏比 init 晚约 0.4s，主干一出现就已经长完）。
    private(set) var startDate: Date?
    /// 时间轴从停留点继续走的时刻（距第 0 帧的秒数，不早于停留点）。nil = 还在等后台确认。
    private(set) var resumeOffset: Double?
    private(set) var destination: Destination?
    private var resolvedAt: Date?

    /// S1 可以开始自己的入场动画了（Onboarding 第一屏的 isActive 闸门）。
    private(set) var screen1Ready: Bool
    /// 底下的主界面可以从 dailyContentFromScale 放大到位了（只有日常打开会先缩着）。
    private(set) var contentSettled: Bool
    /// 开屏播完，可以移出视图树。
    private(set) var isFinished = false

    private var scheduled: [Task<Void, Never>] = []

    init(kind: Kind, reduceMotion: Bool) {
        self.kind = kind
        self.reduceMotion = reduceMotion
        // 首次打开时 S1 等开屏收尾再入场；日常打开不涉及 S1。
        self.screen1Ready = kind == .daily
        self.contentSettled = kind != .daily || reduceMotion
        if kind == .daily { destination = .home }
    }

    /// 时间轴会停住等后台确认的那一刻（日常打开不等）。
    var holdPoint: Double {
        typealias M = AppTheme.Motion.Launch
        switch kind {
        case .daily: return 0
        case .firstLaunch: return reduceMotion ? M.reducedHoldPoint : M.holdPoint
        }
    }

    /// 某一时刻对应的时间轴位置：走到停留点就停，确认出结果后再从停留点继续。
    func time(at date: Date) -> Double {
        guard let startDate else { return 0 }
        return Self.timelinePosition(elapsed: date.timeIntervalSince(startDate),
                                     holdPoint: holdPoint, resumedAfter: resumeOffset)
    }

    /// 纯函数版，便于单测。`resumedAfter` = 恢复时刻距第 0 帧的秒数（不早于停留点）。
    nonisolated static func timelinePosition(elapsed: Double, holdPoint: Double, resumedAfter: Double?) -> Double {
        guard let resume = resumedAfter, elapsed >= resume else { return min(max(elapsed, 0), holdPoint) }
        return holdPoint + (elapsed - resume)
    }

    /// 第 0 帧上屏（只认第一次）。
    func begin(now: Date = .now) {
        guard startDate == nil else { return }
        startDate = now
        if destination != nil { scheduleResume(now: now) }
    }

    /// 后台确认出结果（只认第一次）。早于 `begin()` 也可以，届时从第 0 帧起算。
    func resolve(_ destination: Destination, now: Date = .now) {
        guard self.destination == nil else { return }
        self.destination = destination
        resolvedAt = now
        if startDate != nil { scheduleResume(now: now) }
    }

    private func scheduleResume(now: Date) {
        guard let startDate, let destination, resumeOffset == nil else { return }
        let resolvedElapsed = max((resolvedAt ?? startDate).timeIntervalSince(startDate), 0)
        let resume = max(resolvedElapsed, holdPoint)
        resumeOffset = resume
        let wait = resume - now.timeIntervalSince(startDate)

        typealias M = AppTheme.Motion.Launch
        switch (kind, destination, reduceMotion) {
        case (.daily, _, true):
            schedule(after: wait + M.reducedDailyFadeDuration) { $0.finish() }
        case (.daily, _, false):
            schedule(after: wait + M.dailyBackgroundOutStart) { $0.contentSettled = true }
            schedule(after: wait + M.dailyTotal) { $0.finish() }
        case (.firstLaunch, _, false):
            if destination == .onboarding {
                schedule(after: wait + M.screen1Lead) { $0.screen1Ready = true }
            }
            schedule(after: wait + M.backgroundFadeDuration) { $0.finish() }
        case (.firstLaunch, _, true):
            screen1Ready = true
            schedule(after: wait + M.reducedFadeDuration) { $0.finish() }
        }
    }

    private func finish() {
        screen1Ready = true
        contentSettled = true
        isFinished = true
    }

    private func schedule(after seconds: Double, _ action: @escaping (LaunchSplashController) -> Void) {
        scheduled.append(Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(seconds, 0)))
            guard let self, !Task.isCancelled else { return }
            action(self)
        })
    }
}

// MARK: - 每一帧的几何（纯计算，可单测）

/// `poplex-lockup-mark.svg`（画布 1087.9 × 400）里图形与字标的可见范围，测自 SVG 渲染。
enum LaunchLockupGeometry {
    static let canvasW: CGFloat = 1087.9
    static let canvasH: CGFloat = 400
    static let markLeft: CGFloat = 13.0
    static let markRight: CGFloat = 261.0
    static let markVisibleHeight: CGFloat = 333.3
    static let markCenterY: CGFloat = 200            // 图形可见上下沿 33.35 / 366.65 的中点
    static let inkRight: CGFloat = 1083.75            // 字标右沿；左沿在 371
    /// 擦除起点 / 遮掉素材自带图形的分界：都落在图形右沿（261）与字标左沿（371）之间的缝里。
    static let wipeStart: CGFloat = 330
    static let wipeSoftEdge: CGFloat = 50
    static let markCut: CGFloat = 316
    /// 素材里图形组的变换 translate(0 20) scale(0.61387)，作用于 PoplexMarkDecomposition 同一套坐标。
    static let markGroupScale: CGFloat = 0.61387
    static let markGroupOffsetY: CGFloat = 20

    static var markCenterX: CGFloat { (markLeft + markRight) / 2 }
    static var visibleCenterX: CGFloat { (markLeft + inkRight) / 2 }
}

struct LaunchSplashFrame: Equatable {
    /// 屏幕 pt / 画布单位。
    var scale: CGFloat
    /// 组合 frame 的中心（全屏坐标，含安全区）。
    var center: CGPoint
    /// 字标擦出进度：0 = 只有图形，1 = 字标全露。
    var reveal: CGFloat
    var lockupOpacity: CGFloat
    var backgroundOpacity: CGFloat
    /// 嫩芽三部件的生长时间轴位置（日常打开直接给长全，所以不一定等于 t）。
    var growthTime: Double = 0
    /// 日常打开错峰浮现用：嫩芽与字标各自的透明度（整体透明度仍是 lockupOpacity）。
    var sproutOpacity: CGFloat = 1
    var wordOpacity: CGFloat = 1
}

struct LaunchSplashLayout {
    let screen: CGSize
    var settledMarkHeight: CGFloat = AppTheme.Size.launchSplashSettledMarkHeight

    private typealias G = LaunchLockupGeometry
    private typealias M = AppTheme.Motion.Launch

    /// 居中停住时的缩放与位置（完整组合在屏幕正中）。
    var settledScale: CGFloat { settledMarkHeight / G.markVisibleHeight }
    var settledCenter: CGPoint {
        CGPoint(x: lockupCenterX(scale: settledScale), y: screen.height / 2)
    }

    /// 可见组合（图形左沿 → 字标右沿）水平居中时，素材 frame 的中心 x。缩放随帧变化时
    /// 每帧按当前缩放重算，放大才是围绕可见组合的中心，而不是素材画布中心。
    func lockupCenterX(scale: CGFloat) -> CGFloat {
        screen.width / 2 + (G.canvasW / 2 - G.visibleCenterX) * scale
    }

    /// 生长阶段：只有图形，图形可见中心在屏幕正中。
    var growingCenter: CGPoint {
        CGPoint(x: screen.width / 2 + (G.canvasW / 2 - G.markCenterX) * settledScale,
                y: screen.height / 2 + (G.canvasH / 2 - G.markCenterY) * settledScale)
    }

    func frame(at t: Double, kind: LaunchSplashController.Kind, reduceMotion: Bool) -> LaunchSplashFrame {
        if reduceMotion {
            let fade: CGFloat
            switch kind {
            case .daily:
                fade = 1 - launchProgress(t, 0, M.reducedDailyFadeDuration, .linear)
            case .firstLaunch:
                fade = 1 - launchProgress(t, M.reducedHoldPoint, M.reducedFadeDuration, .easeIn)
            }
            return LaunchSplashFrame(scale: settledScale, center: growingCenter, reveal: 0,
                                     lockupOpacity: 0, backgroundOpacity: fade)
        }

        switch kind {
        case .daily:
            // 完整组合（图形已长全、字标全露）：错峰浮现 → 缓慢前推 → 分层退场
            let sproutIn = launchProgress(t, M.dailySproutInStart, M.dailyInDuration, .easeInOut)
            let wordIn = launchProgress(t, M.dailyWordInStart, M.dailyInDuration, .easeInOut)
            let out = launchProgress(t, M.dailyLockupOutStart, M.dailyLockupOutDuration, .easeInOut)
            let scale = settledScale * lerp(M.dailyEntryScale, 1, sproutIn)
                * (1 + M.dailyDrift * launchProgress(t, 0, M.dailyTotal, .linear))
            return LaunchSplashFrame(
                scale: scale,
                center: CGPoint(x: lockupCenterX(scale: scale), y: screen.height / 2 - M.dailyExitRise * out),
                reveal: 1,
                lockupOpacity: 1 - out,
                backgroundOpacity: 1 - launchProgress(t, M.dailyBackgroundOutStart, M.dailyBackgroundOutDuration, .easeInOut),
                growthTime: M.holdPoint,
                sproutOpacity: sproutIn,
                wordOpacity: wordIn
            )

        case .firstLaunch:
            let shift = launchProgress(t, M.shiftStart, M.shiftDuration, LaunchSplashCurve.settle)
            let settled = lerp(growingCenter, settledCenter, shift)
            let exit = launchProgress(t, M.holdPoint, M.exitDuration, .easeIn)
            let rise = launchProgress(t, M.holdPoint, M.exitDuration, .easeOut)
            return LaunchSplashFrame(
                scale: settledScale,
                center: CGPoint(x: settled.x, y: settled.y - M.exitRise * rise),
                reveal: launchProgress(t, M.wipeStart, M.wipeDuration, .easeInOut),
                lockupOpacity: 1 - exit,
                backgroundOpacity: 1 - launchProgress(t, M.holdPoint, M.backgroundFadeDuration, .easeIn),
                growthTime: t
            )
        }
    }
}

enum LaunchSplashCurve {
    /// 起步快、落定软（沿用旧开屏同一条曲线）。
    static let settle = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.22, y: 0.9),
                                         endControlPoint: UnitPoint(x: 0.25, y: 1))
    /// 部件生长（easeOutCubic）。
    static let grow   = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.33, y: 1),
                                         endControlPoint: UnitPoint(x: 0.68, y: 1))
}

/// t 在 [start, start + duration] 内的缓动进度，区间外夹到 0 / 1。
func launchProgress(_ t: Double, _ start: Double, _ duration: Double, _ curve: UnitCurve) -> CGFloat {
    let raw = min(max((t - start) / duration, 0), 1)
    return CGFloat(curve.value(at: raw))
}

private func lerp(_ a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat { a + (b - a) * p }
private func lerp(_ a: CGPoint, _ b: CGPoint, _ p: CGFloat) -> CGPoint {
    CGPoint(x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p))
}

// MARK: - 视图

struct LaunchSplashView: View {
    let controller: LaunchSplashController

    var body: some View {
        TimelineView(.animation(paused: controller.isFinished)) { context in
            let t = controller.time(at: context.date)
            GeometryReader { proxy in
                let screen = CGSize(
                    width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                    height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                )
                let frame = LaunchSplashLayout(screen: screen)
                    .frame(at: t, kind: controller.kind, reduceMotion: controller.reduceMotion)
                ZStack {
                    AppTheme.Color.startupBg
                        .opacity(frame.backgroundOpacity)
                    Color.clear
                        .overlay(alignment: .topLeading) {
                            if frame.lockupOpacity > 0 {
                                LaunchSplashLockup(t: frame.growthTime, scale: frame.scale, reveal: frame.reveal,
                                                   sproutOpacity: frame.sproutOpacity, wordOpacity: frame.wordOpacity)
                                    .opacity(frame.lockupOpacity)
                                    .position(frame.center)
                            }
                        }
                }
                .frame(width: screen.width, height: screen.height)
                .ignoresSafeArea()
            }
        }
        .onAppear { controller.begin() }
        // 开屏期间挡住点击：底下的页面还在入场，不该被误触。
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

/// 横排组合：素材本体只露字标（按擦除进度），图形由三个部件逐个长出、叠在素材图形的位置。
private struct LaunchSplashLockup: View {
    let t: Double
    let scale: CGFloat
    let reveal: CGFloat
    var sproutOpacity: CGFloat = 1
    var wordOpacity: CGFloat = 1

    private typealias G = LaunchLockupGeometry

    var body: some View {
        let edge = G.wipeStart + reveal * (G.canvasW + G.wipeSoftEdge - G.wipeStart)
        let solid = min(max((edge - G.wipeSoftEdge) / G.canvasW, 0), 1)
        let clearAt = min(max(edge / G.canvasW, solid + 0.0001), 1)
        ZStack(alignment: .topLeading) {
            Image(PoplexBrandAsset.lockupMark)
                .resizable()
                .frame(width: G.canvasW * scale, height: G.canvasH * scale)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: solid),
                            .init(color: .clear, location: clearAt),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
                .mask(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: G.markCut * scale)
                        Color.black
                    }
                }
                .opacity(wordOpacity)

            LaunchSplashGrowingMark(t: t)
                .frame(width: PoplexMarkDecomposition.viewBoxWidth * G.markGroupScale * scale,
                       height: PoplexMarkDecomposition.viewBoxHeight * G.markGroupScale * scale)
                .offset(y: G.markGroupOffsetY * scale)
                .opacity(sproutOpacity)
        }
        .frame(width: G.canvasW * scale, height: G.canvasH * scale, alignment: .topLeading)
    }
}

/// 三个部件按时间表依次长出：主干从底部、嫩叶从根部、芽心从自身底部。
private struct LaunchSplashGrowingMark: View {
    let t: Double

    private typealias M = AppTheme.Motion.Launch
    /// 嫩叶 / 芽心的生长支点（PoplexMarkDecomposition 坐标）。
    private static let leafAnchor = UnitPoint(x: 125.0 / 447.44, y: 565.0 / 586.44)
    private static let budAnchor  = UnitPoint(x: 153.0 / 447.44, y: 296.0 / 586.44)

    var body: some View {
        let stem = launchProgress(t, M.stemStart, M.stemDuration, LaunchSplashCurve.grow)
        let leaf = launchProgress(t, M.leafStart, M.leafDuration, LaunchSplashCurve.grow)
        let bud  = launchProgress(t, M.budStart, M.budDuration, LaunchSplashCurve.grow)
        ZStack {
            part(PoplexStemShape(), progress: stem, anchor: .bottom)
            part(PoplexLeafShape(), progress: leaf, anchor: Self.leafAnchor)
            part(PoplexBudShape(), progress: bud, anchor: Self.budAnchor)
        }
    }

    private func part<S: Shape>(_ shape: S, progress: CGFloat, anchor: UnitPoint) -> some View {
        shape
            .fill(AppTheme.Color.brandStrong)
            .scaleEffect(max(progress, 0.001), anchor: anchor)
            .opacity(progress > 0 ? 1 : 0)
    }
}

#Preview("开屏 · 首次打开（停在居中组合，等后台确认）") {
    LaunchSplashView(controller: LaunchSplashController(kind: .firstLaunch, reduceMotion: false))
}
