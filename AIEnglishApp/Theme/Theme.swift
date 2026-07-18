import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hex helper (仅供 Primitive 层构造色值使用，不在组件中直接调用)
private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Primitive layer (raw values — never reference these directly in components)
private enum Primitive {
    // 间距
    static let space4: CGFloat  = 4
    static let space8: CGFloat  = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
    static let space56: CGFloat = 56

    // 控件尺寸
    static let size44: CGFloat = 44

    // 圆角
    static let radius8: CGFloat  = 8
    static let radius16: CGFloat = 16
    static let radius20: CGFloat = 20
    static let radius28: CGFloat = 28

    // ── 底与面（浅色锁定，固定 hex）──────────────────────────────────────
    static let pureWhite    = Color(hex: 0xFFFFFF)  // 页面底 / 卡片底
    static let surfaceInput = Color(hex: 0xFAF9F7)  // 输入框底

    // ── 文字：近黑锚系 ────────────────────────────────────────────────────
    static let nearBlack    = Color(hex: 0x1B1A18)  // 主文字 / CTA 锚
    static let charcoal     = Color(hex: 0x4A4844)  // 次要文字
    static let stone        = Color(hex: 0x85817A)  // 音标 / 词性 / 说明
    static let ash          = Color(hex: 0xB4B0A8)  // 最弱文字 / 占位

    // ── 糖果四色 · 全浓度（chip / 贴纸 / 小圆点 —— 仅用于小块点缀）────────
    static let candyBlue    = Color(hex: 0x84E2FA)
    static let candyPink    = Color(hex: 0xFF88D3)
    static let candyGreen   = Color(hex: 0xA6F686)
    static let candyYellow  = Color(hex: 0xFFCD20)

    // ── 糖果四色 · 淡染（气泡 / 胶囊 / 大面积底色）──────────────────────
    static let tintBlue     = Color(hex: 0xDDF5FD)
    static let tintPink     = Color(hex: 0xFFE3F4)
    static let tintGreen    = Color(hex: 0xE4FBD9)
    static let tintYellow   = Color(hex: 0xFFF3C4)

    // ── AI 追问 / 核心词组 ────────────────────────────────────────────────
    static let triggerGreen = Color(hex: 0x3E9D4E)  // 全浓度绿加深至 AA 可读

    // ── 描边 / 状态 ───────────────────────────────────────────────────────
    static let warmBorder   = Color(hex: 0xF1EFEB)
    static let dangerRed    = Color(hex: 0xDC2626)

    // ── 覆盖在实时媒体（相机画面）上的控件 ────────────────────────────────
    static let mediaSurface   = Color.black             // 相机全屏底
    static let controlOnMedia = Color.white             // 画面上的图标 / 快门
    static let scrimOnMedia    = Color.black.opacity(0.35) // 图标背后的半透明托底
}

// MARK: - Semantic layer (purpose-named tokens — components reference only these)
enum AppTheme {
    enum Space {
        static let paddingXS: CGFloat           = Primitive.space4
        static let paddingS: CGFloat            = Primitive.space8
        static let paddingM: CGFloat            = Primitive.space12
        static let paddingCard: CGFloat         = Primitive.space16
        static let paddingPage: CGFloat         = Primitive.space20
        static let paddingSection: CGFloat      = Primitive.space32
        static let paddingHero: CGFloat         = Primitive.space48
        static let paddingScreenBottom: CGFloat = Primitive.space56
    }

    enum Color {
        // 背景
        static let pageBg   = Primitive.pureWhite
        static let cardBg   = Primitive.pureWhite
        static let inputBg  = Primitive.surfaceInput

        // 文字（由重到轻）
        static let textPrimary   = Primitive.nearBlack
        static let textSecondary = Primitive.charcoal
        static let textMuted     = Primitive.stone
        static let textFaint     = Primitive.ash

        // 卡片类型 chip · 全浓度（仅用于小色块点缀，不做大面积填充）
        static let chipMoment    = Primitive.candyPink    // S4 Moment
        static let chipWord      = Primitive.candyBlue    // S1 Word
        static let chipPolish    = Primitive.candyYellow  // S2 Polish
        static let chipTranslate = Primitive.candyGreen   // S3 Translate

        // 淡染（大面积底：气泡 / 胶囊 / 插画底）
        static let tintMoment    = Primitive.tintPink
        static let tintWord      = Primitive.tintBlue
        static let tintPolish    = Primitive.tintYellow
        static let tintTranslate = Primitive.tintGreen

        // AI 追问区 / 核心词组
        static let accentBuddy   = Primitive.triggerGreen
        static let accentBuddyBg = Primitive.tintGreen

        // 交互控件（发送键 / CTA）
        static let interactive   = Primitive.nearBlack

        // 用户气泡
        static let bubbleUserBg   = Primitive.tintBlue
        static let bubbleUserText = Primitive.nearBlack
        static let bubbleAIBg     = Primitive.pureWhite

        // 描边 / 分割
        static let border       = Primitive.warmBorder
        static let borderDashed = Primitive.warmBorder
        static let divider      = Primitive.warmBorder

        // 语义状态
        static let danger = Primitive.dangerRed

        // 相机全屏表面 + 覆盖控件（白控件浮在实时画面上，与浅色主题无关）
        static let cameraBg        = Primitive.mediaSurface
        static let cameraControl   = Primitive.controlOnMedia
        static let cameraControlBg = Primitive.scrimOnMedia

        // MARK: 过渡别名（旧组件仍引用，横向迁移后废弃 —— 勿在新代码中使用）
        static let textAccent = Primitive.triggerGreen
    }

    enum Font {
        static let englishPrimary = SwiftUI.Font.system(.title2, weight: .semibold)   // 英文主内容 ~22
        static let englishBody    = SwiftUI.Font.system(.body)                        // 英文例句
        static let buddy          = SwiftUI.Font.system(.callout).italic()            // scene trigger（绿斜体）
        static let keyPhrase      = SwiftUI.Font.system(.callout, weight: .medium)    // 核心词组
        static let phonetic       = SwiftUI.Font.system(.footnote, design: .monospaced) // IPA 音标（等宽）
        static let pos            = SwiftUI.Font.system(.caption)                     // 词性
        static let chineseFaint   = SwiftUI.Font.system(.footnote)                    // 中文原文弱化
        static let chineseBody    = SwiftUI.Font.system(.callout)                     // 中文翻译
        static let date           = SwiftUI.Font.system(.caption2, weight: .semibold) // 日期分隔
        static let hero           = SwiftUI.Font.system(.largeTitle, weight: .bold)   // Onboarding 标题
        static let tabLabel       = SwiftUI.Font.system(.subheadline, weight: .semibold) // 顶部 Tab 名称
    }

    enum Radius {
        static let small: CGFloat          = Primitive.radius8   // tag / 小元素
        static let medium: CGFloat         = Primitive.radius16  // 卡片 / 气泡
        static let large: CGFloat          = Primitive.radius20  // 输入框
        static let glassContainer: CGFloat = Primitive.radius28  // 浮动 glass 容器

        // MARK: 过渡别名（旧组件仍引用，横向迁移后统一到上面三档）
        static let bubble: CGFloat = Primitive.radius16
        static let card: CGFloat   = Primitive.radius16
    }

    enum Shadow {
        static let cardColor: SwiftUI.Color = SwiftUI.Color.black.opacity(0.06)
        static let cardRadius: CGFloat = 14
        static let cardX: CGFloat = 0
        static let cardY: CGFloat = 2
    }

    enum Size {
        static let barControl: CGFloat = Primitive.size44  // 顶栏/工具栏可点控件标准边长
    }

    enum Motion {
        // 顶部 Tab 选中滑块：贴近系统分段控件的弹性手感（有回弹、不过冲太多）
        static let tabSelection: Animation = .spring(response: 0.34, dampingFraction: 0.72)
        // 顶栏滚动紧凑/恢复：稍快，确保不拖延内容阅读
        static let topBarCompact: Animation = .spring(response: 0.30, dampingFraction: 0.82)
    }
}

// MARK: - Glass container modifier
// iOS 26+: native Liquid Glass via .glassEffect(in:)
// iOS 17-25: .ultraThinMaterial + shadow fallback
// Components call .glassContainer() and never inline material values.

private struct GlassContainerModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius,
                    x: AppTheme.Shadow.cardX,
                    y: AppTheme.Shadow.cardY
                )
        }
    }
}

// MARK: - Glass bar item modifier (顶栏导航件)
// iOS 26: native glass in the given shape; interactive only for tappable items —
// interactive glass on a non-button container swallows child button taps
// iOS 17-25: ultraThinMaterial + shadow fallback
private struct GlassBarItemModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Shadow added explicitly: glass on a white background has no inherent
            // border or depth cue, so without a shadow the element is invisible at
            // rest (only visible when coloured content scrolls behind it).
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .shadow(color: AppTheme.Shadow.cardColor, radius: 10, x: 0, y: 2)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Top edge scroll fade (顶栏下内容可读性)
// iOS 26: registers soft scroll edge effect on the enclosing ScrollView
// iOS 17-25: no-op (safeAreaInset keeps content starting below the bar)
private struct TopEdgeFadeModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - GlassGroup container
// iOS 26: wraps children in GlassEffectContainer for merged rendering
// iOS 17-25: transparent passthrough (each child handles its own material fallback)
struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = AppTheme.Space.paddingS, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Glass capsule modifier (InputBar single-capsule container)
// iOS 26+: native Liquid Glass via .glassEffect(in: Capsule())
// iOS 17-25: .ultraThinMaterial in Capsule + shadow fallback
private struct GlassCapsuleModifier: ViewModifier {
    // Fixed 26pt radius = full-capsule appearance at the normal 52pt height,
    // and stays properly rounded when the capsule expands (e.g. with a
    // thumbnail). Capsule() would set radius = height/2, which grows to 64pt
    // at 128pt height and curves so far inward that corner content falls
    // outside the glass boundary.
    private let cornerRadius: CGFloat = 26

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius,
                    x: AppTheme.Shadow.cardX,
                    y: AppTheme.Shadow.cardY
                )
        }
    }
}

extension View {
    func glassContainer(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(GlassContainerModifier(cornerRadius: cornerRadius))
    }

    func glassBarItem<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(GlassBarItemModifier(shape: shape, interactive: interactive))
    }

    func topEdgeFade() -> some View {
        modifier(TopEdgeFadeModifier())
    }

    func glassCapsule() -> some View {
        modifier(GlassCapsuleModifier())
    }
}

