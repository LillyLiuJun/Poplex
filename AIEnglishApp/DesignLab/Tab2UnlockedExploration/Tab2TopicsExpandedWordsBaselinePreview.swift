#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 Topics in progress 展开词条线上排版现状基线检视沙盒
//         (Tab2 Topics Expanded Words Production Baseline & Typography Inspector)
//
// 🎯 核心目标：
//   1. 100% 像素级还原线上生产环境当前真实视觉效果：
//      - 英文字体：Charter 15.0pt · Bold 700 (AppTheme.Font.tab2WordEntryTitle)
//      - 中文字体：Hiragino Sans GB 12.0pt · W3 Regular (AppTheme.Font.tab2WordEntryMeaning)
//      - 图标槽位：32×32 暖灰底磁贴 (AppTheme.Color.iconTileBg) 或用户图片缩略图 (圆角 6pt)
//      - 词条间距：英文与释义间距 2.0pt (wordEntrySpacing) · 行间距 8.0pt (paddingS)
//      - 手风琴缩进：子项向右缩进 16.0pt (paddingCard)
//   2. 丰富多元的真实生活表达样例数据（多场景、多长短、多词性）：
//      - 场景 1：职场协作与项目推进 (Work & Collaboration)
//      - 场景 2：咖啡早晨与治愈日常 (Coffee & Morning Routine)
//      - 场景 3：运动健身与活力时刻 (Fitness & Workout)
//      - 场景 4：情感共鸣与深度社交 (Social & Emotional Connections)
//   3. 多视角检视：
//      - 视角 1: 真实卡片手风琴流 (In-Card Accordion Flow)
//      - 视角 2: 词条排版解剖台 (Typography & Spec Microscope)
//      - 视角 3: 词性与长度极限测试 (Length & Category Stress Test)

struct Tab2TopicsExpandedWordsBaselinePreview: View {

    // MARK: - 场景数据集选择枚举

    enum DatasetCategory: String, CaseIterable, Identifiable {
        case work       = "职场与推进 (Work)"
        case coffee     = "咖啡与日常 (Coffee)"
        case fitness    = "运动与活力 (Fitness)"
        case social     = "社交与情感 (Social)"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .work:    return "briefcase"
            case .coffee:  return "cup.and.saucer"
            case .fitness: return "figure.run"
            case .social:  return "person.2"
            }
        }

        var englishTitle: String {
            switch self {
            case .work:    return "Work & Projects"
            case .coffee:  return "Coffee & Routine"
            case .fitness: return "Fitness & Health"
            case .social:  return "Social & Life"
            }
        }
    }

    // MARK: - 检视视角枚举

    enum InspectionPerspective: String, CaseIterable, Identifiable {
        case inCardFlow     = "真实手风琴卡片"
        case typographySpec = "字重与排版解剖"
        case lengthStress   = "长短词极限排布"

        var id: String { rawValue }
    }

    // MARK: - 状态管理

    @State private var selectedCategory: DatasetCategory = .work
    @State private var selectedPerspective: InspectionPerspective = .inCardFlow
    @State private var isExpanded: Bool = true
    @State private var showSpecBadges: Bool = true

    // MARK: - 主视图

    var body: some View {
        VStack(spacing: 0) {
            topControlBar

            Divider().opacity(0.15)

            switch selectedPerspective {
            case .inCardFlow:
                inCardFlowView
            case .typographySpec:
                typographySpecView
            case .lengthStress:
                lengthStressView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶部控制栏

    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 标题与线上基线标签
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Topics 展开英文字体 · 线上排版现状")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Text("生产基准")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                    }

                    Text("Charter 15pt Bold 700 (英) + 冬青黑 12pt W3 (中)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Spacer()

                // 标注开关按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSpecBadges.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showSpecBadges ? "eye.fill" : "eye.slash")
                        Text(showSpecBadges ? "标注开" : "纯净看")
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

            // 场景切换分段器
            Picker("测试场景", selection: $selectedCategory) {
                ForEach(DatasetCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            // 视角切换分段器
            Picker("检视视角", selection: $selectedPerspective) {
                ForEach(InspectionPerspective.allCases) { persp in
                    Text(persp.rawValue).tag(persp)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 10)
        .background(AppTheme.Color.warmGlassSurface)
    }

    // MARK: - 视角 1: 真实手风琴卡片流 (In-Card Accordion Flow)

    private var inCardFlowView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 核心参数提示横幅
                if showSpecBadges {
                    productionSpecBanner
                }

                // 真实 Topics in progress 区域模拟
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    // 大标题：Topics in progress
                    HStack {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        Text("点击右侧胶囊可开合手风琴")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }

                    // 真实卡片外框 (.surfaceCard 容器)
                    VStack(spacing: 0) {
                        // 手风琴行头部
                        accordionHeaderRow

                        // 展开词条列表
                        if isExpanded {
                            VStack(spacing: AppTheme.Space.paddingS) {
                                ForEach(currentEntries) { entry in
                                    WordEntryRowView(entry: entry, showSpecBadge: showSpecBadges)
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

    // MARK: - 手风琴行头 (Header Row)

    private var accordionHeaderRow: some View {
        Button {
            withAnimation(AppTheme.Motion.accordionToggle) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppTheme.Space.paddingM) {
                // 类别图标 (14pt regular, 20x20 纯线条)
                Image(systemName: selectedCategory.iconName)
                    .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                // 分类名称 (生产 13pt Regular 方案 A)
                Text(selectedCategory.englishTitle)
                    .font(AppTheme.Font.tab2TopicLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                // 进度条
                progressBar

                Spacer()

                // Words 胶囊 (含展开箭头)
                wordsPill
            }
            .padding(.vertical, AppTheme.Space.listRowVertical)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .buttonStyle(.plain)
    }

    private var progressBar: some View {
        Capsule()
            .fill(AppTheme.Color.progressTrack.opacity(0.8))
            .frame(height: AppTheme.Size.progressBarHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Color.progressFill)
                    .frame(width: 80)
            }
            .frame(width: 80)
    }

    private var wordsPill: some View {
        HStack(spacing: AppTheme.Size.pillHSpacing) {
            Text("\(currentEntries.count) words")
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

    // MARK: - 视角 2: 词条排版解剖台 (Typography & Spec Microscope)

    private var typographySpecView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                productionSpecBanner

                Text("词条排版微观剖析（当前生产线上规格）")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 14) {
                    ForEach(Array(currentEntries.prefix(4))) { entry in
                        specMicroscopeCard(for: entry)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private func specMicroscopeCard(for entry: Tab2WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 实际渲染效果
            HStack(spacing: AppTheme.Space.paddingM) {
                entryLeftSlot(entry: entry)

                VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                    Text(entry.displayForm ?? entry.lemma)
                        .font(AppTheme.Font.tab2WordEntryTitle)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(AppTheme.Font.tab2WordEntryMeaning)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))

            // 标注分析
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("英文词头：")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text("Charter · 15.0pt · Bold 700")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(Color.purple)
                    Text("视觉感受：笔画极粗，墨量浓重，具有压迫感")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Text("中文释义：")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Text("冬青黑 · 12.0pt · W3 (Regular)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.blue)
                    Text("视觉感受：极细无衬线，与上方英文粗细反差大")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
    }

    // MARK: - 视角 3: 长短词极限测试 (Length & Category Stress Test)

    private var lengthStressView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("长短词、词性与连字符极限排布测试")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("观察当英文字词长短不一、包含短语动词或连字符时，Charter 15pt Bold 的黑度表现：")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 0) {
                    ForEach(Array(stressTestEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: AppTheme.Space.paddingM) {
                            entryLeftSlot(entry: entry)

                            VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                                Text(entry.displayForm ?? entry.lemma)
                                    .font(AppTheme.Font.tab2WordEntryTitle)
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                    .lineLimit(1)

                                if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                                    Text(meaning)
                                        .font(AppTheme.Font.tab2WordEntryMeaning)
                                        .foregroundStyle(AppTheme.Color.textMuted)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // 词性 / 类型轻标签
                            Text(entry.entryKind ?? "word")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.Color.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.04), in: Capsule())
                        }
                        .padding(.vertical, AppTheme.Space.paddingS)
                        .padding(.horizontal, AppTheme.Space.paddingCard)

                        if index < stressTestEntries.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - 生产排版参数横幅

    private var productionSpecBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.purple)
                Text("当前线上生产环境参数审计 (Code as Fact)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text("Theme.swift")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("• 英文单词:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text("Charter 15.0pt · Bold (700) · tab2WordEntryTitle")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.purple)
                }
                GridRow {
                    Text("• 中文释义:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text("Hiragino Sans GB 12.0pt · W3 (Regular) · tab2WordEntryMeaning")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.blue)
                }
                GridRow {
                    Text("• 行内间距:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Text("wordEntrySpacing: 2.0pt · 行距: 8.0pt · 缩进: 16.0pt")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.purple.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 词条左侧槽位 (图标 / 缩略图)

    @ViewBuilder
    private func entryLeftSlot(entry: Tab2WordEntry) -> some View {
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
    }

    // MARK: - 当前选中场景样例数据

    private var currentEntries: [Tab2WordEntry] {
        switch selectedCategory {
        case .work:
            return workSampleEntries
        case .coffee:
            return coffeeSampleEntries
        case .fitness:
            return fitnessSampleEntries
        case .social:
            return socialSampleEntries
        }
    }

    // ── 场景 1: 职场协作与项目推进 ──
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

    // ── 场景 2: 咖啡早晨与治愈日常 ──
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

    // ── 场景 3: 运动健身与活力时刻 ──
    private var fitnessSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "warm up", entryKind: "phrase", granularity: "sentence", nativeMeaning: "热身运动 / 准备活动"),
            Tab2WordEntry(lemma: "consistency", entryKind: "word", granularity: "word", nativeMeaning: "持之以恒 / 持续自律"),
            Tab2WordEntry(lemma: "push through", entryKind: "phrase", granularity: "sentence", nativeMeaning: "咬牙坚持 / 冲破极点"),
            Tab2WordEntry(lemma: "cool down", entryKind: "phrase", granularity: "sentence", nativeMeaning: "整理放松 / 拉伸"),
            Tab2WordEntry(lemma: "runner's high", entryKind: "idiom", granularity: "sentence", nativeMeaning: "跑步者的极度愉悦感")
        ]
    }

    // ── 场景 4: 情感共鸣与深度社交 ──
    private var socialSampleEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "rekindle", entryKind: "word", granularity: "word", nativeMeaning: "重新联络 / 重燃情谊"),
            Tab2WordEntry(lemma: "break the ice", entryKind: "idiom", granularity: "sentence", nativeMeaning: "打破僵局 / 消除拘谨"),
            Tab2WordEntry(lemma: "empathize", entryKind: "word", granularity: "word", nativeMeaning: "产生共鸣 / 感同身受"),
            Tab2WordEntry(lemma: "quality time", entryKind: "phrase", granularity: "sentence", nativeMeaning: "高质量陪伴时光"),
            Tab2WordEntry(lemma: "heart-to-heart", entryKind: "idiom", granularity: "sentence", nativeMeaning: "推心置腹的 / 贴心长谈")
        ]
    }

    // ── 极限长度与特殊结构测试集 ──
    private var stressTestEntries: [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "nap", entryKind: "word", granularity: "word", nativeMeaning: "小憩 / 打盹 (短词)"),
            Tab2WordEntry(lemma: "serendipity", entryKind: "word", granularity: "word", nativeMeaning: "不期而至的美好 (长单语)"),
            Tab2WordEntry(lemma: "on-the-fly", entryKind: "idiom", granularity: "word", nativeMeaning: "临时 / 随时即兴 (连字符词)"),
            Tab2WordEntry(lemma: "leave no stone unturned", entryKind: "idiom", granularity: "sentence", nativeMeaning: "想尽一切办法 (超长成语)"),
            Tab2WordEntry(lemma: "wrap up", entryKind: "phrase", granularity: "sentence", nativeMeaning: "圆满收尾 (双词短语)")
        ]
    }
}

// MARK: - 词条行视图 (带可选标注徽章)

private struct WordEntryRowView: View {
    let entry: Tab2WordEntry
    let showSpecBadge: Bool

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingM) {
            // 左侧槽位
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

            // 词 + 释义纵向排
            VStack(alignment: .leading, spacing: AppTheme.Size.wordEntrySpacing) {
                HStack(spacing: 6) {
                    Text(entry.displayForm ?? entry.lemma)
                        .font(AppTheme.Font.tab2WordEntryTitle)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .lineLimit(1)

                    if showSpecBadge {
                        Text("15pt Bold")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                    }
                }

                if let meaning = entry.nativeMeaning, !meaning.isEmpty {
                    HStack(spacing: 6) {
                        Text(meaning)
                            .font(AppTheme.Font.tab2WordEntryMeaning)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .lineLimit(1)

                        if showSpecBadge {
                            Text("12pt W3")
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SwiftUI Preview Provider

#Preview("Topics 展开词条线上排版基线检视") {
    Tab2TopicsExpandedWordsBaselinePreview()
}
#endif
