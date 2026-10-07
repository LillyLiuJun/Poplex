#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 四大生活分类标签三大优化方案与排版秩序沙盒
//         (Tab2 Category Typography Proposals & Visual Harmony Preview)
//
// 🏛️ 设计学四大原则指导纲领 (Design Principles Framework)：
//   1. 统一性 (Repetition / Consistency)：
//      - 「生活分类 (SceneCategory)」是用户心智中完全对等的同一生活实体，应当拥有高度自洽的字阶基线；
//      - 彻底消除 11.5pt 与 12.0pt 这类暧昧微差，将字号绝对收敛至 13.0pt 黄金基线。
//   2. 对比性 (Contrast)：
//      - 建立「字号 × 字重 × 颜色明度」的综合声部平衡，避免卡内多个元素在 12pt 附近产生视觉拥挤；
//      - 区分「照片反白介质」与「浅色纸底介质」对视觉黑度（Visual Blackness）的不同需求。
//   3. 亲密性 (Proximity)：
//      - 空间亲密性：已承载 Proposal B 10pt 呼吸节奏间距（内部 10pt，大区分隔 28pt）；
//      - 排版亲密性：分类名与同行的时间戳、图标在骨架粗细上达成 1:1 光学同频。
//   4. 对齐 (Alignment)：
//      - 垂直扫描基线：消除上下滚动时分类标签字号忽大忽小的跳动感，建立从容平稳的视线流。
//
// 🎯 三大优化方案与基线矩阵：
//   • 【基线 Baseline】生产现状：Hero 11.5pt/600 · More 12.0pt/600 · Topics 13.0pt/400 · Explore 13.0pt/400
//   • 【方案 A · 纯粹极简】全员 13.0pt · Regular 400（日系温润书卷，彻底去标签化，最安静）
//   • 【方案 B · 介质调和（推荐）】全员 13.0pt，照片/卡头用 500 Medium，列表胶囊用 400 Regular（抗眩光与轻挺平衡）
//   • 【方案 C · 双轨字重】全员 13.0pt，卡头维持 600 SemiBold，列表胶囊维持 400 Regular（强化模块帽子心智）

struct Tab2CategoryTypographyProposalsPreview: View {

    // MARK: - 方案定义枚举

    enum Proposal: String, CaseIterable, Identifiable {
        case baseline   = "生产基线 (11.5/12/13/13)"
        case proposalA  = "方案 A · 全 13pt Regular"
        case proposalB  = "方案 B · 全 13pt 介质调和"
        case proposalC  = "方案 C · 全 13pt 双轨字重"

        var id: String { rawValue }

        var shortTitle: String {
            switch self {
            case .baseline:  return "生产基线"
            case .proposalA: return "方案 A (极简 400)"
            case .proposalB: return "方案 B (调和 500/400)"
            case .proposalC: return "方案 C (双轨 600/400)"
            }
        }

        var badgeDescription: String {
            switch self {
            case .baseline:
                return "现状断层：11.5pt / 12pt / 13pt / 13pt · 2 种字重"
            case .proposalA:
                return "四大分类 100% 统一为 13pt Regular (400) · 极简温润"
            case .proposalB:
                return "字号全 13pt · Hero/More 500 Medium，Topics/Explore 400"
            case .proposalC:
                return "字号全 13pt · Hero/More 600 SemiBold，Topics/Explore 400"
            }
        }
    }

    // MARK: - 测试数据集枚举

    enum DatasetPreset: String, CaseIterable, Identifiable {
        case standard   = "场景 1: 丰富多元生活"
        case mixedEmpty = "场景 2: 紧凑与空态混排"
        case edgeCase   = "场景 3: 极限长短字符"

        var id: String { rawValue }
    }

    // MARK: - 查看视图模式

    enum ViewPerspective: String, CaseIterable, Identifiable {
        case fullFlow       = "全页真实流动"
        case isolatedFour   = "四分类贴身同台"
        case principleAudit = "四大原则雷达表"

        var id: String { rawValue }
    }

    // MARK: - 状态管理

    @State private var selectedProposal: Proposal = .proposalA
    @State private var selectedDataset: DatasetPreset = .standard
    @State private var selectedPerspective: ViewPerspective = .fullFlow
    @State private var isAccordionExpanded: Bool = true
    @State private var showPrincipleDetails: Bool = false

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            // 控制顶栏
            controlToolbar

            Divider().opacity(0.15)

            // 主体呈现
            switch selectedPerspective {
            case .fullFlow:
                fullFlowView
            case .isolatedFour:
                isolatedFourComparisonView
            case .principleAudit:
                principleAuditView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶栏控制面板 (Control Toolbar)

    private var controlToolbar: some View {
        VStack(spacing: 8) {
            // 顶行：标题与原则抽屉开关
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Tab2 分类标签三大优化方案")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text(selectedProposal.shortTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Color.brandTint, in: Capsule())
                    }
                    Text(selectedProposal.badgeDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // 数据场景切换菜单
                Menu {
                    Picker("测试数据场景", selection: $selectedDataset) {
                        ForEach(DatasetPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                        Text(selectedDataset == .standard ? "标准数据" : (selectedDataset == .mixedEmpty ? "空态混排" : "长短字符"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.Color.warmGlassSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }
            }

            // 方案切换分段器
            Picker("优化方案", selection: $selectedProposal) {
                ForEach(Proposal.allCases) { prop in
                    Text(prop.shortTitle).tag(prop)
                }
            }
            .pickerStyle(.segmented)

            // 视角切换分段器
            Picker("查看视角", selection: $selectedPerspective) {
                ForEach(ViewPerspective.allCases) { perspective in
                    Text(perspective.rawValue).tag(perspective)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.warmGlassSurface)
    }

    // MARK: - 视角 1: 全页流动流 (Full Flow View)

    private var fullFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                    
                    // ── 组 1: Talk about today ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("Talk about today", sectionIndex: 1)

                        // 方案注入版 Hero 卡
                        ProposalHeroCard(
                            data: currentHeroData,
                            proposal: selectedProposal,
                            onTalk: {}
                        )
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // ── 组 2: More to talk about ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("More to talk about", sectionIndex: 2)

                        VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                            ForEach(Array(currentMoreRowsData.enumerated()), id: \.offset) { index, rowData in
                                ProposalMoreRow(
                                    data: rowData,
                                    proposal: selectedProposal,
                                    onTap: {}
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // ── 组 3: Topics in progress ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("Topics in progress", sectionIndex: 3)

                        VStack(spacing: 0) {
                            ForEach(Array(currentTopicsData.enumerated()), id: \.offset) { index, topicData in
                                ProposalTopicsRow(
                                    data: topicData,
                                    proposal: selectedProposal,
                                    isExpanded: index == 0 ? isAccordionExpanded : false,
                                    onToggle: {
                                        if index == 0 {
                                            withAnimation(AppTheme.Motion.accordionToggle) {
                                                isAccordionExpanded.toggle()
                                            }
                                        }
                                    }
                                )

                                if index < currentTopicsData.count - 1 {
                                    Divider().padding(.horizontal, AppTheme.Space.paddingPage)
                                }
                            }
                        }
                        .padding(.vertical, AppTheme.Space.paddingS)
                        .surfaceCard(cornerRadius: AppTheme.Radius.large)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // ── 组 4: More topics to explore ──
                    VStack(alignment: .leading, spacing: 0) {
                        ProposalExploreSection(
                            topics: currentExploreTopics,
                            proposal: selectedProposal
                        )
                    }
                }
                .padding(.top, AppTheme.Space.tab2ContentTop)

                Spacer(minLength: AppTheme.Space.tab2FooterTop)

                footerSignoff
                    .padding(.bottom, AppTheme.Space.tab2FooterBottom)
            }
            .background(alignment: .bottom) {
                BottomAuraFooter()
            }
        }
    }

    // MARK: - 视角 2: 四大分类标签贴身等距横评 (Isolated Four Comparison)

    private var isolatedFourComparisonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("四大生活分类标签 · 同台同词等距横评")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("当前方案：\(selectedProposal.rawValue) · 观察「Food & Drink」在各载体中的黑度、骨架与光学平衡：")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 12) {
                    // 1. Hero 顶标
                    isolatedSpecimenBox(
                        tagNum: "1",
                        role: "Hero 封面顶标",
                        medium: "深色照片磨砂浮层 (反白裸字 + 阴影，紧跟理由胶囊)",
                        spec: specForHero(selectedProposal),
                        accentColor: .purple
                    ) {
                        HStack(spacing: 8) {
                            Text("Food & Drink")
                                .font(fontForHero(selectedProposal))
                                .foregroundStyle(AppTheme.Color.tab2HeroPhotoOverlayText)
                                .shadow(
                                    color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow),
                                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                    x: 0,
                                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                                )

                            Text("Added 3 times today")
                                .font(AppTheme.Font.tab2ReasonPill)
                                .foregroundStyle(AppTheme.Color.tab2ReasonPillOnPhotoText)
                                .shadow(
                                    color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow),
                                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                    x: 0,
                                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                                )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Color(red: 0.22, green: 0.18, blue: 0.15)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        )
                    }

                    // 2. More 帽标
                    isolatedSpecimenBox(
                        tagNum: "2",
                        role: "More 推荐行帽标",
                        medium: "浅暖白卡片容器顶端 (次级灰字)",
                        spec: specForMore(selectedProposal),
                        accentColor: .blue
                    ) {
                        Text("Food & Drink")
                            .font(fontForMore(selectedProposal))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }

                    // 3. Topics 行名
                    isolatedSpecimenBox(
                        tagNum: "3",
                        role: "Topics 列表行首标题",
                        medium: "手风琴行，与 14pt 细线图标并列 (主黑字)",
                        spec: specForTopics(selectedProposal),
                        accentColor: .teal
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(AppTheme.Color.textMuted)
                            Text("Food & Drink")
                                .font(fontForTopics(selectedProposal))
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        }
                    }

                    // 4. Explore 胶囊
                    isolatedSpecimenBox(
                        tagNum: "4",
                        role: "Explore 未开启生活胶囊",
                        medium: "30pt 独立轻胶囊，与 13.5pt 图标并列",
                        spec: specForExplore(selectedProposal),
                        accentColor: .orange
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 13.5, weight: .regular))
                            Text("Food & Drink")
                                .font(fontForExplore(selectedProposal))
                        }
                        .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagLabel)
                        .padding(.horizontal, 13)
                        .frame(height: 30)
                        .background {
                            Capsule()
                                .fill(AppTheme.Tab2ExploreTopics.Color.tagFill)
                                .strokeBorder(
                                    AppTheme.Tab2ExploreTopics.Color.tagBorder,
                                    lineWidth: AppTheme.Tab2ExploreTopics.Layout.tagBorderWidth
                                )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
            .padding(.vertical, 16)
        }
    }

    private func isolatedSpecimenBox<Content: View>(
        tagNum: String,
        role: String,
        medium: String,
        spec: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Text(tagNum)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 14, height: 14)
                        .background(accentColor, in: Circle())
                    Text(role)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Text(spec)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.1), in: Capsule())
            }

            Text("介质情境：\(medium)")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textMuted)

            HStack {
                content()
                Spacer()
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .fill(AppTheme.Color.warmGlassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - 视角 3: 设计四大原则雷达审计 (Design Principle Audit)

    private var principleAuditView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("设计四大原则（对齐、对比、统一、亲密）评估对比")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("系统化衡量三大方案在整体性、声部层级与视觉和谐感上的权衡得分：")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                VStack(spacing: 12) {
                    principleEvaluationCard(
                        title: "1. 统一性 (Repetition / Consistency)",
                        icon: "rectangle.3.group",
                        statusText: selectedProposal == .proposalA ? "极致纯粹 (10/10)" : (selectedProposal == .proposalB ? "高度统一 (9.5/10)" : "中度统一 (8/10)"),
                        analysis: selectedProposal == .proposalA ?
                            "四处生活分类 100% 抹平为 13pt Regular，全屏分类心智毫无噪点，彻底去粗重感。" :
                            (selectedProposal == .proposalB ?
                                "字号物理拉平为 13pt，消灭 11.5/12 碎裂中间档；字重依介质在 500 与 400 之间微幅调和，极具工业严谨性。" :
                                "字号拉平至 13pt，但 600 SemiBold 与 400 Regular 视觉粗细分水岭依然明显。")
                    )

                    principleEvaluationCard(
                        title: "2. 对比性 (Contrast)",
                        icon: "circle.lefthalf.filled",
                        statusText: selectedProposal == .proposalB ? "声部最和谐 (10/10)" : (selectedProposal == .proposalA ? "温和内敛 (8.5/10)" : "对比分明 (9/10)"),
                        analysis: selectedProposal == .proposalB ?
                            "【最优解】Hero 照片浮层采用 500 Medium 抗眩光；More 帽标 500 与下方 12pt 衬线胶囊拉开清晰的主次层次；Topics 与 Explore 400 维持轻挺。" :
                            (selectedProposal == .proposalA ?
                                "全员 400 Regular。Hero 在强光照片上可能略显轻薄；More 卡片内帽子与活动胶囊均无粗体，对比主要依赖字色与衬线。" :
                                "Hero 和 More 维持 600 SemiBold，强化了卡片帽子的标签属性，但中文字重存在微块感。")
                    )

                    principleEvaluationCard(
                        title: "3. 亲密性 (Proximity)",
                        icon: "arrow.left.and.right",
                        statusText: "空间亲密 100% 对齐 10pt",
                        analysis: "全方案均搭载 Proposal B 10pt 呼吸节奏间距（小标到胶囊 10pt，胶囊到词数 10pt，大区 28pt）。方案 B 的 13pt Medium 在 More 帽行中与右侧 11.5pt 时间戳形成极为平稳的基线亲密感。"
                    )

                    principleEvaluationCard(
                        title: "4. 对齐 (Alignment)",
                        icon: "align.vertical.top",
                        statusText: "纵向扫描视线完全顺畅",
                        analysis: "方案 A、B、C 均将物理字阶统领到 13.0pt，用户在上下滚动时视线不再经历「11.5 → 12 → 13」的缩放调整，整体阅读律动高度齐整。"
                    )
                }

                // 专家推荐决议卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color.orange)
                        Text("系统设计推导结论：强烈推荐【方案 B】")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }

                    Text("理由：在「字号」上执行绝对统一（13.0pt）以建立全页秩序与对齐；在「字重」上采用 500 Medium 替代 600 SemiBold，既卸下了粗黑块包袱，又保障了照片浮层的抗眩光抗干扰能力，实现 Warm Editorial 的极致和谐。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 16)
        }
    }

    private func principleEvaluationCard(
        title: String,
        icon: String,
        statusText: String,
        analysis: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Color.brandInk)
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                Spacer()
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandInk)
            }

            Text(analysis)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .fill(AppTheme.Color.warmGlassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - 辅助组件

    private func sectionTitleHeader(_ title: String, sectionIndex: Int) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var footerSignoff: some View {
        VStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Color.brandInk.opacity(0.5))
            Text("Every word grounded in your moments")
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 方案排版参数映射工厂 (Typography Parameter Mapping)

    private static func gothicCustom(_ size: CGFloat, weightPostScript: String, relativeTo: Font.TextStyle = .subheadline) -> Font {
        FontLoader.registerCustomFonts()
        return .custom(weightPostScript, size: size, relativeTo: relativeTo)
    }

    private func fontForHero(_ proposal: Proposal) -> Font {
        switch proposal {
        case .baseline:  return Self.gothicCustom(11.5, weightPostScript: "GothicA1-SemiBold", relativeTo: .caption2) // 历史基线 11.5pt / 600
        case .proposalA: return AppTheme.Font.tab2HeroChipCategory // 方案 A 试验（生产 Token 当前值: 13.0pt / 400 Regular）
        case .proposalB: return Self.gothicCustom(13.0, weightPostScript: "GothicA1-Medium", relativeTo: .subheadline) // 方案 B（13.0pt / 500 Medium）
        case .proposalC: return Self.gothicCustom(13.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .subheadline)
        }
    }

    private func specForHero(_ proposal: Proposal) -> String {
        switch proposal {
        case .baseline:  return "11.5pt · SemiBold (600)"
        case .proposalA: return "13.0pt · Regular (400)"
        case .proposalB: return "13.0pt · Medium (500)"
        case .proposalC: return "13.0pt · SemiBold (600)"
        }
    }

    private func fontForMore(_ proposal: Proposal) -> Font {
        switch proposal {
        case .baseline:  return Self.gothicCustom(12.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .caption) // 历史基线 12.0pt / 600
        case .proposalA: return AppTheme.Font.tab2MoreRowCategory // 方案 A 试验（生产 Token 当前值: 13.0pt / 400 Regular）
        case .proposalB: return Self.gothicCustom(13.0, weightPostScript: "GothicA1-Medium", relativeTo: .subheadline) // 方案 B（13.0pt / 500 Medium）
        case .proposalC: return Self.gothicCustom(13.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .subheadline)
        }
    }

    private func specForMore(_ proposal: Proposal) -> String {
        switch proposal {
        case .baseline:  return "12.0pt · SemiBold (600)"
        case .proposalA: return "13.0pt · Regular (400)"
        case .proposalB: return "13.0pt · Medium (500)"
        case .proposalC: return "13.0pt · SemiBold (600)"
        }
    }

    private func fontForTopics(_ proposal: Proposal) -> Font {
        switch proposal {
        case .baseline, .proposalA, .proposalB, .proposalC:
            return AppTheme.Font.tab2TopicLabel // 恒为 13.0pt / 400
        }
    }

    private func specForTopics(_ proposal: Proposal) -> String {
        return "13.0pt · Regular (400)"
    }

    private func fontForExplore(_ proposal: Proposal) -> Font {
        switch proposal {
        case .baseline, .proposalA, .proposalB, .proposalC:
            return AppTheme.Font.tab2ExploreTagLabel // 恒为 13.0pt / 400
        }
    }

    private func specForExplore(_ proposal: Proposal) -> String {
        return "13.0pt · Regular (400)"
    }

    // MARK: - 方案动态注入组件 (Customized Proposal Components)

    /// 方案定制版 Hero 卡片
    private struct ProposalHeroCard: View {
        let data: Tab2CategoryData
        let proposal: Proposal
        let onTalk: () -> Void

        private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: data) }

        var body: some View {
            Button(action: onTalk) {
                VStack(spacing: 0) {
                    // 照片区
                    ZStack(alignment: .topLeading) {
                        // 封面图
                        AsyncImage(url: URL(string: data.activities.first?.cover?.imageUrl ?? "")) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color(red: 0.22, green: 0.18, blue: 0.15)
                            }
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [Color.black.opacity(0.45), Color.black.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                        // 顶栏 Chip 行 (100% 严格对齐生产基线: 左上角紧凑排列, 裸文字 + shadow, 绝无 Spacer 或托底胶囊)
                        HStack(spacing: 8) {
                            // 👈 动态注入的分类标签 (生产原版: 裸文字 + 阴影)
                            Text(data.englishLabel)
                                .font(fontForHeroCategory)
                                .foregroundStyle(AppTheme.Color.tab2HeroPhotoOverlayText)
                                .lineLimit(1)
                                .shadow(
                                    color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow),
                                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                    x: 0,
                                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                                )

                            // 理由胶囊 (生产原版: 紧随其后 spacing 8, 裸文字 + 阴影, 绝对不移到右上角)
                            let reasonState = Tab2CardLabels.reasonPillState(
                                lastMaterialAt: data.lastMaterialAt,
                                newMaterialCount: data.newMaterialCount
                            )
                            Text(reasonState.text)
                                .font(AppTheme.Font.tab2ReasonPill)
                                .foregroundStyle(AppTheme.Color.tab2ReasonPillOnPhotoText)
                                .lineLimit(1)
                                .shadow(
                                    color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow),
                                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                    x: 0,
                                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                                )
                        }
                        .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    }

                    // 卡身下半部
                    VStack(alignment: .leading, spacing: 0) {
                        Text("RECENT ACTIVITIES")
                            .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                            .tracking(0.99)
                            .foregroundStyle(AppTheme.Color.textMuted)

                        // 10pt 呼吸节奏
                        VStack(alignment: .leading, spacing: 6) {
                            if data.activities.isEmpty {
                                Tab2OnlyWordsSlot(metrics: Tab2ActivityCapsuleMetrics.hero())
                            } else {
                                HStack(spacing: 6) {
                                    ForEach(Array(data.activities.prefix(2).enumerated()), id: \.offset) { _, act in
                                        Text(act.sceneDetail)
                                            .font(AppTheme.Font.tab2HeroCapsuleName)
                                            .foregroundStyle(AppTheme.Color.textPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(AppTheme.Color.brandTint.opacity(0.35), in: Capsule())
                                    }
                                }
                                if data.activities.count > 2 {
                                    Text(data.activities[2].sceneDetail)
                                        .font(AppTheme.Font.tab2HeroCapsuleName)
                                        .foregroundStyle(AppTheme.Color.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppTheme.Color.brandTint.opacity(0.35), in: Capsule())
                                }
                            }
                        }
                        .padding(.top, AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) // 10pt

                        // 底部脚行
                        HStack(alignment: .center) {
                            Text(Tab2CardLabels.words(data.wordCount))
                                .font(AppTheme.Font.tab2HeroFootrowWords)
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .monospacedDigit()

                            Spacer()

                            HStack(spacing: 4) {
                                Text("Start talking")
                                Image(systemName: "arrow.right")
                            }
                            .font(AppTheme.Font.tab2HeroCTA)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black, in: Capsule())
                        }
                        .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
                    }
                    .padding(16)
                    .background(AppTheme.Color.warmGlassSurface)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                }
                .cardShadow()
            }
            .buttonStyle(.plain)
        }

        private var fontForHeroCategory: Font {
            switch proposal {
            case .baseline:  return Tab2CategoryTypographyProposalsPreview.gothicCustom(11.5, weightPostScript: "GothicA1-SemiBold", relativeTo: .caption2)
            case .proposalA: return AppTheme.Font.tab2HeroChipCategory // 方案 A（生产落地 Token: 13.0pt / 400）
            case .proposalB: return Tab2CategoryTypographyProposalsPreview.gothicCustom(13.0, weightPostScript: "GothicA1-Medium", relativeTo: .subheadline)
            case .proposalC: return Tab2CategoryTypographyProposalsPreview.gothicCustom(13.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .subheadline)
            }
        }
    }

    /// 方案定制版 More 推荐行
    private struct ProposalMoreRow: View {
        let data: Tab2CategoryData
        let proposal: Proposal
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 0) {
                    // 缩略图
                    Color.clear
                        .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                        .overlay {
                            if let coverUrl = data.activities.first?.cover?.imageUrl {
                                AsyncImage(url: URL(string: coverUrl)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Color(red: 0.88, green: 0.84, blue: 0.80)
                                    }
                                }
                            } else {
                                RowPresetThumb(category: SceneCategory.from(data.sceneCategory))
                            }
                        }
                        .clipped()

                    // 右侧内容
                    VStack(alignment: .leading, spacing: 0) {
                        // 帽行
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            // 👈 动态注入的分类帽标
                            Text(data.englishLabel)
                                .font(fontForMoreCategory)
                                .foregroundStyle(AppTheme.Color.textSecondary)

                            Spacer()

                            if let timeline = Tab2CardLabels.timeLine(lastMaterialAt: data.lastMaterialAt) {
                                Text(timeline)
                                    .font(AppTheme.Font.tab2MoreRowTimeline)
                                    .foregroundStyle(AppTheme.Color.neutralFaint)
                            }
                        }
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)

                        // 活动区 / 空态行 (10pt 呼吸间距)
                        VStack(alignment: .leading, spacing: 0) {
                            if data.activities.isEmpty {
                                Tab2OnlyWordsSlot(metrics: Tab2ActivityCapsuleMetrics.more())
                            } else {
                                HStack(spacing: 6) {
                                    ForEach(Array(data.activities.prefix(2).enumerated()), id: \.offset) { _, act in
                                        Text(act.sceneDetail)
                                            .font(AppTheme.Font.tab2MoreRowCapsuleName)
                                            .foregroundStyle(AppTheme.Color.textPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3.5)
                                            .background(AppTheme.Color.brandTint.opacity(0.3), in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity) // 10pt

                        // 末行词数 (10pt 呼吸间距)
                        HStack {
                            Text(Tab2CardLabels.words(data.wordCount))
                                .font(AppTheme.Font.tab2MoreRowMeta)
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .monospacedDigit()

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                        }
                        .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords) // 10pt
                    }
                    .padding(.vertical, AppTheme.Tab2MoreRow.Layout.contentTopInset)
                    .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
                }
                .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight)
                .background(AppTheme.Color.warmGlassSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                }
                .cardShadow()
            }
            .buttonStyle(.plain)
        }

        private var fontForMoreCategory: Font {
            switch proposal {
            case .baseline:  return Tab2CategoryTypographyProposalsPreview.gothicCustom(12.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .caption)
            case .proposalA: return AppTheme.Font.tab2MoreRowCategory // 方案 A（生产落地 Token: 13.0pt / 400）
            case .proposalB: return Tab2CategoryTypographyProposalsPreview.gothicCustom(13.0, weightPostScript: "GothicA1-Medium", relativeTo: .subheadline)
            case .proposalC: return Tab2CategoryTypographyProposalsPreview.gothicCustom(13.0, weightPostScript: "GothicA1-SemiBold", relativeTo: .subheadline)
            }
        }
    }

    /// 方案定制版 Topics 行
    private struct ProposalTopicsRow: View {
        let data: Tab2CategoryData
        let proposal: Proposal
        let isExpanded: Bool
        let onToggle: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Image(systemName: iconForCategory(data.sceneCategory))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                // 👈 动态注入的分类标题
                                Text(data.englishLabel)
                                    .font(AppTheme.Font.tab2TopicLabel)
                                    .foregroundStyle(AppTheme.Color.textPrimary)

                                Spacer()

                                Text("\(data.wordCount) words")
                                    .font(AppTheme.Font.tab2ProgressCount)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(AppTheme.Color.warmGlassSurface, in: Capsule())
                            }

                            // 进度微轨 (10pt 呼吸节奏间隙)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.06)).frame(height: 2)
                                    Capsule().fill(Color.orange.opacity(0.8)).frame(width: geo.size.width * 0.45, height: 2)
                                }
                            }
                            .frame(height: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("gadget")
                                .font(AppTheme.Font.tab2WordEntryTitle)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Text("n. 小配件；小设备")
                                .font(AppTheme.Font.tab2WordEntryMeaning)
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 48)
                        .padding(.bottom, 12)
                    }
                }
            }
        }

        private func iconForCategory(_ category: String) -> String {
            switch category {
            case "饮食与起居": return "fork.knife"
            case "科技数码": return "desktopcomputer"
            case "日常起居": return "house"
            case "运动健康": return "figure.run"
            case "社交出行": return "car.fill"
            default: return "sparkles"
            }
        }
    }

    /// 方案定制版 Explore 探索区块
    private struct ProposalExploreSection: View {
        let topics: [SceneCategory]
        let proposal: Proposal

        var body: some View {
            Tab2MoreTopicsSection(topics: topics)
        }
    }

    // MARK: - 测试数据集构建器 (Diverse Mock Data Scenarios)

    private var currentHeroData: Tab2CategoryData {
        switch selectedDataset {
        case .standard:
            return Tab2CategoryData(
                sceneCategory: "饮食与起居",
                wordCount: 18,
                unlocked: true,
                lastMaterialAt: Date(),
                activityCount: 3,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Cooking pasta",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-hero-1",
                            imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Morning pour-over", occurrenceCount: 1),
                    Tab2Activity(sceneDetail: "Baking bread", occurrenceCount: 1)
                ]
            )

        case .mixedEmpty:
            // 空态 Hero 卡
            return Tab2CategoryData(
                sceneCategory: "工作与学业",
                wordCount: 24,
                unlocked: true,
                lastMaterialAt: Date().addingTimeInterval(-10800),
                activityCount: 0,
                activities: []
            )

        case .edgeCase:
            // 长字符极端测试
            return Tab2CategoryData(
                sceneCategory: "饮食与起居",
                wordCount: 31,
                unlocked: true,
                lastMaterialAt: Date(),
                activityCount: 2,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Preparing afternoon espresso",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-hero-2",
                            imageUrl: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Tasting sourdough croissants", occurrenceCount: 1)
                ]
            )
        }
    }

    private var currentMoreRowsData: [Tab2CategoryData] {
        switch selectedDataset {
        case .standard:
            return [
                Tab2CategoryData(
                    sceneCategory: "日常起居",
                    wordCount: 42,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-7200),
                    activityCount: 3,
                    activities: [
                        Tab2Activity(
                            sceneDetail: "Fixing a device",
                            occurrenceCount: 2,
                            cover: Tab2Activity.Cover(
                                materialId: "m-row-1",
                                imageUrl: "https://images.unsplash.com/photo-1517404215738-15263e9f9178?w=400&auto=format&fit=crop&q=80"
                            )
                        ),
                        Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2)
                    ]
                ),
                Tab2CategoryData(
                    sceneCategory: "工作与学业",
                    wordCount: 22,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-86400 * 2),
                    activityCount: 0,
                    activities: [] // 空态：Only words so far
                )
            ]

        case .mixedEmpty:
            return [
                Tab2CategoryData(
                    sceneCategory: "娱乐与休闲",
                    wordCount: 36,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-14400),
                    activityCount: 2,
                    activities: [
                        Tab2Activity(
                            sceneDetail: "Streaming movie",
                            occurrenceCount: 1,
                            cover: Tab2Activity.Cover(
                                materialId: "m-row-2",
                                imageUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400&auto=format&fit=crop&q=80"
                            )
                        )
                    ]
                ),
                Tab2CategoryData(
                    sceneCategory: "日常起居",
                    wordCount: 15,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-86400 * 3),
                    activityCount: 0,
                    activities: []
                )
            ]

        case .edgeCase:
            return [
                Tab2CategoryData(
                    sceneCategory: "娱乐与休闲",
                    wordCount: 58,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-3600),
                    activityCount: 2,
                    activities: [
                        Tab2Activity(
                            sceneDetail: "Playing indie video games",
                            occurrenceCount: 3,
                            cover: Tab2Activity.Cover(
                                materialId: "m-row-3",
                                imageUrl: "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=400&auto=format&fit=crop&q=80"
                            )
                        )
                    ]
                ),
                Tab2CategoryData(
                    sceneCategory: "工作与学业",
                    wordCount: 19,
                    unlocked: true,
                    lastMaterialAt: Date().addingTimeInterval(-86400),
                    activityCount: 0,
                    activities: []
                )
            ]
        }
    }

    private var currentTopicsData: [Tab2CategoryData] {
        return [
            Tab2CategoryData(sceneCategory: "科技数码", wordCount: 16, unlocked: false, activityCount: 3),
            Tab2CategoryData(sceneCategory: "运动健康", wordCount: 9, unlocked: false, activityCount: 2)
        ]
    }

    private var currentExploreTopics: [SceneCategory] {
        return [.weather, .social, .gettingAround, .other]
    }
}

// MARK: - 预览提供器

#Preview("Tab2 分类标签三大优化方案与排版秩序沙盒") {
    Tab2CategoryTypographyProposalsPreview()
}
#endif
