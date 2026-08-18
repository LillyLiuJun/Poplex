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
// pageBg 上对比仅 1.06:1，圆形本身几乎不可见，形完全靠阴影撑出——「靠阴影定义
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
// 颜色（F-4）：textSecondary(8.69:1) → textPrimary(16.25:1)。去掉白底和阴影后
// 箭头是左上角唯一的墨迹，8.69 是「次要文字」的重量，撑不起「这里有个可点控件」。
// 中间档 neutral800(13.57:1) 观感也可以，但色板里没有对应语义 token——
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

// MARK: - 页面背景：暖米白 + 网格点底纹 + 底部品牌橙光晕（与 CanvasBackground 参数统一）

struct OnboardingAuraBackground: View {
    private let gridSpacing: CGFloat = 18
    private let dotRadius: CGFloat = 0.6

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg
                .ignoresSafeArea()
                // 底部品牌橙光晕。原先挂在 OnboardingBottomFade 上，那层位于
                // ScrollView **之后**，于是光晕画在内容之上，把照片、卡片、文字
                // 全蒙了一道橙——装饰性的氛围光不该染内容。移到背景层后氛围不变
                // （页面底色上照样有这团暖光），内容盖在它上面。
                // 用 .overlay 而非 ZStack 兄弟：460pt 宽超过页宽，作兄弟会把整个
                // 组件的理想宽度顶到 460，父级按理想尺寸居中时会把整页顶偏、
                // 在页边露出相邻页（真机验证过）。overlay 内容不参与尺寸上报。
                // 挂在已 ignoresSafeArea 的 pageBg 上 → 相对**物理**屏底定位。
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.Color.canvasAura.opacity(0.24), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .frame(width: 460, height: 260)
                        .blur(radius: 44)
                        .offset(y: 40)
                        .allowsHitTesting(false)
                }

            // 网格点底纹（与 Tab1/Tab2 CanvasBackground 一致）
            Canvas { context, size in
                let dot = Path(
                    ellipseIn: CGRect(x: 0, y: 0, width: dotRadius * 2, height: dotRadius * 2)
                )
                let color = GraphicsContext.Shading.color(
                    AppTheme.Color.canvasGridDot.opacity(0.08)
                )
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        context.fill(dot.offsetBy(dx: x, dy: y), with: color)
                        x += gridSpacing
                    }
                    y += gridSpacing
                }
            }
            .ignoresSafeArea()

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
    private let height: CGFloat = 186

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
//   · iOS 18+：onScrollGeometryChange，系统原生。
//   · iOS 17 ：命名坐标空间 + PreferenceKey 探针。
//
// 上一版只留了 iOS 18 分支，理由是「PreferenceKey 写法滚动时不重新触发」。
// 那次失败的真正原因是**探针没有落在一个命名坐标空间里**：GeometryReader 若相对
// .global 或未命名空间取 frame，ScrollView 内容平移不会引起该 frame 变化，于是
// preference 永远是同一个值、看起来像"不触发"。补上 .coordinateSpace(name:)，
// 并把探针贴在滚动内容（而不是 ScrollView 本身）上之后，内容相对 ScrollView 的
// minY 会随滚动实时变化，preference 正常重发。
private enum OnboardingScrollSpace {
    static let name = "onboardingScroll"
}

private struct OnboardingScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
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
                .coordinateSpace(name: OnboardingScrollSpace.name)
                .onPreferenceChange(OnboardingScrollOffsetKey.self) { value in
                    scrollOffset = max(0, value)
                }
        }
    }
}

extension View {
    /// 贴在 **ScrollView 本身** 上：声明命名坐标空间并接收探针上报。
    func onboardingScrollOffsetTracking(_ scrollOffset: Binding<CGFloat>) -> some View {
        modifier(OnboardingScrollOffsetTracking(scrollOffset: scrollOffset))
    }

    /// 贴在 **滚动内容**（ScrollView 的直接子视图）上：上报内容顶边相对 ScrollView
    /// 的位移。iOS 18+ 走 onScrollGeometryChange 用不到它，但挂着无副作用——
    /// GeometryReader 放在 .background 里不参与父视图的尺寸上报。
    func onboardingScrollOffsetProbe() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OnboardingScrollOffsetKey.self,
                    value: -proxy.frame(in: .named(OnboardingScrollSpace.name)).minY
                )
            }
        )
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
