import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 品牌 P 字形

/// App 图标里那个 P 的矢量原稿，与
/// `Assets.xcassets/AppIcon.appiconset/poplex_icon_master.svg` 是同一份路径数据。
///
/// 坐标系固定 120×120；`translate(15.22, -1.5) skewX(-6°)` 是定稿时确定的
/// 居中 + 倾斜变换 —— 两处（SVG 母版 / 本文件）必须同步修改。
/// 注意：图标母版里的墨点**不在**这个 Shape 内。开屏里墨点是独立元素，
/// 因为它要从 P 底下滑到词尾。
///
/// **按墨迹（ink bounds）排版，不按 120 网格排版。**
/// 120 网格是给方形图标用的，字形左右各留了约 22/120 的空边；直接拿整个网格当
/// frame 塞进 HStack，那两段空边就会变成 P 和 `oplex` 之间的一道大缝。
/// 所以 `path(in:)` 把墨迹外框铺满传入的 rect，调用方只需给对高度（= 字高），
/// 宽度按 `aspect` 换算。墨迹底边就是基线（P 无降部），基线对齐因此变成对齐底边。
struct PoplexPShape: Shape {

    /// 变换后墨迹外框的宽高比（约 76.05 / 71.00）。缓存成常量，避免每帧重算。
    static let aspect: CGFloat = {
        let b = measuredInkBounds()
        return b.height > 0 ? b.width / b.height : 1
    }()

    private static func measuredInkBounds() -> CGRect {
        placedPath().boundingRect
    }

    /// 已应用定稿变换（居中 + −6° 斜切）的路径，坐标仍在 120 网格里。
    private static func placedPath() -> Path {
        let skew = CGFloat(tan(-6.0 * .pi / 180.0))
        let place = CGAffineTransform(a: 1, b: 0, c: skew, d: 1, tx: 15.22, ty: -1.5)
        return rawPath().applying(place)
    }

    func path(in rect: CGRect) -> Path {
        let ink = Self.measuredInkBounds()
        guard ink.width > 0, ink.height > 0 else { return Path() }
        let scale = min(rect.width / ink.width, rect.height / ink.height)
        return Self.placedPath()
            .applying(CGAffineTransform(translationX: -ink.minX, y: -ink.minY))
            .applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func rawPath() -> Path {
        var path = Path()

        // 外轮廓：起笔衬线 → 碗 → 竖干 → 下衬线，单条闭合路径
        path.move(to: CGPoint(x: 18, y: 26))
        path.addLine(to: CGPoint(x: 55, y: 26))
        path.addCurve(to: CGPoint(x: 88, y: 50),
                      control1: CGPoint(x: 74, y: 26.5), control2: CGPoint(x: 88, y: 36))
        path.addCurve(to: CGPoint(x: 56, y: 74),
                      control1: CGPoint(x: 88, y: 64), control2: CGPoint(x: 75, y: 73.5))
        path.addLine(to: CGPoint(x: 47, y: 74))
        path.addLine(to: CGPoint(x: 47, y: 88))
        path.addCurve(to: CGPoint(x: 58, y: 93),
                      control1: CGPoint(x: 47, y: 92), control2: CGPoint(x: 52, y: 92.5))
        path.addLine(to: CGPoint(x: 58, y: 97))
        path.addLine(to: CGPoint(x: 17, y: 97))
        path.addLine(to: CGPoint(x: 17, y: 93))
        path.addCurve(to: CGPoint(x: 30, y: 88),
                      control1: CGPoint(x: 25, y: 92.5), control2: CGPoint(x: 30, y: 92))
        path.addLine(to: CGPoint(x: 30, y: 33))
        path.addCurve(to: CGPoint(x: 18, y: 31),
                      control1: CGPoint(x: 29.5, y: 30), control2: CGPoint(x: 25, y: 31))
        path.closeSubpath()

        // 碗内空心（even-odd 挖空）
        path.move(to: CGPoint(x: 47, y: 34))
        path.addCurve(to: CGPoint(x: 72, y: 50),
                      control1: CGPoint(x: 62, y: 34), control2: CGPoint(x: 72, y: 39.5))
        path.addCurve(to: CGPoint(x: 47, y: 65.5),
                      control1: CGPoint(x: 72, y: 60.5), control2: CGPoint(x: 62, y: 65.5))
        path.closeSubpath()

        return path
    }
}

// MARK: - 开屏

/// 方案 A「从图标长出来」，总长 1.00s。
///
/// 第 0 帧刻意画成**和 App 图标放大转场的最后一帧一致**（暖纸底 + 居中的大橙 P），
/// 让系统转场和 App 首屏看起来是连续的一件事。随后 P 收到字标字号、
/// `oplex` 逐字长出、墨点从 P 底下滑到词尾坐定，静止一拍后整体上移淡出。
///
/// 时间表集中在 `AppTheme.Motion.Splash`，不要在本文件里写死数值。
///
/// **不阻塞启动**：本视图只负责播动画并在结束时回调；登录 / 取数在
/// `RootView.task` 里并行进行，动画播完立即让位，绝不因为动画多等。
struct SplashScreenView: View {

    var onAnimationComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 字标字号。必须与 `AppTheme.Font.splashWordmark` 的数值一致，
    /// 否则 P 的字高（由字号算 cap height）会和 `oplex` 对不上。
    private static let wordmarkSize: CGFloat = 56

    /// P 的目标字高 = **字体真实的 cap height**，不是字号。
    /// 衬线体的 cap height 大约只有字号的 0.70；早前直接拿字号当字高，
    /// P 就比 `oplex` 大了约 1/0.70 ≈ 1.43 倍。这里向 UIFont 问真实值。
    private static let pHeightEnd: CGFloat = capHeight(of: wordmarkSize)

    /// 第 0 帧那个大 P 的**墨迹宽度占屏宽的比例**。
    /// 用比例而不是固定 pt：它要对上 iOS 图标放大转场的最后一帧，而那一帧跟着屏幕走。
    private static let pStartWidthRatio: CGFloat = 0.48

    // 字距 / 墨点尺寸全部取自 `PoplexWordmarkMetrics` —— 字标度量的唯一真源。
    // 要调松紧去改那里，改了静态字标和开屏会一起变，不会漂移。
    private static let pToWordGap: CGFloat = wordmarkSize * PoplexWordmarkMetrics.kernRatio
    private static let dotDiameter: CGFloat = wordmarkSize * PoplexWordmarkMetrics.dotDiameterRatio
    private static let dotLeading: CGFloat = wordmarkSize * PoplexWordmarkMetrics.dotLeadingRatio

    private static let dotTravel: CGFloat = -40    // 墨点滑入的起点偏移（仅开屏用）

    /// 视觉居中：几何正中会显得偏下，整组上提约屏高的 4%。
    private static let opticalLift: CGFloat = -30

    private static func capHeight(of size: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let serif = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) }
        return (serif ?? base).capHeight
        #else
        return size * 0.70
        #endif
    }

    private let suffix = Array("oplex")

    @State private var started = false
    /// nil = 还没量到屏宽，先按 `startScale(in:)` 渲染，避免第一帧闪一下小 P
    @State private var pScale: CGFloat?
    @State private var letterShown: [Bool] = Array(repeating: false, count: 5)
    @State private var dotIn = false
    @State private var markShiftX: CGFloat = 0     // 让 P 在第 0 帧处于视觉正中
    @State private var exiting = false

    /// 第 0 帧的大 P 相对字标 P 的倍率。
    private func startScale(in width: CGFloat) -> CGFloat {
        let wordmarkPWidth = Self.pHeightEnd * PoplexPShape.aspect
        guard wordmarkPWidth > 0, width > 0 else { return 1 }
        return width * Self.pStartWidthRatio / wordmarkPWidth
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.Color.splashBg

                HStack(alignment: .lastTextBaseline, spacing: Self.pToWordGap) {
                    PoplexPShape()
                        .fill(AppTheme.Color.brandStrong, style: FillStyle(eoFill: true))
                        .frame(width: Self.pHeightEnd * PoplexPShape.aspect,
                               height: Self.pHeightEnd)
                        // 墨迹底边就是基线（P 无降部），所以基线 = frame 底边。
                        // alignmentGuide 走布局、scaleEffect 走渲染，两者不打架：
                        // 布局始终按字标尺寸算，大 P 只是围绕自身中心放大地画出来。
                        .alignmentGuide(.lastTextBaseline) { d in d.height }
                        .scaleEffect(pScale ?? startScale(in: proxy.size.width))

                    suffixBlock
                        .background(suffixWidthReader(screenWidth: proxy.size.width))
                }
                .offset(x: markShiftX, y: Self.opticalLift + (exiting ? -10 : 0))
                .opacity(exiting ? 0 : 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startFallback(width: proxy.size.width)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: 字标后缀 + 墨点

    private var suffixBlock: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(Array(suffix.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(AppTheme.Font.splashWordmark)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .opacity(letterShown[index] ? 1 : 0)
                    .offset(y: letterShown[index] ? 0 : 7)
            }

            Circle()
                .fill(AppTheme.Color.splashDot)
                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                .padding(.leading, Self.dotLeading)
                .alignmentGuide(.lastTextBaseline) { d in d.height }
                .opacity(dotIn ? 1 : 0)
                // 从 P 底下滑出来：终点是词尾，起点在左侧
                .offset(x: dotIn ? 0 : Self.dotTravel)
        }
    }

    /// 实测「oplex + 墨点」的宽度，量到了才开播。
    ///
    /// HStack 居中时 P 的中心 = 屏幕中心 −（字距 + suffixWidth）/ 2，所以第 0 帧
    /// 把整组按这个量右移，P 就正好落在正中 —— 该式与 P 当前的缩放无关，
    /// 因此 P 收缩过程中不会左右乱跑。
    ///
    /// 之所以由这里触发开播而不是外层 `onAppear`：字标宽度依赖字体度量，首帧不一定
    /// 拿得到；宽度还是 0 时就开播的话，P 会直接杵在偏左的终点位置上。
    private func suffixWidthReader(screenWidth: CGFloat) -> some View {
        GeometryReader { geo in
            SwiftUI.Color.clear
                .onAppear { adopt(suffixWidth: geo.size.width, screenWidth: screenWidth) }
                .onChange(of: geo.size.width) { _, width in
                    adopt(suffixWidth: width, screenWidth: screenWidth)
                }
        }
    }

    private func adopt(suffixWidth: CGFloat, screenWidth: CGFloat) {
        guard !started, suffixWidth > 0 else { return }
        started = true
        // P 右侧的全部东西（字距 + oplex + 墨点）的一半
        markShiftX = (Self.pToWordGap + suffixWidth) / 2
        // 显式落一次起始倍率，别让动画依赖 nil → 1 的隐式解析
        pScale = startScale(in: screenWidth)

        // 必须隔一帧再开播。SwiftUI 把同一个 tick 里的状态变更合并成一次更新，
        // 如果紧接着就 withAnimation { markShiftX = 0 }，引擎看到的是 0 → 0，
        // 既不会动、第 0 帧也直接落在终点位置上（P 一上来就偏左）。
        DispatchQueue.main.async { runSequence() }
    }

    /// 兜底：万一字标宽度始终量不到（理论上不会），也不能把用户卡在开屏上。
    private func startFallback(width: CGFloat) {
        guard !started else { return }
        started = true
        pScale = startScale(in: width)
        DispatchQueue.main.async { runSequence() }
    }

    // MARK: 时间表

    private func runSequence() {
        guard !reduceMotion else { return reducedMotionSequence() }

        typealias S = AppTheme.Motion.Splash
        func ease(_ d: Double) -> Animation { .timingCurve(0.22, 0.9, 0.25, 1, duration: d) }

        // ① P 收到字标字号
        withAnimation(ease(S.shrinkDuration).delay(S.holdStart)) {
            pScale = 1
        }

        // ② oplex 逐字长出；整组同时左移，P 归位到字标起始处
        let revealSpan = Double(suffix.count) * S.letterStagger + S.letterDuration
        withAnimation(ease(revealSpan).delay(S.lettersStart)) {
            markShiftX = 0
        }
        for i in suffix.indices {
            withAnimation(ease(S.letterDuration)
                .delay(S.lettersStart + Double(i) * S.letterStagger)) {
                letterShown[i] = true
            }
        }

        // ③ 墨点从左滑到词尾
        withAnimation(ease(S.dotDuration).delay(S.dotStart)) {
            dotIn = true
        }

        // ④ 静止一拍 → 上移淡出
        withAnimation(.easeIn(duration: S.exitDuration).delay(S.exitStart)) {
            exiting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + S.total, execute: onAnimationComplete)
    }

    /// 「减弱动态效果」开启：不做位移和逐字，只把定稿状态淡入淡出。
    private func reducedMotionSequence() {
        typealias S = AppTheme.Motion.Splash

        pScale = 1
        markShiftX = 0
        letterShown = Array(repeating: true, count: suffix.count)
        dotIn = true
        exiting = true                                        // 先置于「已淡出」，再淡入

        // 同样隔一帧，否则 true → false 会被合并掉，淡入不会发生
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: S.reducedFadeIn)) { exiting = false }
            withAnimation(.easeIn(duration: S.exitDuration)
                .delay(S.reducedTotal - S.exitDuration - S.reducedFadeIn)) { exiting = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + S.reducedTotal,
                                      execute: onAnimationComplete)
    }
}

#Preview("开屏 · 方案 A") {
    SplashScreenView(onAnimationComplete: {})
}
