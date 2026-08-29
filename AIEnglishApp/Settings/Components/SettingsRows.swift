import SwiftUI

// MARK: - Settings row artwork (matches visual spec §04)

/// 视觉规范中的图标是定制 24×24 描边路径，不以近似 SF Symbol 替代。
enum SettingsRowIcon {
    /// 目标语言 —— 地球。**刻意不用「A」「文」或国旗**：CLAUDE.md 要求
    /// target/native 不得硬编码，图形里一旦出现具体语言的字母或旗帜，
    /// 将来换语言这个图标就在撒谎。地球是语言的通用符号，且语言中立。
    case targetLanguage
    /// 母语 —— 人。与地球成对：世界 ↔ 我。
    /// 不用气泡：气泡已被 feedback 占用，同页出现两次会误导。
    case nativeLanguage
    case aiData
    case privacy
    case terms
    case feedback
    case delete
    case reset
}

/// 图标仅作按钮标签的装饰，按钮文字本身承载 VoiceOver 名称。
struct SettingsRowIconView: View {
    let icon: SettingsRowIcon
    let tint: Color

    /// 图标随 Dynamic Type 一起放大。固定 20pt 时，最大无障碍字号下文字放大约 3 倍、
    /// 图标纹丝不动，结果是一个小点飘在三行大字旁边——真机渲染实测到的问题。
    /// 图标列宽同步放大，否则图形会溢出自己的栏位、把文字挤歪。
    @ScaledMetric(relativeTo: .body) private var glyph = AppTheme.Size.settingsRowIconGlyph
    @ScaledMetric(relativeTo: .body) private var column = AppTheme.Size.rowIcon

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)
            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.settingsIconStroke,
                    lineCap: icon == .delete ? .round : .butt,
                    lineJoin: .round
                )
            )
        }
        .frame(width: glyph, height: glyph)
        .frame(width: column)
        .accessibilityHidden(true)
    }

    private var path: Path {
        var path = Path()

        switch icon {
        case .targetLanguage:
            // 外圆 r=8.5 + 赤道横线 + 中央经线椭圆（rx=4, ry=8.5）
            path.addEllipse(in: CGRect(x: 3.5, y: 3.5, width: 17, height: 17))
            path.move(to: CGPoint(x: 3.5, y: 12))
            path.addLine(to: CGPoint(x: 20.5, y: 12))
            path.addEllipse(in: CGRect(x: 8, y: 3.5, width: 8, height: 17))

        case .nativeLanguage:
            // 头 r=3.6 + 肩线
            path.addEllipse(in: CGRect(x: 8.4, y: 4.9, width: 7.2, height: 7.2))
            path.move(to: CGPoint(x: 5, y: 20))
            path.addCurve(
                to: CGPoint(x: 12, y: 14),
                control1: CGPoint(x: 5, y: 16.4),
                control2: CGPoint(x: 8.1, y: 14)
            )
            path.addCurve(
                to: CGPoint(x: 19, y: 20),
                control1: CGPoint(x: 15.9, y: 14),
                control2: CGPoint(x: 19, y: 16.4)
            )

        case .aiData:
            path.move(to: CGPoint(x: 12, y: 3))
            path.addLine(to: CGPoint(x: 13.9, y: 8.1))
            path.addLine(to: CGPoint(x: 19, y: 10))
            path.addLine(to: CGPoint(x: 13.9, y: 11.9))
            path.addLine(to: CGPoint(x: 12, y: 17))
            path.addLine(to: CGPoint(x: 10.1, y: 11.9))
            path.addLine(to: CGPoint(x: 5, y: 10))
            path.addLine(to: CGPoint(x: 10.1, y: 8.1))
            path.closeSubpath()

        case .privacy:
            path.addRoundedRect(
                in: CGRect(x: 5, y: 10, width: 14, height: 10),
                cornerSize: CGSize(width: 2.4, height: 2.4)
            )
            path.move(to: CGPoint(x: 8.2, y: 10))
            path.addLine(to: CGPoint(x: 8.2, y: 7.2))
            path.addCurve(
                to: CGPoint(x: 15.8, y: 7.2),
                control1: CGPoint(x: 8.2, y: 5.1),
                control2: CGPoint(x: 9.9, y: 3.4)
            )
            path.addLine(to: CGPoint(x: 15.8, y: 10))

        case .terms:
            path.move(to: CGPoint(x: 6, y: 3.5))
            path.addLine(to: CGPoint(x: 13.5, y: 3.5))
            path.addLine(to: CGPoint(x: 18, y: 8))
            path.addLine(to: CGPoint(x: 18, y: 20.5))
            path.addLine(to: CGPoint(x: 6, y: 20.5))
            path.closeSubpath()
            path.move(to: CGPoint(x: 13.5, y: 3.5))
            path.addLine(to: CGPoint(x: 13.5, y: 8))
            path.addLine(to: CGPoint(x: 18, y: 8))
            path.move(to: CGPoint(x: 9, y: 13))
            path.addLine(to: CGPoint(x: 15, y: 13))
            path.move(to: CGPoint(x: 9, y: 16.5))
            path.addLine(to: CGPoint(x: 15, y: 16.5))

        case .feedback:
            path.move(to: CGPoint(x: 3.5, y: 6.5))
            path.addLine(to: CGPoint(x: 20.5, y: 6.5))
            path.addLine(to: CGPoint(x: 20.5, y: 17.5))
            path.addLine(to: CGPoint(x: 9.5, y: 17.5))
            path.addLine(to: CGPoint(x: 3.5, y: 21))
            path.closeSubpath()

        case .delete:
            path.move(to: CGPoint(x: 4.5, y: 7))
            path.addLine(to: CGPoint(x: 19.5, y: 7))
            path.move(to: CGPoint(x: 9.5, y: 7))
            path.addLine(to: CGPoint(x: 9.5, y: 4.2))
            path.addLine(to: CGPoint(x: 14.5, y: 4.2))
            path.addLine(to: CGPoint(x: 14.5, y: 7))
            path.move(to: CGPoint(x: 6.8, y: 7))
            path.addLine(to: CGPoint(x: 7.8, y: 20.8))
            path.addLine(to: CGPoint(x: 16.2, y: 20.8))
            path.addLine(to: CGPoint(x: 17.2, y: 7))

        case .reset:
            path.move(to: CGPoint(x: 7, y: 8))
            path.addLine(to: CGPoint(x: 7, y: 4))
            path.addLine(to: CGPoint(x: 3, y: 8))
            path.addLine(to: CGPoint(x: 7, y: 12))
            path.move(to: CGPoint(x: 7, y: 8))
            path.addCurve(
                to: CGPoint(x: 20, y: 12),
                control1: CGPoint(x: 14, y: 3),
                control2: CGPoint(x: 20, y: 6)
            )
            path.addCurve(
                to: CGPoint(x: 12, y: 21),
                control1: CGPoint(x: 20, y: 17),
                control2: CGPoint(x: 16, y: 21)
            )
        }

        return path
    }
}

/// 行尾指示箭头。
/// 颜色走 `textMuted` 而不是 `border`：chevron 是**功能性指示器**（告诉用户这行能进二级页），
/// 而 border 的语义是发丝线/分割。此前两者同色，箭头几乎与分割线一样淡。
private struct SettingsChevron: View {
    /// 与行首图标同样跟随 Dynamic Type 放大。
    /// 行首图标已改 @ScaledMetric（见 SettingsRowIconView），若这里仍是死数，
    /// 最大无障碍字号下同一行的左端图标放大约 3 倍、右端箭头纹丝不动——
    /// 正是当初要修的那个毛病换到了另一头。
    @ScaledMetric(relativeTo: .body) private var glyph = AppTheme.Size.settingsChevronGlyph

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)

            var path = Path()
            path.move(to: CGPoint(x: 9, y: 5))
            path.addLine(to: CGPoint(x: 16, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 19))

            context.stroke(
                path,
                with: .color(AppTheme.Color.textMuted),
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.settingsChevronStroke,
                    lineCap: .round
                )
            )
        }
        .frame(width: glyph, height: glyph)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// 分区：衬线小标题在卡外 + 暖纸内容卡。
///
/// 标题走 **subheadline 衬线 medium + 次要墨色**，明确退到辅助层。
/// 此前用 title3 semibold，仍会比它所归类的单行内容更显眼；保留衬线编辑感，
/// 只降低字号与字重后，
/// 「页面标题 → 分组标题 → 行内容」三级一眼分得开，衬线的杂志感也保住了。
///
struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            if let title {
                Text(title)
                    .font(AppTheme.Font.settingsSectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    // 让 VoiceOver 的「按标题跳转」能用：不加 header 语义时，
                    // 这行会被当成一段普通文字，读屏用户只能一行行往下听。
                    // h2 是相对页面大标题（h1，见 settingsPageTitleSemantics）而言的，
                    // 让转子里读出「Settings 之下有 My language / Legal」这层从属。
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h2)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            VStack(spacing: 0) {
                content()
            }
            // 显式传 large(20)，不吃 surfaceCard 的默认 glassContainer(28)：
            // 28 是「浮动玻璃容器」的语义（顶栏、输入胶囊），被内容卡借用后，
            // 与 Feedback 的输入框（原 16）对不上。20 是既有 token，
            // 一张多行列表卡和一个输入框都撑得住，是设置区唯一的圆角值。
            // 默认值保持 28 不动 —— Tab2 的内容卡在用，不在本次范围内。
            .surfaceCard(cornerRadius: AppTheme.Radius.large,
                         fillColor: AppTheme.Color.settingsCardSurface)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }
}

// MARK: - Rows

/// 可点行：线性图标 + 标签 + 可选箭头。默认前景近黑、图标暖灰；危险行传 danger。
struct SettingsActionRow: View {
    let icon: SettingsRowIcon
    let label: String
    var tint: Color = AppTheme.Color.textPrimary
    var iconTint: Color = AppTheme.Color.textSecondary
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingCard) {
                SettingsRowIconView(icon: icon, tint: iconTint)
                Text(label)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(tint)
                Spacer()
                if showsChevron {
                    SettingsChevron()
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowSurface)
    }
}

/// 只读信息行：标签左、值右，**不是 Button、不可点、没有 chevron**。
///
/// 这是本页唯一「长得像行但点不动」的东西，所以它必须在三个层面都说清楚自己不是按钮：
/// 视觉上无箭头、无按压反馈；结构上不是 Button；语义上合并成一条 VoiceOver 元素，
/// 读作「标签，值」而不是两段游离的文字。
struct SettingsInfoRow: View {
    let icon: SettingsRowIcon
    let label: String
    let value: String

    /// 无障碍字号下改为上下堆叠。左右分栏在放大字号时会把两段文字挤成两条窄柱——
    /// 真机实测最大字号时「Learning / English」断成了「Learn-ing」「Eng-lish」，
    /// 词中间断字比换行更难读。堆叠后每段都能用满整行宽度。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // 堆叠时顶对齐：标签+值占三行，图标居中会飘到中间、与它标注的那行脱节。
        HStack(alignment: isStacked ? .top : .center, spacing: AppTheme.Space.paddingCard) {
            SettingsRowIconView(icon: icon, tint: AppTheme.Color.textSecondary)

            // 标签近黑、值退灰 —— 与可点行的「标签近黑 + chevron 弱色」同一条规则：
            // **主语在左、附注在右**。此前写反了（标签灰、值近黑），于是这一组的
            // 左侧第一列比其余各组浅一档，两组读起来像两种不同的行。
            textLayout {
                Text(label)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                if !isStacked {
                    Spacer(minLength: AppTheme.Space.paddingS)
                }
                Text(value)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .multilineTextAlignment(isStacked ? .leading : .trailing)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var textLayout: AnyLayout {
        isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.Space.paddingXS))
            : AnyLayout(HStackLayout(spacing: AppTheme.Space.paddingCard))
    }
}

/// 行间细分割线，左侧内缩到与文字标签对齐（图标列宽 + 两侧间距）。
///
/// 此前有 `alignsWithIcon` 开关，因为只读信息行没有图标列。现在**每一行都有图标**，
/// 缩进只剩一种，开关随之删除——少一个参数，也少一处「两组行看起来不一样」的来源。
struct SettingsRowDivider: View {
    /// 缩进 = 行左内边距 + 图标列宽 + 图标到文字的间距。
    /// 图标列会随 Dynamic Type 放大，这里必须用同一个 @ScaledMetric 一起放大，
    /// 否则大字号下分割线仍停在原处、与文字左缘错开。
    @ScaledMetric(relativeTo: .body) private var column = AppTheme.Size.rowIcon

    var body: some View {
        Divider()
            .overlay(AppTheme.Color.divider)
            .padding(.leading,
                     AppTheme.Space.paddingCard + column + AppTheme.Space.paddingCard)
    }
}

// MARK: - 标题语义

extension View {
    /// 设置区页面级大标题的无障碍语义。
    ///
    /// 三页的大标题此前只有视觉样式（`pageTitleSerif` + 近黑），在无障碍树里
    /// 就是一段普通文字。而分组标题（`SettingsCard` 的 title）是带 `.isHeader` 的
    /// —— 于是读屏用 Headings 转子导航时，能跳到 "My language"、"Legal"，
    /// 却跳不到 "Settings" 本身：层级正好倒过来了。
    ///
    /// 顺带把级别也定死。`.isHeader` 只表示「这是个标题」，不表示第几级，
    /// 两级标题都只加 trait 的话在转子里是平的，读屏用户无从判断
    /// "Legal" 是从属于 "Settings" 还是与它并列。
    func settingsPageTitleSemantics() -> some View {
        accessibilityAddTraits(.isHeader)
            .accessibilityHeading(.h1)
    }
}
