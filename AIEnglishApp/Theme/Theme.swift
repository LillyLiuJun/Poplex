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
    /// 方案 B 呼吸统一尺度（用于次级信息槽位呼吸留白，与 10pt 内容网格平齐）
    static let space10: CGFloat = 10
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space28: CGFloat = 28
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
    static let space52: CGFloat = 52
    static let space56: CGFloat = 56
    static let space72: CGFloat = 72
    static let space96: CGFloat = 96

    // 控件尺寸
    static let size28: CGFloat = 28
    static let size36: CGFloat = 36
    static let size44: CGFloat = 44
    static let size76: CGFloat = 76
    static let size84: CGFloat = 84
    static let size360: CGFloat = 360

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
    /// 深棕：浅杏色预设底上承载文字（与 primary300 底的对比度 6.6:1）
    static let primaryBrownInk = Color(hex: 0x7A3E18)


    // Neutral — 品牌染色中性（Warm Editorial）：深色端从种子橙 FF7622 掺入橙色相
    //   （黑带暖底，H≈24°），中/浅灰去棕回灰（低彩度、只留一丝暖），暖纸页面。
    //   深色有温度、大面积灰干净。深色模式数值未导出，勿自行补。
    // 暖纸 = 页面底 = 启动屏 / 开屏动画底 = 图标图形色，统一为这一枚（2026-10-08 PM 拍板，
    // 页面底由旧暖米色改为此值，ΔE≈1.08、色相 30°，消除启动屏 → 首页的换色接缝）。
    // 改动前请同步改 docs/brand/assets/ 的 SVG 与 LaunchBackground.colorset。
    static let neutral50  = Color(hex: 0xFBF8F5)  // 暖纸（pageBg / startupBg / 图标图形）
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
    /// 极致深焦墨（接近纯黑，保留微暖调，对比度突破 20:1，专用于弥补极细字干的光通量损失）
    static let neutral975 = Color(hex: 0x0A0705)
    /// Toast 浮层受阻专用纯实色沉静暖纸灰（坚决不透底，确保浮层清晰遮蔽底层内容）
    static let toastPaperGray = Color(hex: 0xEFECE6)

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

    // ── 暖近白卡片：比暖纸页面（neutral50 #FBF8F5）更亮，带一丝暖底，
    //    靠"描边 + 双层紧阴影"分层；不用纯白，避免冷白跳出整套暖色系 ──
    static let warmWhite = Color(hex: 0xFFFDFB)

    // 安静胶囊底（理由胶囊 quiet 态 + Topics 计数胶囊底共用，两个独立组件 → primitive）
    static let quietSurface = Color(hex: 0xF1ECE5)
    // 安静填充（quiet 胶囊圆点 + Topics 进度条填充共用，两个独立组件 → primitive）
    static let quietFill = Color(hex: 0xCFC7BC)

    // ── 品牌资产色（暖墨）────────────────────────────────────────────────
    // 暖纸 = 页面底 = 启动屏底 = 图标图形色，统一为 neutral50（#FBF8F5），见上方 Neutral 色阶。
    // 暖墨 = 字标（poplex-wordmark-ink.svg）的颜色，单列，不与 neutral900 (#211811) 合并。
    // 改动前请同步改 docs/brand/assets/ 的 SVG。
    static let iconInk    = Color(hex: 0x2A2320)  // 暖墨：字标
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
        /// 用户输入回显气泡内边距（横向 14pt 紧凑收敛，纵向 8pt 呼吸节奏）。
        /// 横向 14 是组件私有调优值（卡在 space12/space16 刻度中间是刻意的收敛尺寸，
        /// 不是刻度缺口，不要"补全"成 12 或 16）——仅服务这一个气泡，不进 Primitive 刻度。
        static let bubbleUserHorizontal: CGFloat = 14
        static let bubbleUserVertical: CGFloat   = Primitive.space8

        /// 页面收尾页脚留白（SettingsView 等通用内容页脚版本号底部留白：28pt；卡片到页脚呼吸断层：72pt）
        static let pageFooterTop: CGFloat       = Primitive.space72
        static let pageFooterBottom: CGFloat    = Primitive.space28
        /// Tab1 时间线停靠线：最后一条内容下沿 → 输入框胶囊上沿的视觉间距（52pt）。
        /// 2026-10-03 统一：原先是「内容区底边距 20 + 底部净空 32」两段相加，自动定位
        /// （scrollTo 最后一条 .bottom）会把 20pt 底边距压到输入框后面只剩 32，冷启动
        /// 布局与手动滑到底却是 52——服务器数据回来补定位时页面下跳 20pt。现在整段都
        /// 归底部安全区，所有到底方式停在同一条线。
        static let timelineInputClearance: CGFloat = Primitive.space52
        /// Tab2 首个一级标题距顶栏的固定距离：待解锁 / 已解锁（有无 Hero）三态统一，
        /// 解锁前后标题不跳。2026-10-03 PM 定 4pt：顶栏预留区 + 衬线字形上方留白已约 25pt，
        /// 再加 4pt，肉眼看到的「按钮下沿 → 标题」约 29pt（对标 GitHub 首页 ~28pt）。
        static let tab2ContentTop: CGFloat      = Primitive.space4
        /// Tab2 解锁态收尾页脚留白（打破卡片吸附感，96pt 营造呼吸断层；52pt 踏光上浮沉底）
        static let tab2FooterTop: CGFloat       = Primitive.space96
        static let tab2FooterBottom: CGFloat    = Primitive.space52
        /// Tab2 页脚灰标与灰色字标横向间距（方案 5 定稿：4.5pt）。
        static let tab2FooterMarkSpacing: CGFloat = 4.5
        /// Tab2 页脚品牌签名行与下方 Tagline 垂直间距（6pt）。
        static let tab2FooterBrandToTagline: CGFloat = 6
        /// 沉底操作栏按钮距离安全区底部的间距（Tab2 待解锁底栏等；与 Onboarding 具有相同数值但用途独立演化）
        static let bottomBarActionBottom: CGFloat = Primitive.space12

        // ── Tab1 时间线外部间距（4pt 律，统一时间线节奏）─────────────────────────
        // 与既有内边距 token 当前同值但**用途不同、各自演化**，保持独立语义：
        /// 用户输入 → 对应 AI 结果 / 失败行：12pt
        static let timelineUserToAI: CGFloat           = Primitive.space12
        /// AI 结果 / 失败行 → 下一次输入：28pt
        static let timelineResultToNextInput: CGFloat  = Primitive.space28
        /// 上一组内容 → 日期胶囊：32pt
        static let timelineContentToDate: CGFloat      = Primitive.space32
        /// 日期胶囊 → 当天第一条输入：16pt
        static let timelineDateToFirstInput: CGFloat   = Primitive.space16
        /// 同次输入的图片 → 文字：8pt
        static let timelineImageToText: CGFloat        = Primitive.space8

        // 区标题→内容（Topics / Materials 分区标题到其卡片的呼吸距离，统一散落字面值）
        // 与 onboardingHeaderToContent 当前同值（24）但**用途不同、各自演化**，故不合并：
        // 合并会把两个没有设计因果关系的间距绑死——改 Tab2 的分区节奏时 onboarding 会跟着动。
        static let titleToContent: CGFloat      = Primitive.space24
        // 刀 6 章节眉题（12pt 大写无衬线）→ 内容的间距（v11 .h2t padding-bottom 10px）。
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

        // EmptyStateView 上下留白下限（组件私有）：约 4:6 的比例把视觉焦点提到页面 40% 高度。
        static let emptyStateTopMin: CGFloat          = 46
        static let emptyStateBottomMin: CGFloat       = 120
    }

    enum Color {
        // 背景（暖米色页面 + 近白暖卡片，靠描边 + 紧阴影分层）
        static let pageBg   = Primitive.neutral50   // 暖纸页面（非纯白 #FBF8F5，与启动屏同色）
        // Tab1 输入框底部背板暖色补偿（中和冷感并承担 Tab1 底部承托暖光，初值 5.5%）
        static let inputBackdropWarmTint = Primitive.primary950.opacity(0.055)
        static let cardBg   = Primitive.warmWhite   // 近白暖卡片（#FFFDFB）
        static let inputBg  = Primitive.warmWhite

        // 文字（由重到轻）。对比度按 WCAG 相对亮度公式，「页面底 #FBF8F5 / 卡片底 #FFFDFB」，2026-10-08 复核。
        // 三档已覆盖所有文字层次；textFaint(1.73:1) / textLabel(2.56:1，卡片底) 均不合规，已删除。
        static let textPrimary   = Primitive.neutral900  // 16.49:1 / 17.20:1
        static let textSecondary = Primitive.neutral700  // 8.82:1 / 9.20:1
        // ⚠️ 已知取舍，非疏漏：4.18:1 / 4.36:1，略低于 WCAG AA 对小字的 4.5:1。
        // PM 2026-10-08 看过像素级对照（候选 #76716D 可达 4.56 / 4.75，同色相只暗 2.4%）后，
        // 选择保留现在较浅的观感。最受影响的是 AI 卡片里的中文译文（学习内容本身）；
        // 若有用户反馈译文偏淡，或日后要做无障碍合规，优先换成 #76716D（改 neutral500 一处即可）。
        static let textMuted     = Primitive.neutral500  // 4.18:1 / 4.36:1
        /// Settings 列表行主文本专用焦墨色：采用 Primitive.neutral975 (#0A0705)，极致深焦墨，弥补 ExtraLight 200 纤细笔画在视网膜上的光通量，呈现锐利工笔针管笔质感
        static let settingsRowText = Primitive.neutral975
        /// Settings 列表行首图标专用中灰色彩：采用 Primitive.neutral500 (#7C7773，同展开箭头色，见 textMuted 的对比度说明)，
        /// 彻底化解几何封闭图形在 200 极细文字旁的墨水重感与黑块压迫，与右侧展开箭头达成呼吸呼应，聚焦行内文字
        static let settingsRowIconTint = Primitive.neutral500
        /// Settings 卡外分组标题专用色彩（方案 D · 极简通透）：采用 Primitive.neutral500 (#7C7773，同 textMuted)，
        /// 使分组标题深度后退、近乎隐性标线，将视觉重心 100% 留给卡片内的具体内容
        static let settingsSectionTitle = textMuted

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

        /// 每日额度满额申请邀请码 CTA 胶囊背景色（选型 4 · 温润暖灰次级胶囊）：
        /// 采用 Primitive.neutral100 柔和浅暖灰，介于黑底与白底之间，与纯净暖白卡片（settingsCardSurface）形成自然明度差
        static let usageLimitCTASecondaryBg = controlDisabledBg
        /// 每日额度满额申请邀请码 CTA 胶囊边框色（选型 4 · 柔和轮廓线）：
        /// 采用 Primitive.neutral200，提供清晰温润的胶囊物理边界
        static let usageLimitCTASecondaryBorder = border
        static let usageLimitCTAShadow = Primitive.mediaSurface.opacity(0.04)          // CTA 接触微阴影色（黑 4%）
        static let usageLimitProgressTrack = neutralFaint.opacity(0.20)                // 进度轨底槽（通透纸槽）
        static let usageLimitRetryPillBg = neutralFaint.opacity(0.4)                   // Try again 胶囊底

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

        // 用户气泡（温润书卷：半透暖纸灰底 68% + 书卷石墨暖深灰字 + 0.5pt 细微边缘，消除暗块与浓墨感，凸显 AI 学习卡）
        // 对比度：文字与「气泡底色 68% 叠加在 pageBg 上」的实际合成色（#F4F1EB），按 WCAG 相对亮度公式核算 ≈8.28:1，
        // 超过 AAA 门槛 7:1（2026-10-08 pageBg 改 #FBF8F5 后重算；若改动 bubbleUserBg/pageBg 任一色值需重新核算，别直接照抄这个数字）
        static let bubbleUserBg     = Primitive.neutral100.opacity(0.68)
        static let bubbleUserText   = Primitive.neutral700
        static let bubbleUserBorder = Primitive.neutral200.opacity(0.55)
        static let bubbleAIBg       = Primitive.warmWhite
        // 日期分隔胶囊背景（提亮加暖）
        static let dateChipBg       = Primitive.neutral200.opacity(0.5)

        // 描边 / 分割
        static let border       = Primitive.neutral200
        // 输入框聚焦态描边：中性暖灰微深档（neutral400 #ABA69F），柔和温润，避免纯黑重框
        static let inputFocusBorder = Primitive.neutral400
        // 卡片精细轮廓描边：0.5pt @ 约 35% 透明度，与紧阴影分工建立提亮后的边界
        static let cardBorder   = Primitive.neutral200.opacity(0.35)
        // Tab2 空状态便签插画：背后晨曦柔光渐变的收尾色（淡出到透明）。
        static let emptyStateGlowFade = SwiftUI.Color.clear
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

        // 词条类型图标的回退底块（无配图时）：比图片占位底更淡，让描边类型图标退后作弱提示。
        // 与活动胶囊 / 计数胶囊同一材质（墨黑 @ 4%），直接引用不另存数值——此前是 5%，
        // 与胶囊只差 1 个百分点、肉眼分不出，却是两份数字。有配图的词条不走这个 token。
        static let iconTileBg = tab2ActivityChipBg

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
        // Settings 家族卡片（Settings / About AI / Feedback）专用：对齐 Today TAB 100% 纯不透明暖白底（cardBg #FFFDFB），
        // 遵循“别名引用而非重声明”规范，彻底消除 85% 透明度透底暗沉微灰感，让卡片通透明亮。
        static let settingsCardSurface = cardBg

        // Tab2 Hero 顶部照片的统一调色与预设图（B1）专用色。组件只消费这些语义 token，
        // 不直接引用 Primitive 或字面 Color，以便日后更换目标市场的视觉主题时集中调整。
        // 视觉回归 main 基线（2026-09-22 §2.1/2.4/2.5）：以下 token 名与取值逐条取自
        // `git show main:AIEnglishApp/Theme/Theme.swift`，不转录、不另起名。
        static let tab2HeroPhotoToneWarm = Primitive.primary600
        static let tab2HeroPhotoTonePaper = Primitive.primary100
        static let tab2HeroPhotoTopScrim = Primitive.neutral900
        static let tab2HeroPhotoOverlayText = Primitive.controlOnMedia
        static let tab2HeroPhotoOverlayShadow = Primitive.mediaSurface
        // Tab2 类别预设图（2026-10-04 方案 A「色阶实心」）：Hero 预设图与 More 行内
        // 缩略图共用同一套五色，全部取品牌橙色阶，不引入新色相。
        static let tab2PresetArtBackground = Primitive.primary300  // 纯色底
        static let tab2PresetArtSurface    = Primitive.primary100  // 大浅色主物体
        static let tab2PresetArtDetail     = Primitive.primary400  // 主物体内 2pt 细节线
        static let tab2PresetArtSecondary  = Primitive.primary700  // 辅物
        static let tab2PresetArtAccent     = Primitive.primary800  // 左侧细条（降一档，不用满饱和种子橙）
        // 图上标签：照片底 = 纯白文字 + 柔焦微阴影（以下两个 token）；预设底另见 tab2HeroPreset* 两个 token（深棕字，2026-10-06 起分流）。
        // 理由胶囊文案已经把状态说完
        // （"Added 3 times today" / "Nothing new in 2 weeks"），不再用颜色说第二遍——
        // 两态共用同一套配色，取原 Quiet 值（更克制，不与暖橙"今天有新东西"信号抢戏）。
        static let tab2ReasonPillOnPhotoText = Primitive.controlOnMedia.opacity(0.82)
        // 预设底（浅杏色）上的标签改用深棕字、不加阴影（2026-10-06 PM 拍板：预设卡 / 照片卡分流；此前「全部纯白、不分流」的决定作废）。
        // 类别名 6.6:1；理由行 72% 约 3.6:1，PM 看过真机渲染后接受（比白字的 1.2:1 清楚得多，保留与类别名的层次）。
        static let tab2HeroPresetLabelText = Primitive.primaryBrownInk
        static let tab2HeroPresetReasonText = Primitive.primaryBrownInk.opacity(0.72)
        // 活动胶囊：轻雾柔霜 · 极简无边框（方案 2）
        // 极低彩度 4% 墨染柔底（neutral900 @ 4%），融入卡片同时保持极致清爽素雅；
        // 彻底不加边框（Color.clear）；字色使用 neutral900 高对比近黑。
        static let tab2ActivityChipBg = Primitive.neutral900.opacity(0.04)
        static let tab2ActivityChipBorder = SwiftUI.Color.clear
        static let tab2ActivityChipText = Primitive.neutral900
        // 照片暖橙 multiply 层：与 hero 同 primitive（primary600）、强度独立（.24 vs .20），
        // 独立 token 便于单侧调整（同 brandWash / tab2HeroPhotoTonePaper 共用 primary100 的先例）。
        static let tab2MoreRowPhotoToneWarm = Primitive.primary600
        // Topics 计数胶囊（轻雾柔霜极简微底 + 无边框，与活动胶囊同材质）
        static let tab2ProgressPillBg = tab2ActivityChipBg
        static let tab2ProgressPillBorder = tab2ActivityChipBorder
        // 半轻灰胶囊底（计数 + chevron 合并单元）：暖近黑极低透明，中性、不引入橙
        static let pillNeutralBg    = Primitive.neutral900.opacity(0.06)

        // Toast 浮层专用实色背景（坚决不透底，确保浮层能完全遮蔽底层列表与卡片内容）
        /// Toast 积极确认底色（#FFF3EB 晨曦暖橙实色）
        static let toastPositiveBg  = Primitive.primary100
        /// Toast 动作受阻底色（#EFECE6 沉静暖纸灰实色，100% 不透明）
        static let toastBlockedBg   = Primitive.toastPaperGray

        // 下拉刷新 / 弱加载指示器（极淡浅暖灰，轻盈温润、不抢视觉重心）
        static let refreshIndicator = Primitive.neutral300

        // 玻璃卡内的轻量元素：进度条轨道/填充、行间隔线——暖近黑低透明，
        // 跟着底色走，不再是实心灰。hairline 与 progressTrack 同值是有意共享：
        // 玻璃容器内"最轻一档"的分隔统一 4.5%。
        static let progressTrack = Primitive.neutral900.opacity(0.045)
        // 刀 6 去橙：进度填充改安静灰（与 quiet 胶囊点同源 #CFC7BC）。Topics 不再有橙。
        static let progressFill  = Primitive.quietFill
        static let glassHairline = Primitive.neutral900.opacity(0.045)

        // 启动屏 / 开屏动画底色（= LaunchBackground.colorset，二者必须同值，否则启动会闪一下）。
        // 与 pageBg 同一枚 primitive：开屏退场后露出的页面底不再换色。
        static let startupBg = Primitive.neutral50

        // 相机全屏表面 + 覆盖控件（白控件浮在实时画面上，与浅色主题无关）
        static let cameraBg        = Primitive.mediaSurface
        static let cameraControl   = Primitive.controlOnMedia
        static let cameraControlBg = Primitive.scrimOnMedia


    }

    enum Font {
        // ── 字体三巨头：Charter (英文衬线) + Gothic A1 (英文无衬线) + 冬青黑 (中文) ──
        // 字重参数只收本字族「真有的档位」——每个字族一个小枚举，调用方写不出
        // 不存在的字重，由编译器拦截、不靠注释也不靠人记得（刀 5-① PM 拍板）。
        // 旧版是 Font.Weight 九档 + 二值 isBold 静默降级：.medium 全 app 退成
        // Regular、.black 退成 Regular——API 承诺了它兑现不了的东西。
        enum SansWeight {
            case extraLight, light, regular, medium, semibold

            /// UI 无衬线字体的 PostScript 名——全 App（含测试、测量代码）唯一来源。
            /// 换字体只改这里。
            var postScriptName: String {
                switch self {
                case .extraLight: "GothicA1-ExtraLight"
                case .light:      "GothicA1-Light"
                case .regular:    "GothicA1-Regular"
                case .medium:     "GothicA1-Medium"
                case .semibold:   "GothicA1-SemiBold"
                }
            }
        }  // 打包文件：ExtraLight / Light / Regular / Medium / SemiBold
        enum CharterWeight  { case regular, bold }              // 系统字族仅有这两档
        enum HiraginoWeight { case w3, w6 }                     // 冬青黑系统两档

        private static func charter(_ size: CGFloat, weight: CharterWeight = .regular, relativeTo style: SwiftUI.Font.TextStyle = .body) -> SwiftUI.Font {
            FontLoader.registerCustomFonts()
            let name = weight == .bold ? "Charter-Bold" : "Charter"
            return SwiftUI.Font.custom(name, size: size, relativeTo: style)
        }

        /// 固定字号变体（不随 Dynamic Type 缩放）。品牌资产专用（Onboarding 封面大标题），
        /// 放大会撑破居中构图、且不承载可读信息。
        private static func charterFixed(_ size: CGFloat, weight: CharterWeight = .regular) -> SwiftUI.Font {
            FontLoader.registerCustomFonts()
            return SwiftUI.Font.custom(weight == .bold ? "Charter-Bold" : "Charter", fixedSize: size)
        }

        private static func sans(_ size: CGFloat, weight: SansWeight = .regular, relativeTo style: SwiftUI.Font.TextStyle = .body) -> SwiftUI.Font {
            FontLoader.registerCustomFonts()
            return SwiftUI.Font.custom(weight.postScriptName, size: size, relativeTo: style)
        }

        private static func hiragino(_ size: CGFloat, weight: HiraginoWeight = .w3, relativeTo style: SwiftUI.Font.TextStyle = .body) -> SwiftUI.Font {
            FontLoader.registerCustomFonts()
            return SwiftUI.Font.custom(weight == .w6 ? "HiraginoSansGB-W6" : "HiraginoSansGB-W3", size: size, relativeTo: style)
        }

        // 英文主内容 / 词条大标题（Warm Editorial 内容衬线，Charter 权威粗衬线）
        static let englishPrimary = charter(17, weight: .regular, relativeTo: .body)                    // 英文主内容（Charter 衬线，保 Dynamic Type）
        static let wordTitle      = charter(20, weight: .bold, relativeTo: .title3)                 // 词条大标题（内容衬线，半粗以有分量不过重）
        /// 英文例句正文（Charter 17pt 常规字重，Warm Editorial 内容衬线，随 Dynamic Type 缩放）。
        /// 语义是「学习卡片内的英文例句」，与 Polish / 英文主内容（englishPrimary 17pt）同字族同字重同字号，
        /// 保持英文表达饱满开阔的呼吸感；独立维护 Token，坚决不挪用 chineseBody。
        static let exampleSentence = charter(17, weight: .regular, relativeTo: .body)
        static let englishBody    = sans(17, weight: .regular, relativeTo: .body)                     // 界面正文：设置行 / 输入框 / 空态提示等
        /// 用户输入回显气泡文字（15pt 常规字重，温润书卷正文，保 Dynamic Type 缩放）。
        /// 与下方 feedbackChipLabel 数值巧合相同（两者用途无关，纯属这次设计都选了 15pt regular）——
        /// 刻意不合并成一个共用 Token：气泡和反馈表单是两件独立的事，以后单独调气泡字号不该连累反馈表单。
        static let userBubbleText = sans(15, weight: .regular, relativeTo: .subheadline)
        // Onboarding 拼贴里的示意微文案（照片注脚 / 语音转写 / 便签正文）。
        // 尺寸：15（比 englishBody 17 降一档）——这些字是「让人认出这是什么输入」的示意，
        //   不是要读的内容；17pt 主色会让三张卡同时抢主标题的注意力，整页发重。
        // 字族：**衬线**。这三行是用户产生的内容，和结果页的英文主句（englishPrimary，
        //   同为内容衬线）是同一类东西，理应同族；且整页其余全是衬线，卡上突然出现无衬线
        //   就是「形态语言不同族」，与 N-1 里 chevron 的问题同类。
        // 不挪用 chineseBody（语义是中文）或 statusNote（语义是加载/空态提示）。
        static let onboardingCollageNote = charter(15, weight: .regular, relativeTo: .subheadline)
        static let buddy          = sans(14.5, weight: .medium, relativeTo: .subheadline)           // 次级按钮与说明（Not now / Try saying it / 话题 chip / 对话顶栏话题名等，9 个文件；=参考稿 14.5/500）
        static let keyPhrase      = sans(15, weight: .semibold, relativeTo: .subheadline)               // 核心词组（=参考稿 kp-word 15/700 加黑；.bold→.semibold 显式化：无衬线最重档 SemiBold，渲染不变）
        static let phonetic       = SwiftUI.Font.system(.footnote, design: .monospaced)               // IPA 音标（等宽）
        static let pos            = sans(11, weight: .regular, relativeTo: .caption2)                // 词性 / 卡片 Meta（=参考稿 ~11-12px）
        // CardTypeChip 曾用 pos 叠加 .fontWeight(.bold)：请求的是没打包的 Bold 700，
        // 系统会自行挑最近字重或合成假粗体，结果不可控。改用强类型枚举里真有的 SemiBold。
        static let cardTypeChipLabel = sans(11, weight: .semibold, relativeTo: .caption2)           // 卡片类型标签（CardTypeChip，大写 uppercase 展示）
        // 静态事实 / 计数小字：版本号、字数计数、字段脚注。
        // 与 pos 当前同值（.caption2）但**语义不同、各自演化**，故不合并：
        // pos 的语义是「学习内容的词性标注」，跟着内容卡走；这一档跟着功能页的
        // 辅助信息走。此前这三处都挪用了 pos，改版权衡时会互相牵制。
        static let metaNote       = sans(11, weight: .regular, relativeTo: .caption2)
        static let tab2ProgressCount = sans(12, weight: .regular, relativeTo: .caption)             // Topics 进度行 words 计数（12/400 Regular：与左侧 13pt Regular 形成 1:1 光学同频匀质感，扎实耐看）
        static let tab2ExploreTagLabel = sans(13, weight: .regular, relativeTo: .subheadline)     // More topics to explore 未开启主题胶囊名（13/400，与 Topics in progress 13pt 保持视觉平齐与连贯松紧度）
        static let tab2TopicLabel = sans(13, weight: .regular, relativeTo: .subheadline)           // Topics 类别名（方案 3-B 细线轻挺风：13/400 纤细排印，与 14pt 细线图标光学平衡，恒中性）
        static let sectionLabel   = sans(11, weight: .semibold, relativeTo: .caption2)              // 区块小标（例句 / 说明，11/600 无衬线 SemiBold）
        /// 卡片说明正文（Note 区块：形式与语法说明正文，15pt 常规字重无衬线，随 Dynamic Type 缩放）。
        /// 语义是「学习卡片底部的语法/形式观察说明」，采用西文无衬线体系，与 NOTE 小标（sectionLabel）形成统一的辅助说明语族；
        /// 15pt 与中文正文同大，字字清朗、舒展易读，消除断崖式小字感；坚决不挪用 chineseBody（冬青黑体西文粗钝）。
        static let noteBody       = sans(15, weight: .regular, relativeTo: .subheadline)
        static let statusNote     = sans(13, weight: .regular, relativeTo: .footnote)                // 加载态 / 空态 / 系统提示性短句
        static let growthStatus   = sans(13, weight: .semibold, relativeTo: .footnote)              // 成长线状态（如「0 pops so far」）
        static let actionNote     = sans(13, weight: .regular, relativeTo: .footnote)               // 操作项的补充说明（如拍照入口副文案）
        static let compactActionLabel = sans(15, weight: .medium, relativeTo: .subheadline)         // 上传胶囊动作（Camera / Gallery）：无图标时用中等字重建立操作重量
        static let inlineActionLabel = sans(13, weight: .semibold, relativeTo: .footnote)           // 无底框行内动作按钮文字（错误态 Try again，13/600，随 Dynamic Type 缩放）
        /// 反馈分类标签：采用 Gothic A1 14pt Medium (500)，微缩一档更加紧致扎实，与分类图标平齐
        static let feedbackChipLabel = sans(14, weight: .medium, relativeTo: .subheadline)
        static let chineseFaint   = hiragino(13, weight: .w3, relativeTo: .footnote)             // 中文原文弱化 (冬青黑体)
        static let chineseBody    = hiragino(15, weight: .w3, relativeTo: .subheadline)          // 中文翻译 / 释义（=参考稿 content-zh 14px 灰）
        static let date           = sans(11, weight: .semibold, relativeTo: .caption2)              // 日期分隔
        static let hero           = sans(34, weight: .semibold, relativeTo: .largeTitle)                // Onboarding 标题（.bold→.semibold 显式化：无衬线最重档 SemiBold，渲染不变）
        static let screenTitle    = sans(22, weight: .semibold, relativeTo: .title2)                    // 功能页大标题（onboarding 实操页等；.bold→.semibold 显式化：无衬线最重档 SemiBold，渲染不变）
        static let pageTitleSerif = charter(34, weight: .bold, relativeTo: .largeTitle)          // 页面衬线大标题（Tab2「Not open yet」等，与内容衬线同族）
        // Onboarding 封面大标题：比 largeTitle 更大的展示字号，撑起全屏第一印象。
        // 封面特例——固定字号、不随 Dynamic Type 放大（与 pageTitleSerif 同为衬线同族，
        // 仅尺寸更大）。换装仍保留该特例：改用 charterFixed（固定字号工厂，品牌资产
        // 专用），因为随 Dynamic Type 缩放与特例语义冲突。
        static let onboardingHeroSerif = charterFixed(46, weight: .bold)
        static let onboardingLeadSerif = englishPrimary  // Onboarding 各屏副标题（标题下的价值/说明句）：复用内容衬线，与 onboardingHeroSerif 成对；别名而非重声明，避免与例句内容耦合、也不重复定义同值。（tabLabel 已于 2026-09-01 改无衬线，脱离本次换装范围，见需求清单 C11。）
        static let sectionTitleSerif = charter(22, weight: .bold, relativeTo: .title2)           // 分区衬线小标题（Topics in progress / Materials Yours），比页面大标题小一档
        static let compactSectionTitleSerif = charter(20, weight: .bold, relativeTo: .title3)    // 紧凑页面内的小分区标题（如 Onboarding 样例区）
        /// Settings 卡外分组标题：Charter 14.5pt Regular 细衬线（方案 D 极简通透，保留衬线编辑感，退到辅助层）
        static let settingsSectionTitleSerif = charter(14.5, weight: .regular, relativeTo: .subheadline)
        static let settingsPinnedTitleSerif = charter(20, weight: .bold, relativeTo: .title3)    // Settings 家族固定顶栏标题：比系统导航栏字号大一档，仍在 60pt 顶栏内不挤，保留品牌衬线
        static let settingsVersion = charter(12, weight: .regular, relativeTo: .caption)              // Settings 页脚版本号：caption 直立端正衬线（方案 2：严谨书籍出版感）
        /// Settings 列表行主标签及辅值：采用 Gothic A1 ExtraLight (200)，彻底卸下 CJK Regular 400 骨架过粗的黑块感，呈现轻盈利落的精工工笔感。
        /// 「粗体文本」无障碍开关只对系统字体自动生效，对自定义字体（Font.custom）
        /// 不会做任何处理——ExtraLight 200 开着这项设置的用户完全得不到任何收益。
        /// 因此这里显式读 `legibilityWeight`：开启时切到 Light (300) 的**真实字重文件**
        /// （而非 `.fontWeight(.bold)` 伪加粗），比 200 明显扎实但仍在细字重家族内，
        /// 不跳到 400 打破整体纤细基调。调用点需传入 `@Environment(\.legibilityWeight)`。
        static func settingsRowLabel(legibilityWeight: SwiftUI.LegibilityWeight?) -> SwiftUI.Font {
            sans(17, weight: legibilityWeight == .bold ? .light : .extraLight, relativeTo: .body)
        }
        /// Settings 文稿/说明页标题（如 About AI）：采用 Charter 20pt 直立细衬线（Regular 400），黑度温润雅致，不喧宾夺主
        static let settingsDocumentTitleSerif = charter(20, weight: .regular, relativeTo: .title3)
        // settingsDocumentBody / settingsFormInput（本组）与下方 quotaSubtext 当前同为
        // sans(15, .light, .subheadline)——同值是巧合，不是约束。三者服务不同页面
        // （About AI 正文 / Feedback 输入框 / 用量弹窗副文），允许各自独立调整字号，
        // 不因为现在同值就合并成一个通用 token（如 formContentBody）而把三处业务耦合死。
        // 项目里 statusNote/actionNote/tab2HeroFootrowWords/tab2EmptyStateLine 四个
        // token 同为 sans(13, .regular, .footnote) 是同一模式的既有先例。
        /// Settings 文稿/合规说明长正文（如 About AI）：采用 Gothic A1 Light (300) 15pt，字干 60u，比通用 17pt 更舒适透气
        static let settingsDocumentBody = sans(15, weight: .light, relativeTo: .subheadline)
        /// Settings 文稿页操作链接（如 Privacy Policy / Terms 外链）：采用 Gothic A1 Medium (500) 15pt，字号与正文协调并具备可点击分量
        static let settingsDocumentActionLink = sans(15, weight: .medium, relativeTo: .subheadline)
        /// Settings 表单引导副标题（如 Feedback "Share your ideas..."）：采用 Gothic A1 Light (300) 14.5pt，避免从 20pt 标题剧烈跳崖，温和过渡
        static let settingsFormIntro = sans(14.5, weight: .light, relativeTo: .subheadline)
        /// Settings 表单输入框正文及占位符（如 Feedback Details/Email）：采用 Gothic A1 Light (300) 15pt，彻底消除 17pt 倒挂反超组标的病灶，多行书写透气舒展
        static let settingsFormInput = sans(15, weight: .light, relativeTo: .subheadline)
        static let libraryFooterTagline = charter(12, weight: .regular, relativeTo: .caption)         // Library 页脚品牌收口宣言：caption 直立端正衬线，与标题 Serif 呼应
        static let ctaLabel       = sans(17, weight: .semibold, relativeTo: .body)                  // 主按钮文字（Continue / Get Started）
        static let tab2HeroMeta = sans(12, weight: .semibold, relativeTo: .caption)
        static let tab2HeroWordPartOfSpeech = sans(11, weight: .regular, relativeTo: .caption2).italic()
        static let tab2HeroWordMeaning = hiragino(13, weight: .w3, relativeTo: .footnote)
        static let tab2HeroCTA = sans(15, weight: .semibold, relativeTo: .subheadline)
        // ── 刀 6 卡面（刀 6b v12 视觉稿「胶囊改版」）──
        // 活动胶囊：一行一个胶囊（Charter 活动名 on 幽灵半透底），+N more 无底尾随；
        // 固定两行高、只排得下一条也占两行（Hero 57 / More 50）。次数上标已随 v12 删除
        // （occurrence_count 仍返回，只参与后端排序，卡面永不渲染）。
        // 基准字号独立成常量：胶囊拟合用 CoreText 测量宽度，SwiftUI Font 无法反解字号，
        // 故测量侧用 UIFontMetrics(forTextStyle:) 复刻同名 token 的缩放（见 Tab2ActivityDisplay）。
        static let tab2HeroCapsuleNameBaseSize: CGFloat = 13.5
        static let tab2MoreRowCapsuleNameBaseSize: CGFloat = 12
        static let tab2HeroCapsuleMoreBaseSize: CGFloat = 12
        static let tab2MoreRowCapsuleMoreBaseSize: CGFloat = 11
        static let tab2HeroCapsuleName = charter(tab2HeroCapsuleNameBaseSize, weight: .regular, relativeTo: .subheadline)       // Hero 胶囊活动名 13.5px Charter
        // 内容声部：比 hero 胶囊（tab2HeroCapsuleName 13.5pt）低一档——12 vs 13.5，
        // hero 是「推荐」的强断言，这里只是「也说得出口」。层级差异完全由字号承担，
        // 调其中一个数前先看这句。
        static let tab2MoreRowCapsuleName = charter(tab2MoreRowCapsuleNameBaseSize, weight: .regular, relativeTo: .footnote)     // More 胶囊活动名 12px
        static let tab2HeroCapsuleMore = sans(tab2HeroCapsuleMoreBaseSize, weight: .regular, relativeTo: .footnote) // Hero +N more 12px muted
        static let tab2MoreRowCapsuleMore = sans(tab2MoreRowCapsuleMoreBaseSize, weight: .regular, relativeTo: .caption2) // More +N more 11px muted
        static let tab2MoreRowMeta = sans(12, weight: .regular, relativeTo: .caption)   // More 词数行 12px（v12 .rwords）
        /// 理由胶囊文字（刀 6b v12 .opill）：两态同形同 11.5/500（v12 quiet 态不降字重），
        /// 只换颜色——hot 暖奶油字、quiet 白 82%。
        static let tab2ReasonPill = sans(11.5, weight: .medium, relativeTo: .caption)
        /// 照片标签类别名（方案 A 纯粹极简试验：四大生活分类 100% 统一为 13pt Regular 400，日系温润书卷，彻底去标签化）。
        static let tab2HeroChipCategory = sans(13, weight: .regular, relativeTo: .subheadline)
        /// Hero「Recent activities」区内小标题（v12 .seclab）：11px/600 无衬线大写。
        static let tab2HeroActivitySectionLabel = sans(11, weight: .semibold, relativeTo: .caption2)
        /// Hero 脚行左端词数（v12 .footrow .words）：13px muted 表格数字。
        static let tab2HeroFootrowWords = sans(13, weight: .regular, relativeTo: .footnote)
        /// 无 activity 空态说明行（刀 6b 空态 v1 .onlywords）：13px 无衬线 muted，
        /// 单行自然高度——衬线是用户内容的标记，这是系统在说明状态，不带衬线。
        /// Hero 与 More 空态共用同一句、同一档（B2 拍板：同一个状态在两处说同一
        /// 句话）。规格与 tab2HeroFootrowWords 同为 13px 常规无衬线，但用途不同、
        /// 不共用 token（单侧调字号不应牵动另一处）；重复值待 token hygiene 巡检。
        static let tab2EmptyStateLine = sans(13, weight: .regular, relativeTo: .footnote)
        /// More 类别帽（方案 A 纯粹极简试验：四大生活分类 100% 统一为 13pt Regular 400，轻盈安静，与整页统一呼吸）。
        static let tab2MoreRowCategory = sans(13, weight: .regular, relativeTo: .subheadline)
        static let tab2MoreRowTimeline = sans(11.5, weight: .regular, relativeTo: .caption2)    // More 时间 11.5px，升到帽行右端（§三②）
        /// 手风琴展开词条单词（方案 1 意式书卷：Charter 14pt Regular 400，中英 1:1 光学同宽，彻底消解 15pt Bold 粗笨感，与全页 13pt Regular 自洽）。
        static let tab2WordEntryTitle = charter(14, weight: .regular, relativeTo: .subheadline)
        /// 手风琴展开词条释义（方案 1 微字号收敛：冬青黑 11.0pt W3 Regular，主次反差清晰，完全退居辅助查阅地位）。
        static let tab2WordEntryMeaning = hiragino(11, weight: .w3, relativeTo: .caption2)

        // 顶部 Tab 名称：2026-09-01 改无衬线（与内容衬线脱钩，不再随衬线家族
        // 换装同步——见需求清单 C11，问题已随此改动消解）。两项同重，选中关系
        // 仍交给毛玻璃胶囊，而不是靠字重制造对比。
        // 基准字号独立成常量：AIEnglishAppTests 实测顶栏行宽时与生产共用这一个数
        // （测试按 .subheadline 的 UIFontMetrics 表复刻 relativeTo 的缩放，再量打包的
        // GothicA1-Medium 真字体）。旧三常量 tabLabelStyle/Design/Weight 已删——它们只有
        // 测试在读、生产从不读，实测的是 SF Pro 而非无衬线自有字体，等于保证了一个不存在的
        // 东西；改字重档位时须同步测试里的 PostScript 名，不同步会红。
        static let tabLabelBaseSize: CGFloat = 15
        static let tabLabel       = sans(tabLabelBaseSize, weight: .medium, relativeTo: .subheadline)
        static let cardSentence   = charter(17, weight: .bold, relativeTo: .body)
        static let feedbackTitleSerif = cardSentence
        static let onboardingUploadTitle = charter(17, weight: .regular, relativeTo: .body)  // (.medium→.regular 显式化：Charter 无中间档，渲染不变)
        /// 每日额度弹窗顶栏标题：Charter 22pt Bold（沉稳压轴定力，别名绑定 sectionTitleSerif，不与 settingsDocumentTitleSerif 耦合）
        static let usageLimitSheetTitleSerif = sectionTitleSerif

        // 每日额度数字：Charter 24pt Regular 细衬线（方案 2-C，焦黑 #0A0705，告别旧版 34pt 粗黑与警告红）
        static let quotaHeroNumber = charter(24, weight: .regular, relativeTo: .title2)
        /// 每日额度副文：Gothic A1 15pt ExtraLight 200 (/ 5 generations today)，
        /// 官方方案 A 规范，对齐 Settings 页面 Target language 字符样式，笔画工笔利落。
        /// 支持系统「粗体文本」无障碍自动升阶（开启时切至 Light 300 真实字重）。
        static func quotaSubtext(legibilityWeight: SwiftUI.LegibilityWeight? = nil) -> SwiftUI.Font {
            sans(15, weight: legibilityWeight == .bold ? .light : .extraLight, relativeTo: .subheadline)
        }
        static let quotaSubtext = sans(15, weight: .extraLight, relativeTo: .subheadline)
        // 每日额度满额标题：Charter 16.5pt Regular 细衬线降重
        static let quotaReachedTitle = charter(16.5, weight: .regular, relativeTo: .body)
        // 每日额度满额说明正文：Gothic A1 14pt Light
        static let quotaReachedBody = sans(14, weight: .light, relativeTo: .subheadline)
        // 申请邀请码 CTA 胶囊文字：Gothic A1 14pt Medium。与 feedbackChipLabel 现同值——
        // 同值是巧合，各自独立演化，不合并（同一模式见上）。
        static let quotaFeedbackAction = sans(14, weight: .medium, relativeTo: .subheadline)
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
        /// Settings 文稿/合规披露页（如 About AI）等长篇说明的额外行距（比通用正文更舒展，保呼吸感）。
        static let lineDocument: CGFloat = 6
        /// 顶部 Tab 文字的动态字号上限（含本档）。「顶部 Tab 始终显示文字」决策的配套。
        /// 2026-09-01 tabLabel 改无衬线后行宽变窄，AX2 档位在最窄屏（375pt）上还有余量，
        /// 实测封顶档从 AX2 松到了 AX3。用户开到 AX4 及以上时导航文字不再放大，
        /// 正文等其他内容不受此限。
        /// 注意：具体字号随 iOS 版本的字号缩放表浮动，档位是否正确由 AIEnglishAppTests 的
        /// labelTabRowFitsNarrowestSupportedScreenAtMaxDynamicTypeSize 双面包夹测试在运行时强制
        /// （文案变长、字体配方再变动或加第三个 Tab 同样会让该测试变红）；
        /// 本注释数值仅作参考，不必精确。
        static let topTabLabelMaxDynamicTypeSize: DynamicTypeSize = .accessibility3

        /// 整个 App 的字号上限（2026-10-06 PM 拍板）：系统字号拉到「无障碍」那 5 档（AX1–AX5）时，App 里的字
        /// 停在这一档（超大 xxxLarge，正文约 23pt）；普通范围（极小 … 超大）照常跟随系统。
        /// 在 WindowGroup 上通过 `appDynamicTypeCap()` 统一生效。以后要支持无障碍字号，去掉那一处调用即可。
        /// 顶部页签自己的上限（topTabLabelMaxDynamicTypeSize）比它宽，不再起作用，保留不删。
        static let appMaxDynamicTypeSize: DynamicTypeSize = .xxxLarge
    }

    /// 不透明度语义层。
    ///
    /// 不透明度既不是尺寸也不是颜色，独立成层：写 `Size.xxxOpacity` 会让
    /// 「按 category-purpose-level 命名」的约定失效，也让 Size 层不再是纯几何量。
    /// 只收「同一个颜色 token 在不同语境下的减弱程度」，颜色本身仍归 Color。
    enum Opacity {
        // ── Tab2 空状态便签插画（component-private，仅 EmptyStateIllustration 使用）──
        /// 背后柔光渐变起点：brandTint 的浓度。
        static let emptyStateGlowTint: CGFloat   = 0.35
        /// 背后柔光渐变中段：brandStrong 的浓度。
        static let emptyStateGlowBrand: CGFloat  = 0.12
        /// 便签卡描边：cardBorder 再略收一点。
        static let emptyStateNoteBorder: CGFloat = 0.85
        /// 便签首行 / 中行 / 底行文字痕迹（textSecondary），由深到浅三档。
        static let emptyStateFocusLine: CGFloat  = 0.30
        static let emptyStateMiddleLine: CGFloat = 0.18
        static let emptyStateBottomLine: CGFloat = 0.14
    }

    /// 静态几何旋转角（度）。
    ///
    /// 与 Motion 区分：Motion 描述「随时间变化」，这里是排版上钉死的倾角，
    /// 不参与动画、不随状态改变。
    enum Rotation {
        /// 空态便签卡：轻微逆时针倾斜，像随手放下的一张纸。
        static let emptyStateNote: CGFloat = -3
    }

    enum Radius {
        static let small: CGFloat          = Primitive.radius8   // tag / 小元素
        static let bubbleUser: CGFloat     = 14                  // 用户回显气泡：便签轻量圆角（组件私有调优值，不进 Primitive 刻度）
        static let medium: CGFloat         = Primitive.radius16  // 卡片 / 气泡
        static let large: CGFloat          = Primitive.radius20  // 输入框
        static let glassContainer: CGFloat = Primitive.radius28  // 浮动 glass 容器
        static let emptyStateNote: CGFloat = 10                  // 空态便签卡圆角（组件私有调优值，不进 Primitive 刻度）
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

        // 空状态便签卡：纯黑 4% 的微接触阴影，只交代纸张厚度。
        static let emptyStateNoteColor: SwiftUI.Color = Primitive.mediaSurface.opacity(0.04)
        static let emptyStateNoteRadius: CGFloat = 8
        static let emptyStateNoteX: CGFloat = 0
        static let emptyStateNoteY: CGFloat = 4
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
        static let categoryBadge: CGFloat = 20  // Topics 类别图标边长（20×20 纯线条，紧凑不占位）
        /// AI Consent 弹窗固定高度：文案精简自洽，不设展开档；消灭空旷下巴与过度拉伸。
        static let consentSheetHeight: CGFloat = 410
        /// Tab1 Passage 卡片展开正文的外层时间线高度上限。超出部分在卡内滚动，
        /// 避免单个动态行撑到数屏高，触发 LazyVStack 对后续消息的大幅几何纠正。
        static let passageExpandedViewportMaxHeight: CGFloat = Primitive.size360
        /// Passage 展开态为系统垂直滚动条保留的正文安全通道。
        static let passageScrollIndicatorGutter: CGFloat = Primitive.space12
        /// Passage 内部滚动视口上下缘的同色柔化高度。
        static let passageScrollEdgeFadeHeight: CGFloat = Primitive.space24
        // brandMark（84pt 圆形 app-icon 报头直径）已随 Settings 删除品牌报头一并移除。

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
        static let progressBarHeight: CGFloat    = 1.5   // 进度条轨道高度（超轻 1.5pt 微轨）
        static let categoryIconGlyph: CGFloat    = 14    // 分类图标 SF Symbol 字号（方案 3-B：从 15 微调为 14，与 13pt 细线标题光学平齐）
        static let expandArrow: CGFloat          = 7.5   // 展开三角字号
        static let entryThumbnail: CGFloat       = 32    // 词条左栏缩略图 / 图标底块边长
        static let entryBadgeGlyph: CGFloat      = 14    // 词条类型 SF Symbol 字号
        static let pillHSpacing: CGFloat         = 5     // 分类行进度胶囊 HStack 间距
        static let pillHPad: CGFloat             = 7     // 分类行进度胶囊水平内边距（方案 A 黄金比例降重：从 9 调整为 7）
        static let pillVPad: CGFloat             = 2.5   // 分类行进度胶囊垂直内边距（方案 A 黄金比例降重：从 4 调整为 2.5）
        static let rowLabelToProgress: CGFloat   = Primitive.space10   // 分类行首行（标题+胶囊）→ 进度条间距（方案 B：从 6.5pt 舒展至 10pt，给予英文下沉字母 y/g/p 充足呼吸空间）
        static let categoryRowContentSpacing: CGFloat = Primitive.space10 // 分类图标与右侧内容列水平间距
        /// 词条行词 + 释义纵向间距（标准 4pt 网格：Primitive.space4 = 4.0pt，留足西文降部 p/y/g 与 11pt 中文顶线呼吸空间）
        static let wordEntrySpacing: CGFloat     = Primitive.space4
        /// 分类行进度条微轨 → 展开词列表首项间距（16.0pt，与词与词之间的 categoryWordListSpacing 同值，展开后节奏统一；
        /// 此前 10pt 是与上方 rowLabelToProgress 的镜像对称，现已有意拉开）
        static let categoryProgressToWords: CGFloat = Primitive.space16
        /// 展开词列表项与项之间的纵向净间距（16.0pt，等于跨大类间距 24pt 的 2/3 黄金律，紧实凝聚不散架）
        static let categoryWordListSpacing: CGFloat = Primitive.space16
        static let wordListLoadingVPad: CGFloat  = 14    // 词列表加载态垂直内边距
        static let inlineActionIconGlyph: CGFloat = 11   // 行内动作按钮图标字号（错误态 Try again ↻，与 inlineActionLabel 光学配对）

        // ── UsageLimit 每日额度弹窗控件度量（方案 2-C 与方案 1 精细规范）──────
        static let usageLimitProgressBarHeight: CGFloat = 3.0 // 方案 A 饱满通透连续微线轨高度（由 2.0pt 微调为 3.0pt，端点圆角 R1.5pt）
        static let usageLimitCTAHeight: CGFloat          = 44.0 // 细线描边胶囊按钮高度
        static let usageLimitCTABorderWidth: CGFloat     = 0.8  // 细线描边胶囊线宽
        static let usageLimitQuotaRowMinHeight: CGFloat  = 30.0 // 首行用量数字与副文最小行高槽（默认字号下保住 30pt 杜绝下沉跳动，大字号下允许随 Dynamic Type 向上自适应伸展）
        static let usageLimitSpinnerSlotSize: CGFloat    = 22.0 // 状态 07 加载菊花正方形容器槽尺寸（与 24pt 数字占位光学平衡）
        static let usageLimitSheetHeight: CGFloat            = 260.0 // 底部弹窗高度：在线未达标（状态 01 / 03 / 07）
        static let usageLimitSheetHeightReached: CGFloat     = 365.0 // 额度已达标（状态 02）
        static let usageLimitSheetHeightReachedOffline: CGFloat = 395.0 // 额度已达标 + 离线 / 刷新失败（状态 04）
        static let usageLimitSheetHeightLoadFailed: CGFloat  = 295.0 // 冷启动无数字 + 失败（状态 05-A / 05-B）
        static let usageLimitSectionNudge: CGFloat           = 2.0   // 进度轨 / 页脚注记各自上方的微小下推
        static let usageLimitCTAIconGlyph: CGFloat           = 14.0  // CTA 信封图标字号
        static let usageLimitNoteIconGlyph: CGFloat          = 12.0  // 离线注记图标、Try again ↻ 图标字号
        static let usageLimitEmptyIconGlyph: CGFloat         = 26.0  // 冷启动离线空态大图标字号
        static let usageLimitEmptyIconFrame: CGFloat         = 36.0  // 冷启动离线空态大图标容器边长
        static let usageLimitCTAShadowRadius: CGFloat        = 3.0   // CTA 接触微阴影半径
        static let usageLimitCTAShadowY: CGFloat             = 1.0   // CTA 接触微阴影下移
        static let usageLimitSpinnerOpticalOffset: CGFloat = 6.0 // 状态 07 加载菊花相对占位数字行中心的垂直偏移（实测使菊花中心落在 / 5 基线上方 2.8pt，与此前 -10pt 光学位置一致）

        // ── AppToast 双模自适应（component-private，仅 toast 使用）──────────
        static let toastFixedWidth: CGFloat = 328          // 普通字号固定卡宽（藏书票等宽条）
        static let toastAccessibilityVPad: CGFloat = 10   // AX 大字号档垂直内边距（行高变大，8→10 留呼吸）

        // ── Tab2 空状态 ──────────────────────────────────────────────────
        static let emptyStateCaptureIconGlyph: CGFloat      = 19  // 空态 CTA 描边相机图标

        // Tab2 加载失败插画（合页书本）的方形边长。
        // #44 原先借用 `brandMark`（语义=圆形 app-icon 报头容器直径），
        // 而报头已在 Settings 改造里删除、该 token 随之移除。按本文件既有约定
        // ——每个插画有自己按用途命名的尺寸 token（emptyStateIllustration* /
        // onboardingUploadIllustration* …）——改用与它的配色 token 同族的名字。
        static let feedbackIllustrationSize: CGFloat        = Primitive.size84

        // 空态便签插画（component-private，仅 EmptyStateIllustration 使用）。
        static let emptyStateIllustrationWidth: CGFloat     = 124  // 插画整体占位
        static let emptyStateIllustrationHeight: CGFloat    = 96
        static let emptyStateGlowWidth: CGFloat             = 120  // 背后柔光块
        static let emptyStateGlowHeight: CGFloat            = 100
        static let emptyStateGlowBlur: CGFloat              = 20
        static let emptyStateGlowOffset: CGFloat            = 10   // 柔光向右下偏移（x、y 同值）
        static let emptyStateGlowStopTint: CGFloat          = 0.0  // 柔光渐变三个色标的位置（0 = 左上起点，1 = 右下终点）
        static let emptyStateGlowStopBrand: CGFloat         = 0.45
        static let emptyStateGlowStopFade: CGFloat          = 0.9
        static let emptyStateNoteWidth: CGFloat             = 86   // 便签卡
        static let emptyStateNoteHeight: CGFloat            = 80
        static let emptyStateNoteHairline: CGFloat          = 0.8  // 便签卡描边线宽
        static let emptyStateNotePadding: CGFloat           = 14   // 便签卡内边距
        static let emptyStateNoteRowSpacing: CGFloat        = 10   // 卡内各行间距
        static let emptyStateFocusGap: CGFloat              = 8    // 首行圆点与首行线的间距
        static let emptyStateFocusDot: CGFloat              = 6    // 首行品牌圆点直径
        static let emptyStateFocusLineWidth: CGFloat        = 34   // 首行线
        static let emptyStateFocusLineHeight: CGFloat       = 2.2
        static let emptyStateMiddleLineWidth: CGFloat       = 52   // 中行文字痕迹
        static let emptyStateBottomLineWidth: CGFloat       = 40   // 底行文字痕迹
        static let emptyStateTraceLineHeight: CGFloat       = 1.8  // 中行 / 底行线粗
        static let emptyStateSubtitleMaxWidth: CGFloat      = 300  // EmptyStateView 副标最大宽度（保证两行断句）

        // ── Onboarding 顶部节奏（N-1）────────────────────────────────────
        // 标题位置与返回按钮位置各自单一真源，互不通过占位块耦合——
        // 旧实现靠「占位块高 36 + header 自带 padding 16」两个数字拼出标题位置，
        // 占位块本身又比返回按钮触区少 8pt，纯属巧合而非设计。
        static let onboardingBackInset: CGFloat             = 2   // 返回 chevron 触区距安全区上沿
        static let onboardingHeaderTop: CGFloat             = 48  // 页面标题（S2 / S3a / S3b）布局顶距安全区上沿。S1 报头不用此值，见下
        // S1 是品牌页：没有返回按钮，那条线上方的 44pt 触区是空的，报头贴在内页标题线上会显得被顶到天花板。
        // 刊头惯例是封面留白大于内页，故单开一档。代价：横滑 S1→S2 时报头与标题错开 16pt（已确认接受，
        // 验收「三页标题同高」不含 S1）。若真机觉得仍不够，下一档是 80，不要取中间值。
        /// 注意这是**布局**顶距：以 32pt 基准框定位，图形放大时保持基准框的可见左上角不动，
        /// 所以 36pt 图形的可见上沿实际在安全区下 ≈ 66.7pt（64 + 32 × 33.35/400）、可见左沿 ≈ 21pt，
        /// 与衬线标题的字形左沿（≈ 21pt）对齐。这是 OnboardingS1 实验室定稿的位置，不是偏差。
        static let onboardingS1MastheadTop: CGFloat         = 64
        /// S1 报头图形可见高（36pt，品牌规范下限 32pt 与原始 40pt 之间的黄金平衡，左轴对齐标题）。
        static let onboardingS1MastheadMarkHeight: CGFloat  = Primitive.size36
        /// 开屏动画里组合在屏幕中央停住时的图形可见高（实验室 48/56/64 三档对比，PM 未改默认）。组件私有。
        static let launchSplashSettledMarkHeight: CGFloat   = 56
        /// Tab2 页脚灰色字标的 P 字高（方案 5 定稿：由 12.5pt 收缩至 9.0pt，安静退后不抢内容）。
        static let tab2FooterWordmarkCapHeight: CGFloat     = 9.0
        /// Tab2 页脚灰色嫩芽 Logo 高度（方案 5 定稿：11.0pt 协调微缩）。
        static let tab2FooterSproutHeight: CGFloat          = 11.0
        /// S1 hero 文字组下缘 → Continue 上缘（方案 1 定稿：由 200pt 微调收缩 40pt 至 160pt，视觉重心稳健下沉至黄金分割线，天顶更显开阔从容）。
        static let onboardingHeroToCTA: CGFloat             = 160
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

    /// Tab2 Hero 卡的固定图像区度量（刀 6 重排：文字区由「理由胶囊 + 固定两行活动块 +
    /// CTA」撑开，不再需要最小高度兜底——活动块两行槽高天然恒定卡高）。
    enum Tab2Hero {
        enum Layout {
            static let artHeight: CGFloat = 150
            static let artTextOverlap: CGFloat = -14
            static let sceneDetailMaximumWidth: CGFloat = 175
            static let ctaHeight: CGFloat = 42
            static let ctaHorizontalInset: CGFloat = 22
            static let ctaContentGap: CGFloat = 8
            static let ctaCornerRadius: CGFloat = 21
            static let photoTopScrimHeight: CGFloat = 54
            static let wordRowHeight: CGFloat = 26
            static let wordRowGap: CGFloat = 9
            static let metaContentGap: CGFloat = 5
            // ── 刀 6 ──
            /// 图上标签行（§二①）左上角定位。2026-09-22 视觉回归 main 基线（§2.4）：
            /// chip/理由胶囊的托底胶囊（内边距/圆角/圆点）已删除，改为裸文字 + shadow，
            /// shadow 半径/Y 取自 main HeroTopOverlay。
            static let chipTopLeading: CGFloat = Primitive.space12
            static let photoOverlayShadowRadius: CGFloat = 6
            static let photoOverlayShadowY: CGFloat = 1
            /// 封面左上角：类别名与理由并排时的间距。
            static let coverLabelGap: CGFloat = Primitive.space8
            /// 一行放不下（大字号）改成上下两行时，两行之间的间距。组件私有，不在 4pt 刻度上。
            static let coverLabelStackGap: CGFloat = 2
            /// 文字区内边距（v12 .hbody 16/18/18）与纵向节奏（方案 B 10pt 呼吸统一：.seclab 下距 10、
            /// 胶囊组→脚行 16）。
            static let bodyTopInset: CGFloat = Primitive.space16
            static let bodyHorizontalInset: CGFloat = 18
            static let bodyBottomInset: CGFloat = 18
            static let sectionLabelToCapsules: CGFloat = Primitive.space10
            static let activityToCTA: CGFloat = Primitive.space16
            // ── 刀 6b 活动胶囊（方案 A 黄金比例降重：行高 23 / gap 6 / 边距 8/5）──
            // 行高 23 = 13.5px Charter 字 + 适度内边距；两行槽 52 = 23×2 + gap 6。
            // 固定两行高、只排得下一条也占两行（v12 溢出例④）。组件私有，不在 4pt 刻度上。
            static let activityCapsuleRowHeight: CGFloat = 23
            static let activityCapsuleRowGap: CGFloat = 6
            static let activityCapsuleHorizontalInset: CGFloat = 8
            static let activityCapsuleMoreHorizontalInset: CGFloat = 5
            /// 「Recent activities」区内小标题字距：v12 .seclab letter-spacing .09em
            /// × 11px = 0.99。组件私有。
            static let sectionLabelTracking: CGFloat = 0.99
        }

        enum Opacity {
            static let transparent: CGFloat = 0
            static let photoToneWarm: CGFloat = 0.20
            static let photoTonePaper: CGFloat = 0.45
            static let photoTopScrim: CGFloat = 0.30
            static let photoTextShadow: CGFloat = 0.50
        }

        enum ImageTreatment {
            static let photoSaturation: Double = 0.70
            static let bottomFadeOpaqueEnd: CGFloat = 0.58
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
            /// 刀 6b 重排后内容变为「帽行 + 固定两行胶囊组 + 词数行」。此值随实测校准：
            /// 方案 B 瘦身时自然内容 ≈ 116.7（旧下限 119，约 2.3pt 富余）；2026-10-06 间距改为
            /// 10/10（categoryToActivity、activityToWords）、分类名 12→13pt 后，自然内容 ≈ 120.33，
            /// 超过旧下限 1.33pt，下限失效、测试变红。现取整到 121（约 0.67pt 富余）。
            /// 以后再动这一行的字号或间距，要回来按 Tab2ActivityRowHeightTests 的实测重新校准。
            static let rowHeight: CGFloat = 121
            static let thumbnailWidth: CGFloat = Primitive.size76
            /// 主句区两行高度的下限（§5.2）：短句留白、长句省略号，不用「最多两行」。
            /// 实测取自两行 + sentenceLineSpacing 后的自然高度，理由同 rowHeight。
            static let sentenceSlotHeight: CGFloat = 43
            /// 分类行 → 主句的呼吸距离（三稿从 4 放宽到 7）。不在 4pt 间距刻度上，
            /// 组件私有（同 progressBarHeight 先例）。
            static let categoryToSentence: CGFloat = 7
            /// 帽行 → 胶囊组的距离（方案 B：统一 10pt 呼吸步进，消除粘连压迫感；卡片总高由 rowHeight 下限兜住）。
            static let categoryToActivity: CGFloat = Primitive.space10
            /// 胶囊组 → 词数行的距离（方案 B：统一 10pt 呼吸步进，与帽行→胶囊距离保持严谨镜像对齐）。
            static let activityToWords: CGFloat = Primitive.space10
            /// 纯查词行内「词—释义—·—词—释义」的均匀间距（= 释义紧跟词的左距 4）。
            static let wordGap: CGFloat = Primitive.space4
            static let arrowGlyph: CGFloat = 15
            /// 文字区内边距与右侧统一对齐基准（对齐 Space.paddingPage 16pt，与下方 Topics 展开胶囊保持同轴）。
            static let contentTopInset: CGFloat = Primitive.space12
            static let contentBottomInset: CGFloat = Primitive.space12
            static let contentLeadingInset: CGFloat = 14
            static let contentTrailingInset: CGFloat = Primitive.space10
            /// 帽行（类别名 + 时间标签）右侧边距：16pt，右对齐时间文本，与下方 Topics 展开胶囊同轴
            static let hatRowTrailingInset: CGFloat = Space.paddingPage
            /// 箭头右边距：16pt，与帽行时间文本及下方 Topics 展开胶囊右边缘严格同轴对齐
            static let arrowTrailingInset: CGFloat = Space.paddingPage
            // ── 刀 6b 活动胶囊（方案 A 黄金比例降重：行高 20 / gap 5 / 边距 7/4）──
            // 行高 20 = 12px Charter 字 + 紧致内边距；两行槽 45 = 20×2 + gap 5。
            // 固定两行高、只排得下一条也占两行。组件私有，不在 4pt 刻度上。
            static let activityCapsuleRowHeight: CGFloat = 20
            static let activityCapsuleRowGap: CGFloat = 5
            static let activityCapsuleHorizontalInset: CGFloat = 7
            static let activityCapsuleMoreHorizontalInset: CGFloat = 4
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

    /// Tab2「More topics to explore」：尚无词的主题以中性胶囊铺开（2026-10-03 定案，
    /// 沙盒 Tab2LockedProgressExplorationPreview）。胶囊是静态展示，不可点。
    enum Tab2ExploreTopics {
        enum Layout {
            /// 标题 → 胶囊组、胶囊组 → 注脚的距离（全 13pt 体系下提升为 16pt，与上方大模块留白呼吸节奏一致）。
            static let titleToTags: CGFloat = Primitive.space16
            static let tagsToFootnote: CGFloat = Primitive.space8
            /// 注脚图标 → 文字。
            static let footnoteIconToText: CGFloat = Primitive.space4
            /// 胶囊之间（同排）与两排之间的间距。
            static let tagGap: CGFloat = Primitive.space8
            /// 胶囊内：图标与文字间距 / 左右内边距 / 最小高度（全 13pt 匀质体系：高度 30pt、内边距 13pt、图标 13.5pt，与 Section 3 达成松紧度光学平衡）。组件私有。
            static let tagIconToLabel: CGFloat = 6
            static let tagHorizontalInset: CGFloat = 13
            static let tagMinHeight: CGFloat = 30
            static let tagIconGlyph: CGFloat = 13.5
            static let tagBorderWidth: CGFloat = 0.8
        }

        enum Color {
            static let tagFill = AppTheme.Color.cardBg
            static let tagBorder = AppTheme.Color.cardBorder.opacity(0.6)
            static let tagIcon = AppTheme.Color.textMuted
            static let tagLabel = AppTheme.Color.textSecondary
            static let footnote = AppTheme.Color.textMuted
            static let tagShadow = Primitive.mediaSurface.opacity(0.015)
        }

        enum Shadow {
            static let tagRadius: CGFloat = 3
            static let tagY: CGFloat = 1
        }
    }

    enum Motion {
        // 顶部 Tab 选中滑块：Notion 风格高阻尼质感弹簧（沉稳、有质量感，不弹跳）
        static let tabSelection: Animation = .spring(response: 0.35, dampingFraction: 0.85)
        // 时间线被动对齐跟随（刷新带回新内容、用户已在底部时的小幅跟随）：
        // 短促 easeOut——跟上新内容但不拖沓，也不抢走阅读注意力
        static let timelinePassiveFollow: Animation = .easeOut(duration: 0.15)
        // 时间线主动动作跟随（发消息、卡片生成完成、重试锚定）：
        // 平滑阻尼弹簧，无多余晃动
        static let timelineActiveFollow: Animation = .spring(response: 0.38, dampingFraction: 0.82)
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
        /// 引导完成 → 首页的交叉淡入淡出（替代硬切）。2026-10-04 PM 试看：0.25s 不够明显，
        /// 改 0.4s。纯透明度过渡，减弱动态下同样适用。
        static let onboardingExitFade: Animation = .easeInOut(duration: 0.4)
        // 光晕自身在 0.86s 完成淡出，额外保留 90ms 后再移出视图树。
        static let radiantAscentLifetime: Duration = .milliseconds(950)

        // 词条骨架屏悠扬晨曦流光：2.2s 灵动舒缓往复，温润从容
        static let shimmerSkeletonCycle: Animation = .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
        static let categoryWordsReveal: Animation = .easeInOut(duration: 0.32)
        static let categoryWordsFailure: Animation = .easeInOut(duration: 0.24)

        // Topics 手风琴展开与收起动效：0.36s 弹韧轻阻尼弹簧，舒展从容
        static let accordionToggle: Animation = .spring(response: 0.36, dampingFraction: 0.82)
        static let accordionReducedToggle: Animation = .easeInOut(duration: 0.25)

        // 普通 toast 悬停 3s（微圆角藏书票便签）；里程碑短句 2.2s。
        static let toastLifetime: Duration = .seconds(3)
        static let onboardingPhotoToastLifetime: Duration = .seconds(3)
        static let milestoneToastLifetime: Duration = .milliseconds(2200)

        /// 开屏动画（2026-10-07 定稿生长版；2026-10-08 PM 改：首次打开不再飞入 S1 报头，改为原地淡出、
        /// 把视线交给 S1 中间的标题；日常打开改为静态组合）。单位秒，均从开屏第 0 帧起算。
        /// 实现：Components/LaunchSplashView.swift（自带 Canvas 预览）。
        enum Launch {
            // 首次打开
            static let stemStart  = 0.05, stemDuration  = 0.35   // 主干与大拱从底部长出
            static let leafStart  = 0.25, leafDuration  = 0.25   // 左侧嫩叶从根部展开
            static let budStart   = 0.40, budDuration   = 0.22   // 芽心最后点出
            static let shiftStart = 0.55, shiftDuration = 0.40   // 嫩芽左移让出字标位置
            static let wipeStart  = 0.58, wipeDuration  = 0.40   // 字标从左往右擦出
            /// 居中组合停稳的时刻。后台身份确认没出结果时就停在这一帧等。
            static let holdPoint  = 1.10
            /// 收尾（新用户与重装老用户相同）：组合原地上移淡出，暖纸底随后淡出。
            static let exitDuration = 0.30
            static let exitRise: CGFloat = 10
            static let backgroundFadeDuration = 0.35
            /// 收尾开始后多久让 S1 入场：先让视线留在中间的组合上，标题再在同一区域接上。
            static let screen1Lead = 0.08

            // 日常打开（1.2s 柔和，2026-10-08 PM 定）：全部慢进慢出，不长、不擦
            // 进场：嫩芽先浮现、字标晚 0.08s 跟上，同时从 97% 放大到 100%
            static let dailySproutInStart = 0.0, dailyWordInStart = 0.08, dailyInDuration = 0.35
            static let dailyEntryScale: CGFloat = 0.97
            /// 全程再缓慢放大 4%（线性），停留时隐约能感到在往前推，画面不「死」。
            static let dailyDrift: CGFloat = 0.04
            // 退场分两层：组合先淡出并上浮 6pt；暖纸底晚 0.08s 起、用更长时间退；
            // 主界面同时从 98% 放大到位，像「浮上来」接住视线
            static let dailyLockupOutStart = 0.80, dailyLockupOutDuration = 0.30
            static let dailyExitRise: CGFloat = 6
            static let dailyBackgroundOutStart = 0.88, dailyBackgroundOutDuration = 0.32
            static let dailyContentFromScale: CGFloat = 0.98
            static var dailyTotal: Double { dailyBackgroundOutStart + dailyBackgroundOutDuration }   // 1.20
            static let dailyContentSettle: Animation = .easeInOut(duration: dailyBackgroundOutDuration)

            // 减弱动态效果：不长、不移，暖纸底直接淡出
            static let reducedHoldPoint = 0.10
            static let reducedFadeDuration = 0.35
            static let reducedDailyFadeDuration = 0.20
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
