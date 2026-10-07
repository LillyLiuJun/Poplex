#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 已解锁页面排版规范透视与全要素基线 (Tab2 Typography Inspection & Production Baseline)
//
// 🏛️ 架构与文档依据 (Architecture & Reference Documents)：
//   1. 《Agent内容组织与成长系统_PRD_v2.md》§十三：Tab2 视觉层重构与词汇资产台账（Lexicon Ledger）展现；
//   2. 《Tab2_探索区与待解锁态重构_需求与设计规格_v1.md》：双标题结构、呼吸间距与四分类生活区域探索规格；
//   3. 《AIEnglishApp/Theme/Theme.swift》Font 枚举规范：严格遵循 3-tier DTCG Token 架构，西文衬线 Charter（内容/大标题）、
//      现代无衬线 Gothic A1（系统骨架/操作/标签）、和风黑体 Hiragino Sans GB（中文释义）三大声部严谨协作。
//
// 🎯 核心工程职责与设计目标：
//   1. 100% 像素级真实承接生产环境已落地的最新排版与布局间距：
//      - 间距（Proposal B 10pt 呼吸节奏）：Hero sectionLabelToCapsules = 10pt，More categoryToActivity = 10pt，
//        More activityToWords = 10pt，Topics rowLabelToProgress = 10pt，组间距 paddingBetweenSections = 28pt；
//      - 样式容器：包含原生 Tab2HeroCard、Tab2ActivityRow、CategoryProgressRow（手风琴）、Tab2MoreTopicsSection 与 BottomAuraFooter。
//   2. 视觉标注标签（Callout Badges）生产级优雅呈现：
//      - 非遮挡式侧置/顶置引线标签：彻底告别粗暴覆盖被测文字，通过高亮轮廓（Highlight Halo）与指示锚点（Anchor Pin）精准指向，
//        让被测文字字形 100% 完整裸露，便于肉眼比对字形与字重；
//      - 双层专业标注信息：第一层「字号 + 字重」（如 11.5pt · SemiBold 600），第二层「字体家族 + Token 名称」（如 Gothic A1 · tab2HeroChipCategory）；
//      - 四种交互模式一键切换：
//        • 「四分类焦点透视」：聚焦 4 个 Section 的生活分类标签（SceneCategory）现状与割裂诊断；
//        • 「全页字阶全景」：全方位透视整页 11 种字阶层级（22pt 标题、13.5pt 胶囊、11.5pt 理由、11pt/11.5pt 时间与小标、12pt 词数、15pt CTA、15pt/12pt 词条）；
//        • 「四分类贴身对比」：在同一中性白底基准线下贴身对比 4 种分类标签的真实像素渲染；
//        • 「生产纯净态」：100% 生产无标注纯净视图。
//   3. 内嵌「全页字阶资产透视字典」（Spec Matrix Drawer）：直接在预览内提供全页 15 组 Font Token 的严谨对照表。

struct Tab2CategoryTypographyInspectionPreview: View {
    
    // MARK: - 模式枚举定义
    
    /// 预览视图展示模式
    enum ViewMode: String, CaseIterable, Identifiable {
        case categoryFocus      = "四分类焦点透视"
        case fullSpectrum       = "全页字阶全景"
        case isolatedComparison = "四分类贴身对比"
        case cleanProduction    = "生产纯净态"
        
        var id: String { rawValue }
    }

    // MARK: - 状态管理

    @State private var viewMode: ViewMode = .categoryFocus
    @State private var isAccordionExpanded: Bool = false
    @State private var showDiagnosisPanel: Bool = true
    @State private var showSpecMatrixSheet: Bool = false

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            // 控制顶栏
            controlHeader

            Divider().opacity(0.15)

            // 主体展示区
            switch viewMode {
            case .categoryFocus, .fullSpectrum, .cleanProduction:
                fullPageFlowView
            case .isolatedComparison:
                isolatedComparisonView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶部控制栏 (Control Header)

    private var controlHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Tab2 排版规范透视与基线")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text("10pt 呼吸节奏")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.brandInk)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(AppTheme.Color.brandTint, in: Capsule())
                    }
                    Text("严格镜像生产组件 · 非遮挡式引线标注 · 3-tier Token 体系")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                Spacer()

                // 功能切换按钮组
                HStack(spacing: 6) {
                    // 全页字阶字典呼出按钮
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSpecMatrixSheet.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: showSpecMatrixSheet ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                            Text("字阶字典")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(showSpecMatrixSheet ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(showSpecMatrixSheet ? AppTheme.Color.brandTint : AppTheme.Color.warmGlassSurface)
                                .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)

                    // 诊断卡展开/收起按钮
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDiagnosisPanel.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: showDiagnosisPanel ? "chevron.up.circle.fill" : "chevron.down.circle")
                            Text(showDiagnosisPanel ? "收起诊断" : "四维诊断")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(showDiagnosisPanel ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(showDiagnosisPanel ? AppTheme.Color.brandTint : AppTheme.Color.warmGlassSurface)
                                .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // 模式选择分段控制器
            Picker("查看模式", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 四维诊断面板 (展开时显示)
            if showDiagnosisPanel && viewMode != .isolatedComparison {
                diagnosisSummaryCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 全页字阶字典抽屉 (展开时显示)
            if showSpecMatrixSheet {
                fullPageSpecMatrixCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.warmGlassSurface)
    }

    // MARK: - 四维分类标签现状诊断卡 (Diagnosis Summary Card)

    private var diagnosisSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.orange)
                    Text("生产环境 4 个 Section 分类标签 (SceneCategory) 排印割裂现状")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                Spacer()
                Text("4 个区块 · 3 种字号 · 2 种字重")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.red.opacity(0.85))
            }

            HStack(spacing: 6) {
                diagnosisChip(
                    num: "1",
                    section: "Hero 封面标签",
                    size: "11.5pt",
                    weight: "SemiBold 600",
                    family: "Gothic A1",
                    token: "tab2HeroChipCategory",
                    color: Color.purple
                )
                diagnosisChip(
                    num: "2",
                    section: "More 推荐帽标",
                    size: "12.0pt",
                    weight: "SemiBold 600",
                    family: "Gothic A1",
                    token: "tab2MoreRowCategory",
                    color: Color.blue
                )
                diagnosisChip(
                    num: "3",
                    section: "Topics 列表行首",
                    size: "13.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    token: "tab2TopicLabel",
                    color: Color.teal
                )
                diagnosisChip(
                    num: "4",
                    section: "Explore 探索胶囊",
                    size: "13.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    token: "tab2ExploreTagLabel",
                    color: Color.orange
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func diagnosisChip(
        num: String,
        section: String,
        size: String,
        weight: String,
        family: String,
        token: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(num)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 12, height: 12)
                    .background(color, in: Circle())
                Text(section)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineLimit(1)
            }

            Text(size)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)

            Text(weight)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text(token)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 全页字阶资产透视字典 (Full Page Spec Matrix Card)

    private var fullPageSpecMatrixCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Color.brandInk)
                    Text("Tab2 已解锁页面排版资产全要素规范 (Theme.swift Font Tokens)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                Spacer()
                Text("共 15 组规范 Token")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            VStack(spacing: 4) {
                specMatrixRow(
                    tier: "大区小标题",
                    token: "sectionTitleSerif",
                    size: "22.0pt",
                    weight: "Bold 700",
                    family: "Charter 衬线",
                    relativeTo: ".title2",
                    usage: "4 个 Section 统领标题 (Talk about today 等)"
                )
                specMatrixRow(
                    tier: "Hero 胶囊名",
                    token: "tab2HeroCapsuleName",
                    size: "13.5pt",
                    weight: "Regular 400",
                    family: "Charter 衬线",
                    relativeTo: ".subheadline",
                    usage: "Hero 照片下半部活动胶囊名 (Cooking pasta)"
                )
                specMatrixRow(
                    tier: "More 胶囊名",
                    token: "tab2MoreRowCapsuleName",
                    size: "12.0pt",
                    weight: "Regular 400",
                    family: "Charter 衬线",
                    relativeTo: ".footnote",
                    usage: "More 推荐行活动胶囊名 (Fixing a device)"
                )
                specMatrixRow(
                    tier: "手风琴词条",
                    token: "tab2WordEntryTitle",
                    size: "15.0pt",
                    weight: "Bold 700",
                    family: "Charter 衬线",
                    relativeTo: ".subheadline",
                    usage: "Topics 展开后词条单词 (gadget)"
                )
                specMatrixRow(
                    tier: "活动区小标",
                    token: "tab2HeroActivitySectionLabel",
                    size: "11.0pt",
                    weight: "SemiBold 600",
                    family: "Gothic A1 (大写)",
                    relativeTo: ".caption2",
                    usage: "Hero 卡「RECENT ACTIVITIES」小标题"
                )
                specMatrixRow(
                    tier: "空态说明行",
                    token: "tab2EmptyStateLine",
                    size: "13.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    relativeTo: ".footnote",
                    usage: "More/Hero 无活动空态「Only words so far」"
                )
                specMatrixRow(
                    tier: "More 戳记时间",
                    token: "tab2MoreRowTimeline",
                    size: "11.5pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    relativeTo: ".caption2",
                    usage: "More 卡右上角时间「Added 2 days ago」"
                )
                specMatrixRow(
                    tier: "More 词数统计",
                    token: "tab2MoreRowMeta",
                    size: "12.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1 (等宽数)",
                    relativeTo: ".caption",
                    usage: "More 卡左下角词数统计「22 words」"
                )
                specMatrixRow(
                    tier: "Hero 词数统计",
                    token: "tab2HeroFootrowWords",
                    size: "13.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1 (等宽数)",
                    relativeTo: ".footnote",
                    usage: "Hero 左下角词数统计「18 words」"
                )
                specMatrixRow(
                    tier: "Hero 操作按钮",
                    token: "tab2HeroCTA",
                    size: "15.0pt",
                    weight: "SemiBold 600",
                    family: "Gothic A1",
                    relativeTo: ".subheadline",
                    usage: "Hero 右下角主操作「Start talking →」"
                )
                specMatrixRow(
                    tier: "Topics 词数",
                    token: "tab2ProgressCount",
                    size: "12.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    relativeTo: ".caption",
                    usage: "Topics 进度行词数统计 (16 words)"
                )
                specMatrixRow(
                    tier: "品牌宣言/注脚",
                    token: "metaNote",
                    size: "11.0pt",
                    weight: "Regular 400",
                    family: "Gothic A1",
                    relativeTo: ".caption2",
                    usage: "页脚灵感宣言 (Every word grounded...)"
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func specMatrixRow(
        tier: String,
        token: String,
        size: String,
        weight: String,
        family: String,
        relativeTo: String,
        usage: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(tier)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(width: 64, alignment: .leading)

            Text(size)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Color.brandInk)
                .frame(width: 44, alignment: .leading)

            Text(weight)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 72, alignment: .leading)

            Text(family)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 74, alignment: .leading)

            Text(usage)
                .font(.system(size: 8.5))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - 模式 1 & 2: 全真滚动流 (含非遮挡式引线标注系统)

    private var fullPageFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // 生产真实内容流 (严格镜像 MineView.swift -> contentSections)
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                    
                    // ── 组 1: Talk about today ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("Talk about today", sectionIndex: 1)

                        // 生产 Hero 卡
                        Tab2HeroCard(
                            category: mockHeroData,
                            onTalk: {}
                        )
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .overlay(alignment: .top) {
                            // Section 1 标注覆盖层
                            if viewMode == .categoryFocus || viewMode == .fullSpectrum {
                                heroCalloutLayer
                            }
                        }
                    }

                    // ── 组 2: More to talk about ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("More to talk about", sectionIndex: 2)

                        VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                            // 推荐行 1
                            Tab2ActivityRow(
                                category: mockMoreRowData,
                                onTap: {}
                            )
                            .overlay(alignment: .top) {
                                if viewMode == .categoryFocus || viewMode == .fullSpectrum {
                                    moreRowCalloutLayer
                                }
                            }

                            // 推荐行 2 (空态 - 对应截图 1：Work & Study)
                            Tab2ActivityRow(
                                category: mockMoreEmptyRowData,
                                onTap: {}
                            )
                            .overlay(alignment: .top) {
                                if viewMode == .fullSpectrum {
                                    moreEmptyRowCalloutLayer
                                }
                            }
                        }
                    }

                    // ── 组 3: Topics in progress (包装在 surfaceCard 卡盒内) ──
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                        sectionTitleHeader("Topics in progress", sectionIndex: 3)

                        // 生产卡盒容器
                        VStack(spacing: 0) {
                            CategoryProgressRow(
                                category: mockProgressRowData1,
                                isExpanded: isAccordionExpanded,
                                onToggle: {
                                    withAnimation(AppTheme.Motion.accordionToggle) {
                                        isAccordionExpanded.toggle()
                                    }
                                },
                                loadWords: { mockWordsForLiving },
                                wordsRevision: 1
                            )
                            .overlay(alignment: .top) {
                                if viewMode == .categoryFocus || viewMode == .fullSpectrum {
                                    topicsRowCalloutLayer
                                }
                            }

                            Divider().padding(.horizontal, AppTheme.Space.paddingPage)

                            CategoryProgressRow(
                                category: mockProgressRowData2,
                                isExpanded: false,
                                onToggle: {},
                                loadWords: { [] },
                                wordsRevision: 0
                            )
                        }
                        .padding(.vertical, AppTheme.Space.paddingS)
                        .surfaceCard(cornerRadius: AppTheme.Radius.large)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                    }

                    // ── 组 4: More topics to explore (原生生产组件) ──
                    VStack(alignment: .leading, spacing: 0) {
                        Tab2MoreTopicsSection(
                            topics: [.weather, .social, .gettingAround, .other]
                        )
                        .overlay(alignment: .top) {
                            if viewMode == .categoryFocus || viewMode == .fullSpectrum {
                                exploreSectionCalloutLayer
                            }
                        }
                    }
                }
                .padding(.top, AppTheme.Space.tab2ContentTop) // 4pt

                // ════ 页脚留白与品牌宣言 ════
                Spacer(minLength: AppTheme.Space.tab2FooterTop) // 96pt

                footerSignoff
                    .padding(.bottom, AppTheme.Space.tab2FooterBottom) // 52pt
            }
            .background(alignment: .bottom) {
                BottomAuraFooter()
            }
        }
    }

    // MARK: - 精准标注覆盖层 (非遮挡式引线系统)

    /// Section 1: Hero 卡片的非遮挡引线标注层 (严格覆盖截图 2 中所有元素)
    private var heroCalloutLayer: some View {
        ZStack(alignment: .topLeading) {
            // 标注 1: Food & Drink 分类标签 (右上侧置，指引左上角 chip)
            nonObstructiveBadge(
                tagNum: "1",
                targetName: "Food & Drink (分类标签)",
                specText: "11.5pt · SemiBold (600)",
                tokenText: "Gothic A1 · tab2HeroChipCategory",
                color: .purple,
                pinX: 68,
                pinY: 28,
                badgeX: 130,
                badgeY: 10
            )

            // 全景模式下展示截图 2 中的全套排印
            if viewMode == .fullSpectrum {
                // 标注: 理由胶囊 (Added 3 times today)
                nonObstructiveBadge(
                    tagNum: "H1",
                    targetName: "Reason Pill (理由胶囊)",
                    specText: "11.5pt · Medium (500)",
                    tokenText: "Gothic A1 · tab2ReasonPill",
                    color: Color.brown,
                    pinX: 300,
                    pinY: 28,
                    badgeX: 200,
                    badgeY: 48
                )

                // 标注: RECENT ACTIVITIES 区块小标题 (截图 2 顶部)
                nonObstructiveBadge(
                    tagNum: "H2",
                    targetName: "RECENT ACTIVITIES (小标)",
                    specText: "11.0pt · SemiBold (600) · 大写",
                    tokenText: "Gothic A1 · tab2HeroActivitySectionLabel",
                    color: Color.pink,
                    pinX: 70,
                    pinY: 168,
                    badgeX: 145,
                    badgeY: 156
                )

                // 标注: 活动胶囊名 (Cooking pasta / Morning pour-over)
                nonObstructiveBadge(
                    tagNum: "H3",
                    targetName: "Capsule Name (活动名)",
                    specText: "13.5pt · Regular (400)",
                    tokenText: "Charter · tab2HeroCapsuleName",
                    color: Color.indigo,
                    pinX: 90,
                    pinY: 202,
                    badgeX: 175,
                    badgeY: 190
                )

                // 标注: 词数统计 (18 words)
                nonObstructiveBadge(
                    tagNum: "H4",
                    targetName: "Footrow Words (词数)",
                    specText: "13.0pt · Regular (400)",
                    tokenText: "Gothic A1 (等宽数) · tab2HeroFootrowWords",
                    color: Color.gray,
                    pinX: 50,
                    pinY: 268,
                    badgeX: 110,
                    badgeY: 256
                )

                // 标注: 主操作按钮 (Start talking →)
                nonObstructiveBadge(
                    tagNum: "H5",
                    targetName: "Start talking → (主操作CTA)",
                    specText: "15.0pt · SemiBold (600)",
                    tokenText: "Gothic A1 · tab2HeroCTA",
                    color: Color.orange,
                    pinX: 280,
                    pinY: 268,
                    badgeX: 170,
                    badgeY: 290
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Section 2: More 推荐行 1（有活动态）的非遮挡引线标注层
    private var moreRowCalloutLayer: some View {
        ZStack(alignment: .topLeading) {
            // 标注 2: Daily Routine 分类帽标
            nonObstructiveBadge(
                tagNum: "2",
                targetName: "Daily Routine (分类帽标)",
                specText: "12.0pt · SemiBold (600)",
                tokenText: "Gothic A1 · tab2MoreRowCategory",
                color: .blue,
                pinX: 140,
                pinY: 18,
                badgeX: 195,
                badgeY: 6
            )

            if viewMode == .fullSpectrum {
                // 标注: More 胶囊活动名
                nonObstructiveBadge(
                    tagNum: "M1",
                    targetName: "Capsule Name (活动名)",
                    specText: "12.0pt · Regular (400)",
                    tokenText: "Charter · tab2MoreRowCapsuleName",
                    color: Color.indigo,
                    pinX: 140,
                    pinY: 52,
                    badgeX: 215,
                    badgeY: 42
                )

                // 标注: 词数统计 (42 words)
                nonObstructiveBadge(
                    tagNum: "M2",
                    targetName: "Words (词数)",
                    specText: "12.0pt · Regular (400)",
                    tokenText: "Gothic A1 (等宽数) · tab2MoreRowMeta",
                    color: Color.gray,
                    pinX: 140,
                    pinY: 96,
                    badgeX: 200,
                    badgeY: 86
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Section 2: More 推荐行 2（空态行 - 严格覆盖截图 1 中所有元素）的非遮挡引线标注层
    private var moreEmptyRowCalloutLayer: some View {
        ZStack(alignment: .topLeading) {
            // 标注: Work & Study 分类帽标 (截图 1)
            nonObstructiveBadge(
                tagNum: "E1",
                targetName: "Work & Study (分类帽标)",
                specText: "12.0pt · SemiBold (600)",
                tokenText: "Gothic A1 · tab2MoreRowCategory",
                color: .blue,
                pinX: 140,
                pinY: 18,
                badgeX: 195,
                badgeY: 6
            )

            // 标注: Added 2 days ago (时间戳 - 截图 1 右上角)
            nonObstructiveBadge(
                tagNum: "E2",
                targetName: "Added 2 days ago (时间戳)",
                specText: "11.5pt · Regular (400)",
                tokenText: "Gothic A1 · tab2MoreRowTimeline",
                color: Color.purple,
                pinX: 300,
                pinY: 18,
                badgeX: 180,
                badgeY: 34
            )

            // 标注: Only words so far (空态说明行 - 截图 1 中间)
            nonObstructiveBadge(
                tagNum: "E3",
                targetName: "Only words so far (空态行)",
                specText: "13.0pt · Regular (400)",
                tokenText: "Gothic A1 · tab2EmptyStateLine",
                color: Color.orange,
                pinX: 140,
                pinY: 52,
                badgeX: 200,
                badgeY: 56
            )

            // 标注: 22 words (词数统计 - 截图 1 左下角)
            nonObstructiveBadge(
                tagNum: "E4",
                targetName: "22 words (词数统计)",
                specText: "12.0pt · Regular (400)",
                tokenText: "Gothic A1 (等宽数) · tab2MoreRowMeta",
                color: Color.gray,
                pinX: 140,
                pinY: 96,
                badgeX: 200,
                badgeY: 90
            )
        }
        .allowsHitTesting(false)
    }

    /// Section 3: Topics 进度行卡片的非遮挡引线标注层
    private var topicsRowCalloutLayer: some View {
        ZStack(alignment: .topLeading) {
            // 标注 3: Digital Life 分类行首标题
            nonObstructiveBadge(
                tagNum: "3",
                targetName: "Digital Life (分类标题)",
                specText: "13.0pt · Regular (400)",
                tokenText: "Gothic A1 · tab2TopicLabel",
                color: .teal,
                pinX: 85,
                pinY: 20,
                badgeX: 155,
                badgeY: 6
            )

            if viewMode == .fullSpectrum {
                // 标注: 进度词数
                nonObstructiveBadge(
                    tagNum: "T1",
                    targetName: "Words Count (词数)",
                    specText: "12.0pt · Regular (400)",
                    tokenText: "Gothic A1 · tab2ProgressCount",
                    color: Color.gray,
                    pinX: 310,
                    pinY: 20,
                    badgeX: 210,
                    badgeY: 34
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Section 4: Explore 探索流的非遮挡引线标注层
    private var exploreSectionCalloutLayer: some View {
        ZStack(alignment: .topLeading) {
            // 标注 4: Weather 胶囊分类名
            nonObstructiveBadge(
                tagNum: "4",
                targetName: "Weather (探索胶囊名)",
                specText: "13.0pt · Regular (400)",
                tokenText: "Gothic A1 · tab2ExploreTagLabel",
                color: .orange,
                pinX: 58,
                pinY: 66,
                badgeX: 130,
                badgeY: 52
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - 核心标注气泡组件 (Non-obstructive Callout Badge)

    /// 专业非遮挡引线标注徽章
    private func nonObstructiveBadge(
        tagNum: String,
        targetName: String,
        specText: String,
        tokenText: String,
        color: Color,
        pinX: CGFloat,
        pinY: CGFloat,
        badgeX: CGFloat,
        badgeY: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // 指示锚点脉冲圈 (Anchor Pin)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: color.opacity(0.8), radius: 2)
                .offset(x: pinX - 3, y: pinY - 3)

            // 引线与标注气泡实体
            HStack(spacing: 5) {
                // 编号圆点
                Text(tagNum)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 14, height: 14)
                    .background(color, in: Circle())

                // 核心规格说明
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(specText)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                        Text(targetName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(color.opacity(0.95))
                    }
                    Text(tokenText)
                        .font(.system(size: 7.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.07).opacity(0.95))
                    .overlay(Capsule().strokeBorder(color.opacity(0.85), lineWidth: 1.0))
            )
            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
            .offset(x: badgeX, y: badgeY)
        }
    }

    // MARK: - 模式 3: 四大分类标签贴身横向对比 (Isolated View)

    private var isolatedComparisonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("四分类标签贴身等距排印对比")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("同一词条「Food & Drink」在 4 个生产组件中的实际渲染形态（已剥离背景与杂质）：")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 14) {
                    isolatedRow(
                        num: "1",
                        source: "Hero 封面顶标",
                        spec: "11.5pt · SemiBold (600)",
                        token: "tab2HeroChipCategory",
                        role: "照片内浮层标签",
                        color: .purple
                    ) {
                        Text("Food & Drink")
                            .font(AppTheme.Font.tab2HeroChipCategory)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }

                    isolatedRow(
                        num: "2",
                        source: "More 推荐行帽标",
                        spec: "12.0pt · SemiBold (600)",
                        token: "tab2MoreRowCategory",
                        role: "卡头分类元数据",
                        color: .blue
                    ) {
                        Text("Food & Drink")
                            .font(AppTheme.Font.tab2MoreRowCategory)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }

                    isolatedRow(
                        num: "3",
                        source: "Topics 行首标题",
                        spec: "13.0pt · Regular (400)",
                        token: "tab2TopicLabel",
                        role: "列表主条目行名",
                        color: .teal
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(AppTheme.Color.textMuted)
                            Text("Food & Drink")
                                .font(AppTheme.Font.tab2TopicLabel)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        }
                    }

                    isolatedRow(
                        num: "4",
                        source: "Explore 探索胶囊",
                        spec: "13.0pt · Regular (400)",
                        token: "tab2ExploreTagLabel",
                        role: "未开启生活胶囊",
                        color: .orange
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 13.5, weight: .regular))
                            Text("Food & Drink")
                                .font(AppTheme.Font.tab2ExploreTagLabel)
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

    private func isolatedRow<Content: View>(
        num: String,
        source: String,
        spec: String,
        token: String,
        role: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Text(num)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 14, height: 14)
                        .background(color, in: Circle())
                    Text(source)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("(\(role))")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                Spacer()

                Text(spec)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1), in: Capsule())
            }

            HStack {
                content()
                Spacer()
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))

            Text("Token: AppTheme.Font.\(token)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .fill(AppTheme.Color.warmGlassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                        .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - 辅助子视图组件 (Auxiliary Components)

    /// 大区分区标题头部 (带全景模式标注)
    private func sectionTitleHeader(_ title: String, sectionIndex: Int) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            if viewMode == .fullSpectrum {
                Text("22pt · Bold (700) · Charter")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.brandInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Color.brandTint, in: Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 页面底部品牌收口
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

    // MARK: - Mock 数据源 (对齐生产级场景)

    private var mockHeroData: Tab2CategoryData {
        Tab2CategoryData(
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
    }

    private var mockMoreRowData: Tab2CategoryData {
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
                Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Cleaning room", occurrenceCount: 1)
            ]
        )
    }

    private var mockMoreEmptyRowData: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "工作与学业",
            wordCount: 22,
            unlocked: true,
            lastMaterialAt: Date().addingTimeInterval(-86400 * 2),
            activityCount: 0,
            activities: []
        )
    }

    private var mockProgressRowData1: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "科技数码",
            wordCount: 16,
            unlocked: false,
            activityCount: 3
        )
    }

    private var mockProgressRowData2: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "运动健康",
            wordCount: 9,
            unlocked: false,
            activityCount: 2
        )
    }

    private var mockWordsForLiving: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "gadget", displayForm: "gadgets", entryKind: "word", pos: "n.", granularity: "sentence", sourceType: "material", sampleSentence: "I have quite a few smart gadgets on my desk.", nativeMeaning: "小配件；小设备", imageUrl: nil),
            Tab2WordEntry(lemma: "thermos", displayForm: "thermos", entryKind: "word", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: nil, nativeMeaning: "保温杯", imageUrl: nil)
        ]
    }
}

// MARK: - 预览提供器

#Preview("Tab2 分类字体现状与方案基线") {
    Tab2CategoryTypographyInspectionPreview()
}
#endif
