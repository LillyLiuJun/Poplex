#if DEBUG
import SwiftUI
import UIKit

// 旧方案（预设浅底单色深字，2026-10-06 已废弃）的墨色。线上 Token 已删除，本历史预览自带一份，保持画面不变。
private let legacyPresetLabelInk = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255)  // #8A4A20
private let legacyReasonInkOnLightArt = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255).opacity(0.72)

/// Tab2 全页 12pt 统一排印方案视觉实验室 (Tab2 All-12pt Uniform Category Typo Lab)
///
/// 探索用户提出的全新「全页 12pt 均质大一统」排印思路：
/// 1. ① Talk about today (Hero): 照片/预设图左上角标签由 11.5pt 升至 12pt SemiBold；
/// 2. ② More to talk about (Row): 维持原生的 12pt SemiBold 帽子声部；
/// 3. ③ Topics in progress (Accordion): 分类名由 13pt 调整至 12pt Regular (与右侧 12pt words 计数绝对同频)；
/// 4. ④ More topics to explore (Pills): 维持 12pt Regular，胶囊高度微调至 28pt (舒展挺拔，消灭 25pt 的局促缩水感)。
///
/// 核心价值：
/// - 验证四大 Section 类别标签彻底统一为 12pt 时的视觉匀质度、松紧度节奏与呼吸感；
/// - 提供「全 12pt 方案 vs 现状混排 vs 13pt 推荐方案」同屏 1:1 深度比对。
struct Tab2All12ptUniformPreview: View {
    @State private var viewMode: LabViewMode = .fullPageFlow
    @State private var typographyScheme: TypoScheme = .uniform12pt
    @State private var topics12Weight: TopicsWeightOption = .regular
    @State private var exploreCapsuleHeight: CapsuleHeightOption = .h28pt
    @State private var heroCase: HeroCaseOption = .foodSolidPreset
    @State private var showTopBarShell: Bool = true
    @State private var toastMessage: String?

    enum LabViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fullPageFlow = "全真整页流"
        case threeSchemes = "3 大排印方案同屏对比 ⭐"
        case typoRuler    = "四模块标签标尺"

        var title: String { rawValue }
    }

    enum TypoScheme: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case uniform12pt  = "全 12pt 均质大一统 ⭐"
        case proposal13pt = "全 13pt 同频方案"
        case baselineMix  = "现状基线混排"

        var shortName: String { rawValue }

        var heroSizeDesc: String {
            switch self {
            case .uniform12pt:  return "12pt SemiBold"
            case .proposal13pt: return "11.5pt SemiBold"
            case .baselineMix:  return "11.5pt SemiBold"
            }
        }

        var moreSizeDesc: String {
            "12pt SemiBold"
        }

        var topicsSizeDesc: String {
            switch self {
            case .uniform12pt:  return "12pt Regular"
            case .proposal13pt: return "13pt Regular"
            case .baselineMix:  return "13pt Regular"
            }
        }

        var exploreSizeDesc: String {
            switch self {
            case .uniform12pt:  return "12pt Regular · 28pt 高"
            case .proposal13pt: return "13pt Regular · 30pt 高"
            case .baselineMix:  return "12pt Regular · 25pt 高"
            }
        }

        var rationale: String {
            switch self {
            case .uniform12pt:
                return "【全 12pt 均质大一统 ⭐】Hero 提升至 12pt，Topics 收敛至 12pt，与 More 行帽标 (12pt) 及 Explore 胶囊 (12pt) 彻底达成四模块 1:1 绝对平齐。Topics 分类名与右侧 words 计数完全等大，整体呈现素雅、紧凑、内敛的日式极简秩序感。"
            case .proposal13pt:
                return "【13pt 同频方案】将 Explore 胶囊提升至 13pt，对齐 Topics in progress 的 13pt 主体地位。胶囊高度提升至 30pt，自信挺拔，消除 24pt 大衬线标题下方的缩水与头重脚轻感。"
            case .baselineMix:
                return "【现状基线混排】Hero 11.5pt、More 12pt、Topics 13pt、Explore 12pt (高 25pt)。层级细碎微散，Topics 略大而 Explore 胶囊明显偏小局促。"
            }
        }
    }

    enum TopicsWeightOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case regular = "12pt Regular"
        case medium  = "12pt Medium"
    }

    enum CapsuleHeightOption: CGFloat, CaseIterable, Identifiable {
        var id: CGFloat { rawValue }
        case h25pt = 25
        case h28pt = 28
        case h30pt = 30

        var label: String { "\(Int(rawValue))pt" }
    }

    enum HeroCaseOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case foodSolidPreset = "Food 预设餐盘"
        case workSolidPreset = "Work 预设纸笔"
        case travelPhoto     = "Travel 真实照片"
    }

    var body: some View {
        VStack(spacing: 0) {
            topControlBar
            Divider().opacity(0.15)

            switch viewMode {
            case .fullPageFlow:
                fullPageFlowContent
            case .threeSchemes:
                threeSchemesContent
            case .typoRuler:
                typoRulerContent
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                toastOverlay(text: toast)
            }
        }
    }

    // MARK: - 顶部控制栏

    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 一级模式
            Picker("视图模式", selection: $viewMode) {
                ForEach(LabViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewMode == .fullPageFlow {
                // 排印方案即时联动
                HStack(spacing: 8) {
                    Text("整页排印:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandInk)

                    Picker("排印方案", selection: $typographyScheme) {
                        ForEach(TypoScheme.allCases) { s in
                            Text(s.shortName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if typographyScheme == .uniform12pt {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Topics字重:")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Picker("Topics字重", selection: $topics12Weight) {
                                ForEach(TopicsWeightOption.allCases) { w in
                                    Text(w.rawValue).tag(w)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack(spacing: 4) {
                            Text("胶囊高度:")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Picker("胶囊高度", selection: $exploreCapsuleHeight) {
                                ForEach(CapsuleHeightOption.allCases) { h in
                                    Text(h.label).tag(h)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 8)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 1. 全真整页流 (Full Page Flow)

    private var fullPageFlowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                // ① Talk about today (Hero)
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Talk about today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    customHeroCard(scheme: typographyScheme)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // ② More to talk about (推荐列表行，原生 12pt)
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("More to talk about")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                        Tab2ActivityRow(category: UniformLabMock.moreShopping, onTap: {})
                        Tab2ActivityRow(category: UniformLabMock.moreHealth, onTap: {})
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // ③ Topics in progress (根据方案渲染 12pt 或 13pt)
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(spacing: 0) {
                        customProgressRow(
                            category: UniformLabMock.inProgressHome,
                            scheme: typographyScheme
                        )
                        customProgressRow(
                            category: UniformLabMock.inProgressSocial,
                            scheme: typographyScheme
                        )
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // ④ More topics to explore (未开始分类探索区)
                customExploreSection(scheme: typographyScheme)

                // 底部 96pt 呼吸断层与宣言
                Spacer(minLength: AppTheme.Space.tab2FooterTop)
                footerSignoffView
                    .padding(.bottom, AppTheme.Space.tab2FooterBottom)
            }
            .padding(.top, AppTheme.Space.tab2ContentTop)
            .background(alignment: .bottom) {
                BottomAuraFooter()
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 2. 3 大排印方案同屏深度比对 (Three Schemes Comparison)

    private var threeSchemesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("全页分类排印方案深度比对")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("同屏比对「全 12pt 均质大一统」、「全 13pt 同频推荐」与「现状基线混排」的视觉节奏")
                        .font(AppTheme.Font.actionNote)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(TypoScheme.allCases) { scheme in
                    schemeComparisonCard(scheme: scheme)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func schemeComparisonCard(scheme: TypoScheme) -> some View {
        let isChosen = scheme == .uniform12pt
        return VStack(alignment: .leading, spacing: 14) {
            // 头部
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(scheme.rawValue)
                        .font(AppTheme.Font.compactSectionTitleSerif)
                        .foregroundStyle(isChosen ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary)

                    Spacer()

                    Text(isChosen ? "用户灵感 · 核心推演 ⭐" : "对照方案")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(isChosen ? AppTheme.Color.brandInk : AppTheme.Color.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isChosen ? AppTheme.Color.brandTint.opacity(0.4) : AppTheme.Color.pageBg)
                        .clipShape(Capsule())
                }

                Text(scheme.rationale)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.12)

            // 4 模块字号规格指示器
            VStack(spacing: 4) {
                specRow(section: "① Hero 封面标签", spec: scheme.heroSizeDesc)
                specRow(section: "② More 推荐行帽子", spec: scheme.moreSizeDesc)
                specRow(section: "③ Topics in progress", spec: scheme.topicsSizeDesc)
                specRow(section: "④ More topics 胶囊", spec: scheme.exploreSizeDesc)
            }
            .padding(10)
            .background(AppTheme.Color.pageBg.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            // 真实视觉上下文咬合：Section 3 进度卡 + Section 4 探索区
            VStack(alignment: .leading, spacing: 10) {
                Text("【Section 3 进度卡 ➔ Section 4 探索区 现场承接】")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.textMuted)

                // 进度卡
                customProgressRow(
                    category: UniformLabMock.inProgressHome,
                    scheme: scheme
                )
                .surfaceCard(cornerRadius: AppTheme.Radius.medium)

                // 28pt 留白标尺
                HStack(spacing: 8) {
                    Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.3))
                    Text("28pt 标准模块留白")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.red.opacity(0.8))
                    Rectangle().frame(height: 1).foregroundStyle(Color.red.opacity(0.3))
                }
                .padding(.vertical, 2)

                // 探索区
                customExploreSection(scheme: scheme, isEmbeddedInCard: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(isChosen ? AppTheme.Color.brandStrong : AppTheme.Color.cardBorder, lineWidth: isChosen ? 1.5 : 0.5)
        )
    }

    private func specRow(section: String, spec: String) -> some View {
        HStack {
            Text(section)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textSecondary)
            Spacer()
            Text(spec)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Color.brandInk)
        }
    }

    // MARK: - 3. 四模块标签标尺展台 (Typo Ruler)

    private var typoRulerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("四大 Section 类别标签标尺对比")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("将四处出现的分类名抽离并列，直观检视其字级、粗细与视觉重量的光学协调性")
                        .font(AppTheme.Font.actionNote)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 方案对比展台
                VStack(alignment: .leading, spacing: 16) {
                    rulerSection(
                        title: "方案 A · 全 12pt 均质大一统 (用户灵感 ⭐)",
                        subtitle: "四处分类彻底统归 12pt，消除任何体量落差与突兀跳跃",
                        badge: "全 12pt",
                        isHighlight: true
                    ) {
                        rulerItem(section: "① Hero 照片/预设", text: "Food & Drink", font: .system(size: 12, weight: .semibold), spec: "12pt / 600 SemiBold")
                        rulerItem(section: "② More 列表帽子", text: "Shopping", font: .system(size: 12, weight: .semibold), spec: "12pt / 600 SemiBold")
                        rulerItem(section: "③ Topics 进行中", text: "Home & Family", font: .system(size: 12, weight: .regular), spec: "12pt / 400 Regular")
                        rulerItem(section: "④ Explore 探索胶囊", text: "Weather & Nature", font: .system(size: 12, weight: .regular), spec: "12pt / 400 Regular")
                    }

                    rulerSection(
                        title: "方案 B · 现状基线混排 (现状事实)",
                        subtitle: "11.5pt 与 12pt、13pt 混杂，探索区胶囊偏小局促",
                        badge: "现状基线",
                        isHighlight: false
                    ) {
                        rulerItem(section: "① Hero 照片/预设", text: "Food & Drink", font: .system(size: 11.5, weight: .semibold), spec: "11.5pt / 600 SemiBold")
                        rulerItem(section: "② More 列表帽子", text: "Shopping", font: .system(size: 12, weight: .semibold), spec: "12pt / 600 SemiBold")
                        rulerItem(section: "③ Topics 进行中", text: "Home & Family", font: .system(size: 13, weight: .regular), spec: "13pt / 400 Regular")
                        rulerItem(section: "④ Explore 探索胶囊", text: "Weather & Nature", font: .system(size: 12, weight: .regular), spec: "12pt / 400 Regular (高25pt)")
                    }

                    rulerSection(
                        title: "方案 C · 13pt 向上同频 (此前方案 1)",
                        subtitle: "探索区胶囊拉升到 13pt 与 Topics 对齐，胶囊 30pt",
                        badge: "13pt 同频",
                        isHighlight: false
                    ) {
                        rulerItem(section: "① Hero 照片/预设", text: "Food & Drink", font: .system(size: 11.5, weight: .semibold), spec: "11.5pt / 600 SemiBold")
                        rulerItem(section: "② More 列表帽子", text: "Shopping", font: .system(size: 12, weight: .semibold), spec: "12pt / 600 SemiBold")
                        rulerItem(section: "③ Topics 进行中", text: "Home & Family", font: .system(size: 13, weight: .regular), spec: "13pt / 400 Regular")
                        rulerItem(section: "④ Explore 探索胶囊", text: "Weather & Nature", font: .system(size: 13, weight: .regular), spec: "13pt / 400 Regular (高30pt)")
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func rulerSection<Content: View>(
        title: String,
        subtitle: String,
        badge: String,
        isHighlight: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(AppTheme.Font.compactSectionTitleSerif)
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary)
                Spacer()
                Text(badge)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandInk : AppTheme.Color.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isHighlight ? AppTheme.Color.brandTint.opacity(0.4) : AppTheme.Color.pageBg)
                    .clipShape(Capsule())
            }

            Text(subtitle)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textMuted)

            Divider().opacity(0.12)

            VStack(spacing: 8) {
                content()
            }
        }
        .padding(16)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(isHighlight ? AppTheme.Color.brandStrong : AppTheme.Color.cardBorder, lineWidth: isHighlight ? 1.5 : 0.5)
        )
    }

    private func rulerItem(section: String, text: String, font: Font, spec: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(text)
                    .font(font)
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }
            Spacer()
            Text(spec)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.Color.brandInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.Color.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 自定义组件 (用于实时呈现指定排印参数)

    private func customHeroCard(scheme: TypoScheme) -> some View {
        let heroCategory = UniformLabMock.heroFoodPreset
        let display = Tab2ActivityDisplay.compute(category: heroCategory)
        let font: Font = (scheme == .uniform12pt) ? .system(size: 12, weight: .semibold) : AppTheme.Font.tab2HeroChipCategory

        return VStack(spacing: 0) {
            // 顶部图与标签
            ZStack(alignment: .topLeading) {
                CategoryPresetArtView(category: .food)
                    .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()

                HStack(spacing: 8) {
                    Text(heroCategory.englishLabel)
                        .font(font)
                        .foregroundStyle(legacyPresetLabelInk)
                        .lineLimit(1)

                    Text("Added today")
                        .font(AppTheme.Font.tab2ReasonPill)
                        .foregroundStyle(legacyReasonInkOnLightArt)
                        .lineLimit(1)
                }
                .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
            }

            // 卡身
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
                    Text("Recent activities")
                        .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                        .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Color.textMuted)

                    Tab2ActivityCapsuleGroup(
                        activities: display.valid,
                        activityCount: heroCategory.activityCount,
                        blockedCount: display.blockedCount,
                        metrics: Tab2ActivityCapsuleMetrics.hero(),
                        nameFont: AppTheme.Font.tab2HeroCapsuleName,
                        moreFont: AppTheme.Font.tab2HeroCapsuleMore
                    )
                }
                .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

                HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                    Text(Tab2CardLabels.words(heroCategory.wordCount))
                        .font(AppTheme.Font.tab2HeroFootrowWords)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .monospacedDigit()
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
                        Text("Start talking")
                        Image(systemName: "arrow.right")
                            .imageScale(.small)
                    }
                    .font(AppTheme.Font.tab2HeroCTA)
                    .foregroundStyle(AppTheme.Color.textOnChip)
                    .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
                    .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
                    .background(
                        AppTheme.Color.interactive,
                        in: RoundedRectangle(
                            cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius,
                            style: .continuous
                        )
                    )
                }
                .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
            }
            .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
            .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
            .background(AppTheme.Color.cardBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
    }

    private func customProgressRow(
        category: Tab2CategoryData,
        scheme: TypoScheme
    ) -> some View {
        let topicFont: Font = {
            switch scheme {
            case .uniform12pt:
                return topics12Weight == .regular ? .system(size: 12, weight: .regular) : .system(size: 12, weight: .medium)
            case .proposal13pt, .baselineMix:
                return AppTheme.Font.tab2TopicLabel // 13pt Regular
            }
        }()

        return HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
            Image(systemName: SceneCategory.from(category.sceneCategory).iconName)
                .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 20, height: 20, alignment: .center)

            VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                HStack(alignment: .center) {
                    Text(category.englishLabel)
                        .font(topicFont)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    HStack(spacing: AppTheme.Size.pillHSpacing) {
                        Text(Tab2CardLabels.words(category.wordCount))
                            .font(AppTheme.Font.tab2ProgressCount)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: AppTheme.Size.expandArrow))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                    .padding(.horizontal, AppTheme.Size.pillHPad)
                    .padding(.vertical, AppTheme.Size.pillVPad)
                    .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
                }

                // 纤细进度条
                Capsule()
                    .fill(AppTheme.Color.progressFill)
                    .frame(height: 1.5)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.listRowVertical)
    }

    private func customExploreSection(scheme: TypoScheme, isEmbeddedInCard: Bool = false) -> some View {
        let topics: [SceneCategory] = [.weather, .social, .other, .gettingAround]
        let rows = Tab2ExploreTagLayout.rows(topics)
        let horizontalPadding: CGFloat = isEmbeddedInCard ? 0 : AppTheme.Space.paddingPage

        let tagFont: Font = {
            switch scheme {
            case .uniform12pt:  return .system(size: 12, weight: .regular)
            case .proposal13pt: return .system(size: 13, weight: .regular)
            case .baselineMix:  return .system(size: 12, weight: .regular)
            }
        }()

        let tagHeight: CGFloat = {
            switch scheme {
            case .uniform12pt:  return exploreCapsuleHeight.rawValue
            case .proposal13pt: return 30
            case .baselineMix:  return 25
            }
        }()

        let iconSize: CGFloat = (scheme == .proposal13pt) ? 13.5 : 12.0
        let hPadding: CGFloat = (scheme == .proposal13pt) ? 13.0 : 11.5

        return VStack(alignment: .leading, spacing: 0) {
            Text("More topics to explore")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            ForEach(rows[index], id: \.self) { topic in
                                HStack(spacing: 5.5) {
                                    Image(systemName: topic.iconName)
                                        .font(.system(size: iconSize, weight: .regular))
                                        .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagIcon)

                                    Text(topic.englishLabel)
                                        .font(tagFont)
                                        .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagLabel)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(.horizontal, hPadding)
                                .frame(minHeight: tagHeight)
                                .background {
                                    Capsule()
                                        .fill(AppTheme.Tab2ExploreTopics.Color.tagFill)
                                        .strokeBorder(AppTheme.Tab2ExploreTopics.Color.tagBorder, lineWidth: 0.8)
                                }
                                .shadow(color: AppTheme.Tab2ExploreTopics.Color.tagShadow, radius: 3, y: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerSignoffView: some View {
        VStack(spacing: 6) {
            PoplexWordmark(capHeight: 12.5, style: .mono(AppTheme.Color.textMuted), showsPeriod: true)
            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func toastOverlay(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Color.brandStrong)
            Text(text)
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
        .clipShape(Capsule())
        .cardShadow()
        .padding(.bottom, 24)
    }
}

// MARK: - 高保真专用 Mock 数据

private enum UniformLabMock {
    static var heroFoodPreset: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.food.rawValue,
            wordCount: 52,
            unlocked: true,
            notSpokenCount: 12,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 5,
            activities: [
                Tab2Activity(sceneDetail: "Dinner at home", occurrenceCount: 3, cover: nil)
            ]
        )
    }

    static var moreShopping: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.shopping.rawValue,
            wordCount: 64,
            unlocked: true,
            notSpokenCount: 14,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            newMaterialCount: 2,
            activityCount: 5,
            activities: [
                Tab2Activity(sceneDetail: "Weekend grocery haul", occurrenceCount: 2, cover: nil)
            ]
        )
    }

    static var moreHealth: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.healthFitness.rawValue,
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 11,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            newMaterialCount: 1,
            activityCount: 4,
            activities: [
                Tab2Activity(sceneDetail: "Evening 5k run", occurrenceCount: 2, cover: nil)
            ]
        )
    }

    static var inProgressHome: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.homeFamily.rawValue,
            wordCount: 18,
            unlocked: false,
            notSpokenCount: 18,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 2,
            activityCount: 4,
            activities: []
        )
    }

    static var inProgressSocial: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: SceneCategory.social.rawValue,
            wordCount: 11,
            unlocked: false,
            notSpokenCount: 11,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            newMaterialCount: 0,
            activityCount: 3,
            activities: []
        )
    }
}

#Preview("全页 12pt 均质大一统排印方案") {
    Tab2All12ptUniformPreview()
}
#endif
