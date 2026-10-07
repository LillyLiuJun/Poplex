#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 解锁后全要素像素级透视与统一性标尺预览 (Tab2 Full Spec Inspection Preview)
// 🎯 核心目标：
//   1. 100% 绝对像素级引用当前生产环境（MineView.swift -> contentSections）的真实布局结构与 Token；
//   2. 彻底移除所有非生产的人造伪标题，原汁原味还原：
//      - Talk about today (22pt 衬线大标 + 16pt 间距 + Tab2HeroCard)
//      - More to talk about (22pt 衬线大标 + 16pt 间距 + Tab2ActivityRow 列表，行间距 16pt)
//      - Topics in progress (22pt 衬线大标 + 16pt 间距 + .surfaceCard 磨砂白卡盒容器 + CategoryProgressRow)
//      - More topics to explore (Tab2MoreTopicsSection 原生生产组件，标题下距 16pt，胶囊高 30pt)
//      - 组与组之间严格走生产规范：paddingBetweenSections = 28pt；
//      - 顶部 padding：tab2ContentTop = 4pt；
//      - 页脚宣言前留白：tab2FooterTop = 96pt；
//   3. 标尺透视系统：在组与组之间、标题与内容之间、容器内边距上，用精准的物理标尺引线与气泡进行 1:1 测量标注。

struct Tab2FullSpecInspectionPreview: View {
    enum ViewMode: String, CaseIterable, Identifiable {
        case clean = "生产纯净态"
        case interRulers = "组与组间距"
        case intraRulers = "组内微间距"
        case fullSpec = "全要素透视"
        var id: String { rawValue }
    }

    @State private var viewMode: ViewMode = .intraRulers
    @State private var isAccordionExpanded: Bool = false

    private var showInterRulers: Bool {
        viewMode == .interRulers || viewMode == .fullSpec
    }

    private var showIntraRulers: Bool {
        viewMode == .intraRulers || viewMode == .fullSpec
    }

    private var showBadges: Bool {
        viewMode == .fullSpec
    }

    var body: some View {
        VStack(spacing: 0) {
            // 控制顶栏
            controlHeader

            Divider().opacity(0.15)

            // 生产真实滚动容器（100% 生产架构，绝不插入破坏排版的伪占位组件）
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ════ 生产核心内容流 (100% 镜像 MineView.swift -> contentSections) ════
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                        
                        // ── 组 1: Talk about today ──
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            sectionTitleHeader("Talk about today", badge: "22pt/700 (Charter)")
                                .overlay(alignment: .bottom) {
                                    if showInterRulers {
                                        intraGroupRuler(height: AppTheme.Space.paddingCard, label: "paddingCard: 16pt (标题→卡片)")
                                    }
                                }

                            // 生产 Hero 卡
                            Tab2HeroCard(
                                category: mockHeroData,
                                onTalk: {}
                            )
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .overlay {
                                if showIntraRulers {
                                    heroIntraRulersOverlay
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                if showBadges {
                                    specBubble("11.5pt/600 · tab2HeroChipCategory", x: 36, y: 16)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if showBadges {
                                    specBubble("理由胶囊 11.5pt/500 · H:22", x: -36, y: 16)
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                if showBadges {
                                    specBubble("胶囊 13.5pt · H:23 槽高:52 · 词数 13pt", x: 36, y: -16)
                                }
                            }
                        }
                        .overlay(alignment: .bottom) {
                            // 组间距标尺 1: 零位移原位卡尺（填充在 VStack spacing 的 28pt 槽位中，不撑大高度）
                            if showInterRulers {
                                interGroupRuler(label: "组与组间距 paddingBetweenSections: 28pt")
                            }
                        }

                        // ── 组 2: More to talk about ──
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            sectionTitleHeader("More to talk about", badge: "22pt/700 (Charter)")
                                .overlay(alignment: .bottom) {
                                    if showInterRulers {
                                        intraGroupRuler(height: AppTheme.Space.paddingCard, label: "paddingCard: 16pt (标题→列表)")
                                    }
                                }

                            VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                                // 推荐行 1
                                Tab2ActivityRow(
                                    category: mockMoreRowData,
                                    onTap: {}
                                )
                                .overlay {
                                    if showIntraRulers {
                                        moreRowIntraRulersOverlay
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if showBadges {
                                        specBubble("帽行 12pt/600 · 时间 11.5pt", x: 96, y: 12)
                                    }
                                }
                                .overlay(alignment: .center) {
                                    if showBadges {
                                        specBubble("胶囊 12pt · H:20 槽高:45 · 顶距 9.5", x: 40, y: 0)
                                    }
                                }
                                .overlay(alignment: .bottomLeading) {
                                    if showBadges {
                                        specBubble("末行 12pt/400 · minHeight: 119pt", x: 96, y: -10)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if showIntraRulers {
                                        intraGroupRuler(height: AppTheme.Tab2MoreRow.Layout.rowGap, label: "rowGap: 16pt (行与行之间)")
                                    }
                                }

                                // 推荐行 2
                                Tab2ActivityRow(
                                    category: mockMoreEmptyRowData,
                                    onTap: {}
                                )
                                .overlay(alignment: .center) {
                                    if showBadges {
                                        specBubble("空态等高 119pt · 槽位 45pt", x: 40, y: 0)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                        }
                        .overlay(alignment: .bottom) {
                            // 组间距标尺 2: 零位移原位卡尺
                            if showInterRulers {
                                interGroupRuler(label: "组与组间距 paddingBetweenSections: 28pt")
                            }
                        }

                        // ── 组 3: Topics in progress (生产规范：包装在 surfaceCard 磨砂白卡盒内) ──
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                            sectionTitleHeader("Topics in progress", badge: "22pt/700 (Charter)")
                                .overlay(alignment: .bottom) {
                                    if showInterRulers {
                                        intraGroupRuler(height: AppTheme.Space.paddingCard, label: "paddingCard: 16pt (标题→卡盒)")
                                    }
                                }

                            // 生产卡盒容器 (VStack padding.vertical 8pt + surfaceCard)
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
                                .overlay(alignment: .leading) {
                                    if showBadges {
                                        specBubble("分类 13pt/400 · 图标 14pt (20×20槽)", x: 20, y: -10)
                                    }
                                }
                                .overlay(alignment: .trailing) {
                                    if showBadges {
                                        specBubble("Words胶囊 12pt (内衬 7/2.5) · 轨 1.5pt", x: -20, y: 6)
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
                            .padding(.vertical, AppTheme.Space.paddingS) // 8pt
                            .surfaceCard(cornerRadius: AppTheme.Radius.large) // 20pt
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .overlay {
                                if showIntraRulers {
                                    topicsCardIntraRulersOverlay
                                }
                            }
                            .overlay(alignment: .top) {
                                if showInterRulers {
                                    cardInnerPaddingRuler(label: "卡盒内边距 paddingS: 8pt (顶内衬)")
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if showInterRulers {
                                    cardInnerPaddingRuler(label: "卡盒内边距 paddingS: 8pt (底内衬)", isBottom: true)
                                }
                            }
                        }
                        .overlay(alignment: .bottom) {
                            // 组间距标尺 3: 零位移原位卡尺
                            if showInterRulers {
                                interGroupRuler(label: "组与组间距 paddingBetweenSections: 28pt")
                            }
                        }

                        // ── 组 4: More topics to explore (原生生产组件) ──
                        Tab2MoreTopicsSection(
                            topics: [.weather, .social, .gettingAround, .other]
                        )
                        .overlay {
                            if showIntraRulers {
                                exploreIntraRulersOverlay
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if showBadges {
                                specBubble("探索大标 22pt/700 · 下距 16pt (titleToTags)", x: -20, y: 2)
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            if showBadges {
                                specBubble("探索胶囊 13pt/400 · H:30pt · 内衬:13pt · 图标:13.5pt", x: 20, y: -4)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Space.tab2ContentTop) // 4pt 首标顶边距
                    .overlay(alignment: .top) {
                        if showInterRulers {
                            topClearanceRuler(height: AppTheme.Space.tab2ContentTop, label: "tab2ContentTop: 4pt")
                        }
                    }

                    // ════ 页脚留白与品牌宣言 (96pt 呼吸断层 + 52pt 踏光底衬) ════
                    Spacer(minLength: AppTheme.Space.tab2FooterTop)
                        .overlay(alignment: .center) {
                            if showInterRulers {
                                footerSpacerRuler(height: AppTheme.Space.tab2FooterTop, label: "页脚推底断层 tab2FooterTop: 96pt")
                            }
                        }

                    footerSignoff
                        .padding(.bottom, AppTheme.Space.tab2FooterBottom) // 52pt
                        .overlay(alignment: .bottom) {
                            if showInterRulers {
                                footerBottomRuler(height: AppTheme.Space.tab2FooterBottom, label: "踏光安全底衬 tab2FooterBottom: 52pt")
                            }
                        }
                }
                .background(alignment: .bottom) {
                    BottomAuraFooter()
                }
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
        }
    }

    // MARK: - 标题行与标尺定位

    private func sectionTitleHeader(_ title: String, badge: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)

            if showBadges {
                specBubble(badge, x: 8, y: 0)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 组内微间距卡尺系统 (Intra-Group Horizontal Ruler Lines & Calipers)

    /// 真实横线标尺 (带上下两条贯穿横线引线与半透明色槽，绝不截断文本)
    private func horizontalGapRuler(
        width: CGFloat,
        height: CGFloat,
        label: String,
        color: Color = .blue,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        ZStack {
            // 间距着色高亮带
            Rectangle()
                .fill(color.opacity(0.12))
                .frame(width: width, height: max(height, 2))

            // 上下两条横向界线 (横线标尺)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(color.opacity(0.85))
                    .frame(width: width, height: 1.0)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(color.opacity(0.85))
                    .frame(width: width, height: 1.0)
            }
            .frame(width: width, height: max(height, 2))

            // 居中文本徽标（固定尺寸、字迹清晰、绝不换行截断）
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 7.5, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.06).opacity(0.95))
                    .overlay(Capsule().strokeBorder(color, lineWidth: 1.0))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
            .fixedSize(horizontal: true, vertical: false) // 关键：绝对禁止任何截断！
        }
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    /// 水平跨度标尺 (例如 76pt 缩略图宽)
    private func horizontalSpanRuler(
        width: CGFloat,
        height: CGFloat = 20,
        label: String,
        color: Color = .orange,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(color.opacity(0.10))
                .frame(width: width, height: height)

            HStack(spacing: 0) {
                Rectangle().fill(color.opacity(0.85)).frame(width: 1.0, height: height)
                Spacer(minLength: 0)
                Rectangle().fill(color.opacity(0.85)).frame(width: 1.0, height: height)
            }
            .frame(width: width, height: height)

            HStack(spacing: 3) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 7.5, weight: .bold))
                Text(label)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.06).opacity(0.95))
                    .overlay(Capsule().strokeBorder(color, lineWidth: 0.8))
            )
            .fixedSize(horizontal: true, vertical: false)
        }
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    /// Hero 卡片组内微间距透视 (带横线标尺)
    private var heroIntraRulersOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let contentW = w - 36
            let centerX = w / 2

            // 计算各部件垂直起点
            let bodyTopY = AppTheme.Tab2Hero.Layout.artHeight + AppTheme.Tab2Hero.Layout.artTextOverlap // 150 - 14 = 136
            let seclabBottomY = bodyTopY + AppTheme.Tab2Hero.Layout.bodyTopInset + 14 // 136 + 16 + 14 = 166
            let capsuleSlotY = seclabBottomY + AppTheme.Tab2Hero.Layout.sectionLabelToCapsules // 166 + 9 = 175
            let ctaGapY = capsuleSlotY + 52 // 175 + 52 = 227
            let ctaBottomY = ctaGapY + AppTheme.Tab2Hero.Layout.activityToCTA // 227 + 16 = 243

            ZStack {
                // 1. 卡身文字区顶衬 16pt (上叠穿透点)：横跨整张卡片
                horizontalGapRuler(
                    width: w,
                    height: AppTheme.Tab2Hero.Layout.bodyTopInset,
                    label: "16pt · 文字区顶衬 (bodyTopInset)",
                    color: .blue,
                    x: centerX,
                    y: bodyTopY + AppTheme.Tab2Hero.Layout.bodyTopInset / 2
                )

                // 2. 小标到胶囊 (横跨正文内容区)
                horizontalGapRuler(
                    width: contentW,
                    height: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules,
                    label: "\(formatPt(AppTheme.Tab2Hero.Layout.sectionLabelToCapsules)) · 小标→胶囊 (sectionLabelToCapsules)",
                    color: .purple,
                    x: centerX,
                    y: seclabBottomY + AppTheme.Tab2Hero.Layout.sectionLabelToCapsules / 2
                )

                // 3. 胶囊双行槽位 52pt
                horizontalGapRuler(
                    width: contentW,
                    height: 52,
                    label: "52pt · 胶囊双行恒定槽位",
                    color: .teal,
                    x: centerX,
                    y: capsuleSlotY + 26
                )

                // 4. 胶囊到 CTA 间距 16pt
                horizontalGapRuler(
                    width: contentW,
                    height: AppTheme.Tab2Hero.Layout.activityToCTA,
                    label: "16pt · 胶囊→CTA (activityToCTA)",
                    color: .blue,
                    x: centerX,
                    y: ctaGapY + AppTheme.Tab2Hero.Layout.activityToCTA / 2
                )

                // 5. CTA 按钮高度 42pt
                horizontalGapRuler(
                    width: contentW,
                    height: AppTheme.Tab2Hero.Layout.ctaHeight,
                    label: "42pt · Start talking CTA 按钮",
                    color: .orange,
                    x: centerX,
                    y: ctaBottomY + AppTheme.Tab2Hero.Layout.ctaHeight / 2
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// More 推荐行组内微间距透视 (带横线标尺)
    private var moreRowIntraRulersOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let thumbW = AppTheme.Tab2MoreRow.Layout.thumbnailWidth // 76
            let contentStartX = thumbW + AppTheme.Tab2MoreRow.Layout.contentLeadingInset // 76 + 14 = 90
            let contentW = w - contentStartX - AppTheme.Tab2MoreRow.Layout.arrowTrailingInset // w - 90 - 20 = 243
            let contentCenterX = contentStartX + contentW / 2

            let hatBottomY = AppTheme.Tab2MoreRow.Layout.contentTopInset + 15 // 12 + 15 = 27
            let capsuleSlotY = hatBottomY + AppTheme.Tab2MoreRow.Layout.categoryToActivity // 27 + 9.5 = 36.5
            let wordsGapY = capsuleSlotY + 45 // 36.5 + 45 = 81.5

            ZStack {
                // 1. 缩略图宽 76pt
                horizontalSpanRuler(
                    width: thumbW,
                    height: 24,
                    label: "thumb: 76pt",
                    color: .orange,
                    x: thumbW / 2,
                    y: 20
                )

                // 2. 帽行到胶囊 (横线标尺贯穿右侧内容区)
                horizontalGapRuler(
                    width: contentW,
                    height: AppTheme.Tab2MoreRow.Layout.categoryToActivity,
                    label: "\(formatPt(AppTheme.Tab2MoreRow.Layout.categoryToActivity)) · 帽行→胶囊 (categoryToActivity)",
                    color: .purple,
                    x: contentCenterX,
                    y: hatBottomY + AppTheme.Tab2MoreRow.Layout.categoryToActivity / 2
                )

                // 3. 胶囊槽高 45pt
                horizontalGapRuler(
                    width: contentW,
                    height: 45,
                    label: "45pt · 胶囊双行槽位",
                    color: .teal,
                    x: contentCenterX,
                    y: capsuleSlotY + 22.5
                )

                // 4. 胶囊到词数 (横线标尺贯穿右侧内容区)
                horizontalGapRuler(
                    width: contentW,
                    height: AppTheme.Tab2MoreRow.Layout.activityToWords,
                    label: "\(formatPt(AppTheme.Tab2MoreRow.Layout.activityToWords)) · 胶囊→词数 (activityToWords)",
                    color: .blue,
                    x: contentCenterX,
                    y: wordsGapY + AppTheme.Tab2MoreRow.Layout.activityToWords / 2
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Topics 卡盒组内微间距透视 (带横线标尺)
    private var topicsCardIntraRulersOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // 1. 顶内衬 8pt (横线贯穿卡盒)
                horizontalGapRuler(
                    width: w,
                    height: AppTheme.Space.paddingS,
                    label: "8pt · 卡盒顶内衬 (paddingS)",
                    color: .purple,
                    x: w / 2,
                    y: AppTheme.Space.paddingS / 2
                )

                // 2. 文字到微轨
                horizontalGapRuler(
                    width: w - 70,
                    height: AppTheme.Size.rowLabelToProgress,
                    label: "\(formatPt(AppTheme.Size.rowLabelToProgress)) · 文字→微轨 (rowLabelToProgress)",
                    color: .blue,
                    x: w / 2 + 15,
                    y: AppTheme.Space.paddingS + 34 + AppTheme.Size.rowLabelToProgress / 2
                )

                // 3. 底内衬 8pt (横线贯穿卡盒)
                horizontalGapRuler(
                    width: w,
                    height: AppTheme.Space.paddingS,
                    label: "8pt · 卡盒底内衬 (paddingS)",
                    color: .purple,
                    x: w / 2,
                    y: h - AppTheme.Space.paddingS / 2
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Explore 探索区组内微间距透视 (带横线标尺)
    private var exploreIntraRulersOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let titleToTags = AppTheme.Tab2ExploreTopics.Layout.titleToTags // 16
            let tagH = AppTheme.Tab2ExploreTopics.Layout.tagMinHeight // 30
            let tagGap = AppTheme.Tab2ExploreTopics.Layout.tagGap // 8

            ZStack {
                // 1. 标题到胶囊 16pt (横线标尺贯穿整行)
                horizontalGapRuler(
                    width: w - AppTheme.Space.paddingPage * 2,
                    height: titleToTags,
                    label: "16pt · 标题→探索胶囊 (titleToTags)",
                    color: .blue,
                    x: w / 2,
                    y: 26 + titleToTags / 2
                )

                // 2. 胶囊高度 30pt
                horizontalGapRuler(
                    width: 140,
                    height: tagH,
                    label: "30pt · 探索胶囊高度",
                    color: .orange,
                    x: AppTheme.Space.paddingPage + 70,
                    y: 26 + titleToTags + tagH / 2
                )

                // 3. 胶囊行距 8pt
                horizontalGapRuler(
                    width: w - AppTheme.Space.paddingPage * 2,
                    height: tagGap,
                    label: "8pt · 胶囊行距/列距 (tagGap)",
                    color: .purple,
                    x: w / 2,
                    y: 26 + titleToTags + tagH + tagGap / 2
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 零位移原位标尺系统 (Zero-Layout-Shift Rulers)
    // 核心原理：使用 .frame(height: 0) 包装并精准 offset 到已有 gap 内部，绝不引入哪怕 1 个额外像素的排版偏移！

    /// 组与组之间 28pt 间距标尺（利用 VStack spacing 预留的 28pt 缝隙原位显色）
    private func interGroupRuler(label: String) -> some View {
        ZStack {
            // 背景槽高亮带 (28pt)
            Rectangle()
                .fill(AppTheme.Color.brandStrong.opacity(0.07))
                .frame(height: AppTheme.Space.paddingBetweenSections)

            // 上下卡尺边界引线
            VStack {
                Rectangle()
                    .fill(AppTheme.Color.brandStrong.opacity(0.35))
                    .frame(height: 0.8)
                Spacer()
                Rectangle()
                    .fill(AppTheme.Color.brandStrong.opacity(0.35))
                    .frame(height: 0.8)
            }
            .frame(height: AppTheme.Space.paddingBetweenSections)

            // 居中度量徽标
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 8.5, weight: .bold))
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(AppTheme.Color.brandInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(AppTheme.Color.cardBg)
                    .overlay(Capsule().strokeBorder(AppTheme.Color.brandStrong.opacity(0.5), lineWidth: 0.8))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
        .frame(height: 0) // 零高度主张，绝不挤压或撑大布局！
        .offset(y: AppTheme.Space.paddingBetweenSections / 2) // 准确定位到两组正中间
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 组内标题到内容 16pt 间距标尺
    private func intraGroupRuler(height: CGFloat, label: String) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.06))
                .frame(height: height)

            VStack {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(height: 0.8)
                Spacer()
                Rectangle().fill(Color.blue.opacity(0.3)).frame(height: 0.8)
            }
            .frame(height: height)

            HStack(spacing: 3) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 8, weight: .bold))
                Text(label)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(AppTheme.Color.cardBg)
                    .overlay(Capsule().strokeBorder(Color.blue.opacity(0.4), lineWidth: 0.7))
            )
        }
        .frame(height: 0)
        .offset(y: height / 2)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 卡盒内边距 8pt 标尺
    private func cardInnerPaddingRuler(label: String, isBottom: Bool = false) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.purple.opacity(0.08))
                .frame(height: AppTheme.Space.paddingS)

            HStack(spacing: 3) {
                Text("↕ \(label)")
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.purple)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.Color.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.purple.opacity(0.4), lineWidth: 0.6))
            )
        }
        .frame(height: 0)
        .offset(y: isBottom ? -AppTheme.Space.paddingS / 2 : AppTheme.Space.paddingS / 2)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 顶部 4pt 间距标尺
    private func topClearanceRuler(height: CGFloat, label: String) -> some View {
        ZStack {
            Rectangle().fill(Color.orange.opacity(0.1)).frame(height: height)
            Text("↕ \(label)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.orange)
        }
        .frame(height: 0)
        .offset(y: -height / 2)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 页脚 96pt 呼吸断层标尺
    private func footerSpacerRuler(height: CGFloat, label: String) -> some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.Color.brandStrong.opacity(0.04))
                .frame(height: height)

            VStack {
                Rectangle().fill(AppTheme.Color.brandStrong.opacity(0.2)).frame(height: 0.8)
                Spacer()
                Rectangle().fill(AppTheme.Color.brandStrong.opacity(0.2)).frame(height: 0.8)
            }
            .frame(height: height)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(AppTheme.Color.brandInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(AppTheme.Color.cardBg)
                    .overlay(Capsule().strokeBorder(AppTheme.Color.brandStrong.opacity(0.4), lineWidth: 0.8))
            )
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    /// 页脚 52pt 踏光底衬标尺
    private func footerBottomRuler(height: CGFloat, label: String) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.orange.opacity(0.05))
                .frame(height: height)

            Text("↕ \(label)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.orange.opacity(0.9))
        }
        .frame(height: 0)
        .offset(y: height / 2)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 底部宣言与签名

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(
                capHeight: 12.5,
                style: .mono(AppTheme.Color.textMuted),
                showsPeriod: true
            )
            .overlay(alignment: .trailing) {
                if showBadges {
                    specBubble("Mono 12.5pt", x: 75, y: 0)
                }
            }

            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
                .overlay(alignment: .trailing) {
                    if showBadges {
                        specBubble("11.5pt/400 · libraryFooterTagline", x: 130, y: 0)
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 悬浮规格气泡

    private func specBubble(_ text: String, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(red: 0.12, green: 0.1, blue: 0.08).opacity(0.92))
                    .overlay(Capsule().strokeBorder(AppTheme.Color.brandStrong, lineWidth: 0.8))
            )
            .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
            .offset(x: x, y: y)
            .allowsHitTesting(false)
    }

    // MARK: - 控制顶栏

    private var controlHeader: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("Tab2 生产全真标尺透视")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Text("MineView 1:1 像素级生产架构")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.brandInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(AppTheme.Color.brandStrong.opacity(0.1), in: Capsule())
            }

            Picker("视图模式", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 模拟数据源 (100% 对齐生产数据契约)

    private var mockHeroData: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "美食饮品",
            wordCount: 18,
            unlocked: true,
            lastMaterialAt: Date(),
            newMaterialCount: 1,
            activityCount: 3,
            activities: [
                Tab2Activity(
                    sceneDetail: "Ramen for dinner",
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
            Tab2WordEntry(lemma: "thermos", displayForm: "thermos", entryKind: "word", pos: "n.", granularity: "word", sourceType: "material", sampleSentence: nil, nativeMeaning: "保温杯", imageUrl: nil),
            Tab2WordEntry(lemma: "reboot", displayForm: "rebooting", entryKind: "word", pos: "v.", granularity: "sentence", sourceType: "material", sampleSentence: "Try rebooting your device before giving up.", nativeMeaning: "重新启动", imageUrl: nil)
        ]
    }

    private func formatPt(_ val: CGFloat) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))pt" : String(format: "%.1fpt", val)
    }
}

#Preview("Tab2 全要素标尺与生产透视") {
    Tab2FullSpecInspectionPreview()
}
#endif
