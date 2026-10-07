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

// MARK: - Tab2 展开词条间距精细化探索与生产级手风琴下拉沙盒
//         (Tab2 Word Row Spacing Exploration & Production Accordion Dropdown Sandbox)
//
// 🎯 用户关键指令与真实生产还原：
//   1. 聚焦间距单一变量：排除其他干扰，专注解决「词条之间间距」问题；
//   2. 7 档精细候选间距快速切换：24pt (当前生产现状), 22pt, 20pt, 18pt, 16pt, 14pt, 12pt；
//   3. 100% 还原生产环境视觉与「下拉展开交互质感」：
//      - 包含完整的「Topics in progress」卡片、多分类折叠/展开联动；
//      - 精准复刻用户真实真机截图的 10 个词条（are coming, cloudy sky, fluffy, monsters, nose ring...）；
//      - 真实相册微缩照片与 fallback 图标混排；
//      - 丝滑原生 spring 动画，下游分类（Health & Fitness）被真实推开/回弹。

struct Tab2WordRowSpacingExplorationPreview: View {

    // MARK: - 间距候选档位枚举

    enum SpacingOption: CGFloat, CaseIterable, Identifiable {
        case space24 = 24.0 // 生产现状 Baseline (VStack 8 + vertical padding 8*2)
        case space22 = 22.0
        case space20 = 20.0
        case space18 = 18.0
        case space16 = 16.0
        case space14 = 14.0
        case space12 = 12.0

        var id: CGFloat { rawValue }

        var label: String {
            switch self {
            case .space24: return "24pt (现状)"
            case .space22: return "22pt"
            case .space20: return "20pt"
            case .space18: return "18pt"
            case .space16: return "16pt"
            case .space14: return "14pt"
            case .space12: return "12pt"
            }
        }

        var shortLabel: String {
            "\(Int(rawValue))"
        }

        var description: String {
            switch self {
            case .space24: return "生产现状：VStack 8pt + 行内上下各 8pt = 24pt。列表过长、严重散架。"
            case .space22: return "微缩 2pt：略微抑制散架感，但依然偏空。"
            case .space20: return "适中从容：行间呼吸充分，适合长句释义较多的场景。"
            case .space18: return "黄金平衡：行间亲密适度，多词展开时屏幕占用合理。"
            case .space16: return "紧凑雅致：经典 iOS 列表与书卷词典节奏，推荐重点体验。"
            case .space14: return "凝练高效：词条间亲密凝聚，高密度信息流。"
            case .space12: return "极致紧凑：近乎纯文字连续排版，展开 10 词仅占半屏。"
            }
        }
    }

    // MARK: - 真实真机词条数据结构（100% 还原用户截图）

    struct ScreenshotWord: Identifiable {
        let id = UUID()
        let english: String
        let chinese: String?
        let symbol: String
        let hasPhoto: Bool
        let photoAssetColor: Color
    }

    // 10 个真实真机词条（完全对应用户真机截图）
    private let screenshotWords: [ScreenshotWord] = [
        ScreenshotWord(english: "are coming", chinese: nil, symbol: "link", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "cloudy sky", chinese: "多云的天空", symbol: "link", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "distant landscape", chinese: "远处的风景", symbol: "link", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "fluffy", chinese: "毛茸茸的", symbol: "photo", hasPhoto: true, photoAssetColor: Color(hex: 0x8D8158)),
        ScreenshotWord(english: "grassy hill", chinese: "长满草的山丘", symbol: "link", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "monsters", chinese: nil, symbol: "book.closed", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "nose ring", chinese: "鼻环", symbol: "photo", hasPhoto: true, photoAssetColor: Color(hex: 0x827756)),
        ScreenshotWord(english: "overlooking the ocean", chinese: "俯瞰海洋", symbol: "link", hasPhoto: false, photoAssetColor: .clear),
        ScreenshotWord(english: "Pomeranian dog", chinese: "博美犬", symbol: "photo", hasPhoto: true, photoAssetColor: Color(hex: 0x7E7250)),
        ScreenshotWord(english: "sitting cross-legged", chinese: "盘腿坐着", symbol: "photo", hasPhoto: true, photoAssetColor: Color(hex: 0x7F7454))
    ]

    // MARK: - 交互状态

    @State private var selectedSpacing: SpacingOption = .space24
    @State private var selectedProgToWord: CGFloat = 10.0 // 默认采用 10.0pt (与上方标签 10pt 形成 1:1 镜像对称)
    @State private var selectedZhSize: CGFloat = 11.0 // 默认采用用户提议的更小字号 11.0pt
    @State private var selectedInnerGap: CGFloat = 4.0 // 默认采用用户提议的 4.0pt 行间距
    @State private var isHobbiesExpanded: Bool = true
    @State private var isFitnessExpanded: Bool = false
    @State private var showRulers: Bool = true
    @State private var viewPerspective: Perspective = .realFlow

    enum Perspective: String, CaseIterable, Identifiable {
        case realFlow     = "真实手风琴流"
        case sideBySide   = "关键档位对比"
        case metricsAudit = "高度数据分析"

        var id: String { rawValue }
    }

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            topControlBar

            Divider().opacity(0.15)

            switch viewPerspective {
            case .realFlow:
                realFlowView
            case .sideBySide:
                sideBySideView
            case .metricsAudit:
                metricsAuditView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶部控制栏

    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 模式切换
            Picker("查看视角", selection: $viewPerspective) {
                ForEach(Perspective.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            // 微调控制行 1：进度条至首词间距（10pt / 12pt / 14pt / 16pt / 28pt）
            HStack(spacing: 8) {
                Text("轨至首词:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x6D28D9))

                Picker("进度条至首词", selection: $selectedProgToWord) {
                    Text("10pt(镜像⭐)").tag(CGFloat(10.0))
                    Text("12pt").tag(CGFloat(12.0))
                    Text("14pt").tag(CGFloat(14.0))
                    Text("16pt").tag(CGFloat(16.0))
                    Text("28pt(现状)").tag(CGFloat(28.0))
                }
                .pickerStyle(.segmented)
            }

            // 微调控制行 2：中文字号与 4pt 间距
            HStack(spacing: 12) {
                // 中文字号选择
                HStack(spacing: 4) {
                    Text("中文:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("中文字号", selection: $selectedZhSize) {
                        Text("12pt(原)").tag(CGFloat(12.0))
                        Text("11.5pt").tag(CGFloat(11.5))
                        Text("11pt(更小)").tag(CGFloat(11.0))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 155)
                }

                // 英中间距选择
                HStack(spacing: 4) {
                    Text("行距:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("英中间距", selection: $selectedInnerGap) {
                        Text("3.5pt").tag(CGFloat(3.5))
                        Text("4.0pt").tag(CGFloat(4.0))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 105)
                }

                Spacer(minLength: 0)
            }

            // 7 档词间距快速选择器（24, 22, 20, 18, 16, 14, 12）
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("词与词间距 (Words Spacing):")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Text("\(Int(selectedSpacing.rawValue)) pt")
                        .font(AppTheme.Font.tab2ProgressCount)
                        .foregroundStyle(selectedSpacing == .space24 ? Color(hex: 0xB0392A) : AppTheme.Color.brandInk)
                        .monospacedDigit()

                    Spacer()

                    Toggle(isOn: $showRulers) {
                        Text("标尺")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                // 7 档圆角按钮栏
                HStack(spacing: 5) {
                    ForEach(SpacingOption.allCases) { opt in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedSpacing = opt
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(opt.shortLabel)
                                    .font(.system(size: 13, weight: selectedSpacing == opt ? .bold : .medium, design: .rounded))
                                if opt == .space24 {
                                    Text("现状")
                                        .font(.system(size: 8.5, weight: .regular))
                                } else if opt == .space16 {
                                    Text("推荐")
                                        .font(.system(size: 8.5, weight: .bold))
                                } else {
                                    Text("pt")
                                        .font(.system(size: 8.5, weight: .regular))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                selectedSpacing == opt
                                    ? (opt == .space24 ? Color(hex: 0x4B4640) : AppTheme.Color.brandStrong)
                                    : Color(hex: 0xF1ECE5)
                            )
                            .foregroundStyle(selectedSpacing == opt ? Color.white : AppTheme.Color.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedSpacing == opt ? Color.clear : Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 模式 1: 真实手风琴流（100% 还原生产真机界面）

    private var realFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部说明横幅
                spacingInfoBanner
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // 生产真实标题："Topics in progress"
                Text("Topics in progress")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingM)

                // 核心卡片容器（surfaceCard）
                VStack(spacing: 0) {
                    // 分类 1：Hobbies & Leisure (10 words)
                    hobbiesCategorySection

                    // 分类 2：Health & Fitness (1 word，被真实推开)
                    fitnessCategorySection

                    // 分类 3：Work & Career (5 words，真实下游)
                    workCategorySection
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 底部轻度留白提示
                Text("💡 点击「10 words ▲/▼」胶囊体验下拉展开与折叠推挤的真实手感")
                    .font(AppTheme.Font.tab2HeroMeta)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 分类 1: Hobbies & Leisure（含展开词条列表）

    private var hobbiesCategorySection: some View {
        VStack(spacing: 0) {
            // 分类头行（可点击折叠/展开）
            Button {
                withAnimation(AppTheme.Motion.accordionToggle) {
                    isHobbiesExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
                    // 游戏手柄图标
                    Image(systemName: "gamecontroller")
                        .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                    VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                        HStack(alignment: .center) {
                            Text("Hobbies & Leisure")
                                .font(AppTheme.Font.tab2TopicLabel)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            Spacer()

                            // 词数胶囊（含旋转箭头）
                            wordsPill(count: 10, isExpanded: isHobbiesExpanded)
                        }

                        // 进度条微轨与标尺 ③ (标签到进度条 10.0pt)
                        HStack(alignment: .center, spacing: 6) {
                            progressBar(progress: 0.5)

                            if showRulers {
                                Text("③ 标签→轨: 10.0pt")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: 0x1E40AF))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color(hex: 0xDBEAFE), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.listRowVertical)
            }
            .buttonStyle(.plain)

            // 手风琴展开的 10 个词条列表
            if isHobbiesExpanded {
                if showRulers {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color(hex: 0x7C3AED).opacity(0.35))
                            .frame(height: 1)

                        Text("① 轨至首词: \(String(format: "%.0f", selectedProgToWord))pt \(selectedProgToWord == 10 ? "(镜像对称⭐)" : "")")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0x6D28D9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: 0xEDE9FE), in: RoundedRectangle(cornerRadius: 3))

                        Rectangle()
                            .fill(Color(hex: 0x7C3AED).opacity(0.35))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                }

                // 进度条到首词的真实高度连接槽
                Spacer()
                    .frame(height: max(selectedProgToWord - 6, 2))

                VStack(spacing: selectedSpacing.rawValue) {
                    ForEach(Array(screenshotWords.enumerated()), id: \.element.id) { index, word in
                        wordEntryRow(word: word, index: index)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingXS)
                .padding(.leading, AppTheme.Space.paddingCard)
                .padding(.trailing, AppTheme.Space.paddingCard)
                .transition(.opacity.combined(with: .offset(y: 4)))
            }

            // 分类 1 与 分类 2 之间的间隙标尺 ① (24.0pt = 12pt 下边距 + 12pt 上边距)
            if showRulers {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(hex: 0xDC2626).opacity(0.35))
                        .frame(height: 1)

                    Text("① 两个大分类间距: 24.0pt (12+12)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x991B1B))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0xFEE2E2), in: RoundedRectangle(cornerRadius: 4))

                    Rectangle()
                        .fill(Color(hex: 0xDC2626).opacity(0.35))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 分类 2: Health & Fitness (1 word)

    private var fitnessCategorySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(AppTheme.Motion.accordionToggle) {
                    isFitnessExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
                    Image(systemName: "figure.run")
                        .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                    VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                        HStack(alignment: .center) {
                            Text("Health & Fitness")
                                .font(AppTheme.Font.tab2TopicLabel)
                                .foregroundStyle(AppTheme.Color.textPrimary)

                            Spacer()

                            wordsPill(count: 1, isExpanded: isFitnessExpanded)
                        }

                        progressBar(progress: 0.05)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.listRowVertical)
            }
            .buttonStyle(.plain)

            if isFitnessExpanded {
                VStack(spacing: selectedSpacing.rawValue) {
                    wordEntryRow(
                        word: ScreenshotWord(english: "stamina", chinese: "持久耐力", symbol: "figure.run", hasPhoto: false, photoAssetColor: .clear),
                        index: 0
                    )
                }
                .padding(.vertical, AppTheme.Space.paddingXS)
                .padding(.leading, AppTheme.Space.paddingCard)
                .padding(.trailing, AppTheme.Space.paddingCard)
                .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
    }

    // MARK: - 分类 3: Work & Career (5 words)

    private var workCategorySection: some View {
        HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
            Image(systemName: "briefcase")
                .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

            VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                HStack(alignment: .center) {
                    Text("Work & Career")
                        .font(AppTheme.Font.tab2TopicLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    wordsPill(count: 5, isExpanded: false)
                }

                progressBar(progress: 0.25)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.listRowVertical)
    }

    // MARK: - 单个词条行（完全匹配生产环境的 WordEntryRow）

    private func wordEntryRow(word: ScreenshotWord, index: Int) -> some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            // 左侧 32×32 缩略图 / Fallback 图标
            leftSlotView(word)

            // 词 + 释义纵向排
            VStack(alignment: .leading, spacing: selectedInnerGap) {
                Text(word.english)
                    .font(AppTheme.Font.tab2WordEntryTitle) // Charter 14pt Regular
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)

                if let meaning = word.chinese, !meaning.isEmpty {
                    Text(meaning)
                        .font(Font.custom("HiraginoSansGB-W3", size: selectedZhSize, relativeTo: .caption))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // 标尺指示器
            if showRulers && index < screenshotWords.count - 1 {
                HStack(spacing: 4) {
                    if index == 1 {
                        Text("④ 词内 \(String(format: "%.1f", selectedInnerGap))pt")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0x166534))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: 0xDCFCE7), in: RoundedRectangle(cornerRadius: 3))
                    }

                    Text("② 词距 \(Int(selectedSpacing.rawValue))pt")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(selectedSpacing == .space24 ? Color(hex: 0xB0392A) : Color(hex: 0x9A3412))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(selectedSpacing == .space24 ? Color(hex: 0xFEE2E2) : Color(hex: 0xFFEDD5), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder((selectedSpacing == .space24 ? Color(hex: 0xDC2626) : Color(hex: 0xEA580C)).opacity(0.3), lineWidth: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 左侧 32×32 图标（100% 生产现状）

    @ViewBuilder
    private func leftSlotView(_ word: ScreenshotWord) -> some View {
        if word.hasPhoto {
            // 真实配图（模拟用户抓拍的微缩相片）
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .fill(word.photoAssetColor)
                .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                .saturation(0.85)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        } else {
            // 生产真实 Fallback：32×32 方块 + 5% neutral900 底色 + textMuted 图标
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Color.iconTileBg) // neutral900.opacity(0.05)
                    .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)

                Image(systemName: word.symbol)
                    .font(.system(size: AppTheme.Size.entryBadgeGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .frame(width: AppTheme.Size.entryThumbnail, height: AppTheme.Size.entryThumbnail)
        }
    }

    // MARK: - 词数胶囊（WordsPill）

    private func wordsPill(count: Int, isExpanded: Bool) -> some View {
        HStack(spacing: AppTheme.Size.pillHSpacing) {
            Text("\(count) \(count == 1 ? "word" : "words")")
                .font(AppTheme.Font.tab2ProgressCount)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textSecondary)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: AppTheme.Size.expandArrow))
                .foregroundStyle(AppTheme.Color.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, AppTheme.Size.pillHPad)
        .padding(.vertical, AppTheme.Size.pillVPad)
        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
    }

    // MARK: - 进度条（ProgressBar）

    private func progressBar(progress: CGFloat) -> some View {
        Capsule()
            .fill(AppTheme.Color.progressTrack.opacity(0.8))
            .frame(height: AppTheme.Size.progressBarHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.progressFill)
                    .scaleEffect(x: max(progress, 0.02), anchor: .leading)
            }
    }

    // MARK: - 顶部说明横幅

    private var spacingInfoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: selectedSpacing == .space24 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(selectedSpacing == .space24 ? Color(hex: 0xB0392A) : AppTheme.Color.brandStrong)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(selectedSpacing.label)
                        .font(AppTheme.Font.tab2TopicLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    if selectedSpacing == .space24 {
                        Text("当前生产现状")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(hex: 0xB0392A))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: 0xFAF0EB), in: Capsule())
                    }
                }

                Text(selectedSpacing.description)
                    .font(AppTheme.Font.tab2HeroMeta)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFFDFB))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .strokeBorder(selectedSpacing == .space24 ? Color(hex: 0xB0392A).opacity(0.3) : AppTheme.Color.brandStrong.opacity(0.25), lineWidth: 0.8)
        )
    }

    // MARK: - 模式 2: 关键档位对比（24 vs 20 vs 16 vs 12 同台比较）

    private var sideBySideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("4 大典型档位同台对比 (10 词展开高度差)")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                ForEach([SpacingOption.space24, SpacingOption.space20, SpacingOption.space16, SpacingOption.space12]) { opt in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(opt.label)
                                .font(AppTheme.Font.tab2TopicLabel)
                                .foregroundStyle(opt == .space24 ? Color(hex: 0xB0392A) : (opt == .space16 ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary))

                            Spacer()

                            // 计算 10 词列表预计总节省高度
                            let savedPt = (24.0 - opt.rawValue) * 9.0
                            Text(savedPt == 0 ? "基线高度 100%" : "卡片节省 \(Int(savedPt)) pt")
                                .font(AppTheme.Font.tab2ProgressCount)
                                .foregroundStyle(opt == .space24 ? AppTheme.Color.textMuted : AppTheme.Color.brandStrong)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                        Text(opt.description)
                            .font(AppTheme.Font.tab2HeroMeta)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                        // 预览前 4 个词
                        VStack(spacing: opt.rawValue) {
                            ForEach(Array(screenshotWords.prefix(4).enumerated()), id: \.element.id) { index, word in
                                wordEntryRow(word: word, index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(AppTheme.Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                            .strokeBorder(opt == .space16 ? AppTheme.Color.brandStrong.opacity(0.4) : Color.black.opacity(0.06), lineWidth: opt == .space16 ? 1.5 : 0.6)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - 模式 3: 高度数据分析与亲密性评估

    private var metricsAuditView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("10 词展开时的几何高度与亲密性数据表")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                VStack(spacing: 12) {
                    ForEach(SpacingOption.allCases) { opt in
                        let totalGap = opt.rawValue * 9.0
                        let approxTotalHeight = (37.5 * 10.0) + totalGap + 44.0 // 词高 + 间隙 + 标题行
                        let saved = (24.0 - opt.rawValue) * 9.0

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("\(Int(opt.rawValue)) pt")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(opt == .space24 ? Color(hex: 0xB0392A) : (opt == .space16 ? AppTheme.Color.brandInk : AppTheme.Color.textPrimary))

                                    if opt == .space24 {
                                        Text("(当前现状)")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color(hex: 0xB0392A))
                                    } else if opt == .space16 {
                                        Text("(推荐黄金档)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(AppTheme.Color.brandStrong)
                                    }
                                }

                                Text("总间距占据: \(Int(totalGap))pt · 卡片总高约 \(Int(approxTotalHeight))pt")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(AppTheme.Color.textMuted)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(saved == 0 ? "原始长度" : "节省 -\(Int(saved))pt")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(saved == 0 ? AppTheme.Color.textMuted : AppTheme.Color.brandStrong)

                                Text(saved == 0 ? "100%" : "-\(Int(saved / 216.0 * 100))% 留白")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(AppTheme.Color.textMuted)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                .strokeBorder(opt == .space16 ? AppTheme.Color.brandStrong.opacity(0.3) : Color.black.opacity(0.05), lineWidth: 0.8)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - 预览提供者

#Preview("Tab2 Word Row Spacing Lab") {
    Tab2WordRowSpacingExplorationPreview()
}
#endif
