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
    // error950 的加深档（同色相不换色系）：error950 仅 3.57:1 做文字不达 AA，
    // 此档 5.96:1，是 danger 的唯一合规出口。
    static let errorDeep = Color(hex: 0xB0392A)

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
        static let onboardingUploadCardVertical: CGFloat = Primitive.space24
        // 列表行垂直节奏（Topics 进度行上下留白）
        static let listRowVertical: CGFloat     = Primitive.space12
    }

    enum Color {
        // 背景（暖米色页面 + 近白暖卡片，靠层次而非纯白飘白区分）
        static let pageBg   = Primitive.neutral50   // 暖米色页面（非纯白）
        static let cardBg   = Primitive.warmWhite   // 近白暖卡片，比页面浅一档
        static let inputBg  = Primitive.warmWhite

        // 文字（由重到轻，全部 ≥4.4:1 WCAG AA 合规）
        // 三档已覆盖所有文字层次；textFaint(1.73:1) / textLabel(2.55:1) 均不合规，已删除。
        static let textPrimary   = Primitive.neutral900  // 17.2:1
        static let textSecondary = Primitive.neutral700  // 9.9:1
        static let textMuted     = Primitive.neutral500  // 4.4:1

        // 非阅读性用途的最浅中性：禁用态填充、禁用态文字、装饰图形、分隔符号。
        // 1.73:1 —— 永远不可用于需要阅读的文字（WCAG 豁免非文字/禁用态对比度要求）。
        // 与 border(neutral200 #E3DFD9) 不同值：border 是发丝线语义，neutralFaint 是浅灰实心填充语义。
        static let neutralFaint  = Primitive.neutral300  // #C7C3BD
        // 满宽禁用 CTA：惰性面（方案 B）。neutral200 是描边/分割语义，拿它做大面积
        // 填充是越权——填充改用 neutral100（用户气泡/图片占位底同档），描边归位到
        // 专属的 controlDisabledBorder，两者不再同值导致描边视觉隐形。
        static let controlDisabledBg = Primitive.neutral100
        static let controlDisabledBorder = Primitive.neutral200
        static let controlDisabledText = Primitive.neutral600

        static let textOnChip    = Primitive.neutral50   // chip 胶囊 / 深底按钮上的浅色文字

        // 品牌 / 交互
        // 橙按「做什么」分档，不按「好不好看」调透明度：
        //   brandInk   — 橙做文字的唯一出口（5.09:1）：≤24pt 文字
        //   brandStrong — 满饱和图形（FF7622）：≤24pt 图标、点、满格进度。永不做文字。
        //   brandMid   — 中档填充：24–120pt 进度条、chip、下划线
        //   brandTint  — 大面积浅底：>120pt 达标胶囊、横幅、水印
        //   brandWash  — 整块区域的最淡橙底（比 brandTint 再浅一档）
        // 任何尺寸均禁止半透明橙：橙 50% 叠暖纸底会得到脏粉，不橙不灰。
        static let brandInk    = Primitive.primaryDeep   // 橙做文字（≤24pt 文字场景）
        static let brandStrong = Primitive.primary950    // 满饱和图形（≤24pt，=种子橙 FF7622）
        static let brandMid    = Primitive.primary800    // 中档填充（24–120pt）
        static let brandTint   = Primitive.primary200    // 大面积浅底（>120pt）
        static let brandWash   = Primitive.primary100    // 整块区域的最淡橙底
        static let brandWashLight = Primitive.primary50  // 比 brandWash 再浅一档（插画天空渐变顶）

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
        // 虚线框是页面上的弱分组提示；降低不透明度，避免在暖纸背景上抢视觉重量。
        static let borderDashed = Primitive.neutral200.opacity(0.65)
        static let onboardingUploadActionBorder = Primitive.neutral200.opacity(0.75)
        static let divider      = Primitive.neutral200

        // 语义状态（承载文字，取加深档以保可读性：error950 仅 3.57:1 不达 AA；errorDeep 5.96:1 合规）
        static let danger = Primitive.errorDeep

        // 模态遮罩：加载 / 删除时压暗背景。用暖近黑（neutral950）而非纯黑，与暖色系一致
        static let scrimOverlay = Primitive.neutral950.opacity(0.25)

        // 图片加载占位底
        static let imagePlaceholderBg = Primitive.neutral100
        // 图片暖纸薄蒙：叠在缩略图上，压低对比、融进暖色系（不是文字色，opacity 在此处合规）
        static let imageWarmOverlay   = Primitive.neutral50.opacity(0.15)

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
        static let statusNote     = SwiftUI.Font.system(.footnote)                     // 加载态 / 空态 / 系统提示性短句
        static let growthStatus   = SwiftUI.Font.system(.footnote, weight: .semibold)  // 成长线状态（如「0 pops so far」）
        static let actionNote     = SwiftUI.Font.system(.footnote)                     // 操作项的补充说明（如拍照入口副文案）
        static let compactActionLabel = SwiftUI.Font.system(.subheadline, weight: .medium) // 上传胶囊动作（Camera / Gallery）：无图标时用中等字重建立操作重量
        static let chineseFaint   = SwiftUI.Font.system(.footnote)                    // 中文原文弱化
        static let chineseBody    = SwiftUI.Font.system(.subheadline)                 // 中文翻译（=参考稿 content-zh 14px 灰）
        static let date           = SwiftUI.Font.system(.caption2, weight: .semibold) // 日期分隔
        static let hero           = SwiftUI.Font.system(.largeTitle, weight: .bold)   // Onboarding 标题
        static let screenTitle    = SwiftUI.Font.system(.title2, weight: .bold)       // 功能页大标题（onboarding 实操页等）
        static let pageTitleSerif = SwiftUI.Font.system(.largeTitle, design: .serif, weight: .semibold) // 页面衬线大标题（Warm Editorial：Tab2「Not open yet」等，与内容衬线同族）
        static let onboardingHeroSerif = SwiftUI.Font.system(size: 46, weight: .semibold, design: .serif) // Onboarding 封面大标题：比 largeTitle 更大的展示字号，撑起全屏第一印象。封面特例——固定字号、不随 Dynamic Type 放大（与 pageTitleSerif 同为衬线同族，仅尺寸更大）
        static let onboardingLeadSerif = englishPrimary  // Onboarding 各屏副标题（标题下的价值/说明句）：复用内容衬线（现 New York→将来 Newsreader），与 onboardingHeroSerif 成对；别名而非重声明，避免与例句内容耦合、也不重复定义同值。
        static let sectionTitleSerif = SwiftUI.Font.system(.title2, design: .serif, weight: .semibold)  // 分区衬线小标题（Topics in progress / Materials Yours），比页面大标题小一档
        static let compactSectionTitleSerif = SwiftUI.Font.system(.title3, design: .serif, weight: .semibold) // 紧凑页面内的小分区标题（如 Onboarding 样例区）
        static let groupLabel        = SwiftUI.Font.system(.footnote, weight: .semibold)                  // 分组列表 section header（iOS 标准）：配大写 + 字距 + 弱色，退后作辅助标签
        static let ctaLabel       = SwiftUI.Font.system(.body, weight: .semibold)     // 主按钮文字（Continue / Get Started）
        static let tabLabel       = SwiftUI.Font.system(.subheadline, weight: .semibold) // 顶部 Tab 名称
        static let cardSentence   = SwiftUI.Font.system(.body, design: .serif, weight: .semibold) // 时刻卡英文主句（衬线 + 半粗，Dynamic Type 安全）
        static let onboardingUploadTitle = SwiftUI.Font.system(.body, design: .serif, weight: .medium) // 上传卡标题：比内容主句更轻一级
        // 开屏字标「oplex」：与 App 内容字同族（design: .serif = New York，
        // 和 pageTitleSerif / wordTitle 是同一套），再加 italic 呼应 PoplexPShape 的 -6° 斜切。
        // 品牌资产特例——固定字号、不随 Dynamic Type 变化（放大后会撑破居中构图，
        // 且开屏不承载可读信息，无可访问性损失）。
        // 字号改动需同步 SplashScreenView.wordmarkSize，两者必须一致，
        // 否则 P 的字高（由字号算 cap height）会和 oplex 对不上。
        static let splashWordmark = wordmark(size: 56)

        /// Topics 分类行标题：非 hot 为 medium，最接近解锁 / 已达标时为 semibold。
        /// 保持原有字重，只把条件字体选择收回 Theme 语义层。
        static func categoryLabel(isHot: Bool) -> SwiftUI.Font {
            SwiftUI.Font.system(.callout, weight: isHot ? .semibold : .medium)
        }

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

        // 小型叠纸插画：极低浓度、短距离阴影只负责交代纸层厚度，不制造悬浮卡片感。
        static let paperLayerColor: SwiftUI.Color = Primitive.neutral900.opacity(0.05)
        static let paperLayerRadius: CGFloat = 4
        static let paperLayerX: CGFloat = 0
        static let paperLayerY: CGFloat = 4
    }

    enum Size {
        static let barControl: CGFloat = Primitive.size44  // 顶栏/工具栏可点控件标准边长
        static let iconBadge: CGFloat  = Primitive.size44  // 图标徽章容器边长（圆形浅底托图标）
        static let rowIcon: CGFloat    = Primitive.size28  // 列表行前导图标框 / 小圆控件（设置行、关闭键）
        static let categoryBadge: CGFloat = Primitive.size36  // Topics 类别圆形徽章边长（浅橘底托类别图标）
        static let brandMark: CGFloat  = Primitive.size84  // 圆形 app-icon 报头容器直径
        static let brandGlyph: CGFloat = Primitive.size36  // 报头里 PoplexPShape 的字高

        // ── Settings 行矢量图标（对应视觉规范 §04 的 24×24 描边资产）──────────
        static let settingsRowIconGlyph: CGFloat = 20  // 行前导图标绘制尺寸
        static let settingsIconStroke: CGFloat    = 1.8 // 行前导图标在 24×24 资产坐标内的描边
        static let settingsChevronGlyph: CGFloat = 13  // 行尾 chevron 绘制尺寸
        static let settingsChevronStroke: CGFloat = 3.2 // chevron 在 24×24 资产坐标内的描边

        // ── CategoryProgressRow 控件度量（不落在 4pt 间距刻度上的内量，不要凑整）──
        static let progressBarHeight: CGFloat    = 2.5   // 进度条轨道高度（超轻细线）
        static let categoryIconGlyph: CGFloat    = 17    // 分类图标徽章 SF Symbol 字号
        static let expandArrow: CGFloat          = 8     // 展开三角字号（颜色已升为 textMuted，回到原有 8pt 度量）
        static let entryThumbnail: CGFloat       = 32    // 词条左栏缩略图 / 图标底块边长
        static let entryBadgeGlyph: CGFloat      = 14    // 词条类型 SF Symbol 字号
        static let pillHSpacing: CGFloat         = 6     // PopsPill HStack 间距
        static let pillHPad: CGFloat             = 10    // PopsPill 水平内边距
        static let pillVPad: CGFloat             = 5     // PopsPill 垂直内边距
        static let rowLabelToProgress: CGFloat   = 10    // 分类行首行（标题+胶囊）→ 进度条间距
        static let wordEntrySpacing: CGFloat     = 2     // 词条行词 + 释义纵向间距
        static let wordListLoadingVPad: CGFloat  = 14    // 词列表加载态垂直内边距

        // ── Tab2 空状态（视觉规范 §05）─────────────────────────────────────
        static let emptyStateContentTop: CGFloat            = 120 // 内容距屏幕顶部：与 Tab2 / Onboarding 左上轴对齐
        static let emptyStateBodyWidth: CGFloat             = 290 // 说明文字阅读行宽，锁定两行节奏
        static let emptyStateBodyToGrowth: CGFloat          = 34  // 说明文字 → 成长状态间距
        static let emptyStatePopsDot: CGFloat               = 7   // 「0 pops so far」前的成长点
        static let emptyStateWatermarkHeight: CGFloat       = 290 // 品牌 P 水印字高（只露出右下背景层）
        static let emptyStateWatermarkTrailingOffset: CGFloat = 30 // P 水印右侧出血，避免变成居中主图
        static let emptyStateWatermarkBottom: CGFloat       = 130 // P 水印距底，避开 CTA
        static let emptyStateCaptureIconGlyph: CGFloat      = 19  // 空态 CTA 描边相机图标

        // ── Onboarding 顶部节奏（N-1）────────────────────────────────────
        // 标题位置与返回按钮位置各自单一真源，互不通过占位块耦合——
        // 旧实现靠「占位块高 36 + header 自带 padding 16」两个数字拼出标题位置，
        // 占位块本身又比返回按钮触区少 8pt，纯属巧合而非设计。
        static let onboardingBackInset: CGFloat             = 2   // 返回 chevron 触区距安全区上沿
        static let onboardingHeaderTop: CGFloat             = 48  // 页面标题（S1 报头 / S2 / S3a / S3b）布局顶距安全区上沿

        // ── Onboarding 拍照页（视觉规范 §06）───────────────────────────────
        static let onboardingCaptureGlyph: CGFloat          = 24  // 主拍照入口描边相机
        static let onboardingPhotosGlyph: CGFloat           = 20  // 紧凑相册入口描边图标
        static let onboardingCardChevronGlyph: CGFloat      = 13  // 主卡右端 chevron
        static let onboardingInlineChevronGlyph: CGFloat    = 10  // 紧跟次操作文字的 chevron
        static let onboardingUploadIllustrationWidth: CGFloat = 104 // 虚线空输入区的有机叠纸插画宽
        static let onboardingUploadIllustrationHeight: CGFloat = 72 // 虚线空输入区的有机叠纸插画高
        static let onboardingUploadActionWidth: CGFloat     = 240 // 双入口胶囊宽度，建立稳定中轴
        static let onboardingUploadActionGlyph: CGFloat     = 14 // 双入口胶囊内的轻量 SF Symbol
        static let onboardingUploadActionBorderWidth: CGFloat = 1 // 明亮胶囊清晰描边
        static let onboardingUploadBorderWidth: CGFloat     = 1.5 // 空输入区虚线边界
        static let onboardingUploadDashLength: CGFloat      = 6   // 空输入区单段虚线长度
        static let onboardingUploadDashGap: CGFloat         = 6   // 空输入区虚线间距
        static let disabledControlBorderWidth: CGFloat      = 1   // 大面积禁用 CTA 的轻描边
        static let onboardingMaxPhotoAspectRatio: CGFloat   = 2.25 // 接受常规手机全屏截图；更长/更宽素材需重选
        // 照片预览区的固定开销（N-1 后随标题上移 20 而减少：317 → 297）。
        // 预览区最小高度 = 视口 - 该值：正常字号恰好顶到 Continue 按钮上方；
        // 大字号/小屏时预览区不压缩、保持此高度，页面转为可滚动。
        // 注意：标题区参考高随 Dynamic Type 变化，此常数只用于「正常字号」基准，偏差仅影响临界点。
        static let onboardingPhotoPreviewFixedOverhead: CGFloat = 297
        // 结果页（N-3）时刻卡的固定开销：同上一枚是同一类常数，只是给结果页的
        // 「标题 + 卡片」结构用。卡片总高 = 视口 - 该值（16 Pro ≈ 419），
        // 卡内 photoHeight = clamp(卡片总高 - 实测文字区高, 180, 320)，
        // 卡片外框因此与内容长度无关，只随视口变化。
        // 数值按 N-1 后的 resultHeader 结构与需求文档 §3.2 的算例（16 Pro：451-32=419）
        // 反推得出，未在真机复核实际渲染的 header 高度，正常字号下需真机校准。
        static let onboardingResultCardFixedOverhead: CGFloat = 379
        static let onboardingContentBottomClearance: CGFloat = 80 // Continue 槽位避让（内容底进遮罩渐隐区，不钻按钮背后）
        // Continue 距安全区下沿（F-2）。四页四态原本各挂一份 `.ignoresSafeArea(.container,
        // edges: .bottom)`，但承载各页的 GeometryReader 本身已被安全区内缩，这句在 CTA 上
        // 实际不起作用——只是让这个数的语义变得不可读（旧注释写的是「贴系统条上方」，
        // 是错的）。F-2 已删掉全部 8 处 ignoresSafeArea，这个数现在是字面意义的
        // 「距安全区下沿」：34 + 12 = 46，Home Indicator（8–13）净空 33pt。
        static let onboardingContinueBottom: CGFloat = 12
        static let inputBarMinHeight: CGFloat = 52 // 底部胶囊最小高度（Tab1 InputBar / Onboarding Continue 对齐）
        static let onboardingSampleWidth: CGFloat           = 104 // 样例图横滑卡宽
        static let onboardingSampleHeight: CGFloat          = 120 // 样例图横滑卡高：给固定 CTA 留出呼吸
        // 兜底态（生成失败 / 放弃）的纸雕插画：与空输入区叠纸同族，尺寸放大作页面锚点
        static let onboardingFallbackIllustrationWidth: CGFloat  = 140 // 兜底态叠纸插画整体宽
        static let onboardingFallbackIllustrationHeight: CGFloat = 116 // 兜底态叠纸插画整体高
        static let onboardingFallbackCardSize: CGFloat           = 66  // 前景纸卡边长
        static let onboardingFallbackBadge: CGFloat              = 30  // 橙色角标直径（小面积满饱和图形）
        static let onboardingFallbackBadgeGlyph: CGFloat         = 15  // 角标内白色描边字形
    }

    enum Motion {
        // 顶部 Tab 选中滑块：贴近系统分段控件的弹性手感（有回弹、不过冲太多）
        static let tabSelection: Animation = .spring(response: 0.34, dampingFraction: 0.72)
        // 顶栏滚动紧凑/恢复：稍快，确保不拖延内容阅读
        static let topBarCompact: Animation = .spring(response: 0.30, dampingFraction: 0.82)
        // 分类成长：toast 先出现 0.25s，再用 0.45s 补满；结果读完后移动分类。
        static let categoryProgressUpdate: Animation = .easeOut(duration: 0.4)
        static let categoryMilestone: Animation = .easeOut(duration: 0.45)
        static let categoryMilestoneReduced: Animation = .easeOut(duration: 0.2)
        static let categoryMilestoneEmphasisRise: Animation = .easeOut(duration: 0.16)
        static let categoryMilestoneEmphasisSettle: Animation = .easeOut(duration: 0.29)
        static let categoryMilestoneToastLead: Duration = .milliseconds(250)
        static let categoryMilestoneEmphasisPeak: Duration = .milliseconds(160)
        static let categoryMilestoneReveal: Duration = .milliseconds(700)
        static let categoryMilestoneReducedReveal: Duration = .milliseconds(450)
        static let categoryMilestoneResultHold: Duration = .milliseconds(800)
        // 普通 toast 为整句阅读预留 4s；Onboarding 图片校验 3s；里程碑短句 2.2s。
        static let toastLifetime: Duration = .seconds(4)
        static let onboardingPhotoToastLifetime: Duration = .seconds(3)
        static let milestoneToastLifetime: Duration = .milliseconds(2200)

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

// MARK: - Surface floating modifier (工具栏 / 菜单 / 输入框)
// iOS 26: native glass in the given shape; interactive only for tappable items —
// interactive glass on a non-button container swallows child button taps.
// iOS 17-25: ultraThinMaterial + 暖白薄蒙 + 细描边 + 阴影。
// 所有浮动工具表面共用这一个配方，避免同一层级出现不同玻璃质感。
private struct SurfaceFloatingModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
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
                        shape.fill(AppTheme.Color.cardBg.opacity(0.85))
                        shape.strokeBorder(AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
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

// MARK: - Surface card modifier (内容容器)
// 单层暖纸底、无描边、带极淡品牌橙薄纱与右上柔光；不使用玻璃，避免内容卡发灰。
// 内容容器统一走此配方与 28pt 容器圆角，靠阴影而不是描边建立层级。
private struct SurfaceCardModifier: ViewModifier {
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
    /// 内容容器：暖纸卡配方，默认 28pt 容器圆角。
    func surfaceCard(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius))
    }

    /// 浮动工具：玻璃配方。默认使用 28pt 容器圆角；圆形 / 胶囊请传入对应形状。
    func surfaceFloating(cornerRadius: CGFloat = AppTheme.Radius.glassContainer) -> some View {
        modifier(SurfaceFloatingModifier(
            shape: RoundedRectangle(cornerRadius: cornerRadius),
            interactive: true
        ))
    }

    func surfaceFloating<S: InsettableShape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(SurfaceFloatingModifier(shape: shape, interactive: interactive))
    }

    func topEdgeFade() -> some View {
        modifier(TopEdgeFadeModifier())
    }
}
