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
    static let size28: CGFloat = 28
    static let size36: CGFloat = 36
    static let size44: CGFloat = 44
    static let size84: CGFloat = 84

    // 圆角
    static let radius8: CGFloat  = 8
    static let radius16: CGFloat = 16
    static let radius20: CGFloat = 20
    static let radius28: CGFloat = 28

    // ── Warm Minimalism 色板（温润极简，围绕品牌色 FF7622 构建，浅色锁定）──────
    // 说明：primary 色阶方向沿用 50 = 最浅、950 = 最深/最饱和（=品牌种子色 FF7622），
    //   低编号为种子色朝纯白的渐浅色阶（保留橘色相，不发灰发奶）。
    //   neutral 为低彩度暖灰（类 Stone），提供近白底 + 中性暖灰文字的干净层次。
    // 深色模式数值尚未导出，先只做浅色，勿自行补深色值。

    // Primary — 品牌橙（种子 FF7622，浅色阶为其朝白渐变）
    static let primary50  = Color(hex: 0xFFF8F4)
    static let primary100 = Color(hex: 0xFFF3EB)
    static let primary200 = Color(hex: 0xFFEADE)
    static let primary300 = Color(hex: 0xFFDFCC)
    static let primary400 = Color(hex: 0xFFD3B8)
    static let primary500 = Color(hex: 0xFFC6A2)
    static let primary600 = Color(hex: 0xFFB588)
    static let primary700 = Color(hex: 0xFFA36B)
    static let primary800 = Color(hex: 0xFF914E)
    static let primary900 = Color(hex: 0xFF8438)
    static let primary950 = Color(hex: 0xFF7622)

    // Primary Deep — 比种子更深的橘（用于浅橘底上承载文字 / 深橘强调，
    // 渐白色阶里没有更深的档，单列一枚 shade）
    static let primaryDeep = Color(hex: 0xC2410C)

    // Neutral — 品牌染色中性（Warm Editorial）：深色端从种子橙 FF7622 掺入橙色相
    //   （黑带暖底，H≈24°），中/浅灰去棕回灰（低彩度、只留一丝暖），暖纸页面。
    //   深色有温度、大面积灰干净。深色模式数值未导出，勿自行补。
    static let neutral50  = Color(hex: 0xFBF6F1)  // 暖纸页面（pageBg）
    static let neutral100 = Color(hex: 0xEBE8E3)  // 用户气泡 / 图片占位底
    static let neutral200 = Color(hex: 0xE3DFD9)  // 描边 / 分割
    static let neutral300 = Color(hex: 0xC7C3BD)  // 最弱文字（faint）
    static let neutral400 = Color(hex: 0xA5A099)  // 区块小标（label）
    static let neutral500 = Color(hex: 0x7C7773)  // 次要弱文字（muted）
    static let neutral600 = Color(hex: 0x5C554B)
    static let neutral700 = Color(hex: 0x4B4640)  // 次要文字（secondary）
    static let neutral800 = Color(hex: 0x2E2820)
    static let neutral900 = Color(hex: 0x211811)  // 主文字 · 品牌染色近黑
    static let neutral950 = Color(hex: 0x17120C)  // interactive / CTA 近黑

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

    // ── 暖近白卡片：比暖纸页面（neutral50 #FBF6F1）更亮，带一丝暖底，
    //    靠"更亮 + 柔阴影"分层；不用纯白，避免冷白跳出整套暖色系 ──
    static let warmWhite = Color(hex: 0xFFFDF8)

    // ── App 图标资产色 ────────────────────────────────────────────────────
    // 开屏动画的第 0 帧必须与 iOS 图标放大转场的最后一帧一致，否则启动会闪一下。
    // 故这两枚直接取 AppIcon.appiconset 母版里的实际色值，单列、不与 neutral50
    // (#FBF6F1) / neutral900 (#211811) 合并 —— 差值虽小，合并就会在接缝处露出来。
    // 改动前请同步改 Assets.xcassets/AppIcon.appiconset/poplex_icon_master.svg。
    static let iconGround = Color(hex: 0xFBF8F5)  // 图标底 = 开屏底
    static let iconInk    = Color(hex: 0x2A2320)  // 图标墨点 = 开屏墨点

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

        // 区标题→内容（Topics / Materials 分区标题到其卡片的呼吸距离，统一散落字面值）
        static let titleToContent: CGFloat      = Primitive.space24
        // 列表行垂直节奏（Topics 进度行上下留白）
        static let listRowVertical: CGFloat     = Primitive.space12
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
        static let textLabel     = Primitive.neutral400  // 区块小标（例句 / 说明）

        // 卡片类型 chip 配色。第5刀卡片合并后 CardTypeChip 改走单色 textMuted，
        // 以下四色暂时无引用，留待 token 卫生轮决定合并/删除（勿在本刀顺手删）。
        static let chipMoment    = Primitive.primary900  // Moment    · 橙 + 白字
        static let chipWord      = Primitive.info900     // Word      · 蓝 + 白字
        static let chipPolish    = Primitive.warning700  // Polish    · 浅金 + 深字
        static let chipTranslate = Primitive.success950  // Translate · 绿 + 白字
        static let textOnChip    = Primitive.neutral50   // chip 胶囊上的浅色文字（默认）

        // 品牌 / 交互
        // brandStrong 指向种子橙 FF7622（实心填充承载白字）；brandDefault 取稍浅一档
        // 作描边/浅底强调；brandSubtleBg 取浅橘淡底。
        static let brandDefault  = Primitive.primary900  // 默认品牌色（浅底/描边等）
        static let brandStrong   = Primitive.primary950  // 实心填充上承载浅色文字（如 CTA），=种子橙
        static let brandSubtleBg = Primitive.primary100  // 品牌极淡橘底

        // AI 追问区 / 核心词组（温润极简：透明底 + 橘色图标 + 顶部细分割线，不再整块底）
        static let accentBuddy   = Primitive.neutral700
        static let accentBuddyBg = SwiftUI.Color.clear

        // 交互控件（发送键 / CTA / 光标）—— 暖近黑
        static let interactive   = Primitive.neutral950

        // 用户气泡（极简暖灰底 + 深暖灰字：提问容器降权，凸显 AI 单词/语法卡片）
        static let bubbleUserBg   = Primitive.neutral100
        static let bubbleUserText = Primitive.neutral900
        static let bubbleAIBg     = Primitive.warmWhite

        // 描边 / 分割
        static let border       = Primitive.neutral200
        static let borderDashed = Primitive.neutral200
        static let divider      = Primitive.neutral200

        // 语义状态（承载文字，取最深一档珊瑚红以保可读性）
        static let danger = Primitive.error950

        // 模态遮罩：加载 / 删除时压暗背景。用暖近黑（neutral950）而非纯黑，与暖色系一致
        static let scrimOverlay = Primitive.neutral950.opacity(0.25)

        // 图片加载占位底
        static let imagePlaceholderBg = Primitive.neutral100

        // 词条类型图标的回退底块（无配图时）：比图片占位底更淡，让描边类型图标退后作弱提示
        static let iconTileBg = Primitive.neutral900.opacity(0.05)

        // 首页画布装饰（网格点 = 暖灰底纹；aura = 底部品牌橘光晕）——
        // 透明度在组件内按需施加，此处只定义基色
        static let canvasGridDot = Primitive.neutral500
        static let canvasAura     = Primitive.primary950

        // 磨砂玻璃卡（Tab2 卡片 / 列表容器）：暖白 44% 薄蒙 + 0.5px 白边，
        // 叠在 ultraThinMaterial 上出"透"感；画布光晕是玻璃透出的内容。
        // 基色复用 warmWhite / white，透明度本身是玻璃配方的一部分。
        static let glassCardSurface = Primitive.warmWhite.opacity(0.44)
        static let glassCardEdge    = SwiftUI.Color.white.opacity(0.72)

        // 暖橙薄纱卡（warmGlassCard · Topics 列表容器 + Hero 卡）：单层暖纸白底 +
        // 整卡极淡橙薄纱 + 右上角品牌橙柔光，去描边。透明度是配方的一部分，在 modifier 内施加。
        static let warmGlassSurface = Primitive.warmWhite   // 暖纸白底（不透明单层）
        static let warmGlassGlow    = Primitive.primary950  // 品牌橙柔光基色（=种子橙）
        // 半轻灰胶囊底（计数 + chevron 合并单元）：暖近黑极低透明，中性、不引入橙
        static let pillNeutralBg    = Primitive.neutral900.opacity(0.06)

        // 玻璃卡内的轻量元素：进度条轨道/填充、行间隔线——暖近黑低透明，
        // 跟着底色走，不再是实心灰。hairline 与 progressTrack 同值是有意共享：
        // 玻璃容器内"最轻一档"的分隔统一 4.5%。
        static let progressTrack = Primitive.neutral900.opacity(0.045)
        static let progressFill  = Primitive.neutral900.opacity(0.145)
        static let glassHairline = Primitive.neutral900.opacity(0.045)

        // 开屏（= App 图标资产色，用于和图标转场无缝衔接）
        // 字母本身走 brandStrong（= 种子橙 FF7622，与图标里的 P 同色），不另立 token。
        static let splashBg  = Primitive.iconGround
        static let splashDot = Primitive.iconInk

        // 相机全屏表面 + 覆盖控件（白控件浮在实时画面上，与浅色主题无关）
        static let cameraBg        = Primitive.mediaSurface
        static let cameraControl   = Primitive.controlOnMedia
        static let cameraControlBg = Primitive.scrimOnMedia

        // Tab2 词条 badge 配色（按表达类型区分，而非来源材料粒度）
        static let badgeWordBg       = Primitive.info100     // 单词（word）
        static let badgeWordIcon     = Primitive.info700
        static let badgePhraseBg     = Primitive.primary100  // 短语/搭配/句型（phrase/collocation/pattern）
        static let badgePhraseIcon   = Primitive.primary800
        static let badgeIdiomBg      = Primitive.warning200  // 习语/俚语（idiom/slang）
        static let badgeIdiomIcon    = Primitive.warning800
        static let badgeDialogueBg   = Primitive.success100  // 对话来源（dialogue source type）
        static let badgeDialogueIcon = Primitive.success800

        // About AI & Your Data 设置行图标色（绿色，与 AI 功能相关）
        static let aiFeatureAccent = Primitive.success950

        // MARK: 过渡别名（Mine 等未换肤界面仍引用；指向品牌强色 = 种子橙，
        // 各界面换肤时再统一到 brandStrong / accent* —— 勿在新代码中使用）
        static let textAccent = Primitive.primary950
    }

    enum Font {
        // 英文主内容 / 词条大标题走衬线（Warm Editorial：内容用 Newsreader；
        // 暂以系统衬线 New York 顶位，待打包 Newsreader 后仅换 design/family）。
        static let englishPrimary = SwiftUI.Font.system(.body, design: .serif)                    // 英文主内容（内容衬线，规则用 .body 保 Dynamic Type）
        static let wordTitle      = SwiftUI.Font.system(.title2, design: .serif, weight: .semibold) // 词条大标题（内容衬线，半粗以有分量不过重）
        static let englishBody    = SwiftUI.Font.system(.body)                        // 英文例句
        static let buddy          = SwiftUI.Font.system(.subheadline, weight: .medium) // 场景追问（=参考稿 14.5/500）
        static let keyPhrase      = SwiftUI.Font.system(.subheadline, weight: .bold)  // 核心词组（=参考稿 kp-word 15/700 加黑）
        static let phonetic       = SwiftUI.Font.system(.footnote, design: .monospaced) // IPA 音标（等宽）
        static let pos            = SwiftUI.Font.system(.caption2)                    // 词性 / 卡片 Meta（=参考稿 ~11-12px）
        static let popsCount      = SwiftUI.Font.system(.caption, weight: .medium)    // Topics 进度行 pops 计数（配 .monospacedDigit()）
        static let iconBadgeLetter = SwiftUI.Font.system(.subheadline, design: .serif, weight: .semibold) // 词条类型徽章里的衬线字母（句中单词 A）
        static let cardMeta       = SwiftUI.Font.system(.footnote, weight: .medium)   // 卡片右上角 meta（Hero 卡 pops 数等）
        static let sectionLabel   = SwiftUI.Font.system(.caption2, weight: .semibold) // 区块小标（例句 / 说明，11/600）
        static let chineseFaint   = SwiftUI.Font.system(.footnote)                    // 中文原文弱化
        static let chineseBody    = SwiftUI.Font.system(.subheadline)                 // 中文翻译（=参考稿 content-zh 14px 灰）
        static let date           = SwiftUI.Font.system(.caption2, weight: .semibold) // 日期分隔
        static let hero           = SwiftUI.Font.system(.largeTitle, weight: .bold)   // Onboarding 标题
        static let screenTitle    = SwiftUI.Font.system(.title2, weight: .bold)       // 功能页大标题（onboarding 实操页等）
        static let pageTitleSerif = SwiftUI.Font.system(.largeTitle, design: .serif, weight: .semibold) // 页面衬线大标题（Warm Editorial：Tab2「Not open yet」等，与内容衬线同族）
        static let onboardingHeroSerif = SwiftUI.Font.system(size: 46, weight: .semibold, design: .serif) // Onboarding 封面大标题：比 largeTitle 更大的展示字号，撑起全屏第一印象。封面特例——固定字号、不随 Dynamic Type 放大（与 pageTitleSerif 同为衬线同族，仅尺寸更大）
        static let sectionTitleSerif = SwiftUI.Font.system(.title2, design: .serif, weight: .semibold)  // 分区衬线小标题（Topics in progress / Materials Yours），比页面大标题小一档
        static let groupTitleSerif   = SwiftUI.Font.system(.subheadline, design: .serif, weight: .bold)   // 分组衬线小标题（备选，品牌衬线风）
        static let groupLabel        = SwiftUI.Font.system(.footnote, weight: .semibold)                  // 分组列表 section header（iOS 标准）：配大写 + 字距 + 弱色，退后作辅助标签
        static let ctaLabel       = SwiftUI.Font.system(.body, weight: .semibold)     // 主按钮文字（Continue / Get Started）
        static let tabLabel       = SwiftUI.Font.system(.subheadline, weight: .semibold) // 顶部 Tab 名称
        static let cardSentence   = SwiftUI.Font.system(.body, design: .serif, weight: .semibold) // 时刻卡英文主句（衬线 + 半粗，Dynamic Type 安全）
        // 开屏字标「oplex」：与 App 内容字同族（design: .serif = New York，
        // 和 pageTitleSerif / wordTitle 是同一套），再加 italic 呼应 PoplexPShape 的 -6° 斜切。
        // 品牌资产特例——固定字号、不随 Dynamic Type 变化（放大后会撑破居中构图，
        // 且开屏不承载可读信息，无可访问性损失）。
        // 字号改动需同步 SplashScreenView.wordmarkSize，两者必须一致，
        // 否则 P 的字高（由字号算 cap height）会和 oplex 对不上。
        static let splashWordmark = wordmark(size: 56)

        /// 字标专用字体。品牌资产特例：**尺寸由字标度量推算**，所以这里是函数不是常量，
        /// 也不随 Dynamic Type 变化（字标放大会撑破构图，且不承载可读信息）。
        /// 除 `PoplexWordmark` / `SplashScreenView` 外不要调用它写正文。
        static func wordmark(size: CGFloat) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: .bold, design: .serif).italic()
        }
    }

    // 排版微调（行距 / 字距）。SwiftUI 的 Font 装不下这两项，故单列一层，
    // 在用到的地方按约定 .lineSpacing() / .tracking() 引用（值集中在此，不散写）。
    // 注意：lineSpacing 只能在默认行距上「加」，无法压紧到默认以下。
    enum Typography {
        /// 展示型大标题的字距（略负，让大字更「整」）。
        static let trackingDisplay: CGFloat = -0.5
        /// 小标签字距（正，配合大写做编辑体系感）。
        static let trackingLabel: CGFloat = 0.8
        /// 英文正文 / 段落的额外行距。
        static let lineBody: CGFloat = 3
        /// 中文 / 多语言正文的额外行距（CJK 更需要放开）。
        static let lineCJK: CGFloat = 6
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
        // 温润极简：无边框卡片靠暖黑（neutral900）低透明、大扩散阴影托起，
        // 精确对齐参考稿 rgba(28,25,23,0.04) 0 12px 32px 的悬浮感。
        static let cardColor: SwiftUI.Color = Primitive.neutral900.opacity(0.04)
        static let cardRadius: CGFloat = 32
        static let cardX: CGFloat = 0
        static let cardY: CGFloat = 12

        // 暖橙薄纱卡去边框后，靠加深一档的阴影托起（无描边时承担分层职责）
        static let warmCardColor: SwiftUI.Color = Primitive.neutral900.opacity(0.09)
        static let warmCardRadius: CGFloat = 28
        static let warmCardX: CGFloat = 0
        static let warmCardY: CGFloat = 12
    }

    enum Size {
        static let barControl: CGFloat = Primitive.size44  // 顶栏/工具栏可点控件标准边长
        static let iconBadge: CGFloat  = Primitive.size44  // 图标徽章容器边长（圆形浅底托图标）
        static let rowIcon: CGFloat    = Primitive.size28  // 列表行前导图标框 / 小圆控件（设置行、关闭键）
        static let categoryBadge: CGFloat = Primitive.size36  // Topics 类别圆形徽章边长（浅橘底托类别图标）
        static let brandMark: CGFloat  = Primitive.size84  // 圆形 app-icon 报头容器直径
        static let brandGlyph: CGFloat = Primitive.size36  // 报头里 PoplexPShape 的字高
    }

    enum Motion {
        // 顶部 Tab 选中滑块：贴近系统分段控件的弹性手感（有回弹、不过冲太多）
        static let tabSelection: Animation = .spring(response: 0.34, dampingFraction: 0.72)
        // 顶栏滚动紧凑/恢复：稍快，确保不拖延内容阅读
        static let topBarCompact: Animation = .spring(response: 0.30, dampingFraction: 0.82)

        /// 开屏动画时间表（方案 A · 总长 1.00s）。
        /// 多出来的时间全部给了 `holdEnd` 前那一拍静止 —— 词写完后完整停 0.10s，
        /// 这是「名字被看清」的时间。若要缩短，**不要按比例压缩各段**（会毁掉那一拍），
        /// 正确做法是整体换成 reduceMotion 分支的纯淡入。
        enum Splash {
            static let holdStart: Double     = 0.08   // 承接图标：大 P 静止
            static let shrinkDuration: Double = 0.32  // P 收到字标字号
            static let lettersStart: Double  = 0.26   // oplex 开始逐字长出
            static let letterStagger: Double = 0.046  // 字母间隔
            static let letterDuration: Double = 0.22
            static let dotStart: Double      = 0.48   // 墨点从左滑到词尾
            static let dotDuration: Double   = 0.28
            static let exitStart: Double     = 0.86   // 静止一拍后开始淡出
            static let exitDuration: Double  = 0.14
            static var total: Double { exitStart + exitDuration }   // 1.00

            /// 「减弱动态效果」开启时的降级版：无位移、只淡入，总长 0.45s。
            static let reducedFadeIn: Double = 0.20
            static let reducedTotal: Double  = 0.45
        }
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

// MARK: - Glass card modifier (Tab2 磨砂玻璃卡 / 列表容器)
// iOS 26+: native Liquid Glass + 阴影
// iOS 17-25: ultraThinMaterial + 暖白 44% 薄蒙 + 0.5px 白边 + 顶部 40% 内高光，
//            对齐 v4 参考稿——有"厚度"的玻璃，而不是一块浅色。
// 与 glassContainer 分开：那是浮层/面板配方（InputBar、AccountMenu），勿合并。
private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26, *) {
            content
                .glassEffect(in: shape)
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: AppTheme.Shadow.cardRadius,
                    x: AppTheme.Shadow.cardX,
                    y: AppTheme.Shadow.cardY
                )
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(AppTheme.Color.glassCardSurface)
                        // 顶部内高光（0 → 45% 渐隐），玻璃的"厚度"来源
                        shape.fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.42), location: 0),
                                    .init(color: .white.opacity(0), location: 0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        shape.strokeBorder(AppTheme.Color.glassCardEdge, lineWidth: 0.5)
                    }
                }
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
// iOS 17-25: ultraThinMaterial + warm cardBg tint + subtle border + shadow fallback
private struct GlassBarItemModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .shadow(color: AppTheme.Shadow.cardColor, radius: 10, x: 0, y: 2)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(AppTheme.Color.cardBg.opacity(0.85))
                        shape.stroke(AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
                    }
                }
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
// iOS 17-25: ultraThinMaterial + warm cardBg tint + subtle border + shadow fallback
private struct GlassCapsuleModifier: ViewModifier {
    private let cornerRadius: CGFloat = 26

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26, *) {
            content
                .glassEffect(in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(AppTheme.Color.cardBg.opacity(0.85))
                        shape.strokeBorder(AppTheme.Color.border, lineWidth: 0.5)
                    }
                }
                .shadow(
                    color: AppTheme.Shadow.cardColor,
                    radius: 14,
                    x: 0,
                    y: 4
                )
        }
    }
}

// MARK: - Warm glass card modifier (暖橙薄纱卡 · Topics 列表容器 + Hero 卡)
// 与 glassCard 分开：这是单层暖纸底、无描边、带品牌橙薄纱 + 右上柔光的"暖纸卡"，
// 不是磨砂玻璃。去边框后靠加深阴影托起。Topics 卡与 Hero 卡共用此配方。
private struct WarmGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background {
                ZStack {
                    shape.fill(AppTheme.Color.warmGlassSurface)                 // 暖纸白底
                    shape.fill(AppTheme.Color.warmGlassGlow.opacity(0.035))     // 整卡极淡橙薄纱
                    shape.fill(                                                 // 右上角品牌橙柔光
                        RadialGradient(
                            colors: [
                                AppTheme.Color.warmGlassGlow.opacity(0.13),
                                AppTheme.Color.warmGlassGlow.opacity(0)
                            ],
                            center: UnitPoint(x: 0.9, y: -0.1),
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                }
            }
            .shadow(
                color: AppTheme.Shadow.warmCardColor,
                radius: AppTheme.Shadow.warmCardRadius,
                x: AppTheme.Shadow.warmCardX,
                y: AppTheme.Shadow.warmCardY
            )
    }
}

extension View {
    func glassContainer(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(GlassContainerModifier(cornerRadius: cornerRadius))
    }

    func glassCard(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func warmGlassCard(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(WarmGlassCardModifier(cornerRadius: cornerRadius))
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

