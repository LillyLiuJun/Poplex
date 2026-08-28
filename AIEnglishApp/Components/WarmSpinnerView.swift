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
        WarmRefreshControlHelper()
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

// MARK: - Direct RefreshControl UIKit Injector (动态自愈 + 手势渐进跟随)
struct WarmRefreshControlHelper: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIView {
        let view = WarmRefreshControlDetectingView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? WarmRefreshControlDetectingView {
            view.reduceMotion = reduceMotion
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

        if pullDistance < 15.0 {
            pearl.alpha = 0.0
            pearl.stopRotating()
        } else {
            let progress = min(1.0, (pullDistance - 15.0) / 45.0)  // 15pt ~ 60pt
            pearl.alpha = progress
            // 水滴由散开 11.5pt 向心聚拢到标准 8.5pt
            let currentRadius = 11.5 - (3.0 * progress)
            pearl.updateOrbitRadius(currentRadius)
            if scrollView.isDragging {
                pearl.setPullRotationAngle(reduceMotion ? 0 : Double(progress * 180.0))
            } else {
                // 刷新完成后的系统回弹会让 pullDistance 从 60pt 降回 0。
                // 此阶段若继续按 progress 写角度，珍珠会从 180°反向倒转回去。
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotsLayer.transform = CATransform3DIdentity
        CATransaction.commit()
    }
}
