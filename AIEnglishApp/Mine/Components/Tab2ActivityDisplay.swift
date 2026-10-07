import SwiftUI
import UIKit
import CoreText

/// 刀 4b 引入、刀 6 文字流、刀 6b 胶囊化：Hero 卡与 More 行共用的「活动清单展示口径」。
///
/// 「哪些有效 / 挡掉几条 / 照片取哪张」与宽度无关，收在 `compute` 一次算好；
/// 「显示几条 / 分到哪一行 / +N 是多少」随可用宽度浮动（v12 胶囊让位规则），
/// 由 `Tab2ActivityCapsuleGroup` 在拿到宽度后做胶囊拟合——两处不再各算一遍，
/// 胶囊数不会漂移。
///
/// - **valid**：通过四条校验（`Tab2SceneDetailValidation`）的活动，后端原序、不重排
/// - **blockedCount** = fetched − valid（被校验挡掉的条数）
/// - **photoCover**：第一条有效活动的封面——被挡的活动「整条不渲染」= 不参与取图；
///   imageUrl 为空串视同无图。nil → 类别预设图
/// - **showsActivities**：有可显示的活动才渲染「Recent activities」区块——
///   activityCount = 0 时 valid 必为空，整块（小标题 + 胶囊组）随之消失（刀 6b）。
///   全部候选被挡（activityCount > 0 但 valid 空）同判：无事可显示，区块不渲染。
/// - 显示条数与 +N 由 `Tab2CapsuleFit.fit` 按宽度算：collapsed =
///   activity_count − displayed − blocked（基数是 activity_count 不是 fetched 条数：
///   后端给 5 条是余量，没取回的那部分也必须算进 +N；被挡掉的不计入）
struct Tab2ActivityDisplay {
    struct ValidActivity: Equatable {
        let name: String          // trim 后的活动名
        let occurrenceCount: Int
        let cover: Tab2Activity.Cover?
    }

    let valid: [ValidActivity]
    let blockedCount: Int
    let photoCover: Tab2Activity.Cover?

    var showsActivities: Bool { !valid.isEmpty }

    static func compute(category: Tab2CategoryData) -> Tab2ActivityDisplay {
        let valid: [ValidActivity] = category.activities.compactMap { activity in
            guard let name = Tab2SceneDetailValidation.validatedTargetSceneDetail(activity.sceneDetail) else {
                return nil
            }
            return ValidActivity(
                name: name,
                occurrenceCount: activity.occurrenceCount,
                cover: activity.cover
            )
        }
        let blocked = category.activities.count - valid.count
        let photoCover = valid.first?.cover.flatMap { ($0.imageUrl?.isEmpty ?? true) ? nil : $0 }
        return Tab2ActivityDisplay(
            valid: valid,
            blockedCount: blocked,
            photoCover: photoCover
        )
    }
}

// MARK: - 胶囊度量（刀 6b v12）
/// 胶囊几何的全部来源：名字 / +N 的字号（含 Dynamic Type 缩放后的 UIFont，用
/// UIFontMetrics 复刻 AppTheme.Font 同名 token 的 relativeTo 缩放）、行高、行距、
/// 水平内边距。两行槽高 = (行高 × 2 + 行距)——默认档取方案 B 值
/// （Hero 23×2+6=52 / More 20×2+5=45）；字号放大时行高随字形线高增量同步放大，
/// 保证大字号不裁字、同行高度依旧一致。
///
/// 胶囊宽度 = 名字单行测量宽 + 2×水平内边距。测量（CoreText CTLine）与渲染
/// （SwiftUI Text）共用同一 UIFont 与字符串——测出来的宽度就是渲染出来的宽度，
/// 两个实现不会漂移。
/// Equatable：UIFont 按内容（name/size 等）判等而非指针，`.hero()`/`.more()` 每次
/// 调用重新构造的实例可以正确比出"内容没变"——给 Tab2ActivityCapsuleGroup 的
/// .equatable() 用。
struct Tab2ActivityCapsuleMetrics: Equatable {
    let nameBaseUIFont: UIFont          // 默认档（未缩放）名字字体，行高增量的基准
    let nameUIFont: UIFont              // Dynamic Type 缩放后的名字字体（测量 + 行高）
    let moreUIFont: UIFont              // Dynamic Type 缩放后的 +N 字体（测量）
    let baseRowHeight: CGFloat          // 默认档行高（Hero 23 / More 20）
    let rowGap: CGFloat                 // 行距（Hero 6 / More 5）
    let namePaddingH: CGFloat           // 名字胶囊水平内边距（Hero 8 / More 7）
    let morePaddingH: CGFloat           // +N 水平内边距（Hero 5 / More 4）

    /// 当前字号档下的行高：默认档 = 方案 B 瘦身值；AX 放大档 = 基值 + 字形线高增量
    /// （只加缩放增量，不加绝对线高——CSS line-height:1 的 15+16=31 在 iOS 上
    /// 要用固定帧高复刻，Charter 15pt 固有行高 18.36 不能参与）。
    var rowHeight: CGFloat {
        let delta = max(0, nameUIFont.lineHeight - nameBaseUIFont.lineHeight)
        return baseRowHeight + delta
    }

    /// 固定两行槽高——只排得下一条也占两行，保证卡高恒定（v12 溢出例④）。
    var twoRowHeight: CGFloat { rowHeight * 2 + rowGap }

    // 与 AppTheme.Font 同名 token 共用的 PostScript 名。基准字号也取自 Font 层常量，
    // relativeTo 档位与 token 定义一致，改动时两侧必须同步（测试会抓渲染高度漂移）。
    /// 当前字号特征，已按 App 的字号封顶压住（封顶没生效——例如单元测试——时与改前完全一致）。
    /// 直接用 UIFontMetrics 算尺寸的代码读不到 SwiftUI / 窗口层面的封顶，所以这里要自己压一下，
    /// 否则胶囊的行高会按系统的无障碍字号算，而里面的文字已被封在「超大」。
    /// SwiftUI 求值 body 时 UITraitCollection.current 的字号档位常是「未指定」（实测），
    /// 这时 UIFontMetrics 会回落到系统字号；所以未指定时要改读屏幕的系统字号再压。
    private static func cappedTraits() -> UITraitCollection {
        let current = UITraitCollection.current
        guard AppDynamicTypeLimit.activeCategory != nil else { return current }
        let base = current.preferredContentSizeCategory == .unspecified
            ? UIScreen.main.traitCollection.preferredContentSizeCategory
            : current.preferredContentSizeCategory
        return UITraitCollection(preferredContentSizeCategory: AppDynamicTypeLimit.clamped(base))
    }

    private static func charter(baseSize: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: UIFont(name: "Charter", size: baseSize)!, compatibleWith: cappedTraits())
    }

    private static func charterUnscaled(baseSize: CGFloat) -> UIFont {
        UIFont(name: "Charter", size: baseSize)!
    }

    private static func sansRegular(baseSize: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: UIFont(name: AppTheme.Font.SansWeight.regular.postScriptName, size: baseSize)!, compatibleWith: cappedTraits())
    }

    /// Hero 胶囊组（方案 A）：13.5px / 行 23 / 距 6 / 内边距 名字 8、+N 5。
    static func hero() -> Tab2ActivityCapsuleMetrics {
        Tab2ActivityCapsuleMetrics(
            nameBaseUIFont: charterUnscaled(baseSize: AppTheme.Font.tab2HeroCapsuleNameBaseSize),
            nameUIFont: charter(baseSize: AppTheme.Font.tab2HeroCapsuleNameBaseSize, textStyle: .subheadline),
            moreUIFont: sansRegular(baseSize: AppTheme.Font.tab2HeroCapsuleMoreBaseSize, textStyle: .footnote),
            baseRowHeight: AppTheme.Tab2Hero.Layout.activityCapsuleRowHeight,
            rowGap: AppTheme.Tab2Hero.Layout.activityCapsuleRowGap,
            namePaddingH: AppTheme.Tab2Hero.Layout.activityCapsuleHorizontalInset,
            morePaddingH: AppTheme.Tab2Hero.Layout.activityCapsuleMoreHorizontalInset
        )
    }

    /// More 胶囊组（方案 A）：12px / 行 20 / 距 5 / 内边距 名字 7、+N 4。
    static func more() -> Tab2ActivityCapsuleMetrics {
        Tab2ActivityCapsuleMetrics(
            nameBaseUIFont: charterUnscaled(baseSize: AppTheme.Font.tab2MoreRowCapsuleNameBaseSize),
            nameUIFont: charter(baseSize: AppTheme.Font.tab2MoreRowCapsuleNameBaseSize, textStyle: .footnote),
            moreUIFont: sansRegular(baseSize: AppTheme.Font.tab2MoreRowCapsuleMoreBaseSize, textStyle: .caption2),
            baseRowHeight: AppTheme.Tab2MoreRow.Layout.activityCapsuleRowHeight,
            rowGap: AppTheme.Tab2MoreRow.Layout.activityCapsuleRowGap,
            namePaddingH: AppTheme.Tab2MoreRow.Layout.activityCapsuleHorizontalInset,
            morePaddingH: AppTheme.Tab2MoreRow.Layout.activityCapsuleMoreHorizontalInset
        )
    }

    /// 测试用：直接给定 UIFont（默认字号档下与 hero()/more() 等价，但不需要
    /// UIFontMetrics 的环境缩放，输入更确定）。
    init(nameBaseUIFont: UIFont, nameUIFont: UIFont, moreUIFont: UIFont,
         baseRowHeight: CGFloat, rowGap: CGFloat, namePaddingH: CGFloat,
         morePaddingH: CGFloat) {
        self.nameBaseUIFont = nameBaseUIFont
        self.nameUIFont = nameUIFont
        self.moreUIFont = moreUIFont
        self.baseRowHeight = baseRowHeight
        self.rowGap = rowGap
        self.namePaddingH = namePaddingH
        self.morePaddingH = morePaddingH
    }

    /// 单行文字宽（CoreText CTLine 实测，向上取整防亚像素下溢）。
    private static func singleLineWidth(_ string: String, font: UIFont) -> CGFloat {
        let attr = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        return ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
    }

    /// 一个名字胶囊的整宽 = 名字宽 + 2×水平内边距。
    func nameCapsuleWidth(_ name: String) -> CGFloat {
        Self.singleLineWidth(name, font: nameUIFont) + namePaddingH * 2
    }

    /// +N more 胶囊的整宽（字符串与渲染侧逐字一致：前导空格 + "\(n) more"）。
    func moreCapsuleWidth(_ count: Int) -> CGFloat {
        Self.singleLineWidth(" +\(count) more", font: moreUIFont) + morePaddingH * 2
    }
}

// MARK: - 胶囊拟合（刀 6b v12 让位规则）
/// 让位规则：两行装不下时减少显示的胶囊数，绝不截断活动名（省略号禁止）、
/// 绝不截断 +N more；少显示一条，N 自动加一，总数永远对得上。不设条数上限
/// （后端上限 5），两行排得下几条就显示几条。
///
/// +N more 是**流里的第 displayed+1 个元素**（与 v12 的 JS 生成、flex-wrap 排布
/// 逐元素等价）：首行还放得下就落首行尾（溢出例②），首行满则独占第二行开头
/// （溢出例③：3 颗满首行 → "+9 more" 在第二行），第二行尾同理。more 自身放不
/// 下时同样让位（少显示一条活动）。任何名字宽于整行 → 该名字与后续全部弃置
/// （不截断），只剩 +N more 独占首行——显示 0 条也是合法输出，规则闭合。
struct Tab2CapsuleFit: Equatable {
    let displayed: Int                  // 实际渲染的名字胶囊数（≥0）
    let collapsed: Int                  // +N 的 N（0 = 不渲染 +N）
    let row1: [String]                  // 第一行名字（渲染序）
    let row2: [String]                  // 第二行名字（可为空——只排一条也占两行高）
    let moreInRow1: Int?                // +N more 落第一行时的 N（行尾）
    let moreInRow2: Int?                // +N more 落第二行时的 N（该行名字之后；空行即行首）

    var showsMore: Bool { collapsed > 0 }

    static func fit(
        valid: [Tab2ActivityDisplay.ValidActivity],
        activityCount: Int,
        blockedCount: Int,
        width: CGFloat,
        metrics: Tab2ActivityCapsuleMetrics
    ) -> Tab2CapsuleFit {
        let capped = min(valid.count, 5)
        // 从最多到 1 条逐一尝试：名字 + more 作为一条流完整放进两行，即接受。
        for displayed in stride(from: capped, through: 1, by: -1) {
            let collapsed = max(0, activityCount - displayed - blockedCount)
            var items: [Item] = valid.prefix(displayed).map { .name($0.name) }
            if collapsed > 0 { items.append(.more(collapsed)) }
            if let placement = pack(items, width: width, metrics: metrics) {
                return Tab2CapsuleFit(
                    displayed: displayed,
                    collapsed: collapsed,
                    row1: placement.names1,
                    row2: placement.names2,
                    moreInRow1: placement.more1,
                    moreInRow2: placement.more2
                )
            }
        }
        // 防御兜底：连一条名字都放不进一行（名字比容器还宽）——按让位规则整条
        // 弃置（不截断），只剩 +N more。实际场景短语不可能达到此宽度，但规则
        // 必须闭合：显示 0 条也是合法输出。
        let collapsed = max(0, activityCount - blockedCount)
        if collapsed > 0, let placement = pack([.more(collapsed)], width: width, metrics: metrics) {
            return Tab2CapsuleFit(displayed: 0, collapsed: collapsed,
                                  row1: [], row2: [],
                                  moreInRow1: placement.more1, moreInRow2: placement.more2)
        }
        return Tab2CapsuleFit(displayed: 0, collapsed: collapsed,
                              row1: [], row2: [], moreInRow1: nil, moreInRow2: nil)
    }

    // fileprivate 而非 private：本文件底部的 Tab2ActivityCapsuleMetrics 扩展
    // 要按 Item 求宽（private 的嵌套类型跨类型扩展不可见）。
    fileprivate enum Item {
        case name(String)
        case more(Int)
    }

    private struct Placement {
        var names1: [String] = []
        var names2: [String] = []
        var more1: Int? = nil
        var more2: Int? = nil
        var width1: CGFloat = 0
        var width2: CGFloat = 0
        var row1Closed = false

        mutating func place(_ item: Item, width: CGFloat, metrics: Tab2ActivityCapsuleMetrics) -> Bool {
            let w = metrics.itemWidth(item)
            if !row1Closed, width1 + (width1 > 0 ? metrics.rowGap : 0) + w <= width {
                switch item {
                case .name(let n): names1.append(n)
                case .more(let c): more1 = c
                }
                width1 += (width1 > 0 ? metrics.rowGap : 0) + w
                return true
            }
            // 第一个放不进第一行的元素**关闭第一行**（flex-wrap 语义：一行断了
            // 就断了，后续元素一律从第二行开始）。没有这步，流末尾的 +N more
            // 会在前面元素被挤到第二行后回填第一行尾的空隙，视觉上插到后续
            // 名字之前——v12 验收例②实测暴露（+3 more 跑到了 Getting up 前面）。
            row1Closed = true
            if width2 + (width2 > 0 ? metrics.rowGap : 0) + w <= width {
                switch item {
                case .name(let n): names2.append(n)
                case .more(let c): more2 = c
                }
                width2 += (width2 > 0 ? metrics.rowGap : 0) + w
                return true
            }
            return false
        }
    }

    /// 贪心两行排布：逐元素放入，第一行放不下进第二行，两行都放不下即失败。
    /// 首元素（名字或 more）宽于整行 → 返回 nil，由上层让位循环继续。
    private static func pack(
        _ items: [Item],
        width: CGFloat,
        metrics: Tab2ActivityCapsuleMetrics
    ) -> Placement? {
        var placement = Placement()
        for item in items {
            if !placement.place(item, width: width, metrics: metrics) {
                return nil
            }
        }
        return placement
    }
}

private extension Tab2ActivityCapsuleMetrics {
    /// fit 流元素宽度：名字胶囊整宽 / +N more 胶囊整宽。
    func itemWidth(_ item: Tab2CapsuleFit.Item) -> CGFloat {
        switch item {
        case .name(let name): return nameCapsuleWidth(name)
        case .more(let count): return moreCapsuleWidth(count)
        }
    }
}

// MARK: - 胶囊组视图（Hero 与 More 共用）
/// 固定两行槽高的胶囊组：在拿到宽度后动态拟合条数（刀 6b v12）。字体（SwiftUI token
/// 层）与度量随 surface 传入；颜色两 surface 相同（胶囊 tab2ActivityChipBg 底 /
/// tab2ActivityChipText 字，+N 无底 textMuted）。valid 为空时不渲染（Hero 由 `showsActivities` 连小标题
/// 一起整块移除，More 由外层判断）。
///
/// Equatable + 调用点 .equatable()：Tab2CapsuleFit.fit 在 GeometryReader 里跑
/// CoreText 文本测量，本身不贵，但 body 会随任何祖先重渲染（滚动/toast/下拉刷新
/// 等与本组件无关的状态变化）无条件重跑。所有入参已是内容判等（Font/UIFont
/// 按值不按指针），.equatable() 让 SwiftUI 在这些入参真的没变时直接跳过 body。
struct Tab2ActivityCapsuleGroup: View, Equatable {
    let activities: [Tab2ActivityDisplay.ValidActivity]
    let activityCount: Int
    let blockedCount: Int
    let metrics: Tab2ActivityCapsuleMetrics
    let nameFont: Font
    let moreFont: Font

    var body: some View {
        if !activities.isEmpty {
            GeometryReader { geo in
                let fit = Tab2CapsuleFit.fit(
                    valid: activities,
                    activityCount: activityCount,
                    blockedCount: blockedCount,
                    width: geo.size.width,
                    metrics: metrics
                )
                VStack(alignment: .leading, spacing: metrics.rowGap) {
                    capsuleRow(fit.row1, moreCount: fit.moreInRow1)
                    // 第二行三种渲染情形：有名字（more 可随之落行尾）、
                    // 无名字但有 more（溢出例③：more 独占第二行行首）、
                    // 两者皆无（只排一条活动，第二行留空保槽高）。
                    if !fit.row2.isEmpty || fit.moreInRow2 != nil {
                        capsuleRow(fit.row2, moreCount: fit.moreInRow2)
                    }
                }
                .frame(width: geo.size.width, height: metrics.twoRowHeight, alignment: .topLeading)
            }
            .frame(height: metrics.twoRowHeight)
        }
    }

    private func capsuleRow(_ names: [String], moreCount: Int?) -> some View {
        HStack(spacing: metrics.rowGap) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                nameCapsule(name)
            }
            if let moreCount {
                // 字符串与 Tab2ActivityCapsuleMetrics.moreCapsuleWidth 测量侧逐字一致
                // （前导空格 + "\(n) more"）——测量与渲染同源，不会漂移。
                moreCapsule(" +\(moreCount) more")
            }
        }
        .frame(height: metrics.rowHeight)
    }

    private func nameCapsule(_ name: String) -> some View {
        Text(name)
            .font(nameFont)
            .foregroundStyle(AppTheme.Color.tab2ActivityChipText)
            .lineLimit(1)
            .padding(.horizontal, metrics.namePaddingH)
            .frame(height: metrics.rowHeight)
            .background(
                Capsule()
                    .fill(AppTheme.Color.tab2ActivityChipBg)
            )
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.Color.tab2ActivityChipBorder, lineWidth: 0.5)
            )
    }

    private func moreCapsule(_ text: String) -> some View {
        Text(text)
            .font(moreFont)
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
            .padding(.horizontal, metrics.morePaddingH)
            .frame(height: metrics.rowHeight)
    }
}

// MARK: - 空态说明行与槽位（Hero 与 More 共用）

/// 无 activity 时的一行说明（同一个状态在两处说同一句话、同一档样式）。
/// 13px 无衬线 muted（AppTheme.Font.tab2EmptyStateLine），文案来自 `Tab2CardLabels.onlyWordsSoFar`。
struct Tab2OnlyWordsLine: View {
    var body: some View {
        Text(Tab2CardLabels.onlyWordsSoFar)
            .font(AppTheme.Font.tab2EmptyStateLine)
            .foregroundStyle(AppTheme.Color.textMuted)
            .lineLimit(1)
    }
}

/// 无 activity 时的两行空态槽位（严格保持与两行胶囊完全一致的槽高与留白呼吸感，消除列表高度锯齿）：
/// - 第一行：放置 `Tab2OnlyWordsLine`，高度对齐当前 metrics 下的单行高（metrics.rowHeight）
/// - 第二行：留出等高空白，与两行活动胶囊保持一致的纵向节奏
/// - 总槽高：锁定为 `metrics.twoRowHeight`（默认档 Hero 52pt / More 45pt；Dynamic Type 放大档随字体增量安全放行）
struct Tab2OnlyWordsSlot: View {
    let metrics: Tab2ActivityCapsuleMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            HStack {
                Tab2OnlyWordsLine()
                Spacer(minLength: 0)
            }
            .frame(height: metrics.rowHeight)

            Color.clear
                .frame(height: metrics.rowHeight)
        }
        .frame(height: metrics.twoRowHeight)
    }
}

