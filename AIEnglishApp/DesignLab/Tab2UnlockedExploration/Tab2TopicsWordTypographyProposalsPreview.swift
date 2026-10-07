#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Topics in progress 展开词条三大排版优化方案与全页秩序沙盒
//         (Tab2 Topics Expanded Word Typography Proposals & Visual Harmony Preview)
//
// 🏛️ 设计学四大原则指导框架 (Design Principles Framework)：
//   1. 对比 (Contrast)：
//      - 彻底修复 Charter 15pt Bold 带来的中英墨量断层（解决 3:1 视觉力量失衡）；
//      - 消除子词条（原 15pt）压倒父级分类名（现 13pt Regular）的「层级倒挂」。
//   2. 亲密性 (Proximity)：
//      - 词头与释义垂直间距从 2.0pt 调谐至 2.5~3.5pt，让西文降部（p/y/g）充分呼吸；
//      - 多行连续展开时，消除粗黑衬线堆叠导致的「黑块压迫感」。
//   3. 重复与统一 (Repetition / Consistency)：
//      - 呼应当前页面已落地的「全员 13pt Regular + 10pt 呼吸节奏」暖极简语言；
//      - 统筹西文衬线（Charter）与无衬线（Gothic A1）在整页中的语义分工。
//   4. 对齐 (Alignment)：
//      - 图标磁贴与双行文字垂直轴线达成真正光学对齐。
//
// 🎯 三大优化方案定义：
//   • 【基线 Baseline】线上现状：Charter 15.0pt · Bold 700 + 冬青黑 12pt W3，间距 2.0pt (笨重粗黑)
//   • 【方案 1 · 意式书卷 (推荐 ⭐)】Charter 14.0pt · Regular 400 + 冬青黑 12pt W3，间距 3.5pt (中英 1:1 光学同宽，优雅沉静)
//   • 【方案 2 · 轻挺微缩】Charter 13.5pt · Bold 700 + 冬青黑 12pt W3，间距 2.5pt (收缩字阶，保留粗衬线锚点)
//   • 【方案 3 · 现代同源】Gothic A1 13.5pt · Medium 500 + 冬青黑 12pt W3，间距 2.5pt (与分类名同家族，纯粹现代感)

struct Tab2TopicsWordTypographyProposalsPreview: View {

    // MARK: - 方案枚举

    enum Proposal: String, CaseIterable, Identifiable {
        case baseline   = "生产基线 · Charter 15pt Bold"
        case proposal1  = "方案 1 · 意式书卷 (Charter 14pt Regular) ⭐"
        case proposal2  = "方案 2 · 轻挺微缩 (Charter 13.5pt Bold)"
        case proposal3  = "方案 3 · 现代同源 (Gothic A1 13.5pt Medium)"

        var id: String { rawValue }

        var shortTitle: String {
            switch self {
            case .baseline:  return "生产基线"
            case .proposal1: return "方案 1 (书卷 14 Regular) ⭐"
            case .proposal2: return "方案 2 (微缩 13.5 Bold)"
            case .proposal3: return "方案 3 (同源 13.5 Sans)"
            }
        }

        var badgeDescription: String {
            switch self {
            case .baseline:
                return "现状偏重：Charter 15.0pt Bold 700 · 墨量过浓 · 压迫分类名"
            case .proposal1:
                return "推荐首选：Charter 14.0pt Regular 400 · 中英 1:1 光学同宽 · 典雅词典"
            case .proposal2:
                return "保留骨架：Charter 13.5pt Bold 700 · 字号缩小 1.5pt · 控制体量"
            case .proposal3:
                return "纯粹几何：Gothic A1 13.5pt Medium 500 · 与分类名统一家族 · 现代利落"
            }
        }
    }

    // MARK: - 测试场景数据集枚举

    enum DatasetCategory: String, CaseIterable, Identifiable {
        case work       = "场景 1: 职场与项目推进 (7词)"
        case coffee     = "场景 2: 咖啡早晨与治愈日常 (6词)"
        case fitness    = "场景 3: 运动健身与活力时刻 (5词)"
        case social     = "场景 4: 社交共鸣与深度生活 (5词)"
        case stress     = "场景 5: 长短词与连字符极限 (5词)"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .work:    return "briefcase"
            case .coffee:  return "cup.and.saucer"
            case .fitness: return "figure.run"
            case .social:  return "person.2"
            case .stress:  return "text.word.spacing"
            }
        }

        var englishTitle: String {
            switch self {
            case .work:    return "Work & Projects"
            case .coffee:  return "Coffee & Routine"
            case .fitness: return "Fitness & Health"
            case .social:  return "Social & Life"
            case .stress:  return "Expressive Vocabulary"
            }
        }
    }

    // MARK: - 检视视角枚举

    enum ViewPerspective: String, CaseIterable, Identifiable {
        case inCardFlow       = "真实卡片手风琴流"
        case isolatedFourWay  = "4 方案同词贴身横评"
        case principlesAudit  = "四大原则评估雷达"

        var id: String { rawValue }
    }

    // MARK: - 状态管理

    @State private var selectedProposal: Proposal = .proposal1
    @State private var selectedDataset: DatasetCategory = .work
    @State private var selectedPerspective: ViewPerspective = .inCardFlow
    @State private var isAccordionExpanded: Bool = true
    @State private var showSpecBadges: Bool = true

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            topControlBar

            Divider().opacity(0.15)

            switch selectedPerspective {
            case .inCardFlow:
                inCardFlowView
            case .isolatedFourWay:
                isolatedFourWayView
            case .principlesAudit:
                principlesAuditView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶部控制栏 (Top Control Bar)

    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 第一行：标题与当前方案简介
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Topics 展开词条三大优化方案")
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

                // 场景选择下拉菜单
                Menu {
                    Picker("测试场景", selection: $selectedDataset) {
                        ForEach(DatasetCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                        Text(datasetShortName(selectedDataset))
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

            // 第二行：方案切换分段器
            Picker("优化方案", selection: $selectedProposal) {
                ForEach(Proposal.allCases) { prop in
                    Text(prop.shortTitle).tag(prop)
                }
            }
            .pickerStyle(.segmented)

            // 第三行：视角切换分段器
            Picker("查看视角", selection: $selectedPerspective) {
                ForEach(ViewPerspective.allCases) { persp in
                    Text(persp.rawValue).tag(persp)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.warmGlassSurface)
    }

    private func datasetShortName(_ cat: DatasetCategory) -> String {
        switch cat {
        case .work:    return "职场协作"
        case .coffee:  return "咖啡日常"
        case .fitness: return "运动健身"
        case .social:  return "社交情感"
        case .stress:  return "极限测试"
        }
    }

    // MARK: - 视角 1: 真实卡片手风琴流 (In-Card Accordion Flow)

    private var inCardFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 方案专属解构标签栏
                proposalSpecBanner(selectedProposal)

                // 真实 Topics in progress 区块呈现
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        Text("点击右侧胶囊可开合手风琴")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }

                    // 真实卡盒表面 (.surfaceCard)
                    VStack(spacing: 0) {
                        // 手风琴行头部
                        accordionHeaderRow

                        // 展开词条列表
                        if isAccordionExpanded {
                            VStack(spacing: AppTheme.Space.paddingS) {
                                ForEach(currentEntries) { entry in
                                    proposalWordRow(entry: entry, proposal: selectedProposal)
                                }
                            }
                            .padding(.vertical, AppTheme.Space.paddingXS)
                            .padding(.leading, AppTheme.Space.paddingCard)
                            .transition(.opacity.combined(with: .offset(y: 4)))
                        }
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - 手风琴卡头行 (Header Row)

    private var accordionHeaderRow: some View {
        Button {
            withAnimation(AppTheme.Motion.accordionToggle) {
                isAccordionExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppTheme.Space.paddingM) {
                Image(systemName: selectedDataset.iconName)
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                Text(selectedDataset.englishTitle)
                    .font(AppTheme.Font.tab2TopicLabel) // 方案 A 落地值 13pt Regular
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Capsule()
                    .fill(AppTheme.Color.progressTrack.opacity(0.8))
                    .frame(width: 80, height: AppTheme.Size.progressBarHeight)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Color.progressFill)
                            .frame(width: 52)
                    }

                Spacer()

                HStack(spacing: AppTheme.Size.pillHSpacing) {
                    Text("\(currentEntries.count) words")
                        .font(AppTheme.Font.tab2ProgressCount)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: AppTheme.Size.expandArrow))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .rotationEffect(.degrees(isAccordionExpanded ? 180 : 0))
                }
                .padding(.horizontal, AppTheme.Size.pillHPad)
                .padding(.vertical, AppTheme.Size.pillVPad)
                .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
            }
            .padding(.vertical, AppTheme.Space.listRowVertical)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 词条单行渲染 (根据方案注入排版参数)

    private func proposalWordRow(entry: Tab2WordEntry, proposal: Proposal) -> some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            // 图标槽位
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Color.iconTileBg)
                    .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)

                switch entry.badgeGlyph {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: AppTheme.Size.entryBadgeGlyph, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                case .quoteBlock:
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                case .linkChain:
                    Tab2LinkChainGlyphView()
                }
            }
            .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)

            // 文字区
            VStack(alignment: .leading, spacing: verticalSpacing(for: proposal)) {
                Text(entry.displayForm ?? entry.lemma)
                    .font(fontForEnglish(proposal))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)

                if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(AppTheme.Font.tab2WordEntryMeaning) // 冬青黑 12pt W3
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 视角 2: 四方案同词贴身横评 (Isolated Four-Way Comparison)

    private var isolatedFourWayView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("同台贴身横评 · 4 套方案排版效果同词对标")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("对比同一组词汇（以 deadline 与 pour-over 为例）在粗细、墨量和呼吸感上的真实差异：")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 16) {
                    ForEach(Proposal.allCases) { prop in
                        fourWayCard(for: prop)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private func fourWayCard(for prop: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(prop.shortTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(prop == .proposal1 ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary)

                if prop == .proposal1 {
                    Text("推荐 ⭐")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                }

                Spacer()

                Text(fontSpecSummary(prop))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            VStack(spacing: 8) {
                proposalWordRow(entry: workSampleEntries[0], proposal: prop) // deadline
                Divider()
                proposalWordRow(entry: coffeeSampleEntries[0], proposal: prop) // pour-over
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))

            // 评价微评
            Text(rationaleForProposal(prop))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(.horizontal, 4)
        }
        .padding(14)
        .background(prop == .proposal1 ? AppTheme.Color.brandTint.opacity(0.15) : AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(prop == .proposal1 ? AppTheme.Color.brandStrong.opacity(0.4) : AppTheme.Color.cardBorder, lineWidth: prop == .proposal1 ? 1 : 0.5))
    }

    // MARK: - 视角 3: 四大原则评估雷达 (Principles Audit)

    private var principlesAuditView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("设计学四大原则矩阵打分与审视")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 12) {
                    principleAuditCard(
                        principle: "1. 对比 (Contrast) · 中英墨量与层级",
                        baselineEval: "❌ 割裂：Charter 15pt Bold 墨量过重（3:1 反差），子项直接压死 13pt 父级分类名。",
                        p1Eval: "⭐⭐⭐⭐⭐ 完美：14pt Regular 与冬青黑 W3 光学 1:1 同宽，与 13pt 分类名达成舒展父子级。",
                        p2Eval: "⭐⭐⭐ 适中：13.5pt Bold 收缩了黑块面积，但粗细断层依然存在。",
                        p3Eval: "⭐⭐⭐⭐ 良好：13.5pt Medium 梯度自然，但衬线与无衬线的声部对比被抹平。"
                    )

                    principleAuditCard(
                        principle: "2. 亲密性 (Proximity) · 垂直微观呼吸",
                        baselineEval: "❌ 拥挤：2.0pt 间距导致 Charter 字母降部（p/y/g）紧贴中文顶梁，多行密集堆叠成黑块。",
                        p1Eval: "⭐⭐⭐⭐⭐ 最佳：3.5pt 黄金间距，字母降部优雅悬空，呈现精致口袋词典的留白呼吸感。",
                        p2Eval: "⭐⭐⭐ 适中：2.5pt 间距，体量缩小后拥挤感略微减轻。",
                        p3Eval: "⭐⭐⭐⭐ 良好：2.5pt 间距下无衬线字母呼吸均匀。"
                    )

                    principleAuditCard(
                        principle: "3. 重复与统一 (Repetition) · 全局一致性",
                        baselineEval: "❌ 违和：全页分类已去粗黑化（13pt Regular），展开区 700 Bold 变成唯一突兀黑坨。",
                        p1Eval: "⭐⭐⭐⭐⭐ 极佳：全页贯穿「温润日系书卷」哲学，与分类标签的 Regular 形成全局呼应。",
                        p2Eval: "⭐⭐ 弱：仍保留 700 Bold 孤岛，未能与全页去标签化完全统一。",
                        p3Eval: "⭐⭐⭐⭐ 强：彻底统一到 Gothic A1 家族，无衬线统一性极强。"
                    )

                    principleAuditCard(
                        principle: "4. 对齐 (Alignment) · 视线流动平稳度",
                        baselineEval: "❌ 微倾：由于右侧粗重字权重心下沉，左侧 32×32 图标视线中心显得偏上。",
                        p1Eval: "⭐⭐⭐⭐⭐ 平稳：14pt Regular 文字块轻盈平正，与左侧图标磁贴完美达成视觉水平轴平衡。",
                        p2Eval: "⭐⭐⭐ 良好：字号微缩后倾斜感减轻。",
                        p3Eval: "⭐⭐⭐⭐ 优良：几何水平字形，居中平稳。"
                    )
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private func principleAuditCard(principle: String, baselineEval: String, p1Eval: String, p2Eval: String, p3Eval: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(principle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Color.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("• 生产基准: \(baselineEval)").font(.system(size: 11.5)).foregroundStyle(AppTheme.Color.textSecondary)
                Text("• 方案 1 (书卷 ⭐): \(p1Eval)").font(.system(size: 11.5)).foregroundStyle(Color.purple)
                Text("• 方案 2 (微缩): \(p2Eval)").font(.system(size: 11.5)).foregroundStyle(AppTheme.Color.textMuted)
                Text("• 方案 3 (现代): \(p3Eval)").font(.system(size: 11.5)).foregroundStyle(AppTheme.Color.textMuted)
            }
        }
        .padding(12)
        .background(AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
    }

    // MARK: - 辅助方法与参数工厂

    private func proposalSpecBanner(_ prop: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(prop == .proposal1 ? Color.orange : Color.purple)
                Text("当前激活方案排版度量：\(prop.shortTitle)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text(fontSpecSummary(prop))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Text(prop.badgeDescription)
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(12)
        .background(prop == .proposal1 ? Color.orange.opacity(0.08) : Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(prop == .proposal1 ? Color.orange.opacity(0.3) : Color.purple.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func fontForEnglish(_ prop: Proposal) -> Font {
        FontLoader.registerCustomFonts()
        switch prop {
        case .baseline:
            return .custom("Charter-Bold", size: 15.0, relativeTo: .subheadline)
        case .proposal1:
            // 方案 1 · 意式书卷：Charter 14.0pt Regular
            return .custom("Charter", size: 14.0, relativeTo: .subheadline)
        case .proposal2:
            // 方案 2 · 轻挺微缩：Charter 13.5pt Bold
            return .custom("Charter-Bold", size: 13.5, relativeTo: .subheadline)
        case .proposal3:
            // 方案 3 · 现代同源：Gothic A1 13.5pt Medium
            return .custom("GothicA1-Medium", size: 13.5, relativeTo: .subheadline)
        }
    }

    private func verticalSpacing(for prop: Proposal) -> CGFloat {
        switch prop {
        case .baseline:  return 2.0
        case .proposal1: return 3.5  // 留足西文降部呼吸
        case .proposal2: return 2.5
        case .proposal3: return 2.5
        }
    }

    private func fontSpecSummary(_ prop: Proposal) -> String {
        switch prop {
        case .baseline:  return "Charter 15pt / Bold 700 · 2.0pt 间距"
        case .proposal1: return "Charter 14pt / Regular 400 · 3.5pt 间距"
        case .proposal2: return "Charter 13.5pt / Bold 700 · 2.5pt 间距"
        case .proposal3: return "Gothic A1 13.5pt / Medium 500 · 2.5pt 间距"
        }
    }

    private func rationaleForProposal(_ prop: Proposal) -> String {
        switch prop {
        case .baseline:
            return "线上现状：黑度极高，单字笨重，大面积展开时压迫感明显。"
        case .proposal1:
            return "推荐理由：笔画与冬青黑 1:1 光学同宽，彻底去除了笨重黑坨，呈现优雅书卷字典质感。"
        case .proposal2:
            return "微缩折中：保留粗衬线词头定位点，但将字号压至 13.5pt，弱化对父级 13pt 的抢戏。"
        case .proposal3:
            return "纯粹极简：与全页生活分类标签同属于 Gothic A1 家族，无衬线线条精炼利落。"
        }
    }

    // MARK: - 真实场景样例数据池

    private var currentEntries: [Tab2WordEntry] {
        switch selectedDataset {
        case .work:    return workSampleEntries
        case .coffee:  return coffeeSampleEntries
        case .fitness: return fitnessSampleEntries
        case .social:  return socialSampleEntries
        case .stress:  return stressTestEntries
        }
    }

    private var workSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "deadline", entryKind: "word", granularity: "word", nativeMeaning: "截止日期 / 最后期限"),
            Tab2WordEntry(lemma: "catch up", entryKind: "phrase", granularity: "sentence", nativeMeaning: "碰头同步进度 / 赶上日程"),
            Tab2WordEntry(lemma: "streamline", entryKind: "word", granularity: "word", nativeMeaning: "精简流程 / 提高效率"),
            Tab2WordEntry(lemma: "touch base", entryKind: "phrase", granularity: "sentence", nativeMeaning: "简短接触 / 快速碰一下"),
            Tab2WordEntry(lemma: "bandwidth", entryKind: "word", granularity: "word", nativeMeaning: "精力 / 时间余量"),
            Tab2WordEntry(lemma: "align on", entryKind: "phrase", granularity: "sentence", nativeMeaning: "对齐观点 / 达成共识"),
            Tab2WordEntry(lemma: "deliverable", entryKind: "word", granularity: "word", nativeMeaning: "可交付成果 / 项目成果")
        ]
    }

    private var coffeeSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "pour-over", entryKind: "word", granularity: "word", nativeMeaning: "手冲滴滤咖啡"),
            Tab2WordEntry(lemma: "cappuccino", entryKind: "word", granularity: "word", nativeMeaning: "卡布奇诺咖啡"),
            Tab2WordEntry(lemma: "grab a bite", entryKind: "phrase", granularity: "sentence", nativeMeaning: "随便吃点垫垫肚子"),
            Tab2WordEntry(lemma: "crema", entryKind: "word", granularity: "word", nativeMeaning: "浓缩咖啡表面的醇厚油脂"),
            Tab2WordEntry(lemma: "morning stroll", entryKind: "phrase", granularity: "sentence", nativeMeaning: "清晨漫步 / 散步"),
            Tab2WordEntry(lemma: "wholesome", entryKind: "word", granularity: "word", nativeMeaning: "健康治愈的 / 温暖美好的")
        ]
    }

    private var fitnessSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "warm up", entryKind: "phrase", granularity: "sentence", nativeMeaning: "热身运动 / 准备活动"),
            Tab2WordEntry(lemma: "consistency", entryKind: "word", granularity: "word", nativeMeaning: "持之以恒 / 持续自律"),
            Tab2WordEntry(lemma: "push through", entryKind: "phrase", granularity: "sentence", nativeMeaning: "咬牙坚持 / 冲破极点"),
            Tab2WordEntry(lemma: "cool down", entryKind: "phrase", granularity: "sentence", nativeMeaning: "整理放松 / 拉伸"),
            Tab2WordEntry(lemma: "runner's high", entryKind: "idiom", granularity: "sentence", nativeMeaning: "跑步者的极度愉悦感")
        ]
    }

    private var socialSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "rekindle", entryKind: "word", granularity: "word", nativeMeaning: "重新联络 / 重燃情谊"),
            Tab2WordEntry(lemma: "break the ice", entryKind: "idiom", granularity: "sentence", nativeMeaning: "打破僵局 / 消除拘谨"),
            Tab2WordEntry(lemma: "empathize", entryKind: "word", granularity: "word", nativeMeaning: "产生共鸣 / 感同身受"),
            Tab2WordEntry(lemma: "quality time", entryKind: "phrase", granularity: "sentence", nativeMeaning: "高质量陪伴时光"),
            Tab2WordEntry(lemma: "heart-to-heart", entryKind: "idiom", granularity: "sentence", nativeMeaning: "推心置腹的 / 贴心长谈")
        ]
    }

    private var stressTestEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "nap", entryKind: "word", granularity: "word", nativeMeaning: "小憩 / 打盹 (超短单字)"),
            Tab2WordEntry(lemma: "serendipity", entryKind: "word", granularity: "word", nativeMeaning: "不期而至的美好 (长单语)"),
            Tab2WordEntry(lemma: "on-the-fly", entryKind: "idiom", granularity: "word", nativeMeaning: "临时 / 即兴而行 (连字符词)"),
            Tab2WordEntry(lemma: "leave no stone unturned", entryKind: "idiom", granularity: "sentence", nativeMeaning: "想尽一切办法 (整句短语)"),
            Tab2WordEntry(lemma: "wrap up", entryKind: "phrase", granularity: "sentence", nativeMeaning: "圆满收尾 (动词短语)")
        ]
    }
}

// MARK: - SwiftUI Preview Provider

#Preview("Topics 展开词条三大优化方案沙盒") {
    Tab2TopicsWordTypographyProposalsPreview()
}
#endif
