import SwiftUI

/// Onboarding 共享 UI 单元：主按钮 / 背景 / 入场动效。
/// 各页只组合这些组件，不在页面里重复拼装样式。

// MARK: - 主按钮：染色近黑实心胶囊，全宽（Warm Editorial：CTA 走 interactive，橙留作稀有强调）

struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(isEnabled ? AppTheme.Color.textOnChip : AppTheme.Color.controlDisabledText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .background(
                    isEnabled ? AppTheme.Color.interactive : AppTheme.Color.controlDisabledBg,
                    in: Capsule()
                )
                .overlay {
                    if !isEnabled {
                        Capsule()
                            .strokeBorder(
                                AppTheme.Color.controlDisabledBorder,
                                lineWidth: AppTheme.Size.disabledControlBorderWidth
                            )
                    }
                }
                .frame(minHeight: AppTheme.Size.inputBarMinHeight) // 高度对齐 Tab1 InputBar capsule
                .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.85))
    }
}

// MARK: - 返回按钮：裸 arrow.left 细线（N-1 + F-1）
//
// 曾是白圆+阴影（与 Settings 子页 backRow 同配方），已去掉：白圆 cardBg 压在
// pageBg 上对比仅 1.04:1（2026-10-08 按 #FBF8F5 重算），圆形本身几乎不可见，形完全靠阴影撑出——「靠阴影定义
// 的形」在视觉层级里读作"浮在最上层"＝最重要，但返回是本页最不重要的控件。
// 它也是整个 onboarding 里唯一的圆形（其余全为胶囊/圆角矩形），形状独一即抓眼；
// 44pt 直径与 Camera/Gallery 胶囊高度相当，次要动作占用了主控件体量。
// 去掉盒子后标题才可能贴近它上移，是 N-1 顶部收紧 20pt 的前提。
//
// 字形（F-1）：chevron.left → arrow.left。标准 SF chevron 在 .body/semibold 下
// 笔画约 2.6pt、等宽、粗短圆头，是 iOS 通用几何形；这一页其余全是衬线排版，
// 形态语言不同族。细线 arrow 呼应衬线字的细横线，横杆给出更明确的方向感。
// 若真机上 .regular 的笔画仍偏粗，退回自绘 Path（22×22，lineWidth 1.6，.round 线帽）。
//
// 颜色（F-4）：textSecondary(8.82:1) → textPrimary(16.49:1)（对 pageBg #FBF8F5，2026-10-08 重算）。
// 去掉白底和阴影后箭头是左上角唯一的墨迹，8.82 是「次要文字」的重量，撑不起「这里有个可点控件」。
// 中间档 neutral800(13.78:1) 观感也可以，但色板里没有对应语义 token——
// 不直接引用 Primitive，本轮用 textPrimary。

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - 背景层：暖纸 + 底部品牌橙光晕（椭圆画在内容之下，不染内容）
//
// ⚠️ 这团椭圆是 Onboarding 有意保留的 **A 档例外**，不要按「A 档不画椭圆」的通则删掉。
//
// 为什么这里必须是径向椭圆、线性背板替代不了：
// Onboarding 要的是「一团浮在 Continue 上方的暖光」，它有**横向衰减**——屏幕中线最暖、
// 左右边缘基本回到纸色。参照版实测（iPhone 16 Pro，距屏底 131pt 那一行）：
// 中线 R−B 比页面基线高 32，屏幕左右边缘只高 5.5。线性渐变在水平方向是恒定的，
// 物理上给不出这个 falloff——Tab1 WarmGlassBar 那套背板配方无法复现本页观感。
//
// 挂载方式：用 .overlay 而非 ZStack 兄弟——460pt 宽超过页宽，作兄弟会把整个组件的理想
// 宽度顶到 460，父级按理想尺寸居中时会把整页顶偏、在页边露出相邻页（真机验证过）。
// overlay 内容不参与尺寸上报。挂在已 ignoresSafeArea 的 pageBg 上 → 相对**物理**屏底定位。
//
// 椭圆中心落在屏底上方 90pt（frame 高 260 底对齐 → 中心 130，再 offsetY 40 下推），
// 正好在 Continue 按钮（屏底 46~98）背后，下半部会被 OnboardingBottomFade 的 130pt
// 纸雾压白——**这是刻意的，不是 bug**。曾有一版把「峰值被纸雾吃掉」当缺陷记录，
// 据此改成「暖光并进背板」的纯线性方案，结果暖度全堆在屏幕最底部、被按钮和 Home 条
// 挡死，页面上几乎看不到光。下半部被削掉之后，肉眼可见的最亮处才会浮到按钮上方
// 约 130pt，而底部 45pt 干净收成纸色——这正是要的观感。
struct OnboardingAuraBackground: View {
    var body: some View {
        AppTheme.Color.pageBg
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Color.canvasAura.opacity(0.20), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 460, height: 260)
                    .blur(radius: 44)
                    .offset(y: 40)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - 底部渐隐托：纯色长雾（只做 pageBg 渐变；光晕见 OnboardingAuraBackground）
//
// 原先用 VariableBlurBackdrop（单层 ultraThinMaterial，模糊半径恒定、只有透明度在变）：
// 渐隐区顶部相当于"低透明度的全模糊副本"盖在清晰内容上，在满幅静止照片背后会露出
// 可见的重影边和亮度台阶（Tab1 能藏住是因为背后是文字气泡+留白，onboarding 背后
// 是照片，对比更高更暴露）。换成纯色渐变没有"糊掉的副本"，物理上不存在上缘。
// 品牌橙光晕曾经并进这一层，现已移回 OnboardingAuraBackground——这一层位于
// ScrollView 之后，光晕挂在这里会画在**内容之上**、把照片和卡片蒙一层橙。
// 当初合并是为了「避免两层各调各的参数」，而现在全 App 只有背景层一处画光晕，
// 那个顾虑本身就不存在了。这一层现在只做纯色长雾，不再有任何叠加。
struct OnboardingBottomFade: View {
    // 186 → 130。186 是 Continue 还在距屏底 60 那个时代的遗产。
    //
    // 更关键的是这一层其实**不需要遮任何东西**：onboardingContentBottomClearance
    // 是滚动内容的底部 padding，意味着任何滚动位置下内容最后一个像素都不会低于
    // 距屏底 114（= 安全区 34 + 80），比 CTA 顶（98）还高 16pt。它却一直按
    // 「要把内容吃掉」的强度在画，结果是内容末端被蒙掉三成、底部发闷。
    // 现在它的职责只剩两件：给 CTA 一个落脚的底、维持底部暖区的收束感。
    //
    // 收到 130 之后（iPhone 16 Pro）：
    //   内容末端 114  34% → 7%      ← 主要收益，底部内容重新清晰
    //   CTA 顶   98   46% → 15%     ← 按钮的落脚感基本不变
    //   完全不透明区  0..26 → 0..18  ← 全在 CTA 下缘（46）以下，看不见
    //
    // 无底部安全区的机型（SE 3）因为整体上移，内容末端处仍有约 34%（原 60%）。
    // 要做到逐机型一致得让 height 跟着 safeAreaInsets.bottom 走，但页面跑在已内缩
    // 安全区的 GeometryReader 里读不到可靠值（顶部遮罩踩过同一个坑），
    // 权衡后用固定值 —— SE 上从 60% 降到 34% 已是明显改善。
    private let height: CGFloat = 130

    var body: some View {
        // 缓曲线渐变：前 24% 只积累到约 14% 不透明度（慢起步，穿过的文字不会被
        // 突兀截断），86% 处已完全不透明（把内容在够到按钮前彻底吃掉）。
        LinearGradient(
            stops: [
                .init(color: AppTheme.Color.pageBg.opacity(0), location: 0.0),
                .init(color: AppTheme.Color.pageBg.opacity(0.14), location: 0.24),
                .init(color: AppTheme.Color.pageBg, location: 0.86),
                .init(color: AppTheme.Color.pageBg, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - 滚动位移探针（F-4）
//
// 两条路并存，不再做「iOS 17 直接没有」的降级：
//   · iOS 18+：onScrollGeometryChange，系统原生，绑定具体 ScrollView 实例。
//   · iOS 17 ：KVO 直接观察底层 UIScrollView.contentOffset。
//
// 这不是第一次为这段掉进坑里，记录一下走过的弯路，别再重踩：
//   第一版只留 iOS 18 分支，iOS 17 直接不渲染遮罩（本刀要修的问题）。
//   第二版补了 GeometryReader + .coordinateSpace(name:) + PreferenceKey 的
//   iOS 17 兜底，诊断日志证实 GeometryReader 的 frame(in:) 确实随滚动逐帧
//   正确重算，一度以为修好了。
//   第三版怀疑是四个 onboarding 页（Screen1 / Screen2 / CaptureView 的
//   selection 态与 result 态，三页并排常驻挂载、共存于同一视图树）共用同一个
//   坐标空间名 "onboardingScroll" 撞了名，于是给四处各起独立名字——诊断日志
//   证明这个猜测是错的：改完之后 onPreferenceChange 依然只在页面首次挂载时
//   触发一次（值恒为 0），此后无论怎么滚动再也不回调，即使 GeometryReader
//   那一侧仍在每帧正确算出新的 minY。真正原因：GeometryReader 的 frame(in:)
//   重算由 UIKit 的布局系统在滚动时驱动，而 .onPreferenceChange 的回调依赖
//   SwiftUI 自己的声明式 diff 周期——纯 UIScrollView 惯性/弹性滚动触发的布局
//   变化不保证会让 SwiftUI 重新走一遍那棵子树的 diff，于是 preference 值变了、
//   订阅方却收不到通知。这是 GeometryReader+PreferenceKey 组合追踪滚动位移在
//   iOS 17 及更早版本上一个已知的不可靠点（iOS 18 加入 onScrollGeometryChange
//   正是为了绕开它），继续在这条路径上改名字、调结构都无法根治。
//   于是这次（第四版）换成对底层 UIScrollView.contentOffset 做 KVO：KVO 通知
//   由 UIKit 在赋值时同步派发，不经过 SwiftUI 的 diff 周期，滚动多快就能跟多快。
// internal，非 private：核心 KVO 逻辑单独锁一份单测（见 AIEnglishAppTests），
// 需要 @testable import 能直接拿到这个类型。
final class OnboardingScrollOffsetObserverView: UIView {
    var onOffsetChange: ((CGFloat) -> Void)?
    private var observation: NSKeyValueObservation?

    // 三个时机都要挂：didMoveToSuperview 触发时，本视图往往只挂到了
    // .background 包装出的中间容器上，UIScrollView 还不在祖先链里（诊断日志
    // 实测过，此时 enclosingScrollView() 拿到的祖先链只有一层）；
    // didMoveToWindow / layoutSubviews 在完整视图层级搭好之后才发生，
    // attachIfNeeded 内部有 observation == nil 的哨兵，重复调用无副作用。
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        attachIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard observation == nil else { return }
        guard let scrollView = enclosingScrollView() else { return }
        observation = scrollView.observe(\.contentOffset, options: [.new, .initial]) { [weak self] scrollView, _ in
            // 与 iOS 18 分支同一套零点语义：静止 = 0、下滚为正（见下方 contentInsets.top 说明）。
            let offset = max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            self?.onOffsetChange?(offset)
        }
    }

    private func enclosingScrollView() -> UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }
}

private struct OnboardingScrollOffsetObserver: UIViewRepresentable {
    @Binding var scrollOffset: CGFloat

    func makeUIView(context: Context) -> OnboardingScrollOffsetObserverView {
        let view = OnboardingScrollOffsetObserverView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onOffsetChange = { offset in
            // KVO 回调可能落在滚动动画的中间帧上，写 @Binding 需要回到主线程语义安全的路径。
            if Thread.isMainThread {
                scrollOffset = offset
            } else {
                DispatchQueue.main.async { scrollOffset = offset }
            }
        }
        return view
    }

    func updateUIView(_ uiView: OnboardingScrollOffsetObserverView, context: Context) {}
}

private struct OnboardingScrollOffsetTracking: ViewModifier {
    @Binding var scrollOffset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            // contentOffset.y 的零点是「内容顶边贴住 ScrollView 的内容内边距上沿」，
            // 也就是静止时它等于 -contentInsets.top（安全区、scrollIndicatorInsets 等
            // 都会计进来）。直接 max(0, contentOffset.y) 会把「已经滚了但还没超过
            // inset」的那一段全部夹成 0——真机上表现为 off 恒等于 0、遮罩永不出现。
            // 加回 contentInsets.top 之后，静止 = 0、下滚为正，语义才对得上。
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, newValue in
                scrollOffset = newValue
            }
        } else {
            content
        }
    }
}

extension View {
    /// 贴在 **ScrollView 本身** 上：iOS 18+ 用系统原生 onScrollGeometryChange。
    /// iOS 17 的探测改由 `onboardingScrollOffsetProbe` 负责（见下方说明）。
    func onboardingScrollOffsetTracking(_ scrollOffset: Binding<CGFloat>) -> some View {
        modifier(OnboardingScrollOffsetTracking(scrollOffset: scrollOffset))
    }

    /// 贴在 **滚动内容**（ScrollView 的直接子视图）上。iOS 18+ 已由
    /// `onboardingScrollOffsetTracking` 的 onScrollGeometryChange 提供数据，这里
    /// 空转；iOS 17 走 KVO 直接观察底层 UIScrollView.contentOffset——不再依赖
    /// SwiftUI 的 PreferenceKey/命名坐标空间管线（那条路径在 iOS 17 上已确认
    /// 不可靠，见上方大段注释）。
    func onboardingScrollOffsetProbe(_ scrollOffset: Binding<CGFloat>) -> some View {
        Group {
            if #available(iOS 18.0, *) {
                self
            } else {
                self.background(OnboardingScrollOffsetObserver(scrollOffset: scrollOffset))
            }
        }
    }
}

// MARK: - 顶部渐隐托（F-4）：BottomFade 的镜像，同一套 pageBg 纯色渐变，不引入新材质。
//
// 必须绑滚动位移、不能常驻：静止时标题 cap-top 只在箭头下沿以下 10pt，常驻的顶部
// 渐隐会把静止状态的标题顶部也吃掉。绑上滚动之后静止时标题完整、一滚才出现——
// 这正是 iOS 自己的 scroll edge effect 的做法。
//
// ⚠️ 坐标系：**页面坐标（安全区上沿 = 0），不是屏幕坐标。**
//
// 上一版按「屏幕坐标 + safeAreaTop 实算 + .ignoresSafeArea(edges: .top)」写，真机翻车：
// 页面跑在 OnboardingView 已内缩安全区的 GeometryReader 里，向 key window 取
// safeAreaInsets.top 拿到 0，于是不透明段只到 46 而整块渐变又贴着物理屏顶，
// 结果标题第一行只被盖掉一部分、第二行完全没盖到（真机截图实测）。
//
// 现在不再需要知道 safeTop：
//   · ScrollView 本身就被安全区内缩，内容**根本画不到安全区上沿以上**（截图里标题
//     那条硬切边就是这条线），所以遮罩没有任何理由往上越过它；
//   · 状态栏那条已经由 OnboardingAuraBackground 的 pageBg 实色铺满，不需要再盖一层。
// 于是不透明段 = onboardingBackInset + barControl（＝返回箭头下沿，页面坐标 46），
// 全程只用 token 算，逐机型自洽，不碰 UIKit、不依赖 ignoresSafeArea 的传播行为。
//
// 收尾用缓曲线而非线性断崖：把 BottomFade 的曲线反过来用——跑道前 14% 只掉到 .86
// （慢起步），中段 62% 走完主要落差，最后 24% 收尾。与底部同一套手感，上下呼应。
// （最早那版是 20pt 内线性砸到 0，扫过文字时会露出一条看得见的横向硬边。）
struct OnboardingTopFade: View {
    /// 直接吃滚动位移；clamp 与缓动都在组件内做，避免四个调用点各写一遍。
    var scrollOffset: CGFloat

    /// 不透明段下沿（页面坐标）。只盖箭头字形，不盖满 44 触区——见 token 注释。
    private var opaqueTo: CGFloat { AppTheme.Size.onboardingTopFadeOpaque }

    private var runway: CGFloat { AppTheme.Size.onboardingTopFadeRunway }

    private var height: CGFloat { opaqueTo + runway }

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: AppTheme.Color.pageBg,               location: 0),
                .init(color: AppTheme.Color.pageBg,               location: opaqueTo / height),
                .init(color: AppTheme.Color.pageBg.opacity(0.86), location: (opaqueTo + runway * 0.14) / height),
                .init(color: AppTheme.Color.pageBg.opacity(0.14), location: (opaqueTo + runway * 0.76) / height),
                .init(color: AppTheme.Color.pageBg.opacity(0),    location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 刻意不加 .ignoresSafeArea——见上方坐标系说明。
        .opacity(progress)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }


    /// smoothstep 而非线性：线性起步在刚开始滚的第一帧就有一层灰扑上来，很"啪"。
    private var progress: CGFloat {
        let t = min(max(scrollOffset / AppTheme.Size.onboardingTopFadeRamp, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - 入场动效：淡入 + 上移；Reduce Motion 时只做淡入

extension View {
    func onboardingEntrance(appeared: Bool, reduceMotion: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .animation(.easeOut(duration: 0.55).delay(delay), value: appeared)
    }
}
