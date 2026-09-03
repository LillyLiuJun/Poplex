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
    static let space28: CGFloat = 28
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
    static let space56: CGFloat = 56

    // 控件尺寸
    static let size28: CGFloat = 28
    static let size36: CGFloat = 36
    static let size44: CGFloat = 44
    static let size76: CGFloat = 76
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
    //
    // 这是一条**完整色阶（palette），不是待消费的 token 列表**。
    // 11 档里当前只有 50/100/200/950 有 semantic 消费者，其余 7 档为零引用——
    // 这是色阶的正常形态，不是「孤儿 token」：色阶要连续可选，semantic 层才从中取值。
    // 删掉中间某一档会在编号序列里留下断档（如 700→900），比闲置更难维护。
    // 「删除无消费者的 token」这条规则针对的是 **semantic 层**——那里一个 token
    // 就是一条活的设计决策，没人用即意味着决策已废止；palette 不适用该规则。
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
    static let neutral50  = Color(hex: 0xFCF8F3)  // 暖纸页面（pageBg）
    static let neutral100 = Color(hex: 0xF0EDE6)  // 用户气泡 / 图片占位底（#F0EDE6，暖度 10）
    static let neutral200 = Color(hex: 0xE6E1DA)  // 描边 / 分割（同步加暖提亮）
    static let neutral300 = Color(hex: 0xC7C3BD)  // 最弱文字（faint）
    static let neutral400 = Color(hex: 0xA5A099)  // 区块小标（label）
    static let neutral500 = Color(hex: 0x7C7773)  // 次要弱文字（muted）
    static let neutral600 = Color(hex: 0x5C554B)
    static let neutral700 = Color(hex: 0x4B4640)  // 次要文字（secondary）
    static let neutral800 = Color(hex: 0x2E2820)
    static let neutral900 = Color(hex: 0x211811)  // 主文字 · 品牌染色近黑
    // interactive / CTA 近黑。
    //
    // ⚠️ **这个值在仓库里存了两份**：这里，以及
    // `Assets.xcassets/AccentColor.colorset/Contents.json`（全局 tint）。
    // 资产目录读不到 Swift 常量，这份重复消除不掉——改这里必须同步改那边，
    // 否则 App 自绘元素与系统组件（alert 按钮、内置 Safari 工具栏）会变成两个色。
    //
    // 为什么全局 tint 用近黑而不是品牌橙：tint 的主场是删号确认框里的 `Cancel`，
    // 它旁边站着红色的 `Delete`。Cancel 要显得安全，而 brandInk(#C2410C) 离
    // danger(#B0392A) 只有 11° 色相，会让两个按钮一起像在报警；
    // brandStrong(#FF7622) 分得开但白底仅 2.6:1。近黑两头都不占，是 PM 拍板的取舍。
    static let neutral950 = Color(hex: 0x17120C)

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

    // ── 暖近白卡片：比暖纸页面（neutral50 #FCF8F3）更亮，带一丝暖底，
    //    靠"描边 + 双层紧阴影"分层；不用纯白，避免冷白跳出整套暖色系 ──
    static let warmWhite = Color(hex: 0xFFFDFB)

    // Tab2 Hero B1 预设图：这些值来自视觉规格，语义层按用途消费。
    static let tab2HeroPresetGradientMiddle = Color(hex: 0xFCF8F5)
    static let tab2HeroPresetBloomSecondary = Color(hex: 0xFFEEE2)
    // 预设图图标描边棕：hero 与 More 行内预设图共用。原名 tab2HeroPresetIcon，
    // 行内变体复用后改名——primitive 是色阶，不应顶着单一组件的名字。
    static let presetIconInk = Color(hex: 0x965832)
    static let tab2HeroPresetLabel = Color(hex: 0x8A4A20)

    // Tab2 More 行内预设图（更淡变体）：这两个值来自视觉规格，语义层按用途消费。
    static let tab2MoreRowPresetFaintGradientTop = Color(hex: 0xFCF7F2)
    static let tab2MoreRowPresetFaintGradientBottom = Color(hex: 0xF5EDE6)

    // ── App 图标资产色 ────────────────────────────────────────────────────
    // 开屏动画的第 0 帧必须与 iOS 图标放大转场的最后一帧一致，否则启动会闪一下。
    // 故这两枚直接取 AppIcon.appiconset 母版里的实际色值，单列、不与 neutral50
    // (#FBF6F1) / neutral900 (#211811) 合并 —— 差值虽小，合并就会在接缝处露出来。
    // 改动前请同步改 Assets.xcassets/AppIcon.appiconset/poplex_icon_master.svg。
    static let iconGround = Color(hex: 0xFBF8F5)  // 图标底 = 开屏底
    static let iconInk    = Color(hex: 0x2A2320)  // 图标墨点 = 开屏墨点
    static let pillWarmBrown = Color(hex: 0x4B3621) // 药丸柔光暖棕

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
        // 与 onboardingHeaderToContent 当前同值（24）但**用途不同、各自演化**，故不合并：
        // 合并会把两个没有设计因果关系的间距绑死——改 Tab2 的分区节奏时 onboarding 会跟着动。
        static let titleToContent: CGFloat      = Primitive.space24
        // Tab2 解锁页分区之间的节奏（已解锁卡片区底 → Topics in progress 顶）
        static let paddingBetweenSections: CGFloat = Primitive.space28
        // 虚线空输入区的上下内边距。24 → 16：框内实测 276 高里有 98pt 是纯空，
        // 「标题组→虚线框」的距离感其实一半来自框内的空，压缩这里比拉外间距更对症。
        static let onboardingUploadCardVertical: CGFloat = Primitive.space16
        // 列表行垂直节奏（Topics 进度行上下留白）
        static let listRowVertical: CGFloat     = Primitive.space12

        // ── Onboarding 中段节奏（承接 N-1 顶部单一真源；四页不再各写各的）─────────────
        // 此前四页的「标题→副标」分别是 16 / 8 / 12 / 8，「标题组→内容」是 弹性 / 48 / 20 / 16，
        // 全部借用通用 padding 档、无语义。下列 token 是这两跳的单一真源。
        /// 「引导 → 被引导」：后者是前者的展开，两者读作一个单元。
        /// 用于四页的标题→副标，以及 S3a 的「Or try a sample」→例图条（同一种关系，同一个数）。
        static let onboardingTitleToLead: CGFloat     = Primitive.space8
        /// 「组 → 组」：标题组到它下面第一块内容。与上一档比值 1:3。
        /// 与 Tab2 的 titleToContent 当前同值（24），有意保留为两个 token —— 见那边的注释。
        /// 只允许这两档，中间不再插值。**已知的两处例外，都是被物理约束夹出来的、不是漏改**：
        ///   - S3b 标题组→结果卡 16（onboardingResultHeaderToCard）——长句卡高 + 遮罩顶
        ///   - S2  标题组→拼贴   36（onboardingCollageTop）——相邻块是实心照片卡，且下沿受遮罩顶限
        /// 新增第三处例外前，先确认它同样有物理理由，否则应该收回这两档。
        /// 本档用于 S3a（标题组→虚线框、虚线框→例图区）。
        /// 32 → 24 的依据（真机实测）：S3a 是全流程唯一真正用到这一档的页面，而虚线框是
        /// 低对比容器 + 24 内边距，标题到框内第一笔墨实测 74pt——框线在 32 处已经读作「太远」。
        static let onboardingHeaderToContent: CGFloat = Primitive.space24
        /// 标题组→结果卡（S3b，全流程唯一的间距例外）：长句态卡高 443，
        /// 48 + 112(标题组) + G + 443 ≤ 626(遮罩顶) → G ≤ 23，吃不下 32。
        /// 16 是被卡高与遮罩顶夹出来的物理值，不是节奏选择。改动前先核对长句态卡底位置。
        static let onboardingResultHeaderToCard: CGFloat = Primitive.space16
        /// 标题组→S2 拼贴墨迹上沿。**刻意不与 S3a 的 24 同档**，两页的第一块内容不在同一线上。
        /// 理由：间距要跟相邻元素的视觉重量走。S3a 接的是低对比虚线框（轻，24 就够），
        /// S2 接的是带照片的实心卡（重）；同样的 24 压在重块上读起来就紧。
        /// 而且拼贴的上沿是旋转卡的一个**角尖**、不是一条直边，比直边更需要余量。
        /// 36 是两头夹出来的：下界由观感（24 偏紧），上界由遮罩顶——墨迹高 428，
        /// 副标块底 221.3 + G + 428 ≤ 688 → **G ≤ 38.4**。想再大只能先把整堆压矮。
        static let onboardingCollageTop: CGFloat      = 36
    }

    enum Color {
        // 背景（暖米色页面 + 近白暖卡片，靠描边 + 紧阴影分层）
        static let pageBg   = Primitive.neutral50   // 暖米色页面（非纯白 #FCF8F3）
        // Tab1 输入框底部背板暖色补偿（中和冷感并承担 Tab1 底部承托暖光，初值 5.5%）
        static let inputBackdropWarmTint = Primitive.primary950.opacity(0.055)
        static let cardBg   = Primitive.warmWhite   // 近白暖卡片（#FFFDFB）
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
        //   brandTint  — 大面积浅底：>120pt 达标胶囊、横幅、水印
        //   brandWash  — 整块区域的最淡橙底（比 brandTint 再浅一档）
        // 任何尺寸均禁止半透明橙：橙 50% 叠暖纸底会得到脏粉，不橙不灰。
        static let brandInk    = Primitive.primaryDeep   // 橙做文字（≤24pt 文字场景）
        static let brandStrong = Primitive.primary950    // 满饱和图形（≤24pt，=种子橙 FF7622）
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
        // 日期分隔胶囊背景（提亮加暖）
        static let dateChipBg     = Primitive.neutral200.opacity(0.5)

        // 描边 / 分割
        static let border       = Primitive.neutral200
        // 卡片精细轮廓描边：0.5pt @ 约 35% 透明度，与紧阴影分工建立提亮后的边界
        static let cardBorder   = Primitive.neutral200.opacity(0.35)
        // Tab2 空状态插画内部结构线：对应 Onboarding 相机的暖石墨描边，
        // 只服务非阅读性的小型图形，不承担正文对比度职责。
        static let emptyStateIllustrationOutline = Primitive.neutral700.opacity(0.72)
        // 虚线框是页面上的弱分组提示；降低不透明度，避免在暖纸背景上抢视觉重量。
        static let borderDashed = Primitive.neutral200.opacity(0.65)
        static let onboardingUploadActionBorder = Primitive.neutral200.opacity(0.75)
        static let divider      = Primitive.neutral200

        // 语义状态（承载文字，取加深档以保可读性：error950 仅 3.57:1 不达 AA；errorDeep 5.96:1 合规）
        static let danger = Primitive.errorDeep
        // 轻量错误插画：与品牌橙解耦，用低饱和暖陶土建立纸页层次；仅作非文字装饰。
        static let feedbackIllustrationBase = Primitive.error200.opacity(0.68)
        static let feedbackIllustrationPage = Primitive.error50.opacity(0.72)
        static let feedbackIllustrationTopPage = Primitive.warmWhite.opacity(0.76)
        static let feedbackIllustrationAccent = Primitive.error600.opacity(0.62)

        // 模态遮罩：加载 / 删除时压暗背景。用暖近黑（neutral950）而非纯黑，与暖色系一致
        static let scrimOverlay = Primitive.neutral950.opacity(0.25)

        // 图片加载占位底
        static let imagePlaceholderBg = Primitive.neutral100
        // 远图首次加载：以品牌暖灰半透明叠在 Tab1 纸灰画布上。
        // 约等效 #F3F0EB：能辨认出图片位置，但不回到通用占位的实心深灰。
        static let imageLoadingPlaceholderBg = Primitive.neutral100.opacity(0.5)
        // 细环只传达「图片正在取得」，用品牌浅灰而非文字灰，退到照片缺席时的背景层。
        static let imageLoadingIndicator = Primitive.neutral300
        // 图片暖纸薄蒙：叠在缩略图上，压低对比、融进暖色系（不是文字色，opacity 在此处合规）
        static let imageWarmOverlay   = Primitive.neutral50.opacity(0.15)

        // 词条类型图标的回退底块（无配图时）：比图片占位底更淡，让描边类型图标退后作弱提示
        static let iconTileBg = Primitive.neutral900.opacity(0.05)

        // 首页画布装饰（aura = 底部品牌橘光晕）——
        // 透明度在组件内按需施加，此处只定义基色
        static let canvasAura     = Primitive.primary950

        // 磨砂玻璃卡（Tab2 卡片 / 列表容器）：暖白 44% 薄蒙 + 0.5px 白边，
        // 叠在 ultraThinMaterial 上出"透"感；画布光晕是玻璃透出的内容。
        // 基色复用 warmWhite / white，透明度本身是玻璃配方的一部分。
        static let glassCardSurface = Primitive.warmWhite.opacity(0.44)
        static let glassCardEdge    = SwiftUI.Color.white.opacity(0.72)
        // 暖纸卡（warmGlassCard · Topics 列表容器 + Hero 卡）：单层不透明暖纸白底，
        // 无描边、无橙薄纱、无柔光——分层职责全部交给阴影（见 Shadow.cardContact*/cardAmbient*）。
        // 名字里的 "glass" 是历史遗留：早期配方确实叠过橙薄纱与右上柔光，
        // 后因整卡发脏、削弱内容对比度而移除，只保留调用点名不改，避免大面积改名。
        static let warmGlassSurface = Primitive.warmWhite   // 暖纸白底（不透明单层）
        // Settings 家族卡片（Settings / About AI / Feedback）专用：warmGlassSurface
        // 100% 不透明在暖米色页面（pageBg neutral50）上对比过强、显"太亮"；
        // 加透明度让页面底色透一点上来，与 warmGlassSurface 共用的 Tab2 卡片
        // （MineView / CategoryProgressRow）不受影响——那两处仍用默认值。
        static let settingsCardSurface = Primitive.warmWhite.opacity(0.85)

        // Tab2 Hero 顶部照片的统一调色与预设图（B1）专用色。组件只消费这些语义 token，
        // 不直接引用 Primitive 或字面 Color，以便日后更换目标市场的视觉主题时集中调整。
        static let tab2HeroPhotoToneWarm = Primitive.primary600
        static let tab2HeroPhotoTonePaper = Primitive.primary100
        static let tab2HeroPhotoTopScrim = Primitive.neutral900
        static let tab2HeroPhotoOverlayText = Primitive.controlOnMedia
        static let tab2HeroPhotoOverlayShadow = Primitive.mediaSurface
        static let tab2HeroCTAOnColor = Primitive.controlOnMedia
        static let tab2HeroPresetGradientTop = Primitive.neutral50
        static let tab2HeroPresetGradientMiddle = Primitive.tab2HeroPresetGradientMiddle
        static let tab2HeroPresetGradientBottom = Primitive.controlOnMedia
        static let tab2HeroPresetBloomPrimary = Primitive.primary400
        static let tab2HeroPresetBloomSecondary = Primitive.tab2HeroPresetBloomSecondary
        static let tab2HeroPresetIcon = Primitive.presetIconInk
        static let tab2HeroPresetLabel = Primitive.tab2HeroPresetLabel
        // Tab2 More 行（§5）：行内预设图两套渐变、描边棕、照片暖橙 multiply 层、✓ 前缀。
        // 常规变体直接复用 primary100/primary300（#FFF3EB/#FFDFCC）；
        // 更淡变体是两个只属于行内预设图的视觉规格值，落在 Primitive。
        static let tab2MoreRowPresetGradientTop = Primitive.primary100
        static let tab2MoreRowPresetGradientBottom = Primitive.primary300
        static let tab2MoreRowPresetFaintGradientTop = Primitive.tab2MoreRowPresetFaintGradientTop
        static let tab2MoreRowPresetFaintGradientBottom = Primitive.tab2MoreRowPresetFaintGradientBottom
        static let tab2MoreRowPresetIcon = Primitive.presetIconInk
        // 照片暖橙 multiply 层：与 hero 同 primitive（primary600）、强度独立（.24 vs .20），
        // 独立 token 便于单侧调整（同 brandWash / tab2HeroPhotoTonePaper 共用 primary100 的先例）。
        static let tab2MoreRowPhotoToneWarm = Primitive.primary600
        // 半轻灰胶囊底（计数 + chevron 合并单元）：暖近黑极低透明，中性、不引入橙
        static let pillNeutralBg    = Primitive.neutral900.opacity(0.06)

        // 下拉刷新 / 弱加载指示器（极淡浅暖灰，轻盈温润、不抢视觉重心）
        static let refreshIndicator = Primitive.neutral300

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
        // Onboarding 拼贴里的示意微文案（照片注脚 / 语音转写 / 便签正文）。
        // 尺寸：15（比 englishBody 17 降一档）——这些字是「让人认出这是什么输入」的示意，
        //   不是要读的内容；17pt 主色会让三张卡同时抢主标题的注意力，整页发重。
        // 字族：**衬线**。这三行是用户产生的内容，和结果页的英文主句（englishPrimary，
        //   同为内容衬线）是同一类东西，理应同族；且整页其余全是衬线，卡上突然出现无衬线
        //   就是「形态语言不同族」，与 N-1 里 chevron 的问题同类。
        // 不挪用 chineseBody（语义是中文）或 statusNote（语义是加载/空态提示）。
        static let onboardingCollageNote = SwiftUI.Font.system(.subheadline, design: .serif)
        static let buddy          = SwiftUI.Font.system(.subheadline, weight: .medium) // 场景追问（=参考稿 14.5/500）
        static let keyPhrase      = SwiftUI.Font.system(.subheadline, weight: .bold)  // 核心词组（=参考稿 kp-word 15/700 加黑）
        static let phonetic       = SwiftUI.Font.system(.footnote, design: .monospaced) // IPA 音标（等宽）
        static let pos            = SwiftUI.Font.system(.caption2)                    // 词性 / 卡片 Meta（=参考稿 ~11-12px）
        // 静态事实 / 计数小字：版本号、字数计数、字段脚注。
        // 与 pos 当前同值（.caption2）但**语义不同、各自演化**，故不合并：
        // pos 的语义是「学习内容的词性标注」，跟着内容卡走；这一档跟着功能页的
        // 辅助信息走。此前这三处都挪用了 pos，改版权衡时会互相牵制。
        static let metaNote       = SwiftUI.Font.system(.caption2)
        static let popsCount      = SwiftUI.Font.system(.caption, weight: .medium)    // Topics 进度行 pops 计数（配 .monospacedDigit()）
        static let iconBadgeLetter = SwiftUI.Font.system(.subheadline, design: .serif, weight: .semibold) // 词条类型徽章里的衬线字母（句中单词 A）
        static let sectionLabel   = SwiftUI.Font.system(.caption2, weight: .semibold) // 区块小标（例句 / 说明，11/600）
        static let statusNote     = SwiftUI.Font.system(.footnote)                     // 加载态 / 空态 / 系统提示性短句
        static let statusNoteSerif = SwiftUI.Font.system(.footnote, design: .serif)     // 衬线小字状态提示（如手风琴展开 loading "Gathering words…"）
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
        static let onboardingLeadSerif = englishPrimary  // Onboarding 各屏副标题（标题下的价值/说明句）：复用内容衬线（现 New York→将来 Newsreader），与 onboardingHeroSerif 成对；别名而非重声明，避免与例句内容耦合、也不重复定义同值。（tabLabel 已于 2026-09-01 改无衬线，脱离本次换装范围，见需求清单 C11。）
        static let sectionTitleSerif = SwiftUI.Font.system(.title2, design: .serif, weight: .semibold)  // 分区衬线小标题（Topics in progress / Materials Yours），比页面大标题小一档
        static let compactSectionTitleSerif = SwiftUI.Font.system(.title3, design: .serif, weight: .semibold) // 紧凑页面内的小分区标题（如 Onboarding 样例区）
        static let settingsSectionTitleSerif = SwiftUI.Font.system(.subheadline, design: .serif, weight: .medium) // Settings 卡外分组标题：保留衬线编辑感，但退到辅助层
        static let settingsPinnedTitleSerif = SwiftUI.Font.system(.title3, design: .serif, weight: .semibold) // Settings 家族固定顶栏标题：比系统导航栏字号大一档，仍在 60pt 顶栏内不挤，保留品牌衬线
        static let settingsVersion = SwiftUI.Font.system(.caption2, design: .serif) // Settings 页脚版本号：小号衬线注脚
        static let ctaLabel       = SwiftUI.Font.system(.body, weight: .semibold)     // 主按钮文字（Continue / Get Started）
        static let tab2HeroCategoryLabel = SwiftUI.Font.system(.caption2, weight: .heavy)
        static let tab2HeroPopsLabel = SwiftUI.Font.system(.caption2, weight: .semibold)
        static let tab2HeroMeta = SwiftUI.Font.system(.caption, weight: .semibold)
        static let tab2HeroWord = SwiftUI.Font.system(.subheadline, design: .serif, weight: .semibold)
        static let tab2HeroWordPartOfSpeech = SwiftUI.Font.system(.caption2).italic()
        static let tab2HeroWordMeaning = SwiftUI.Font.system(.footnote)
        static let tab2HeroCTA = SwiftUI.Font.system(.subheadline, weight: .semibold)
        // ── Tab2 More 行（§5.2，2026-09-01 二稿：两声部而非四声部）：与 hero
        //    同类角色但独立成族，换装/微调互不牵制（同 date/sectionLabel 先例，
        //    允许同式不同名）──────
        // 元数据声部：分类标签 / pops / meta 三者共用同一个 token——写法必须
        // 完全相同，三者才读作同一档而不是各说各话。不要为其中一个单独开小灶
        // （加粗/改色/改字号），那正是二稿要修的问题。
        static let tab2MoreRowMetadata = SwiftUI.Font.system(.caption)
        // 内容声部：全卡唯一深色、唯一衬线。比 hero 主句（.body 衬线 semibold）
        // 小一档字号、轻一档字重——hero 是「推荐」的强断言，这里只是「也说得出口」。
        static let tab2MoreRowSentence = SwiftUI.Font.system(.subheadline, design: .serif, weight: .regular)
        static let tab2MoreRowWord = SwiftUI.Font.system(.subheadline, weight: .semibold)       // 纯查词行词 14/600 无衬线
        static let tab2MoreRowWordMeaning = SwiftUI.Font.system(.caption2)                      // 释义 11/400
        // 顶部 Tab 名称：2026-09-01 改无衬线（与内容衬线脱钩，不再随 Newsreader
        // 换装同步——见需求清单 C11，问题已随此改动消解）。两项同重，选中关系
        // 仍交给毛玻璃胶囊，而不是靠字重制造对比。
        // 配方（TextStyle/design/字重）单独成 token：UIKit 无公开 API 从 SwiftUI Font
        // 反解配方，导航 chrome 宽度测试（labelTabRowFits…）只能读这里的原值来测量——
        // 与 tabLabel 共用同一份，改配方只改这一处、测试自动按新配方重测（放不下会红）。
        static let tabLabelStyle  = SwiftUI.Font.TextStyle.subheadline
        static let tabLabelDesign = SwiftUI.Font.Design.default
        static let tabLabelWeight = SwiftUI.Font.Weight.medium
        static let tabLabel       = SwiftUI.Font.system(tabLabelStyle, design: tabLabelDesign, weight: tabLabelWeight)
        static let cardSentence   = SwiftUI.Font.system(.body, design: .serif, weight: .semibold) // 时刻卡英文主句（衬线 + 半粗，Dynamic Type 安全）
        static let feedbackTitleSerif = cardSentence // 轻量错误/恢复提示标题：沿用内容衬线，但保持 body 层级，不冒充页面标题
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

    // 排版微调（行距 / 字距 / 动态字号上限）。SwiftUI 的 Font 装不下这些，故单列一层，
    // 在用到的地方按约定 .lineSpacing() / .tracking() 引用（值集中在此，不散写）。
    // 注意：lineSpacing 只能在默认行距上「加」，无法压紧到默认以下。
    enum Typography {
        /// 展示型大标题的字距（略负，让大字更「整」）。
        static let trackingDisplay: CGFloat = -0.5
        /// 英文正文 / 段落的额外行距。
        static let lineBody: CGFloat = 3
        /// 中文 / 多语言正文的额外行距（CJK 更需要放开）。
        static let lineCJK: CGFloat = 6
        /// 顶部 Tab 文字的动态字号上限（含本档）。「顶部 Tab 始终显示文字」决策的配套。
        /// 2026-09-01 tabLabel 改无衬线后行宽变窄，AX2 档位在最窄屏（375pt）上还有余量，
        /// 实测封顶档从 AX2 松到了 AX3。用户开到 AX4 及以上时导航文字不再放大，
        /// 正文等其他内容不受此限。
        /// 注意：具体字号随 iOS 版本的字号缩放表浮动，档位是否正确由 AIEnglishAppTests 的
        /// labelTabRowFitsNarrowestSupportedScreenAtMaxDynamicTypeSize 双面包夹测试在运行时强制
        /// （文案变长、字体配方再变动或加第三个 Tab 同样会让该测试变红）；
        /// 本注释数值仅作参考，不必精确。
        static let topTabLabelMaxDynamicTypeSize: DynamicTypeSize = .accessibility3
    }

    /// 不透明度语义层。
    ///
    /// 不透明度既不是尺寸也不是颜色，独立成层：写 `Size.xxxOpacity` 会让
    /// 「按 category-purpose-level 命名」的约定失效，也让 Size 层不再是纯几何量。
    /// 只收「同一个颜色 token 在不同语境下的减弱程度」，颜色本身仍归 Color。
    enum Opacity {
        /// 装饰性图形的内部结构描边：在暖纸底上压到既可见又不抢正文重量。
        static let illustrationHairline: CGFloat = 0.55
    }

    /// 静态几何旋转角（度）。
    ///
    /// 与 Motion 区分：Motion 描述「随时间变化」，这里是排版上钉死的倾角，
    /// 不参与动画、不随状态改变。
    enum Rotation {
        /// 空态叠纸：底片逆时针躺开，露出奶油橙边。
        static let emptyStateCardBack: CGFloat  = -7
        /// 空态叠纸：前卡几乎摆正，只留一点手放的随意感。
        static let emptyStateCardFront: CGFloat = 1.5
    }

    enum Radius {
        static let small: CGFloat          = Primitive.radius8   // tag / 小元素
        static let medium: CGFloat         = Primitive.radius16  // 卡片 / 气泡
        static let large: CGFloat          = Primitive.radius20  // 输入框
        static let glassContainer: CGFloat = Primitive.radius28  // 浮动 glass 容器
    }

    enum Shadow {
        // ── 卡片双层紧阴影（接触阴影 + 环境阴影，取代大扩散模糊阴影）──────────────────
        // 贴地接触阴影（负责轮廓边缘微厚度）：y 1.5 / blur 4 / 中性近黑 3.5%
        static let cardContactColor: SwiftUI.Color = Primitive.neutral900.opacity(0.035)
        static let cardContactRadius: CGFloat = 4
        static let cardContactX: CGFloat = 0
        static let cardContactY: CGFloat = 1.5

        // 浅层环境阴影（负责温润柔和扩散）：y 4 / blur 8 / 暖棕 2.5%
        static let cardAmbientColor: SwiftUI.Color = Primitive.neutral800.opacity(0.025)
        static let cardAmbientRadius: CGFloat = 8
        static let cardAmbientX: CGFloat = 0
        static let cardAmbientY: CGFloat = 4

        // 浮动控件 / 独立大扩散阴影（保留原 token 供工具条/非卡片元素使用）
        static let cardColor: SwiftUI.Color = Primitive.neutral900.opacity(0.04)
        static let cardRadius: CGFloat = 32
        static let cardX: CGFloat = 0
        static let cardY: CGFloat = 12

        // 小型叠纸插画：极低浓度、短距离阴影只负责交代纸层厚度，不制造悬浮卡片感。
        static let paperLayerColor: SwiftUI.Color = Primitive.neutral900.opacity(0.05)
        static let paperLayerRadius: CGFloat = 4
        static let paperLayerX: CGFloat = 0
        static let paperLayerY: CGFloat = 4

        // 顶栏药丸与汉堡按钮专有双层小阴影（小尺寸元素定制，避免大卡片 32pt 阴影导致"太扁太虚"）：
        // 第一层：贴地接触阴影（中性黑 4%），定位
        static let pillContactColor: SwiftUI.Color = Primitive.neutral900.opacity(0.04)
        static let pillContactRadius: CGFloat = 3
        static let pillContactX: CGFloat = 0
        static let pillContactY: CGFloat = 1

        // 第二层：扩散柔光（暖棕 5%），浮起
        static let pillAmbientColor: SwiftUI.Color = Primitive.pillWarmBrown.opacity(0.05)
        static let pillAmbientRadius: CGFloat = 8
        static let pillAmbientX: CGFloat = 0
        static let pillAmbientY: CGFloat = 2

        // 空状态插画前卡：比底片多一圈柔和扩散，让暖白表层成为承重主体。
        static let emptyStateFrontColor: SwiftUI.Color = Primitive.neutral900.opacity(0.065)
        static let emptyStateFrontRadius: CGFloat = 8
        static let emptyStateFrontX: CGFloat = 0
        static let emptyStateFrontY: CGFloat = 5
    }

    enum Size {
        static let barControl: CGFloat = Primitive.size44  // 顶栏/工具栏可点控件标准边长
        // 屏幕居中的顶部 Tab 左右避让槽：页边距 + 44pt 侧边控件。
        static let topBarSideClearance: CGFloat = AppTheme.Space.paddingPage + barControl
        // 顶部文字导航的选中玻璃：视觉高度小于 44pt 触控区，避免读成厚重工具按钮。
        // 这是 minHeight——大字号下玻璃随文本行高撑大（AX2 时约 36pt），属预期行为。
        static let topTabSelectionHeight: CGFloat = Primitive.space32
        // 顶部文字导航两项之间的留白：紧凑成一个居中的导航单元，但不压缩各自 44pt 热区。
        static let topTabItemSpacing: CGFloat = Primitive.space4
        // InputBar 右侧发送/拍照/加载圆键：比 barControl（44）小，黑底圆键太满、
        // 视觉偏重；但比色阶上现成的 36 那一档 PM 又觉得偏小——是介于两档中间
        // 的手动微调值，component-private 例外（只这一个控件用，不进色阶，
        // 独立于 barControl——后者仍是 + 键与顶栏控件的标准边长）。
        static let inputBarActionControl: CGFloat = 40
        static let iconBadge: CGFloat  = Primitive.size44  // 图标徽章容器边长（圆形浅底托图标）
        static let rowIcon: CGFloat    = Primitive.size28  // 列表行前导图标框 / 小圆控件（设置行、关闭键）
        static let imageLoadingIndicatorDiameter: CGFloat = 24
        static let imageLoadingIndicatorStroke: CGFloat = 2
        static let categoryBadge: CGFloat = Primitive.size36  // Topics 类别圆形徽章边长（浅橘底托类别图标）
        // brandMark（84pt 圆形 app-icon 报头直径）已随 Settings 删除品牌报头一并移除。
        // brandGlyph 在此之前就已无消费者，属既有债务，留待 token 体检时统一清理。
        static let brandGlyph: CGFloat = Primitive.size36  // 报头里 PoplexPShape 的字高

        // ── Settings 行矢量图标（对应视觉规范 §04 的 24×24 描边资产）──────────
        static let settingsRowIconGlyph: CGFloat = 20  // 行前导图标绘制尺寸
        static let settingsIconStroke: CGFloat    = 1.8 // 行前导图标在 24×24 资产坐标内的描边
        // 顶栏菜单与 Settings 图标保持同一视觉笔重，但它直接在屏幕点空间绘制，
        // 因此先把 24×24 资产坐标的 1.8 换算到当前 20pt glyph（= 1.5pt）。
        static let topBarMenuIconGlyph: CGFloat = settingsRowIconGlyph
        static let topBarMenuIconStroke: CGFloat = settingsIconStroke * topBarMenuIconGlyph / Primitive.space24
        static let settingsChevronGlyph: CGFloat = 13  // 行尾 chevron 绘制尺寸
        // chevron 在 24×24 资产坐标内的描边。3.2 → 2.8 的依据是**换算到屏幕后与行图标同重**：
        //   行图标  1.8 × (20/24) = 1.50pt
        //   chevron 3.2 × (13/24) = 1.73pt  ← 比行图标粗 15%，同一行里两种笔画不同族
        //           2.8 × (13/24) = 1.52pt  ← 齐平
        // 两个 glyph 尺寸不同（20 vs 13），所以资产坐标里的数字必须不同才能画出同样粗的线。
        static let settingsChevronStroke: CGFloat = 2.8

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

        // ── Tab2 空状态 ──────────────────────────────────────────────────
        static let emptyStateCaptureIconGlyph: CGFloat      = 19  // 空态 CTA 描边相机图标

        // Tab2 加载失败插画（合页书本）的方形边长。
        // #44 原先借用 `brandMark`（语义=圆形 app-icon 报头容器直径），
        // 而报头已在 Settings 改造里删除、该 token 随之移除。按本文件既有约定
        // ——每个插画有自己按用途命名的尺寸 token（emptyStateIllustration* /
        // onboardingUploadIllustration* …）——改用与它的配色 token 同族的名字。
        static let feedbackIllustrationSize: CGFloat        = Primitive.size84

        // 空态插画方案 B：奶油橙底片 + 暖白词条卡，内部以暖灰线和品牌点形成焦点。
        static let emptyStateIllustrationWidth: CGFloat     = 124
        static let emptyStateIllustrationHeight: CGFloat    = 96
        static let emptyStateCardWidth: CGFloat             = 96
        static let emptyStateCardHeight: CGFloat            = 68
        static let emptyStateCardBackOffsetX: CGFloat       = -8
        static let emptyStateCardBackOffsetY: CGFloat       = 3
        static let emptyStateCardFrontOffsetX: CGFloat      = 5
        static let emptyStateCardFrontOffsetY: CGFloat      = 8
        static let emptyStateCardHairlineWidth: CGFloat     = 1
        static let emptyStateGlyphLineHeight: CGFloat       = 1.5
        static let emptyStateGlyphLineSpacing: CGFloat      = 8
        static let emptyStateGlyphTopLineWidth: CGFloat     = 30
        static let emptyStateGlyphTopLineOffsetX: CGFloat   = 6
        static let emptyStateGlyphBottomLineWidth: CGFloat  = 22
        static let emptyStateGlyphBottomLineOffsetX: CGFloat = -6
        static let emptyStateGlyphFocusLeftLineWidth: CGFloat = 10
        static let emptyStateGlyphFocusRightLineWidth: CGFloat = 20
        static let emptyStateGlyphFocusGap: CGFloat         = 3
        static let emptyStateGlyphFocusDot: CGFloat         = 13
        static let emptyStateGlyphFocusCore: CGFloat        = 5

        // ── Onboarding 顶部节奏（N-1）────────────────────────────────────
        // 标题位置与返回按钮位置各自单一真源，互不通过占位块耦合——
        // 旧实现靠「占位块高 36 + header 自带 padding 16」两个数字拼出标题位置，
        // 占位块本身又比返回按钮触区少 8pt，纯属巧合而非设计。
        static let onboardingBackInset: CGFloat             = 2   // 返回 chevron 触区距安全区上沿
        static let onboardingHeaderTop: CGFloat             = 48  // 页面标题（S2 / S3a / S3b）布局顶距安全区上沿。S1 报头不用此值，见下
        // S1 是品牌页：没有返回按钮，那条线上方的 44pt 触区是空的，报头贴在内页标题线上会显得被顶到天花板。
        // 刊头惯例是封面留白大于内页，故单开一档。代价：横滑 S1→S2 时报头与标题错开 16pt（已确认接受，
        // 验收「三页标题同高」不含 S1）。若真机觉得仍不够，下一档是 80，不要取中间值。
        static let onboardingS1MastheadTop: CGFloat         = 64
        // S1 hero 文字组下缘 → Continue 上缘。文字组由「几何居中」改为「锚定 CTA」：
        // 居中的参照系（视口）随机型变，而封面页真正要恒定的是标题到行动召唤的距离；
        // 机型差异被赶到上方留白（没人盯着看的地方）。与 F-6 在结果页的取舍同源。
        static let onboardingHeroToCTA: CGFloat             = 200
        // 返回按钮 leading：触区 44 宽、arrow.left 字形约 22 宽居中 → 字形左缘 = leading + 11。
        // 要字形左缘落在页面左轴 20（用户看到的是墨、不是触区），故 leading = 20 - 11 = 9。
        // 此前用 paddingM(12)，字形左缘落在 23，左轴因此有两个值。
        static let onboardingBackLeading: CGFloat           = 9

        // ── Onboarding 顶部渐隐（F-4）─────────────────────────────────────
        // 遮罩的「不透明段」由 safeTop + onboardingBackInset + barControl 实算得出
        // （= 返回箭头下沿），不写死——safeTop 逐机型不同（16 Pro 62 / 15 Pro 59 /
        // 13 mini 50 / SE 20），写死会在小屏上多盖 40pt、在大屏上盖不住箭头。
        // 这里只定义「不透明段之后还要走多长才彻底透明」和「滚多少判定为已滚动」。
        // 不透明段：只需盖住返回箭头的**字形**，不必盖满 44 的触区——
        // arrow.left 在 19pt 下字形高约 13pt，居中于触区后下沿在页面坐标 ~31，
        // 取 36 留 5pt 余量。顶端必须从 0 开始：内容在安全区上沿被硬切，
        // 这一段实色就是用来把切边藏掉的。
        // ⚠️ 改返回按钮字号/触区时要一起复核这个数。
        static let onboardingTopFadeOpaque: CGFloat         = 36
        // 渐隐跑道：不透明段之后再走多远彻底透明。
        // 64 → 80 → 40 → 28：整层高随之 110→126→86→64。收得太狠会让 alpha 的
        // 单位落差变大、逼近当初 20pt 线性收尾那条"横向硬边"——
        // 28 时约 0.041/pt，已接近可察觉阈值，**不建议再往下压**。
        static let onboardingTopFadeRunway: CGFloat         = 28
        static let onboardingTopFadeRamp: CGFloat           = 16  // 滚动位移 → 遮罩整体不透明度的爬升距离

        // ── Onboarding 拍照页（视觉规范 §06）───────────────────────────────
        static let onboardingCaptureGlyph: CGFloat          = 24  // 主拍照入口描边相机
        static let onboardingPhotosGlyph: CGFloat           = 20  // 紧凑相册入口描边图标
        static let onboardingCardChevronGlyph: CGFloat      = 13  // 主卡右端 chevron
        static let onboardingInlineChevronGlyph: CGFloat    = 10  // 紧跟次操作文字的 chevron
        static let onboardingUploadIllustrationWidth: CGFloat = 104 // 虚线空输入区的有机叠纸插画宽
        // 插画墨迹实测约 58.4 高（底片 72×52 旋转 −8° 后 61.5，再 ×0.95），
        // 名义 72 意味着上下白留了 13.6 的透明边距 —— 收到 60，框内不再有看不见的空。
        static let onboardingUploadIllustrationHeight: CGFloat = 60 // 虚线空输入区的有机叠纸插画高
        static let onboardingUploadActionWidth: CGFloat     = 240 // 双入口胶囊宽度，建立稳定中轴
        static let onboardingUploadActionGlyph: CGFloat     = 14 // 双入口胶囊内的轻量 SF Symbol
        static let onboardingUploadActionBorderWidth: CGFloat = 1 // 明亮胶囊清晰描边
        static let onboardingUploadBorderWidth: CGFloat     = 1.5 // 空输入区虚线边界
        static let onboardingUploadDashLength: CGFloat      = 6   // 空输入区单段虚线长度
        static let onboardingUploadDashGap: CGFloat         = 6   // 空输入区虚线间距
        static let disabledControlBorderWidth: CGFloat      = 1   // 大面积禁用 CTA 的轻描边
        static let onboardingMaxPhotoAspectRatio: CGFloat   = 2.25 // 接受常规手机全屏截图；更长/更宽素材需重选
        // 照片预览区的固定开销。此前是 317 → 297 一路试出来的魔法数字，现改为由布局推导：
        //   overhead = headerTop 48 + 标题组 134.6 + 组间距 24 + 底部净空 64.3 + 卡底→CTA 32 = 303
        // 其中「标题组 134.6」= 标题 2 行(41×2) + 8 + 副标 2 行(22.3×2)；
        //     「底部净空 64.3」= onboardingContinueBottom 12 + 按钮高 52。
        // 预览区最小高度 = 视口 - 该值：正常字号下沿距 CTA 顶 32（与页面组间距同值）；
        // 大字号/小屏时预览区不压缩、保持此高度，页面转为可滚动。
        // 上沿与空态虚线卡同线 —— 两态切换时内容顶不位移（此前会跳 4pt）。
        // 注意：标题区高随 Dynamic Type 变化，此常数只用于「正常字号」基准，偏差仅影响临界点。
        // 任何一项变了就重算，不要再在真机上试。
        static let onboardingPhotoPreviewFixedOverhead: CGFloat = 303
        // 结果页时刻卡的照片高度（F-6，替换 N-3 §3.2 的「卡片总高恒定 + 垂直居中 +
        // 照片自适应 clamp」）：那套策略下卡片总高不变、照片却随文字长度反向伸缩，
        // 短句时照片下沿下移 66pt、长句时上移 43pt——照片是画面主体，一动就是「跳」。
        // 现在反过来：照片高度锁定，卡片总高 = 照片高 + 文字区实际高，随内容自然伸缩，
        // 顶对齐。变化量从「照片」（最显眼）赶到「卡片下边缘/空场」（没人盯着看）。
        // 230 是两头夹出来的：260 时长句卡底会溢出遮罩顶 22pt；200 时短句照片偏小、
        // 失去主体感。四态（生成中/成功/失败）全部引用它，不得再出现硬编码高度。
        static let onboardingResultPhotoHeight: CGFloat = 230
        static let onboardingContentBottomClearance: CGFloat = 80 // Continue 槽位避让（内容底进遮罩渐隐区，不钻按钮背后）
        // Continue 距安全区下沿（F-2）。四页四态原本各挂一份 `.ignoresSafeArea(.container,
        // edges: .bottom)`，但承载各页的 GeometryReader 本身已被安全区内缩，这句在 CTA 上
        // 实际不起作用——只是让这个数的语义变得不可读（旧注释写的是「贴系统条上方」，
        // 是错的）。F-2 已删掉全部 8 处 ignoresSafeArea，这个数现在是字面意义的
        // 「距安全区下沿」：34 + 12 = 46，Home Indicator（8–13）净空 33pt。
        static let onboardingContinueBottom: CGFloat = 12
        static let inputBarMinHeight: CGFloat = 52 // 底部胶囊最小高度（Tab1 InputBar / Onboarding Continue 对齐）
        static let onboardingSampleWidth: CGFloat           = 104 // 样例图横滑卡宽
        // tile 比例 = 原图比例 3:4 → scaledToFill 零裁切，四张都完整显示。
        // 120(0.867) → 139(0.750)：此前每张上下各被吃掉 9.5pt，「不舒展」有一半来自这个裁切。
        static let onboardingSampleHeight: CGFloat          = 139 // 样例图横滑卡高（= 宽 ÷ 0.75）
        // 兜底态（生成失败 / 放弃）的纸雕插画：与空输入区叠纸同族，尺寸放大作页面锚点
        static let onboardingFallbackIllustrationWidth: CGFloat  = 140 // 兜底态叠纸插画整体宽
        static let onboardingFallbackIllustrationHeight: CGFloat = 116 // 兜底态叠纸插画整体高
        static let onboardingFallbackCardSize: CGFloat           = 66  // 前景纸卡边长
        static let onboardingFallbackBadge: CGFloat              = 30  // 橙色角标直径（小面积满饱和图形）
        static let onboardingFallbackBadgeGlyph: CGFloat         = 15  // 角标内白色描边字形
    }

    /// Tab2 Hero 卡的固定图像区与 B1 预设图度量。文字区本身保持由内容撑开，
    /// 这里只有其最小高度，避免短句卡留下不受控的空白。
    enum Tab2Hero {
        enum Layout {
            static let artHeight: CGFloat = 150
            static let artTextOverlap: CGFloat = -14
            static let textMinimumHeight: CGFloat = 138.5
            static let sceneDetailMaximumWidth: CGFloat = 175
            static let ctaHeight: CGFloat = 42
            static let ctaHorizontalInset: CGFloat = 22
            static let ctaContentGap: CGFloat = 7
            static let ctaCornerRadius: CGFloat = 21
            static let photoTopScrimHeight: CGFloat = 54
            static let photoOverlayShadowRadius: CGFloat = 6
            static let photoOverlayShadowY: CGFloat = 1
            static let presetBloomPrimaryWidth: CGFloat = 220
            static let presetBloomPrimaryHeight: CGFloat = 165
            static let presetBloomPrimaryLeading: CGFloat = 20
            static let presetBloomPrimaryTop: CGFloat = -20
            static let presetBloomSecondaryWidth: CGFloat = 180
            static let presetBloomSecondaryHeight: CGFloat = 140
            static let presetBloomSecondaryTrailing: CGFloat = -40
            static let presetBloomSecondaryTop: CGFloat = 24
            static let presetIconSize: CGFloat = 96
            static let presetIconTrailing: CGFloat = 38
            static let presetIconTop: CGFloat = 32
            static let presetDotSize: CGFloat = 8
            static let presetDotLeading: CGFloat = 46
            static let presetDotTop: CGFloat = 74
            static let presetIconStrokeWidth: CGFloat = 1.9
            static let presetBloomBlur: CGFloat = 36
            static let wordRowHeight: CGFloat = 26
            static let wordRowGap: CGFloat = 9
            static let metaContentGap: CGFloat = 5
        }

        enum Opacity {
            static let transparent: CGFloat = 0
            static let photoToneWarm: CGFloat = 0.20
            static let photoTonePaper: CGFloat = 0.45
            static let photoTopScrim: CGFloat = 0.30
            static let photoPops: CGFloat = 0.82
            static let photoTextShadow: CGFloat = 0.50
            static let presetBloomPrimary: CGFloat = 0.55
            static let presetBloomSecondary: CGFloat = 0.90
            static let presetIcon: CGFloat = 0.19
            static let presetPops: CGFloat = 0.60
            static let presetDot: CGFloat = 0.90
        }

        enum ImageTreatment {
            static let photoSaturation: Double = 0.70
            static let bottomFadeOpaqueEnd: CGFloat = 0.58
        }

        enum Typography {
            static let categoryTracking: CGFloat = 1.4
        }

        enum Motion {
            static let pressedScale: CGFloat = 0.97
            static let pressResponse: CGFloat = 0.25
            static let pressDamping: CGFloat = 0.70
        }
    }

    /// Tab2「More to talk about」列表行的固定度量与状态配方（§5，2026-09-01 三稿：
    /// 松弛感调整——卡片外间距、卡片内边距、声部之间的间距全部放开，让五行不再
    /// 读成一堵墙）。
    enum Tab2MoreRow {
        enum Layout {
            /// minHeight 的下限，实测取自默认字号档（Large）下按三稿间距/行距渲染出的
            /// 自然内容高度（UIHostingController.sizeThatFits 实测）——它是「内容比这矮
            /// 时兜底不塌陷」的锚点，不是要死守的行高数字，更不是拍脑袋定的整数。
            /// 默认档下内容天然 ≤ 此值，行会稳定停在这个高度（视觉上等同于固定行高）；
            /// 字号调大到内容超出它时，minHeight 就放行长高，不裁字。组件私有度量，
            /// 不进 primitive 色阶（同 progressBarHeight 先例）。
            static let rowHeight: CGFloat = 117
            static let thumbnailWidth: CGFloat = Primitive.size76
            /// 主句区两行高度的下限（§5.2）：短句留白、长句省略号，不用「最多两行」。
            /// 实测取自两行 + sentenceLineSpacing 后的自然高度，理由同 rowHeight。
            static let sentenceSlotHeight: CGFloat = 43
            /// 分类行 → 主句的呼吸距离（三稿从 4 放宽到 7）。不在 4pt 间距刻度上，
            /// 组件私有（同 progressBarHeight 先例）。
            static let categoryToSentence: CGFloat = 7
            /// 主句区 → meta 的节奏（三稿从 3 放宽到 6）。不在 4pt 间距刻度上，组件私有。
            static let sentenceToMeta: CGFloat = 6
            /// 纯查词行内「词—释义—·—词—释义」的均匀间距（= 释义紧跟词的左距 4）。
            static let wordGap: CGFloat = Primitive.space4
            static let presetIconSize: CGFloat = Primitive.size28
            /// §5.6 未给描边宽度；28pt 小图标下 1.2 与 .42/.30 透明度搭配——
            /// 细了发虚、粗了发闷。
            static let presetIconStrokeWidth: CGFloat = 1.2
            static let arrowGlyph: CGFloat = 13
            /// 卡片之间的外间距（三稿从 11 放宽到 16 = Primitive.space16，
            /// 回到 4pt 刻度上，不再是组件私有的例外值）。判据：外间距必须不小于
            /// 卡片内边距（Space.paddingCard，同为 16）的视觉权重，否则五行会被
            /// 眼睛读成一整块，而不是各自独立的卡片。
            static let rowGap: CGFloat = Primitive.space16
        }

        enum Typography {
            /// 衬线主句「行高约 1.45 倍」的设计意图，用 lineSpacing 落地（SwiftUI 没有
            /// 行高倍数，只有加法式 lineSpacing，且不随 Dynamic Type 缩放）。
            /// 基准值按 .body(17pt) 推算，约 7pt——不是拍脑袋数字，但也不必精确到
            /// 小数位：真实呈现是「衬线 + 常规字重」两行主句的呼吸感，不是某个像素值。
            static let sentenceLineSpacing: CGFloat = 7
        }

        enum Opacity {
            /// 照片上的暖橙 multiply 层（比 hero .20 重一档：行内没有 soft-light 提亮，靠它压住照片）。
            static let photoToneWarm: CGFloat = 0.24
            /// 纯查词行整行透明度。
            static let wordsOnlyRow: CGFloat = 0.82
            /// 预设图图标描边透明度：常规行 / 纯查词行（更淡）。
            static let presetIcon: CGFloat = 0.42
            static let presetIconFaint: CGFloat = 0.30
        }

        enum ImageTreatment {
            /// 行内照片饱和度（比 hero .70 更暗）。
            static let photoSaturation: Double = 0.65
        }

        enum Motion {
            static let pressedScale: CGFloat = 0.97
            static let pressResponse: CGFloat = 0.25
            static let pressDamping: CGFloat = 0.70
        }
    }

    enum Motion {
        // 顶部 Tab 选中滑块：Notion 风格高阻尼质感弹簧（沉稳、有质量感，不弹跳）
        static let tabSelection: Animation = .spring(response: 0.35, dampingFraction: 0.85)
        // 时间线被动对齐跟随（刷新带回新内容、用户已在底部时的小幅跟随）：
        // 短促 easeOut——跟上新内容但不拖沓，也不抢走阅读注意力
        static let timelinePassiveFollow: Animation = .easeOut(duration: 0.15)
        // 图片首次取得：连续、克制的细环；仅在本机没有可显示图片时启用。
        // 1.15 秒一圈：可感知正在加载，但不制造催促感。
        static let imageLoadingRotation: Animation = .linear(duration: 1.15).repeatForever(autoreverses: false)
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
        // 全屏解锁温润消融与升腾揭幕动效：
        // 1. 蓄力凝聚：温润微下沉
        static let unlockCharging: Animation = .spring(response: 0.35, dampingFraction: 0.85)
        // 2. 温润晨曦升腾与旧页消融
        static let unlockDissolve: Animation = .easeInOut(duration: 0.48)
        // 3. 新内容如画卷揭开展开（参考 main 基线灵性承接）
        static let unlockReveal: Animation = .spring(response: 0.58, dampingFraction: 0.80)
        // 4. 减弱动态降级淡入
        static let unlockReducedFade: Animation = .easeInOut(duration: 0.25)
        // 光晕自身在 0.86s 完成淡出，额外保留 90ms 后再移出视图树。
        static let radiantAscentLifetime: Duration = .milliseconds(950)

        // 词条骨架屏悠扬晨曦流光：2.2s 灵动舒缓往复，温润从容
        static let shimmerSkeletonCycle: Animation = .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
        static let categoryWordsReveal: Animation = .easeInOut(duration: 0.32)
        static let categoryWordsFailure: Animation = .easeInOut(duration: 0.24)

        // Topics 手风琴展开与收起动效：0.36s 弹韧轻阻尼弹簧，舒展从容
        static let accordionToggle: Animation = .spring(response: 0.36, dampingFraction: 0.82)
        static let accordionReducedToggle: Animation = .easeInOut(duration: 0.25)

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

// MARK: - Surface pill modifier (顶栏药丸 / 汉堡菜单按钮等小元素)
// 尺寸小（~36-44pt），采用定制双层阴影 + 0.5pt 顶部白色内高光（纸张厚度感）：
// 第一层：接触阴影（定位）；第二层：暖棕柔光（浮起）；顶部：0.5pt 白色渐隐内高光。
// iOS 26: native glass + 顶部内高光 + 双层微阴影
// iOS 17-25: ultraThinMaterial + 暖白薄蒙 + 0.5pt 细描边 + 顶部内高光 + 双层微阴影
private struct SurfacePillModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let topHighlight = shape.strokeBorder(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.65), location: 0.0),
                    .init(color: .white.opacity(0.0), location: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            lineWidth: 0.5
        )

        if #available(iOS 26, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .overlay {
                    topHighlight
                }
                .shadow(
                    color: AppTheme.Shadow.pillAmbientColor,
                    radius: AppTheme.Shadow.pillAmbientRadius,
                    x: AppTheme.Shadow.pillAmbientX,
                    y: AppTheme.Shadow.pillAmbientY
                )
                .shadow(
                    color: AppTheme.Shadow.pillContactColor,
                    radius: AppTheme.Shadow.pillContactRadius,
                    x: AppTheme.Shadow.pillContactX,
                    y: AppTheme.Shadow.pillContactY
                )
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(AppTheme.Color.cardBg.opacity(0.85))
                        shape.strokeBorder(AppTheme.Color.border.opacity(0.8), lineWidth: 0.5)
                        topHighlight
                    }
                }
                .shadow(
                    color: AppTheme.Shadow.pillAmbientColor,
                    radius: AppTheme.Shadow.pillAmbientRadius,
                    x: AppTheme.Shadow.pillAmbientX,
                    y: AppTheme.Shadow.pillAmbientY
                )
                .shadow(
                    color: AppTheme.Shadow.pillContactColor,
                    radius: AppTheme.Shadow.pillContactRadius,
                    x: AppTheme.Shadow.pillContactX,
                    y: AppTheme.Shadow.pillContactY
                )
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
// 单层暖纸底 + 0.5pt 细描边 + 双层紧阴影；不使用玻璃，避免内容卡发灰。
private struct SurfaceCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    var fillColor: Color = AppTheme.Color.warmGlassSurface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background {
                shape.fill(fillColor)
            }
            .overlay {
                shape.strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
    }
}

extension View {
    /// 卡片双层紧阴影（contact 贴地接触 + ambient 浅层环境）
    func cardShadow() -> some View {
        self
            .shadow(
                color: AppTheme.Shadow.cardContactColor,
                radius: AppTheme.Shadow.cardContactRadius,
                x: AppTheme.Shadow.cardContactX,
                y: AppTheme.Shadow.cardContactY
            )
            .shadow(
                color: AppTheme.Shadow.cardAmbientColor,
                radius: AppTheme.Shadow.cardAmbientRadius,
                x: AppTheme.Shadow.cardAmbientX,
                y: AppTheme.Shadow.cardAmbientY
            )
    }

    /// 内容容器：暖纸卡配方，默认 28pt 容器圆角、`warmGlassSurface` 底色。
    /// `fillColor` 留给需要更柔和底色的调用点（如 Settings 家族）单独覆盖，
    /// 默认值不变则其余调用点（Tab2 等）行为完全不受影响。
    func surfaceCard(cornerRadius: CGFloat = AppTheme.Radius.glassContainer,
                      fillColor: Color = AppTheme.Color.warmGlassSurface) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius, fillColor: fillColor))
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

    /// 小元素/药丸专用浮动玻璃（顶栏 Tab 药丸、Settings 汉堡按钮等）：
    /// 包含 0.5pt 顶部高光与专属双层微阴影（contact + ambient），不复用大卡片大阴影。
    func surfacePill<S: InsettableShape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(SurfacePillModifier(shape: shape, interactive: interactive))
    }

    func topEdgeFade() -> some View {
        modifier(TopEdgeFadeModifier())
    }
}
