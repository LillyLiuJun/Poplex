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

    // ── Supa Palette 色板（围绕品牌色 F97B0A 构建，浅色锁定）─────────────────
    // 说明：色阶方向为 50 = 最浅、950 = 最深/最饱和；primary950 即品牌种子色。
    // 深色模式数值 Supa Palette 尚未导出，先只做浅色，勿自行补深色值。

    // Primary — 品牌橙
    static let primary50  = Color(hex: 0xF9F2EB)
    static let primary100 = Color(hex: 0xF6E9DC)
    static let primary200 = Color(hex: 0xF5E0CC)
    static let primary300 = Color(hex: 0xF4DAC0)
    static let primary400 = Color(hex: 0xF5D3B3)
    static let primary500 = Color(hex: 0xF5CCA6)
    static let primary600 = Color(hex: 0xF8C18F)
    static let primary700 = Color(hex: 0xFBB16E)
    static let primary800 = Color(hex: 0xFBA04E)
    static let primary900 = Color(hex: 0xFA8E2C)
    static let primary950 = Color(hex: 0xF97B0A)

    // Neutral — 暖灰（与品牌同色相）
    static let neutral50  = Color(hex: 0xF8F0E6)
    static let neutral100 = Color(hex: 0xEEE0CE)
    static let neutral200 = Color(hex: 0xE3CFB9)
    static let neutral300 = Color(hex: 0xD9C3AB)
    static let neutral400 = Color(hex: 0xCEB79E)
    static let neutral500 = Color(hex: 0xC2AB92)
    static let neutral600 = Color(hex: 0xAB9782)
    static let neutral700 = Color(hex: 0x897A6B)
    static let neutral800 = Color(hex: 0x665B50)
    static let neutral900 = Color(hex: 0x413A33)
    static let neutral950 = Color(hex: 0x1C1916)

    // Warning — 金黄（黄色系物理上做不出高对比度深色，只作浅底 + 深色文字用）
    static let warning50  = Color(hex: 0xFAF8EC)
    static let warning100 = Color(hex: 0xF6F3DB)
    static let warning200 = Color(hex: 0xF3EECA)
    static let warning300 = Color(hex: 0xF2EABE)
    static let warning400 = Color(hex: 0xF0E7B1)
    static let warning500 = Color(hex: 0xEFE5A4)
    static let warning600 = Color(hex: 0xEDE18E)
    static let warning700 = Color(hex: 0xEBDB6D)
    static let warning800 = Color(hex: 0xE7D24C)
    static let warning900 = Color(hex: 0xE2CA29)
    static let warning950 = Color(hex: 0xC8B11B)

    // Success — 绿
    static let success50  = Color(hex: 0xF2F8F5)
    static let success100 = Color(hex: 0xE4F1EA)
    static let success200 = Color(hex: 0xD6E9E0)
    static let success300 = Color(hex: 0xCCE4D8)
    static let success400 = Color(hex: 0xC2DFD0)
    static let success500 = Color(hex: 0xB8DAC8)
    static let success600 = Color(hex: 0xA8D2BB)
    static let success700 = Color(hex: 0x90C5A9)
    static let success800 = Color(hex: 0x76B894)
    static let success900 = Color(hex: 0x5AAA7F)
    static let success950 = Color(hex: 0x4A8F6A)

    // Error — 珊瑚红
    static let error50  = Color(hex: 0xFAF0EB)
    static let error100 = Color(hex: 0xF7E6DF)
    static let error200 = Color(hex: 0xF5DCD2)
    static let error300 = Color(hex: 0xF3D4C9)
    static let error400 = Color(hex: 0xF2CCC0)
    static let error500 = Color(hex: 0xF1C3B7)
    static let error600 = Color(hex: 0xEFB4A7)
    static let error700 = Color(hex: 0xEC9D90)
    static let error800 = Color(hex: 0xE88979)
    static let error900 = Color(hex: 0xE47360)
    static let error950 = Color(hex: 0xE05C46)

    // Info — 蓝
    static let info50  = Color(hex: 0xF0F6F9)
    static let info100 = Color(hex: 0xE2EDF4)
    static let info200 = Color(hex: 0xD3E3F0)
    static let info300 = Color(hex: 0xC8DCED)
    static let info400 = Color(hex: 0xBDD4EA)
    static let info500 = Color(hex: 0xB1CBE8)
    static let info600 = Color(hex: 0x9EBCE4)
    static let info700 = Color(hex: 0x81A4E0)
    static let info800 = Color(hex: 0x658FD8)
    static let info900 = Color(hex: 0x4679D1)
    static let info950 = Color(hex: 0x3065C0)

    // ── 近白暖底：比 neutral50 更接近白，用于卡片与页面之间的柔和分层 ────────
    static let warmWhite = Color(hex: 0xFDFAF6)

    // ── 覆盖在实时媒体（相机画面 / 用户照片）上的控件 ────────────────────────
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
        // 背景（暖米色页面 + 近白暖卡片，靠层次而非纯白飘白区分）
        static let pageBg   = Primitive.neutral50   // 暖米色页面（非纯白）
        static let cardBg   = Primitive.warmWhite   // 近白暖卡片，比页面浅一档
        static let inputBg  = Primitive.warmWhite

        // 文字（由重到轻）
        static let textPrimary   = Primitive.neutral900
        static let textSecondary = Primitive.neutral700
        static let textMuted     = Primitive.neutral500
        static let textFaint     = Primitive.neutral300

        // 卡片类型 chip —— 四种卡片各用一色区分（PM：单色不好看）。
        // 各取色阶较深/饱和一档以承载白字；warning（黄）物理上扛不住白字，
        // 故 Polish 用浅金底 + 深色文字（见 S2GrammarCardView 传入的 textColor）。
        static let chipMoment    = Primitive.primary900  // S4 Moment    · 橙 + 白字
        static let chipWord      = Primitive.info900     // S1 Word      · 蓝 + 白字
        static let chipPolish    = Primitive.warning700  // S2 Polish    · 浅金 + 深字
        static let chipTranslate = Primitive.success950  // S3 Translate · 绿 + 白字
        static let textOnChip    = Primitive.neutral50   // chip 胶囊上的浅色文字（默认）

        // 品牌 / 交互
        // primary500 在无障碍配对检查中测出过孤立的低对比度异常（APCA -21），
        // 承载文字的默认品牌色沿用 600，不回退到 500。
        static let brandDefault  = Primitive.primary600  // 默认品牌色（浅底/描边等）
        static let brandStrong   = Primitive.primary900  // 实心填充上承载浅色文字（如 chip / CTA）
        static let brandSubtleBg = Primitive.primary50   // 品牌极淡底

        // AI 追问区 / 核心词组（原糖果绿收敛为中性 + 极淡暖底，绿色不再出现）
        static let accentBuddy   = Primitive.neutral700
        static let accentBuddyBg = Primitive.primary50

        // 交互控件（发送键 / CTA / 光标）—— 暖近黑
        static let interactive   = Primitive.neutral950

        // 用户气泡（原糖果蓝 → 暖中性底 + 深色文字）
        static let bubbleUserBg   = Primitive.neutral100
        static let bubbleUserText = Primitive.neutral900
        static let bubbleAIBg     = Primitive.warmWhite

        // 描边 / 分割
        static let border       = Primitive.neutral200
        static let borderDashed = Primitive.neutral200
        static let divider      = Primitive.neutral200

        // 语义状态（承载文字，取最深一档珊瑚红以保可读性）
        static let danger = Primitive.error950

        // 图片加载占位底
        static let imagePlaceholderBg = Primitive.neutral100

        // 相机全屏表面 + 覆盖控件（白控件浮在实时画面上，与浅色主题无关）
        static let cameraBg        = Primitive.mediaSurface
        static let cameraControl   = Primitive.controlOnMedia
        static let cameraControlBg = Primitive.scrimOnMedia

        // MARK: 过渡别名（Mine 等未换肤界面仍引用；橘色化后指向品牌强色，
        // 各界面换肤时再统一到 brandStrong / accent* —— 勿在新代码中使用）
        static let textAccent = Primitive.primary900
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

