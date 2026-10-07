#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 解锁后间距微调与系统性优化方案预览 (Tab2 Spacing Optimization Preview)
// 🎯 核心目标：
//   1. 以真实生产环境为基线（MineView -> contentSections 1:1 排版架构）；
//   2. 深入响应用户需求：
//      - 对齐 Hero 的 sectionLabelToCapsules (现 9pt) 与 More 行的 categoryToActivity (现 9.5pt)、activityToWords (现 8pt)；
//      - 优化 Topics in progress 中 rowLabelToProgress (现 6.5pt，字母下沉较贴轨) 的垂直呼吸；
//      - 新增「一键隐藏注释 / 点开注释」功能：既可一键进入 100% 真实纯净界面，又可随时点开展开详细原则与参数；
//   3. 遵循经典 C.R.A.P. 原则（对比 Contrast、亲密 Proximity、重复 Repetition、对齐 Alignment）提供 4 套完整方案：
//      - 基线（生产现行）：9pt / 9.5pt / 8pt / 6.5pt
//      - 方案 A（系统 8pt 律）：8pt / 8pt / 8pt / 8pt（极致归一，严格符合 iOS 8pt 栅格）
//      - 方案 B（通透 10pt 律）：10pt / 10pt / 10pt / 10pt（高度数学闭合 119pt 行高，呼吸开阔）
//      - 方案 C（经典 9pt 律）：9pt / 9pt / 9pt / 8.5pt（居中均衡，兼顾字符基线与信息块粘连）

struct Tab2SpacingOptimizationPreview: View {
    
    // MARK: - 详细注释数据模型 (点开各标尺与卡片时弹出的深度解析)
    struct SpacingDetailItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let location: String
        let currentValue: CGFloat
        let baselineValue: CGFloat
        let principle: String
        let rationale: String
    }
    
    // MARK: - 方案定义模型
    enum SchemeOption: String, CaseIterable, Identifiable {
        case baseline = "基线 (生产现行)"
        case schemeA = "方案 A (系统 8pt 律)"
        case schemeB = "方案 B (通透 10pt 律)"
        case schemeC = "方案 C (均衡 9pt 律)"
        
        var id: String { rawValue }
        
        /// Hero: "RECENT ACTIVITIES" 小标到活动胶囊组的间距
        var heroSectionLabelToCapsules: CGFloat {
            switch self {
            case .baseline: return 9.0
            case .schemeA: return 8.0
            case .schemeB: return 10.0
            case .schemeC: return 9.0
            }
        }
        
        /// More 推荐行: 帽行 (Daily Routine) 到胶囊组的间距
        var moreCategoryToActivity: CGFloat {
            switch self {
            case .baseline: return 9.5
            case .schemeA: return 8.0
            case .schemeB: return 10.0
            case .schemeC: return 9.0
            }
        }
        
        /// More 推荐行: 胶囊组到末行词数 (42 words) 的间距
        var moreActivityToWords: CGFloat {
            switch self {
            case .baseline: return 8.0
            case .schemeA: return 8.0
            case .schemeB: return 10.0
            case .schemeC: return 9.0
            }
        }
        
        /// Topics: 分类标题到 1.5pt 微轨的垂直间隙
        var topicsRowLabelToProgress: CGFloat {
            switch self {
            case .baseline: return 6.5
            case .schemeA: return 8.0
            case .schemeB: return 10.0
            case .schemeC: return 8.5
            }
        }
        
        /// 方案设计阐述
        var title: String {
            switch self {
            case .baseline: return "生产环境当前基线 (现行数值)"
            case .schemeA: return "方案 A · 系统 8pt 律 (8pt Grid Parity)"
            case .schemeB: return "方案 B · 通透 10pt 律 (10pt Breathing Parity)"
            case .schemeC: return "方案 C · 均衡 9pt 律 (Balanced 9pt Parity)"
            }
        }
        
        var summary: String {
            switch self {
            case .baseline:
                return "现状：Hero 小标 9pt、More 帽行 9.5pt、词数 8pt、微轨 6.5pt。四者碎步分散，微轨处下沉字母(g/p/y)离轨较近。"
            case .schemeA:
                return "重构为系统纯正 8pt：三处全部拉平为 8pt，微轨放宽至 8pt。严格贴合 iOS 标准 8pt Token 系统，逻辑最纯粹，重复性极强。"
            case .schemeB:
                return "重构为通透 10pt：三处拉平为 10pt，微轨放宽至 10pt。More 行内高度完美闭合（10+10=20pt，彻底吃满 119pt），松弛感与呼吸感最佳。"
            case .schemeC:
                return "重构为黄金 9pt：三处拉平为 9pt，微轨取 8.5pt。在紧凑与通透之间取得最佳折衷，既消灭碎步，又保留细腻信息密度。"
            }
        }
    }
    
    // MARK: - 状态管理
    @State private var selectedScheme: SchemeOption = .schemeB
    @State private var showAnnotations: Bool = true             // 一键隐藏 / 点开注释核心总开关
    @State private var showRulers: Bool = true                  // 标尺引线独立微调
    @State private var isAnnotationCardExpanded: Bool = true    // 注释卡折叠 / 展开状态
    @State private var selectedRulerDetail: SpacingDetailItem? = nil // 点开单项标尺详情弹窗
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // 控制顶栏 (含一键隐藏/点开注释按钮)
                controlHeader
                
                Divider().opacity(0.15)
                
                // 真实生产环境滚动流
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // ════ 方案设计原理解析卡 (支持一键隐藏与收起/点开) ════
                        if showAnnotations {
                            designPrincipleCard
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                                .padding(.top, 14)
                                .padding(.bottom, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // ════ 生产核心内容流 (spacing = 28pt) ════
                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
                            
                            // ── 组 1: Talk about today (Hero) ──
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                                sectionTitleHeader("Talk about today", badge: "22pt Charter")
                                
                                heroSectionView
                                    .padding(.horizontal, AppTheme.Space.paddingPage)
                            }
                            
                            // ── 组 2: More to talk about ──
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                                sectionTitleHeader("More to talk about", badge: "22pt Charter")
                                
                                VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                                    // 推荐行 1 (带内容)
                                    moreRow1View
                                    
                                    // 推荐行 2 (空态等高 119pt)
                                    Tab2ActivityRow(
                                        category: mockMoreEmptyRowData,
                                        onTap: {}
                                    )
                                }
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            }
                            
                            // ── 组 3: Topics in progress (包装在 surfaceCard 磨砂白卡盒内) ──
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                                sectionTitleHeader("Topics in progress", badge: "22pt Charter")
                                
                                VStack(spacing: 0) {
                                    progressRow1View
                                    
                                    Divider().padding(.horizontal, AppTheme.Space.paddingPage)
                                    
                                    progressRow2View
                                }
                                .padding(.vertical, AppTheme.Space.paddingS)
                                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            }
                            
                            // ── 组 4: More topics to explore (原生生产组件) ──
                            Tab2MoreTopicsSection(
                                topics: [.weather, .social, .gettingAround, .other]
                            )
                        }
                        .padding(.top, AppTheme.Space.tab2ContentTop)
                        
                        // ════ 页脚留白与品牌宣言 ════
                        Spacer(minLength: AppTheme.Space.tab2FooterTop)
                        
                        footerSignoff
                            .padding(.bottom, AppTheme.Space.tab2FooterBottom)
                    }
                    .background(alignment: .bottom) {
                        BottomAuraFooter()
                    }
                }
                .background(AppTheme.Color.pageBg.ignoresSafeArea())
            }
            
            // 纯净模式下右下角悬浮「点开注释」气泡
            if !showAnnotations {
                floatingAnnotationButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showAnnotations)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isAnnotationCardExpanded)
        .sheet(item: $selectedRulerDetail) { item in
            rulerDetailSheet(item)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - 组 1: Hero 卡片 (响应 selectedScheme)
    
    private var heroSectionView: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                // 头图区 (150pt)
                ZStack(alignment: .topLeading) {
                    Image("MockFoodCover")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
                        .clipped()
                        .background(AppTheme.Color.imagePlaceholderBg)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.45),
                                    Color.black.opacity(0.05),
                                    Color.black.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
                    
                    HStack(alignment: .center) {
                        Text(mockHeroData.sceneCategory)
                            .font(AppTheme.Font.tab2HeroChipCategory)
                            .foregroundStyle(Color.white)
                        
                        Spacer()
                        
                        Text("Added today")
                            .font(AppTheme.Font.tab2ReasonPill)
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    .padding(.trailing, AppTheme.Tab2Hero.Layout.chipTopLeading)
                }
                
                // 卡身文字区
                VStack(alignment: .leading, spacing: 0) {
                    // 小标与活动组
                    VStack(alignment: .leading, spacing: selectedScheme.heroSectionLabelToCapsules) {
                        Text("Recent activities")
                            .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                            .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.Color.textMuted)
                        
                        Tab2ActivityCapsuleGroup(
                            activities: Tab2ActivityDisplay.compute(category: mockHeroData).valid,
                            activityCount: mockHeroData.activityCount,
                            blockedCount: 0,
                            metrics: Tab2ActivityCapsuleMetrics.hero(),
                            nameFont: AppTheme.Font.tab2HeroCapsuleName,
                            moreFont: AppTheme.Font.tab2HeroCapsuleMore
                        )
                        .equatable()
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)
                    .overlay(alignment: .bottom) {
                        if showAnnotations && showRulers {
                            horizontalGapRuler(
                                height: selectedScheme.heroSectionLabelToCapsules,
                                label: "\(formatPt(selectedScheme.heroSectionLabelToCapsules)) · 小标→胶囊",
                                color: .purple,
                                yOffset: -52 - selectedScheme.heroSectionLabelToCapsules / 2,
                                detailItem: SpacingDetailItem(
                                    title: "小标到活动胶囊组间距",
                                    location: "Hero 卡片 · sectionLabelToCapsules",
                                    currentValue: selectedScheme.heroSectionLabelToCapsules,
                                    baselineValue: 9.0,
                                    principle: "重复律 (Repetition) & 4/8 栅格",
                                    rationale: "消除与 More 推荐行帽行间距 (9.5pt) 及词数间距 (8.0pt) 之间的微观碎步，统一视线滑动时的节奏频率。"
                                )
                            )
                        }
                    }
                    
                    // 脚行
                    HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                        Text("18 words")
                            .font(AppTheme.Font.tab2HeroFootrowWords)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .monospacedDigit()
                        
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
                            in: RoundedRectangle(cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius, style: .continuous)
                        )
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
                    .overlay(alignment: .top) {
                        if showAnnotations && showRulers {
                            horizontalGapRuler(
                                height: AppTheme.Tab2Hero.Layout.activityToCTA,
                                label: "16pt · 胶囊→CTA (activityToCTA)",
                                color: .blue,
                                yOffset: AppTheme.Tab2Hero.Layout.activityToCTA / 2,
                                detailItem: SpacingDetailItem(
                                    title: "胶囊组到 CTA 间距",
                                    location: "Hero 卡片 · activityToCTA",
                                    currentValue: 16.0,
                                    baselineValue: 16.0,
                                    principle: "亲密性 (Proximity) 宏观分区",
                                    rationale: "保持 16pt (space16) 标准内衬，将活动浏览区与最终行动点 Start Talking 明确分隔。"
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
                .offset(y: AppTheme.Tab2Hero.Layout.artTextOverlap)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.artTextOverlap)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.Color.warmGlassSurface)
            .compositingGroup()
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 组 2: More 推荐行 1 (响应 selectedScheme)
    
    private var moreRow1View: some View {
        Button(action: {}) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                    .overlay(RowPresetThumb(category: .dailyRoutines))
                    .clipped()
                
                VStack(alignment: .leading, spacing: 0) {
                    // 帽行
                    HStack(alignment: .firstTextBaseline) {
                        Text("Daily Routine")
                            .font(AppTheme.Font.tab2MoreRowCategory)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Spacer()
                        Text("2h ago")
                            .font(AppTheme.Font.tab2MoreRowTimeline)
                            .foregroundStyle(AppTheme.Color.neutralFaint)
                    }
                    .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)
                    
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 活动胶囊组
                            Tab2ActivityCapsuleGroup(
                                activities: Tab2ActivityDisplay.compute(category: mockMoreRowData).valid,
                                activityCount: mockMoreRowData.activityCount,
                                blockedCount: 0,
                                metrics: Tab2ActivityCapsuleMetrics.more(),
                                nameFont: AppTheme.Font.tab2MoreRowCapsuleName,
                                moreFont: AppTheme.Font.tab2MoreRowCapsuleMore
                            )
                            .equatable()
                            .padding(.top, selectedScheme.moreCategoryToActivity)
                            .overlay(alignment: .top) {
                                if showAnnotations && showRulers {
                                    horizontalGapRuler(
                                        height: selectedScheme.moreCategoryToActivity,
                                        label: "\(formatPt(selectedScheme.moreCategoryToActivity)) · 帽行→胶囊",
                                        color: .purple,
                                        yOffset: selectedScheme.moreCategoryToActivity / 2,
                                        detailItem: SpacingDetailItem(
                                            title: "帽行到活动胶囊组间距",
                                            location: "More 推荐行 · categoryToActivity",
                                            currentValue: selectedScheme.moreCategoryToActivity,
                                            baselineValue: 9.5,
                                            principle: "亲密性 (Proximity) & 垂直闭合",
                                            rationale: "More 推荐行锁定 119pt 行高。扣除帽行(15pt)、双行胶囊槽(45pt)、词数行(15pt)以及上下内衬(24pt)后净剩余约 20pt。若设为 10pt (方案 B)，10+10=20pt 达成完美的数学闭合；若设为 8pt (方案 A)，行内聚焦度最高。"
                                        )
                                    )
                                }
                            }
                            
                            // 词数行
                            Text(Tab2CardLabels.words(mockMoreRowData.wordCount))
                                .font(AppTheme.Font.tab2MoreRowMeta)
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .padding(.top, selectedScheme.moreActivityToWords)
                                .overlay(alignment: .top) {
                                    if showAnnotations && showRulers {
                                        horizontalGapRuler(
                                            height: selectedScheme.moreActivityToWords,
                                            label: "\(formatPt(selectedScheme.moreActivityToWords)) · 胶囊→词数",
                                            color: .blue,
                                            yOffset: selectedScheme.moreActivityToWords / 2,
                                            detailItem: SpacingDetailItem(
                                                title: "胶囊组到词数行间距",
                                                location: "More 推荐行 · activityToWords",
                                                currentValue: selectedScheme.moreActivityToWords,
                                                baselineValue: 8.0,
                                                principle: "重复律 (Repetition) & 4/8 律",
                                                rationale: "与帽行下距及 Hero 小标下距拉平对齐，消除微观碎片化，提升列表纵向浏览的一致性。"
                                            )
                                        )
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                    }
                }
                .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
                .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
                .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
            }
            .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Color.warmGlassSurface)
            .compositingGroup()
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
            }
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 组 3: Topics 卡盒 (响应 selectedScheme 的 rowLabelToProgress)
    
    private var progressRow1View: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
                // 图标槽 20×20
                Image(systemName: "desktopcomputer")
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)
                
                VStack(alignment: .leading, spacing: selectedScheme.topicsRowLabelToProgress) {
                    HStack(alignment: .center) {
                        Text("Tech & Gadgets")
                            .font(AppTheme.Font.tab2TopicLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        
                        Spacer()
                        
                        HStack(spacing: AppTheme.Size.pillHSpacing) {
                            Text("16 words")
                                .font(AppTheme.Font.tab2ProgressCount)
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: AppTheme.Size.expandArrow))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.horizontal, AppTheme.Size.pillHPad)
                        .padding(.vertical, AppTheme.Size.pillVPad)
                        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    }
                    
                    // 1.5pt 微轨
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.Color.progressTrack)
                            Capsule().fill(AppTheme.Color.progressFill)
                                .frame(width: geo.size.width * 0.7)
                        }
                    }
                    .frame(height: AppTheme.Size.progressBarHeight)
                    .overlay(alignment: .top) {
                        if showAnnotations && showRulers {
                            horizontalGapRuler(
                                height: selectedScheme.topicsRowLabelToProgress,
                                label: "\(formatPt(selectedScheme.topicsRowLabelToProgress)) · 文字→微轨",
                                color: .purple,
                                yOffset: -selectedScheme.topicsRowLabelToProgress / 2,
                                detailItem: SpacingDetailItem(
                                    title: "分类文字到微轨间距",
                                    location: "Topics in progress · rowLabelToProgress",
                                    currentValue: selectedScheme.topicsRowLabelToProgress,
                                    baselineValue: 6.5,
                                    principle: "对比 (Contrast) & 独立实体感",
                                    rationale: "现行 6.5pt 会导致带有下延笔画的英文字母（如 Tech & Gadgets 中的 g/y/p）底部与 1.5pt 微轨紧紧贴合，容易被误读为文字下划线。放宽至 8pt~10pt 后，负空间对比充足，微轨确立为独立进度读数组件。"
                                )
                            )
                        }
                    }
                }
            }
            .padding(.vertical, AppTheme.Space.listRowVertical)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .buttonStyle(.plain)
    }
    
    private var progressRow2View: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
                Image(systemName: "figure.run")
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)
                
                VStack(alignment: .leading, spacing: selectedScheme.topicsRowLabelToProgress) {
                    HStack(alignment: .center) {
                        Text("Fitness & Health")
                            .font(AppTheme.Font.tab2TopicLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        
                        Spacer()
                        
                        HStack(spacing: AppTheme.Size.pillHSpacing) {
                            Text("9 words")
                                .font(AppTheme.Font.tab2ProgressCount)
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: AppTheme.Size.expandArrow))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.horizontal, AppTheme.Size.pillHPad)
                        .padding(.vertical, AppTheme.Size.pillVPad)
                        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.Color.progressTrack)
                            Capsule().fill(AppTheme.Color.progressFill)
                                .frame(width: geo.size.width * 0.45)
                        }
                    }
                    .frame(height: AppTheme.Size.progressBarHeight)
                }
            }
            .padding(.vertical, AppTheme.Space.listRowVertical)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - C.R.A.P. 原则设计分析卡 (可展开 / 可点开)
    
    @ViewBuilder
    private var designPrincipleCard: some View {
        if isAnnotationCardExpanded {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                        Text(selectedScheme.title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)
                    }
                    Spacer()
                    
                    // 标尺引线微调开关
                    Toggle("标尺", isOn: $showRulers)
                        .toggleStyle(.button)
                        .font(.system(size: 10.5, weight: .semibold))
                        .tint(AppTheme.Color.brandStrong)
                    
                    // 收起按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            isAnnotationCardExpanded = false
                        }
                    }) {
                        HStack(spacing: 2) {
                            Text("收起")
                            Image(systemName: "chevron.up")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Text(selectedScheme.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(2.5)
                
                // 4大原则审计要点对比网格 (点击每格可点开详情)
                HStack(spacing: 8) {
                    crapBadge(title: "亲密性", score: "Proximity", desc: selectedScheme == .schemeA ? "紧凑聚焦" : (selectedScheme == .schemeB ? "舒展透气" : "平衡和谐")) {
                        selectedRulerDetail = SpacingDetailItem(
                            title: "亲密性 (Proximity) 审计",
                            location: "More 推荐行 · 行内垂直余量闭合",
                            currentValue: selectedScheme.moreCategoryToActivity,
                            baselineValue: 9.5,
                            principle: "亲密性原则 (Proximity)",
                            rationale: "More 推荐行锁定 119pt 行高。扣除帽行(15pt)、双行胶囊槽(45pt)、词数行(15pt)以及上下内衬(24pt)后，净剩余的流动间隙恰好为 20pt。若统一为 10pt (方案 B)，10+10=20pt 达成完美的数学闭合；若统一为 8pt (方案 A)，行内聚焦度最高。"
                        )
                    }
                    crapBadge(title: "重复律", score: "Repetition", desc: selectedScheme == .schemeA ? "8pt 栅格对齐" : (selectedScheme == .schemeB ? "10pt 闭合" : "9pt 统一")) {
                        selectedRulerDetail = SpacingDetailItem(
                            title: "重复律 (Repetition) 审计",
                            location: "Hero 与 More 行间距拉平",
                            currentValue: selectedScheme.heroSectionLabelToCapsules,
                            baselineValue: 9.0,
                            principle: "重复律原则 (Repetition)",
                            rationale: "现状中 9.0pt、9.5pt、8.0pt 是多次局部微调留下的碎片碎步。三处强制拉平为同一基准数值，消除用户纵向滑动浏览时的视觉节奏抖动。"
                        )
                    }
                    crapBadge(title: "微轨对比", score: "Contrast", desc: selectedScheme.topicsRowLabelToProgress >= 8.0 ? "微轨彻底独立" : "微轨略似下划线") {
                        selectedRulerDetail = SpacingDetailItem(
                            title: "对比 (Contrast) 审计",
                            location: "Topics in progress · rowLabelToProgress",
                            currentValue: selectedScheme.topicsRowLabelToProgress,
                            baselineValue: 6.5,
                            principle: "对比原则 (Contrast)",
                            rationale: "现行 6.5pt 会导致带有下延笔画的英文字母（如 Tech & Gadgets 中的 g/y/p）底部与 1.5pt 微轨紧紧贴合，容易被误读为文字下划线。放宽至 8pt~10pt 后，负空间对比充足，微轨确立为独立进度读数组件。"
                        )
                    }
                    crapBadge(title: "行高对齐", score: "Alignment", desc: "119pt 稳固") {
                        selectedRulerDetail = SpacingDetailItem(
                            title: "对齐 (Alignment) 审计",
                            location: "全页水平与垂直对齐锚点",
                            currentValue: 119,
                            baselineValue: 119,
                            principle: "对齐原则 (Alignment)",
                            rationale: "More 推荐行严格保持 119pt 恒定下限高，使得右侧跳转箭头 arrow.right 在纵向滚屏时停留在一条完全水平的视线轨道上。"
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Color.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.8))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        } else {
            // 折叠态：点开功能
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isAnnotationCardExpanded = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                    
                    Text("方案与 C.R.A.P. 原则注释已折叠 · \(selectedScheme.title)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Text("点开注释")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Color.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.6))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func crapBadge(title: String, score: String, desc: String, onTap: (() -> Void)? = nil) -> some View {
        Button(action: {
            onTap?()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandInk)
                Text(desc)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(AppTheme.Color.tab2ProgressPillBg, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 悬浮「点开注释」呼吸气泡按钮 (纯净态时显示)
    
    private var floatingAnnotationButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showAnnotations = true
                isAnnotationCardExpanded = true
                showRulers = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("点开注释")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(AppTheme.Color.interactive.opacity(0.92))
                    .overlay(Capsule().strokeBorder(AppTheme.Color.brandStrong.opacity(0.6), lineWidth: 1.0))
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 贯穿全宽横线标尺 (可点开单项详情)
    
    private func horizontalGapRuler(
        height: CGFloat,
        label: String,
        color: Color,
        yOffset: CGFloat,
        detailItem: SpacingDetailItem? = nil
    ) -> some View {
        ZStack {
            // 色槽填充带
            Rectangle()
                .fill(color.opacity(0.12))
                .frame(height: max(height, 2))
            
            // 上下两条横向界线 (横线标尺)
            VStack(spacing: 0) {
                Rectangle().fill(color.opacity(0.85)).frame(height: 1.0)
                Spacer(minLength: 0)
                Rectangle().fill(color.opacity(0.85)).frame(height: 1.0)
            }
            .frame(height: max(height, 2))
            
            // 居中文本徽标（可点开详细说明）
            Button(action: {
                if let detailItem {
                    selectedRulerDetail = detailItem
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 7.5, weight: .bold))
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    if detailItem != nil {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 7.5))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
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
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 0) // 零高度，绝不挤压撑大布局
        .offset(y: yOffset)
        .allowsHitTesting(detailItem != nil)
    }
    
    // MARK: - 单项间距点开详情浮层 (Sheet)
    
    private func rulerDetailSheet(_ item: SpacingDetailItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(item.location)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                Spacer()
                Button("完成") {
                    selectedRulerDetail = nil
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Color.brandInk)
            }
            
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前方案值")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text("\(formatPt(item.currentValue))")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Color.tab2ProgressPillBg, in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("生产现行值")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text("\(formatPt(item.baselineValue))")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Color.tab2ProgressPillBg, in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("差值变化")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                    let diff = item.currentValue - item.baselineValue
                    Text(diff == 0 ? "持平" : (diff > 0 ? "+\(formatPt(diff))" : "\(formatPt(diff))"))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(diff == 0 ? AppTheme.Color.textSecondary : (diff > 0 ? Color.blue : Color.purple))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Color.tab2ProgressPillBg, in: RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                    Text(item.principle)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(AppTheme.Color.brandInk)
                }
                Text(item.rationale)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(AppTheme.Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
        }
        .padding(20)
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }
    
    // MARK: - 标题行与控制顶栏
    
    private func sectionTitleHeader(_ title: String, badge: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            
            Text(badge)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
            
            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
    
    private var controlHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("Tab2 间距统一与 C.R.A.P. 优化")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                
                Spacer()
                
                // 一键隐藏 / 点开注释主按钮
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showAnnotations.toggle()
                        if showAnnotations {
                            isAnnotationCardExpanded = true
                            showRulers = true
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showAnnotations ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(showAnnotations ? "隐藏注释" : "点开注释")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(showAnnotations ? AppTheme.Color.textOnChip : AppTheme.Color.brandInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        showAnnotations ? AppTheme.Color.interactive : AppTheme.Color.brandStrong.opacity(0.12),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }
            
            Picker("优化方案", selection: $selectedScheme) {
                ForEach(SchemeOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
    }
    
    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(
                capHeight: 12.5,
                style: .mono(AppTheme.Color.textMuted),
                showsPeriod: true
            )
            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatPt(_ val: CGFloat) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))pt" : String(format: "%.1fpt", val)
    }
    
    // MARK: - 模拟数据源 (对齐生产)
    
    private var mockHeroData: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "美食饮品",
            wordCount: 18,
            unlocked: true,
            lastMaterialAt: Date(),
            newMaterialCount: 1,
            activityCount: 3,
            activities: [
                Tab2Activity(sceneDetail: "Ramen for dinner", occurrenceCount: 2),
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
                Tab2Activity(sceneDetail: "Fixing a device", occurrenceCount: 2),
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
}

#Preview("Tab2 间距统一与优化对比") {
    Tab2SpacingOptimizationPreview()
}
#endif
