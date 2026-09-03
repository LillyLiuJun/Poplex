import SwiftUI
import UIKit

/// 温润极简 珍珠流水滴加载指示器（Pearl Droplets - 方案 C）
///
/// 遵循 Warm Minimalism 设计规范：
/// - 纯正正圆形微水滴（Zero Straight Lines / 零直线零短杠）；
/// - 6 颗大小与透明度自然渐变的微圆珍珠（3.0pt ➡️ 1.1pt），沿圆周轨迹流转；
/// - 1.2s 匀速平滑旋转，如水珠在暖纸上灵动流转，温润柔和无棱角。
struct WarmSpinnerView: View {
    var size: CGFloat = 24
    var color: Color = AppTheme.Color.refreshIndicator
    /// 仅用于确定性预览/测试；生产调用保持 nil，继续读取系统 Reduce Motion。
    var reduceMotionOverride: Bool? = nil

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dropletConfigs: [(diameter: CGFloat, angle: Double, opacity: Double)] = [
        (3.0,   0, 1.00),
        (2.6,  45, 0.85),
        (2.2,  90, 0.65),
        (1.8, 135, 0.45),
        (1.4, 180, 0.30),
        (1.1, 225, 0.18)
    ]

    var body: some View {
        let orbitRadius = (size / 24.0) * 8.5
        let shouldReduceMotion = reduceMotionOverride ?? reduceMotion

        ZStack {
            ForEach(0..<dropletConfigs.count, id: \.self) { index in
                let config = dropletConfigs[index]
                let scaleFactor = size / 24.0
                let dotDiameter = config.diameter * scaleFactor

                Circle()
                    .fill(color)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .offset(y: -orbitRadius)
                    .rotationEffect(.degrees(config.angle))
                    .opacity(config.opacity)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(isAnimating && !shouldReduceMotion ? 360 : 0))
        .animation(
            shouldReduceMotion ? nil : .linear(duration: 1.2).repeatForever(autoreverses: false),
            value: isAnimating && !shouldReduceMotion
        )
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Pearl Spinner · Motion") {
    WarmSpinnerView(size: 32)
        .padding(40)
        .background(AppTheme.Color.pageBg)
}

#Preview("Pearl Spinner · Reduce Motion") {
    WarmSpinnerView(size: 32, reduceMotionOverride: true)
        .padding(40)
        .background(AppTheme.Color.pageBg)
}

#Preview("Pull to Refresh · Interactive") {
    ScrollView {
        WarmRefreshControlHelper(haptics: PullToRefreshHaptics())
            .frame(width: 0, height: 0)

        VStack(spacing: AppTheme.Space.paddingM) {
            Text("Pull down")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Text("Use Live Preview to inspect the pearl refresh motion.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 180)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
    .scrollBounceBehavior(.always, axes: .vertical)
    .refreshable {
        try? await Task.sleep(for: .seconds(1))
    }
    .background(AppTheme.Color.pageBg)
}

/// 下拉刷新触感：跨 UIKit 手势层（WarmRefreshControlDetectingView 判断何时越过
/// 起显门槛）与 SwiftUI `.refreshable` 回调（判断刷新真正触发）共用同一个实例。
///
/// 两条根因都在这里解决：
/// 1. generator 是这个类的存储属性而不是调用点的局部变量——不会在 impactOccurred()
///    的异步派发完成前被 ARC 提前回收（这在旧设备上更容易复现触感丢失/延迟）。
/// 2. prepare() 挪到「本次下拉首次越过起显门槛（28pt）」那一刻调用，而不是紧贴着
///    impactOccurred() 之前才调——prepare() 唤醒 Taptic Engine 是异步的，需要几十到
///    上百毫秒，紧跟着触发基本等于没 prepare。门槛选在 28pt 而不是 60pt 触发点本身，
///    是为了给引擎尽量多留一点预热时间：手指从 28pt 拉到 60pt 松手通常还有一小段
///    行程，比等到 60pt 才 prepare 留给引擎的窗口更宽裕。
///
/// 注意：系统「声音与触感 → 系统触感反馈」开关关闭时，这里做什么都不会有效果——
/// UIImpactFeedbackGenerator 遵守用户这条全局设置，app 层面无法也不应该绕过。
/// 这个类只解决「开关开着、但引擎冷启动导致偶尔延迟或漏响」这个更窄的问题。
final class PullToRefreshHaptics {
    private let generator = UIImpactFeedbackGenerator(style: .light)
    private var hasPreparedThisPull = false

    /// 每次 handleScroll 算出 pullDistance 都调用一次；内部只在本次下拉第一次
    /// 越过起显门槛时真正触发 prepare()，同一次下拉内不重复。
    func noteCrossedStartThreshold() {
        guard !hasPreparedThisPull else { return }
        hasPreparedThisPull = true
        generator.prepare()
    }

    /// 下拉退回不可见、准备迎接下一次独立下拉时调用。
    func resetForNextPull() {
        hasPreparedThisPull = false
    }

    /// 刷新真正触发时调用。
    func fire() {
        generator.impactOccurred()
    }
}

// MARK: - Direct RefreshControl UIKit Injector (动态自愈 + 手势渐进跟随)
struct WarmRefreshControlHelper: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var haptics: PullToRefreshHaptics

    func makeUIView(context: Context) -> UIView {
        let view = WarmRefreshControlDetectingView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? WarmRefreshControlDetectingView {
            view.reduceMotion = reduceMotion
            view.haptics = haptics
            view.attachToScrollView()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        (uiView as? WarmRefreshControlDetectingView)?.detach()
    }
}

private final class WarmRefreshControlDetectingView: UIView {
    private static let pearlTag = 887711
    private var offsetObserver: NSKeyValueObservation?
    private weak var targetScrollView: UIScrollView?
    private weak var targetPearl: PearlRefreshView?
    var haptics: PullToRefreshHaptics?
    var reduceMotion = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachToScrollView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachToScrollView()
    }

    func attachToScrollView() {
        var current: UIView? = self.superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                if targetScrollView !== scrollView {
                    offsetObserver?.invalidate()
                    offsetObserver = nil
                }
                self.targetScrollView = scrollView

                // 1. 监听 contentOffset
                if offsetObserver == nil {
                    offsetObserver = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                        self?.handleScroll(scrollView: sv)
                    }
                }

                // 2. 配置 refreshControl
                configureRefreshControl(on: scrollView)
                break
            }
            current = view.superview
        }
    }

    func detach() {
        offsetObserver?.invalidate()
        offsetObserver = nil
        targetPearl?.stopRotating()
        targetPearl = nil
        targetScrollView = nil
    }

    private func configureRefreshControl(on scrollView: UIScrollView) {
        guard let refresh = scrollView.refreshControl else { return }

        // 隐藏系统默认生硬菊花
        refresh.tintColor = .clear
        for subview in refresh.subviews {
            if let indicator = subview as? UIActivityIndicatorView {
                indicator.isHidden = true
                indicator.alpha = 0
            }
        }

        // 注入或复用方案 C 珍珠水滴 View
        if let existing = refresh.viewWithTag(Self.pearlTag) as? PearlRefreshView {
            self.targetPearl = existing
        } else {
            let pearl = PearlRefreshView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            pearl.tag = Self.pearlTag
            pearl.translatesAutoresizingMaskIntoConstraints = false
            refresh.addSubview(pearl)
            NSLayoutConstraint.activate([
                pearl.centerXAnchor.constraint(equalTo: refresh.centerXAnchor),
                pearl.centerYAnchor.constraint(equalTo: refresh.centerYAnchor, constant: 10),
                pearl.widthAnchor.constraint(equalToConstant: 24),
                pearl.heightAnchor.constraint(equalToConstant: 24)
            ])
            self.targetPearl = pearl
        }
    }

    private func handleScroll(scrollView: UIScrollView) {
        // 动态自愈挂载
        if targetPearl == nil || scrollView.refreshControl?.viewWithTag(Self.pearlTag) == nil {
            configureRefreshControl(on: scrollView)
        }
        guard let pearl = targetPearl, let refreshControl = scrollView.refreshControl else { return }

        if refreshControl.isRefreshing {
            // 加载中：完全显影并启动匀速旋转
            pearl.alpha = 1.0
            pearl.updateOrbitRadius(8.5)
            if reduceMotion {
                pearl.stopRotating()
            } else {
                pearl.startRotating()
            }
            return
        }

        // 下拉拉伸阶段（尚未松手）
        let pullDistance = max(0, -scrollView.contentOffset.y - scrollView.adjustedContentInset.top)

        // 起显门槛 28pt，行程终点 60pt（行程 32pt）
        let startThreshold: CGFloat = 28.0
        let endThreshold: CGFloat = 60.0

        // 触感的 prepare() 在本次下拉首次越过起显门槛（28pt）那一刻就调用，给 Taptic
        // Engine 尽量多留一点预热时间，不再和 impactOccurred() 背靠背。
        if pullDistance >= startThreshold {
            haptics?.noteCrossedStartThreshold()
        }

        if pullDistance < startThreshold {
            // 起显门槛以下珍珠本来就不可见（alpha 0），在此清零角度与棘轮峰值
            // 不会有任何视觉跳变，是唯一安全的归零时机。
            //
            // 这里不需要额外判断 refreshControl.isRefreshing：函数最上方
            // `if refreshControl.isRefreshing { ...; return }` 已经保证正在刷新时
            // 会在到达这里之前就返回，本分支在刷新期间是不可达的——stopRotating()
            // 不会打断刷新中的匀速旋转动画。这个不可达性只取决于上面那个 return，
            // 与 pullDistance 的值无关；全项目目前也没有任何手动调用
            // refreshControl.beginRefreshing() 的路径（唯一入口是 SwiftUI 的
            // .refreshable，由用户下拉手势触发）。若以后加了脱离用户手势的手动
            // 触发路径，只要它仍然会先把 isRefreshing 置 true，这条不可达性依然成立；
            // 不成立的情况只会是有人绕开 isRefreshing 检查改写了上面的 return。
            pearl.alpha = 0.0
            pearl.stopRotating()
            haptics?.resetForNextPull()
        } else {
            // 缓入曲线（easeIn / rawLinear^2）：前慢后快，在 32pt 行程内消除突兀感。
            // 只负责透明度与向心聚拢形变，不再驱动旋转角度（见下方旋转的独立线性映射）。
            let rawLinear = min(1.0, max(0.0, (pullDistance - startThreshold) / (endThreshold - startThreshold)))
            let progress = rawLinear * rawLinear
            pearl.alpha = progress

            // 水滴由散开 11.5pt 向心聚拢到标准 8.5pt
            let currentRadius = 11.5 - (3.0 * progress)
            pearl.updateOrbitRadius(currentRadius)

            if scrollView.isDragging {
                // 旋转不跟随上面的缓入 progress——那条曲线把整段 180° 挤进了行程最后
                // 不到 10pt，松手前正常的手指减速就足以在里面来回穿越，读出来就是抖动。
                // 旋转改用独立的线性映射，按实测位移直接算，起点 42pt、满点 60pt（=
                // 系统触发点 endThreshold），18pt 行程内线性转完 180°，手感接近改动前。
                let rotationStart: CGFloat = 42.0
                let rotationT = min(1.0, max(0.0, (pullDistance - rotationStart) / (endThreshold - rotationStart)))
                let angleDegrees = reduceMotion ? 0 : Double(rotationT * 180.0)
                // 角度只进不退（棘轮）：手指回缩/抖动只会让本帧算出的角度变小，
                // setPullRotationAngleMonotonic 会丢弃比已达峰值更小的值，角度原地
                // 停住而不倒退；棘轮峰值只在上面「完全不可见」分支里被清零。
                pearl.setPullRotationAngleMonotonic(angleDegrees)
            } else {
                // 刷新完成后的系统回弹会让 pullDistance 从 60pt 降回 0。
                // 此阶段若继续按位移写角度，珍珠会反向倒转回去。
                pearl.holdCurrentRotationAngle()
            }
        }
    }

    deinit {
        offsetObserver?.invalidate()
    }
}

final class PearlRefreshView: UIView {
    private let dotsLayer = CALayer()
    private var dotLayers: [CAShapeLayer] = []
    private var currentRadius: CGFloat = 8.5
    /// 手势阶段最后一次明确写入的角度。不能依赖 presentation layer 读取：
    /// Tab2 刷新状态切换与视图更新发生在同一帧时，presentation 可能仍停在上一帧。
    private var pullRotationAngle: CGFloat = 0
    /// 本次连续下拉里角度到达过的最高点（度）。人手下拉不是单调直线，实测位移
    /// 的瞬间回缩不该反映成珍珠倒转——只有这个峰值会被写进 pullRotationAngle。
    private var dragRotationPeakDegrees: Double = 0

    private let dropletConfigs: [(diameter: CGFloat, angle: CGFloat, opacity: Float)] = [
        (3.0,   0, 1.00),
        (2.6,  45, 0.85),
        (2.2,  90, 0.65),
        (1.8, 135, 0.45),
        (1.4, 180, 0.30),
        (1.1, 225, 0.18)
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        dotsLayer.frame = bounds
        layer.addSublayer(dotsLayer)

        let tintColor = UIColor(AppTheme.Color.refreshIndicator)

        for config in dropletConfigs {
            let dot = CAShapeLayer()
            dot.fillColor = tintColor.cgColor
            dot.opacity = config.opacity
            dotsLayer.addSublayer(dot)
            dotLayers.append(dot)
        }

        updateOrbitRadius(8.5)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dotsLayer.frame = bounds
        updateOrbitRadius(currentRadius)
    }

    func updateOrbitRadius(_ radius: CGFloat) {
        currentRadius = radius
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for (index, config) in dropletConfigs.enumerated() {
            guard index < dotLayers.count else { continue }
            let dot = dotLayers[index]
            let rad = config.angle * .pi / 180.0
            let x = center.x + radius * sin(rad)
            let y = center.y - radius * cos(rad)
            let r = config.diameter / 2.0

            let path = UIBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: config.diameter, height: config.diameter))
            dot.path = path.cgPath
        }
    }

    func setPullRotationAngle(_ degrees: Double) {
        dotsLayer.removeAnimation(forKey: "rotate")
        let rad = degrees * .pi / 180.0
        pullRotationAngle = CGFloat(rad)
        dotsLayer.transform = CATransform3DMakeRotation(pullRotationAngle, 0, 0, 1)
    }

    /// 只进不退版本：忽略比已达峰值更小的角度，避免下拉过程中的实测回缩
    /// 被直接渲染成珍珠倒转。峰值只在整段下拉真正收回不可见时清零（见 stopRotating）。
    func setPullRotationAngleMonotonic(_ degrees: Double) {
        dragRotationPeakDegrees = max(dragRotationPeakDegrees, degrees)
        setPullRotationAngle(dragRotationPeakDegrees)
    }

    func startRotating() {
        if dotsLayer.animation(forKey: "rotate") == nil {
            // 从手势最后明确写入的角度继续旋转。直接保存输入值，而不读取
            // presentation layer，避免 Tab1/Tab2 不同状态更新时间造成一帧误差。
            let currentAngle = pullRotationAngle

            // 持续动画接管角度后，model layer 回到标准静止态；禁用隐式动画。
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dotsLayer.transform = CATransform3DIdentity
            CATransaction.commit()

            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = currentAngle
            rotation.toValue = currentAngle + (2 * .pi)
            rotation.duration = 1.2
            rotation.repeatCount = .infinity
            dotsLayer.add(rotation, forKey: "rotate")
        }
    }

    /// 刷新结束进入系统回弹时，冻结持续旋转的当前可见角度。
    /// 回弹只负责透明度与轨道收拢，不再把手势角度反向播放。
    func holdCurrentRotationAngle() {
        guard dotsLayer.animation(forKey: "rotate") != nil else { return }
        let visibleAngleValue = dotsLayer.presentation()?
            .value(forKeyPath: "transform.rotation.z") as? NSNumber
        let visibleAngle = CGFloat(truncating: visibleAngleValue ?? NSNumber(value: Double(pullRotationAngle)))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotsLayer.transform = CATransform3DMakeRotation(visibleAngle, 0, 0, 1)
        dotsLayer.removeAnimation(forKey: "rotate")
        CATransaction.commit()
        pullRotationAngle = visibleAngle
    }

    func stopRotating() {
        dotsLayer.removeAnimation(forKey: "rotate")
        pullRotationAngle = 0
        dragRotationPeakDegrees = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotsLayer.transform = CATransform3DIdentity
        CATransaction.commit()
    }
}
