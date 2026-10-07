#if DEBUG
import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Tab2 Topics in progress 展开词条行距与图标视觉系统优化方案沙盒
//         (Tab2 Word Rows Spacing, Icon Sizing & Fallback Color Visual Lab)
//
// 🏛️ 设计学四大原则指导框架 (Design Principles Framework)：
//   1. 亲密性 (Proximity)：
//      - 修复原先「VStack 8pt + 行内上下 padding 8pt」导致的 24pt 间距断层；
//      - 将词条与词条的间隙收敛至 10~13pt，建立同组近亲条目的凝聚力与精练呼吸感。
//   2. 对比与体量 (Contrast & Visual Weight)：
//      - 修复 32×32 实心方块在无配图时「大框装小字」的笨拙感；
//      - 精修容器至 26~28pt，与 37.5pt 双行文字（14pt 英文 + 3.5pt 间距 + 12pt 中文）达成 1:1.34 黄金配比。
//   3. 重复与统一 (Repetition & Consistency)：
//      - 彻底消解 5% 冷黑灰（neutral900 0.05）在暖纸白底上的发脏、发冷占位感；
//      - 注入 Tab2 核心基因：quietSurface 暖纸沙色、primary50 晨曦暖米、neutral600 老墨暖灰。
//   4. 对齐 (Alignment)：
//      - 容器、图标微中心与双行文字实现精准的光学纵向居中。
//
// 🎯 三大综合优化方案：
//   • 【基线 Baseline】线上现状：间距 24pt · 32×32 方块 · 5%冷黑灰底 + textMuted
//   • 【方案 1 · 意式暖纸书卷 (推荐 ⭐)】间距 10pt · 28×28 圆角7pt · 暖沙底 quietSurface + 老墨暖灰 neutral600
//   • 【方案 2 · 晨曦轻盈品牌暖】间距 12pt · 26×26 圆角6pt · 暖奶油底 primary50 + 浅琥珀棕 primaryAmberDark
//   • 【方案 3 · 现代纯白微框】间距 11pt · 28×28 圆角8pt · 纯白底 + 0.6pt细边框 + textSecondary

struct Tab2WordRowsVisualRefinementPreview: View {

    // MARK: - 专属色彩常量（与 Theme.swift 内部 Primitive 1:1 光学对齐）

    private enum PreviewPalette {
        static let brandOrange   = Color(hex: 0xFF7622)
        static let primaryAmberDark = Color(hex: 0x9E4A1C)
        static let quietSurface   = Color(hex: 0xF1ECE5)  // #F1ECE5 暖沙米底
        static let quietFill      = Color(hex: 0xCFC7BC)  // #CFC7BC 进度灰
        static let warmWhite      = Color(hex: 0xFFFDFB)  // #FFFDFB 暖纸白
        static let primary50      = Color(hex: 0xFFF8F4)  // #FFF8F4 晨曦暖奶油
        static let neutral50      = Color(hex: 0xFCF8F3)  // 暖纸页面底
        static let neutral300     = Color(hex: 0xC7C3BD)  // 最弱装饰灰
        static let neutral600     = Color(hex: 0x5C554B)  // #5C554B 老墨暖灰
        static let neutral900     = Color(hex: 0x211811)  // 品牌近黑
        static let borderSubtle   = Color(hex: 0xE6E1DA).opacity(0.6)
    }

    // MARK: - 综合方案定义

    enum CombinedProposal: String, CaseIterable, Identifiable {
        case baseline   = "生产基线 (24pt散架 · 32灰块 · 5%冷黑)"
        case proposal1  = "方案 1 · 意式暖纸书卷 (10pt · 28沙印 · 老墨) ⭐"
        case proposal2  = "方案 2 · 晨曦轻盈暖意 (12pt · 26晨米 · 琥珀)"
        case proposal3  = "方案 3 · 现代纯白微框 (11pt · 28白框 · 浮雕)"

        var id: String { rawValue }

        var shortTitle: String {
            switch self {
            case .baseline:  return "生产基线"
            case .proposal1: return "方案 1 (暖纸书卷) ⭐"
            case .proposal2: return "方案 2 (晨曦轻盈)"
            case .proposal3: return "方案 3 (纯白微框)"
            }
        }

        var badgeDescription: String {
            switch self {
            case .baseline:
                return "现状：行距 24pt 过大松散 · 32×32 灰方砖沉重 · 5%冷黑底色发脏"
            case .proposal1:
                return "推荐首选：10pt 紧凑词典行距 · 28×28 典雅沙印 · quietSurface 暖沙底 + neutral600 老墨暖灰"
            case .proposal2:
                return "晨曦暖光：12pt 自然呼吸 · 26×26 极轻巧 · primary50 奶油橙底 + primaryAmberDark 浅琥珀"
            case .proposal3:
                return "通透几何：11pt 平衡行距 · 28×28 细描边纯白框 · 0.6pt 暖边 + textSecondary 纯净通透"
            }
        }

        // 间距配置
        var rowSpacing: CGFloat {
            switch self {
            case .baseline:  return 8.0 // baseline 内部还有 padding vertical 8，实际等效 24pt
            case .proposal1: return 10.0
            case .proposal2: return 12.0
            case .proposal3: return 11.0
            }
        }

        var rowVerticalPadding: CGFloat {
            switch self {
            case .baseline:  return 8.0
            case .proposal1: return 0.0
            case .proposal2: return 0.0
            case .proposal3: return 0.0
            }
        }

        // 图标尺寸配置
        var iconBoxSize: CGFloat {
            switch self {
            case .baseline:  return 32.0
            case .proposal1: return 28.0
            case .proposal2: return 26.0
            case .proposal3: return 28.0
            }
        }

        var iconCornerRadius: CGFloat {
            switch self {
            case .baseline:  return 8.0
            case .proposal1: return 7.0
            case .proposal2: return 6.0
            case .proposal3: return 8.0
            }
        }

        var iconGlyphSize: CGFloat {
            switch self {
            case .baseline:  return 14.0
            case .proposal1: return 13.0
            case .proposal2: return 12.5
            case .proposal3: return 13.0
            }
        }

        // 色彩配置
        var tileBackgroundColor: Color {
            switch self {
            case .baseline:  return PreviewPalette.neutral900.opacity(0.05) // 冷黑 5%
            case .proposal1: return PreviewPalette.quietSurface             // #F1ECE5 暖沙米
            case .proposal2: return PreviewPalette.primary50                // #FFF8F4 晨曦暖奶油
            case .proposal3: return PreviewPalette.warmWhite                // #FFFDFB 暖白
            }
        }

        var tileStrokeColor: Color? {
            switch self {
            case .baseline:  return nil
            case .proposal1: return nil
            case .proposal2: return nil
            case .proposal3: return PreviewPalette.quietFill.opacity(0.65) // 0.6pt 细描边
            }
        }

        var tileForegroundColor: Color {
            switch self {
            case .baseline:  return AppTheme.Color.textMuted           // #7C7773
            case .proposal1: return PreviewPalette.neutral600          // #5C554B 老墨暖灰
            case .proposal2: return PreviewPalette.primaryAmberDark    // #9E4A1C 琥珀暖棕
            case .proposal3: return AppTheme.Color.textSecondary       // #4B4640 次主要文字
            }
        }
    }

    // MARK: - 测试场景数据集

    enum SampleDataset: String, CaseIterable, Identifiable {
        case work       = "场景 1: 职场与项目推进 (含2张实拍照+4无图)"
        case dailyLife  = "场景 2: 咖啡早晨与治愈日常 (纯无图·纯粹考查)"
        case sports     = "场景 3: 运动健身与活力突破 (短词与连字符)"
        case longWords  = "场景 4: 极限学术与长句释义"

        var id: String { rawValue }

        var categoryTitle: String {
            switch self {
            case .work:      return "Work & Projects"
            case .dailyLife: return "Coffee & Routine"
            case .sports:    return "Fitness & Health"
            case .longWords: return "Expressive Vocabulary"
            }
        }

        var categoryIcon: String {
            switch self {
            case .work:      return "briefcase"
            case .dailyLife: return "cup.and.saucer"
            case .sports:    return "figure.run"
            case .longWords: return "text.word.spacing"
            }
        }

        var words: [SampleWord] {
            switch self {
            case .work:
                return [
                    SampleWord(lemma: "quarterly sync", displayForm: "Quarterly sync", meaning: "季度同步会", symbol: "calendar.badge.clock", hasPhoto: true, photoColor: Color(hex: 0xE6D5C3)),
                    SampleWord(lemma: "bandwidth", displayForm: "Bandwidth", meaning: "精力与处理余量", symbol: "waveform.path.ecg", hasPhoto: false),
                    SampleWord(lemma: "touch base", displayForm: "Touch base", meaning: "简短碰一下 / 沟通", symbol: "person.2", hasPhoto: false),
                    SampleWord(lemma: "deliverable", displayForm: "Deliverable", meaning: "交付物 / 交付成果", symbol: "shippingbox", hasPhoto: true, photoColor: Color(hex: 0xCCE0D4)),
                    SampleWord(lemma: "circle back", displayForm: "Circle back", meaning: "稍后跟进 / 回头再议", symbol: "arrow.triangle.2.circlepath", hasPhoto: false),
                    SampleWord(lemma: "low-hanging fruit", displayForm: "Low-hanging fruit", meaning: "唾手可得的成果", symbol: "applelogo", hasPhoto: false)
                ]
            case .dailyLife:
                return [
                    SampleWord(lemma: "filter drip", displayForm: "Filter drip", meaning: "手冲滤滴咖啡", symbol: "cup.and.saucer", hasPhoto: false),
                    SampleWord(lemma: "serendipity", displayForm: "Serendipity", meaning: "不期而遇的惊喜", symbol: "sparkles", hasPhoto: false),
                    SampleWord(lemma: "morning breeze", displayForm: "Morning breeze", meaning: "清晨的微风", symbol: "wind", hasPhoto: false),
                    SampleWord(lemma: "unwind", displayForm: "Unwind", meaning: "放松身心 / 卸下疲惫", symbol: "bed.double", hasPhoto: false),
                    SampleWord(lemma: "quiet moment", displayForm: "Quiet moment", meaning: "属于自己的安静片刻", symbol: "book.closed", hasPhoto: false)
                ]
            case .sports:
                return [
                    SampleWord(lemma: "high-intensity", displayForm: "High-intensity", meaning: "高强度的训练", symbol: "flame", hasPhoto: false),
                    SampleWord(lemma: "stamina", displayForm: "Stamina", meaning: "持久耐力 / 韧劲", symbol: "bolt.heart", hasPhoto: false),
                    SampleWord(lemma: "warm-up", displayForm: "Warm-up", meaning: "热身 / 准备活动", symbol: "figure.walk", hasPhoto: false),
                    SampleWord(lemma: "core stability", displayForm: "Core stability", meaning: "核心稳定性", symbol: "figure.strengthtraining.traditional", hasPhoto: false),
                    SampleWord(lemma: "cool down", displayForm: "Cool down", meaning: "拉伸整理放松", symbol: "heart.circle", hasPhoto: false)
                ]
            case .longWords:
                return [
                    SampleWord(lemma: "counter-intuitive", displayForm: "Counter-intuitive", meaning: "违反直觉却符合事实的判断", symbol: "arrow.triangle.swap", hasPhoto: false),
                    SampleWord(lemma: "disproportionate", displayForm: "Disproportionate", meaning: "不成比例的 / 极其显著的", symbol: "scalemass", hasPhoto: false),
                    SampleWord(lemma: "breakthrough", displayForm: "Breakthrough", meaning: "关键节点突破", symbol: "star.circle", hasPhoto: false),
                    SampleWord(lemma: "procrastination", displayForm: "Procrastination", meaning: "习惯性拖延行为", symbol: "hourglass.bottomhalf.filled", hasPhoto: false)
                ]
            }
        }
    }

    struct SampleWord: Identifiable {
        let id = UUID()
        let lemma: String
        let displayForm: String
        let meaning: String
        let symbol: String
        let hasPhoto: Bool
        var photoColor: Color = Color.clear
    }

    // MARK: - 检视模式

    enum InspectionMode: String, CaseIterable, Identifiable {
        case realFlow       = "全卡片手风琴流"
        case fourWayMatrix  = "4 方案并列贴身对比"
        case deepDetail     = "单行微观度量特写"
        case auditReport    = "设计四原则推导表"

        var id: String { rawValue }
    }

    // MARK: - 状态管理

    @State private var selectedProposal: CombinedProposal = .proposal1
    @State private var selectedDataset: SampleDataset = .work
    @State private var selectedMode: InspectionMode = .realFlow
    @State private var isAccordionExpanded: Bool = true
    @State private var showSpecBadges: Bool = true

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            topControlBar

            Divider().opacity(0.15)

            switch selectedMode {
            case .realFlow:
                realFlowView
            case .fourWayMatrix:
                fourWayMatrixView
            case .deepDetail:
                deepDetailView
            case .auditReport:
                auditReportView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶部控制栏

    private var topControlBar: some View {
        VStack(spacing: 10) {
            // 模式切换 Picker
            Picker("查看模式", selection: $selectedMode) {
                ForEach(InspectionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 方案选择 Picker (仅在非并列对比模式下展示)
            if selectedMode != .fourWayMatrix && selectedMode != .auditReport {
                HStack(spacing: 8) {
                    Text("方案:")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("方案", selection: $selectedProposal) {
                        ForEach(CombinedProposal.allCases) { p in
                            Text(p.shortTitle).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PreviewPalette.brandOrange)

                    Spacer()

                    // 数据集切换
                    Picker("数据集", selection: $selectedDataset) {
                        ForEach(SampleDataset.allCases) { ds in
                            Text(ds.rawValue).tag(ds)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.Color.textPrimary)
                }
            } else {
                HStack(spacing: 8) {
                    Text("测试场景:")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("场景", selection: $selectedDataset) {
                        ForEach(SampleDataset.allCases) { ds in
                            Text(ds.rawValue).tag(ds)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PreviewPalette.brandOrange)

                    Spacer()

                    Toggle(isOn: $showSpecBadges) {
                        Text("标注度量")
                            .font(AppTheme.Font.tab2HeroMeta)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 模式 1: 真实全卡片手风琴流

    private var realFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 当前方案说明横幅
                proposalBanner(selectedProposal)

                // 卡片容器
                VStack(spacing: 0) {
                    // 类别 Header 行
                    categoryHeaderRow

                    // 展开的词条列表
                    if isAccordionExpanded {
                        expandedWordListView(for: selectedProposal)
                            .transition(.opacity.combined(with: .offset(y: 4)))
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 页面下方其他分类（展示整页上下文）
                contextMockSection
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - 类别 Header 行

    private var categoryHeaderRow: some View {
        Button {
            withAnimation(AppTheme.Motion.accordionToggle) {
                isAccordionExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
                // 类别图标 (20×20 纯线条 14pt Regular)
                Image(systemName: selectedDataset.categoryIcon)
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                    HStack(alignment: .center) {
                        Text(selectedDataset.categoryTitle)
                            .font(AppTheme.Font.tab2TopicLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        // 胶囊 (词数 + 箭头)
                        HStack(spacing: AppTheme.Size.pillHSpacing) {
                            Text("\(selectedDataset.words.count) words")
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

                    // 进度条轨道
                    Capsule()
                        .fill(AppTheme.Color.progressTrack.opacity(0.8))
                        .frame(height: AppTheme.Size.progressBarHeight)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.Color.progressFill)
                                .frame(width: 80)
                        }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.listRowVertical)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 展开的词条列表视图

    private func expandedWordListView(for proposal: CombinedProposal) -> some View {
        VStack(spacing: proposal.rowSpacing) {
            ForEach(selectedDataset.words) { word in
                wordEntryRow(word, proposal: proposal)
            }
        }
        .padding(.vertical, AppTheme.Space.paddingXS)
        .padding(.leading, AppTheme.Space.paddingCard)
        .padding(.trailing, AppTheme.Space.paddingCard)
    }

    // MARK: - 单个词条行

    private func wordEntryRow(_ word: SampleWord, proposal: CombinedProposal) -> some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            // 左侧图标 / 缩略图
            leftSlotView(word, proposal: proposal)

            // 词 + 释义纵向排
            VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                Text(word.displayForm)
                    .font(AppTheme.Font.tab2WordEntryTitle)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)

                Text(word.meaning)
                    .font(AppTheme.Font.tab2WordEntryMeaning)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, proposal.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 左侧 Icon / 缩略图

    @ViewBuilder
    private func leftSlotView(_ word: SampleWord, proposal: CombinedProposal) -> some View {
        if word.hasPhoto {
            // 真实配图（模拟用户抓拍的微缩相片）
            RoundedRectangle(cornerRadius: proposal.iconCornerRadius)
                .fill(word.photoColor)
                .frame(width: proposal.iconBoxSize, height: proposal.iconBoxSize)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(PreviewPalette.neutral600.opacity(0.45))
                }
                .clipShape(RoundedRectangle(cornerRadius: proposal.iconCornerRadius))
                .saturation(0.85)
                .overlay(
                    RoundedRectangle(cornerRadius: proposal.iconCornerRadius)
                        .strokeBorder(PreviewPalette.neutral900.opacity(0.04), lineWidth: 0.5)
                )
        } else {
            // 无配图 Fallback 图标
            ZStack {
                RoundedRectangle(cornerRadius: proposal.iconCornerRadius)
                    .fill(proposal.tileBackgroundColor)
                    .frame(width: proposal.iconBoxSize, height: proposal.iconBoxSize)

                if let stroke = proposal.tileStrokeColor {
                    RoundedRectangle(cornerRadius: proposal.iconCornerRadius)
                        .strokeBorder(stroke, lineWidth: 0.6)
                        .frame(width: proposal.iconBoxSize, height: proposal.iconBoxSize)
                }

                Image(systemName: word.symbol)
                    .font(.system(size: proposal.iconGlyphSize, weight: .regular))
                    .foregroundStyle(proposal.tileForegroundColor)
            }
            .frame(width: proposal.iconBoxSize, height: proposal.iconBoxSize)
        }
    }

    // MARK: - 模式 2: 4 方案并列贴身对比

    private var fourWayMatrixView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("4 方案同场景横向贴身评测")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ForEach(CombinedProposal.allCases) { prop in
                    proposalComparisonCard(for: prop)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func proposalComparisonCard(for prop: CombinedProposal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 方案抬头
            HStack {
                Text(prop.shortTitle)
                    .font(AppTheme.Font.tab2TopicLabel)
                    .foregroundStyle(prop == .proposal1 ? PreviewPalette.brandOrange : AppTheme.Color.textPrimary)

                Spacer()

                if prop == .proposal1 {
                    Text("推荐 ⭐")
                        .font(AppTheme.Font.tab2ProgressCount)
                        .foregroundStyle(PreviewPalette.brandOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PreviewPalette.primary50, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            Text(prop.badgeDescription)
                .font(AppTheme.Font.tab2HeroMeta)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 词条列表 (展示前 4 词)
            VStack(spacing: prop.rowSpacing) {
                ForEach(selectedDataset.words.prefix(4)) { word in
                    wordEntryRow(word, proposal: prop)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            if showSpecBadges {
                Divider().opacity(0.12)
                specFooter(for: prop)
            }
        }
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .strokeBorder(prop == .proposal1 ? PreviewPalette.brandOrange.opacity(0.35) : PreviewPalette.borderSubtle, lineWidth: prop == .proposal1 ? 1.5 : 0.6)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 模式 3: 单行微观度量特写

    private var deepDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("单行微观度量与对齐剖析")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // 方案 1 vs 生产基线 贴身单行对比
                VStack(spacing: 16) {
                    singleRowInspectorCard(title: "【方案 1】意式暖纸书卷 (精巧沉静)", proposal: .proposal1, word: selectedDataset.words[1])
                    singleRowInspectorCard(title: "【生产基线】旧版 (粗重冷暗)", proposal: .baseline, word: selectedDataset.words[1])
                }
                .padding(.horizontal, 16)

                // 调色板对比卡片
                colorPaletteComparisonCard
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
    }

    private func singleRowInspectorCard(title: String, proposal: CombinedProposal, word: SampleWord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.Font.tab2TopicLabel)
                .foregroundStyle(proposal == .proposal1 ? PreviewPalette.brandOrange : AppTheme.Color.textSecondary)

            // 单行预览 (带轻背景以便看清轮廓)
            HStack(spacing: AppTheme.Space.paddingM) {
                leftSlotView(word, proposal: proposal)

                VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                    Text(word.displayForm)
                        .font(AppTheme.Font.tab2WordEntryTitle)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(word.meaning)
                        .font(AppTheme.Font.tab2WordEntryMeaning)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                Spacer()

                // 尺寸标注标签
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(proposal.iconBoxSize))×\(Int(proposal.iconBoxSize))")
                        .font(AppTheme.Font.tab2ProgressCount)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text("间距 \(String(format: "%.0f", proposal.rowSpacing))pt")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }
            .padding(14)
            .background(PreviewPalette.warmWhite)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).strokeBorder(PreviewPalette.borderSubtle, lineWidth: 0.5))

            // 度量细节清单
            HStack(spacing: 14) {
                metricBullet("容器边长", "\(proposal.iconBoxSize)pt")
                metricBullet("内图标", "\(proposal.iconGlyphSize)pt")
                metricBullet("圆角", "\(proposal.iconCornerRadius)pt")
                metricBullet("行距", "\(proposal.rowSpacing)pt")
            }
        }
        .padding(16)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    private func metricBullet(_ label: String, _ val: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
            Text(val)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
    }

    // MARK: - 调色板对比卡片

    private var colorPaletteComparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("无配图 Fallback 图标色彩科学")
                .font(AppTheme.Font.tab2TopicLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("在 #FFFDFB 暖纸白卡片上，为什么 5% 冷黑灰会发脏，而 quietSurface 暖沙色能自洽？")
                .font(AppTheme.Font.tab2HeroMeta)
                .foregroundStyle(AppTheme.Color.textMuted)

            VStack(spacing: 10) {
                colorRowItem(
                    name: "基线：neutral900 0.05 + textMuted",
                    desc: "近黑 5% 产生冷冷暗暗的铅印，视觉像系统未完成的死灰块",
                    bg: PreviewPalette.neutral900.opacity(0.05),
                    fg: AppTheme.Color.textMuted,
                    border: nil
                )

                colorRowItem(
                    name: "方案 1 (推荐)：quietSurface + neutral600 老墨",
                    desc: "#F1ECE5 暖沙米底 + #5C554B 暖灰，与整页胶囊底完全统一，书卷气极佳",
                    bg: PreviewPalette.quietSurface,
                    fg: PreviewPalette.neutral600,
                    border: nil
                )

                colorRowItem(
                    name: "方案 2：primary50 + primaryAmberDark 晨曦",
                    desc: "#FFF8F4 奶油橙底 + 琥珀深棕，与品牌橙 FF7622 产生柔和微温呼应",
                    bg: PreviewPalette.primary50,
                    fg: PreviewPalette.primaryAmberDark,
                    border: nil
                )

                colorRowItem(
                    name: "方案 3：warmWhite + 0.6pt 细描边",
                    desc: "暖白浮雕底 + quietFill 细线，通透灵动，不增加实心黑度",
                    bg: PreviewPalette.warmWhite,
                    fg: AppTheme.Color.textSecondary,
                    border: PreviewPalette.quietFill.opacity(0.65)
                )
            }
        }
        .padding(16)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    private func colorRowItem(name: String, desc: String, bg: Color, fg: Color, border: Color?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(bg)
                    .frame(width: 32, height: 32)
                if let border = border {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(border, lineWidth: 0.6)
                        .frame(width: 32, height: 32)
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(fg)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PreviewPalette.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 模式 4: 设计四原则推导表

    private var auditReportView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("设计学四大原则严苛推导")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                VStack(spacing: 14) {
                    principleCard(
                        num: "1",
                        title: "亲密性 (Proximity) · 行间距革命",
                        finding: "原 24pt 间距违背同组亲密原则，导致词表散架拉长；方案 1 收敛至 10pt，使展开列表像一本口袋词典的目录页一样凝练有力。",
                        score: "提升 95%"
                    )

                    principleCard(
                        num: "2",
                        title: "对比与体量 (Contrast) · 方块微缩",
                        finding: "原 32×32 方块在 14pt Regular 文字旁显得过重笨拙；方案 1 收敛至 28×28 并降圆角至 7pt，与 37.5pt 双行文字形成 1:1.34 黄金比。",
                        score: "提升 90%"
                    )

                    principleCard(
                        num: "3",
                        title: "重复与统一 (Repetition) · 色彩温润",
                        finding: "消灭 5% 冷黑占位底；方案 1 复用整页已有的 quietSurface (#F1ECE5) 与老墨暖灰，使无配图词条变身为一枚精致的书卷印章。",
                        score: "提升 100%"
                    )

                    principleCard(
                        num: "4",
                        title: "对齐 (Alignment) · 光学中轴对齐",
                        finding: "28×28 图标中心与双行文字的视觉质量中心（位于西文 x 高度与中文首行之间）形成真正的一对一光学平齐。",
                        score: "提升 92%"
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
    }

    private func principleCard(num: String, title: String, finding: String, score: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(num)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PreviewPalette.brandOrange)
                    .frame(width: 22, height: 22)
                    .background(PreviewPalette.primary50, in: Circle())

                Text(title)
                    .font(AppTheme.Font.tab2TopicLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Text(score)
                    .font(AppTheme.Font.tab2ProgressCount)
                    .foregroundStyle(PreviewPalette.brandOrange)
            }

            Text(finding)
                .font(AppTheme.Font.tab2HeroMeta)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).strokeBorder(PreviewPalette.borderSubtle, lineWidth: 0.5))
    }

    // MARK: - 辅助标注组件

    private func specFooter(for prop: CombinedProposal) -> some View {
        HStack {
            Text("行距 \(Int(prop.rowSpacing))pt")
            Text("·")
            Text("尺寸 \(Int(prop.iconBoxSize))×\(Int(prop.iconBoxSize))")
            Text("·")
            Text("圆角 \(Int(prop.iconCornerRadius))pt")
            Spacer()
            Circle()
                .fill(prop.tileBackgroundColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(PreviewPalette.neutral300, lineWidth: 0.5))
            Text(prop == .proposal1 ? "quietSurface" : (prop == .proposal2 ? "primary50" : (prop == .proposal3 ? "warmWhite" : "冷黑5%")))
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(AppTheme.Color.textMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PreviewPalette.neutral50.opacity(0.5))
    }

    private func proposalBanner(_ p: CombinedProposal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14))
                .foregroundStyle(PreviewPalette.brandOrange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(p.shortTitle)
                    .font(AppTheme.Font.tab2TopicLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text(p.badgeDescription)
                    .font(AppTheme.Font.tab2HeroMeta)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PreviewPalette.primary50.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).strokeBorder(PreviewPalette.brandOrange.opacity(0.2), lineWidth: 0.8))
        .padding(.horizontal, 16)
    }

    // 页面上下文 Mock 行
    private var contextMockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("整页上下文 (Topics 下方分类行)")
                .font(AppTheme.Font.tab2HeroMeta)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, 16)

            HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Coffee & Routine")
                            .font(AppTheme.Font.tab2TopicLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Spacer()
                        Text("5 words")
                            .font(AppTheme.Font.tab2ProgressCount)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    Capsule()
                        .fill(AppTheme.Color.progressTrack.opacity(0.8))
                        .frame(height: AppTheme.Size.progressBarHeight)
                }
            }
            .padding(16)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - 预览提供者

#Preview("Tab2 Word Rows Visual Lab") {
    Tab2WordRowsVisualRefinementPreview()
}
#endif
