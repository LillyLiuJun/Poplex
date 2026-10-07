#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 待解锁态（Topics in progress）纯净灰色标签沙盒
// 🎯 专项探索：
//   1. 剩 4 个时的排布形态：支持切换「2 + 2 规则对称」vs「3 + 1 非对称节奏（上3下1）」；
//   2. 注脚字号微调：支持切换「标准字号 (actionNote 13pt)」vs「微缩轻注脚 (metaNote 11pt，更小更静谧)」；
//   3. 文案候选池：内置 4 组注脚 1 文案与 4 组注脚 2 文案，实时切换预览；
//   4. 纯净灰色中性底色：无任何橙色底框，自然字宽自适应，不故意拉长底纹。

struct Tab2LockedProgressExplorationPreviewView: View {
    @State private var remainingVolume: RemainingTopicsOption = .fourTopics
    @State private var selectedDataVolume: DataVolumeOption = .singleWord
    @State private var tagShapeStyle: TagShapeOption = .capsule
    @State private var fourTopicsMode: FourTopicsMode = .threePlusOne
    @State private var footnoteSizeMode: FootnoteSizeMode = .small
    @State private var fn1Option: Footnote1Option = .withWords
    @State private var fn2Text: String = "Moments you capture will automatically sort into these life themes."
    @State private var showTopBarShell: Bool = true
    @State private var isAccordionExpanded: Bool = false

    enum TagShapeOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case capsule = "纯净椭圆胶囊 (定案 ⭐)"
        case roundedRect = "轻圆角小方标(10pt)"
    }

    enum FourTopicsMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case threePlusOne = "3 + 1 非对称节奏 (上3下1 · 定案 ⭐)"
        case twoPlusTwo = "2 + 2 规则对称"
    }

    enum FootnoteSizeMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case small = "微缩轻注脚 (11pt · 定案 ⭐)"
        case standard = "标准字号 (13pt)"

        var font: Font {
            switch self {
            case .small: return AppTheme.Font.metaNote
            case .standard: return AppTheme.Font.actionNote
            }
        }
    }

    enum Footnote1Option: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case withWords = "Any topic with 20 words unlocks speaking."
        case onceReaches = "Once any topic reaches 20 words, speaking unlocks."
        case thatReaches = "Any topic that reaches 20 words unlocks speaking."
        case resultFirst = "Speaking unlocks once any topic reaches 20 words."
        case whenReaches = "When any topic reaches 20 words, speaking unlocks."

        var shortName: String {
            switch self {
            case .withWords: return "1C: Any topic with 20 words... (定案 ⭐)"
            case .onceReaches: return "1A: Once any topic reaches..."
            case .thatReaches: return "1B: Any topic that reaches..."
            case .resultFirst: return "1D: Speaking unlocks once..."
            case .whenReaches: return "1E: When any topic reaches..."
            }
        }
    }

    enum RemainingTopicsOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fourTopics  = "剩 4 个 (3+1 定案 ⭐)"
        case tenTopics   = "剩 10 个 (2排横滑)"
        case threeTopics = "剩 3 个 (1排靠左)"
        case twoTopics   = "剩 2 个 (1排靠左)"
        case oneTopic    = "剩 1 个 (1排单标)"
        case zeroTopics  = "剩 0 个 (隐藏)"

        var count: Int {
            switch self {
            case .fourTopics: return 4
            case .tenTopics: return 10
            case .threeTopics: return 3
            case .twoTopics: return 2
            case .oneTopic: return 1
            case .zeroTopics: return 0
            }
        }
    }

    enum DataVolumeOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case singleWord = "1 个词 (1/20)"
        case fewWords   = "5 个词 (5/20)"
        case twoTopics  = "2 个进行中主题"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端交互控制台（用于快速验收各种数量边界）
            controlBar

            Divider().opacity(0.15)

            // 全真手机视口
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mainContentView
                    }
                    .padding(.top, showTopBarShell ? 64 : AppTheme.Space.paddingPage)
                    .padding(.bottom, 110)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .background(AppTheme.Color.pageBg.ignoresSafeArea())

                // 全真浮动顶栏（Today | Library + 汉堡按钮）
                if showTopBarShell {
                    floatingTopBar
                }

                // 全真沉底栏 [📷 Capture something]
                bottomBarContainer
            }
        }
        .background(AppTheme.Color.pageBg)
    }

    // MARK: - 顶端控制台

    private var controlBar: some View {
        VStack(spacing: 7) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppTheme.Color.brandStrong).frame(width: 6, height: 6)
                    Text("DesignLab")
                        .font(AppTheme.Font.date)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())

                Text("最新定案 · 1C文案 / 微缩注脚 / 3+1排布")
                    .font(AppTheme.Font.growthStatus)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Toggle(isOn: $showTopBarShell) {
                    Text("顶栏")
                        .font(AppTheme.Font.date)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Color.textPrimary))
                .labelsHidden()
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, 6)

            // 控制行 1: 标签形态 (胶囊 vs 圆角方标) + 4标签排布模式
            HStack(spacing: 8) {
                Text("标签形态:")
                    .font(AppTheme.Font.date)
                    .foregroundStyle(AppTheme.Color.textMuted)

                ForEach(TagShapeOption.allCases) { shape in
                    Button {
                        withAnimation(AppTheme.Motion.tabSelection) { tagShapeStyle = shape }
                    } label: {
                        Text(shape.rawValue)
                            .font(tagShapeStyle == shape ? AppTheme.Font.growthStatus : AppTheme.Font.date)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(tagShapeStyle == shape ? AppTheme.Color.textPrimary : Color.black.opacity(0.04))
                            .foregroundStyle(tagShapeStyle == shape ? Color.white : AppTheme.Color.textSecondary)
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 控制行 2: 剩余数量切换
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("剩余未开启:")
                        .font(AppTheme.Font.date)
                        .foregroundStyle(AppTheme.Color.textMuted)

                    ForEach(RemainingTopicsOption.allCases) { vol in
                        remainingVolumePill(vol)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, 6)
            }
        }
    }

    private func remainingVolumePill(_ vol: RemainingTopicsOption) -> some View {
        let isSelected = remainingVolume == vol
        return Button {
            withAnimation(AppTheme.Motion.tabSelection) {
                remainingVolume = vol
            }
        } label: {
            Text(vol.rawValue)
                .font(isSelected ? AppTheme.Font.growthStatus : AppTheme.Font.date)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? AppTheme.Color.textPrimary : Color.black.opacity(0.04))
                .foregroundStyle(isSelected ? Color.white : AppTheme.Color.textSecondary)
                .clipShape(Capsule())
        }
    }

    // MARK: - 主视口内容（定案排版）

    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 区块 1：Topics in progress ──
            Text("Topics in progress")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingSection)
                .padding(.bottom, AppTheme.Space.paddingM)

            // 进行中卡片
            activeCardsContainer

            // 文案 1: 卡片正下方（支持字号微调与文案切换）
            Text(fn1Option.rawValue)
                .font(footnoteSizeMode.font)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Space.paddingSection)

            // ── 区块 2：More topics to explore ──
            if remainingVolume.count > 0 {
                Text("More topics to explore")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingM)

                // 核心布局：支持 3+1 vs 2+2 与 <=3 退化单排
                moreTopicsContainer

                // 文案 2: 标签正下方（微缩字号）
                Text(fn2Text)
                    .font(footnoteSizeMode.font)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - 进行中卡片容器

    private var activeCardsContainer: some View {
        let cats = activeCategories
        return VStack(spacing: 0) {
            ForEach(cats) { cat in
                CategoryProgressRow(
                    category: cat,
                    isExpanded: isAccordionExpanded,
                    onToggle: {
                        withAnimation(AppTheme.Motion.accordionToggle) {
                            isAccordionExpanded.toggle()
                        }
                    },
                    loadWords: {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        return [
                            Tab2WordEntry(
                                lemma: "laptop",
                                displayForm: "laptop",
                                entryKind: "word",
                                pos: "n.",
                                granularity: "sentence",
                                sourceType: "material",
                                sampleSentence: "I work on my laptop all day.",
                                nativeMeaning: "笔记本电脑",
                                imageUrl: nil
                            )
                        ]
                    },
                    wordsRevision: 0
                )
            }
        }
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 未开启分类核心排版（支持 3+1 与 2+2）

    @ViewBuilder
    private var moreTopicsContainer: some View {
        let topics = availableTopics.prefix(remainingVolume.count)
        let count = topics.count

        if count == 4 && fourTopicsMode == .threePlusOne {
            // ★ 用户提议：3 + 1 非对称排布（上 3 下 1）
            threePlusOneView(Array(topics))
        } else if count <= 3 {
            // <= 3 个：单行靠左摆放
            singleRowNaturalView(Array(topics))
        } else {
            // >= 4 个且 2+2 或正常横滑：2 行并排横滑
            twoRowHorizontalScrollView(Array(topics))
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 形态 1：4 个标签时的 3 + 1 非对称节奏（上 3 下 1 · 定案）
    // ─────────────────────────────────────────────────────────────
    private func threePlusOneView(_ topics: [(icon: String, name: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                // 第一排：前 3 个标签
                HStack(spacing: 8) {
                    ForEach(topics.prefix(3), id: \.name) { item in
                        neutralTagView(icon: item.icon, name: item.name)
                    }
                }

                // 第二排：第 4 个标签
                HStack(spacing: 8) {
                    ForEach(topics.suffix(1), id: \.name) { item in
                        neutralTagView(icon: item.icon, name: item.name)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 2)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 形态 2：2 排横滑流（2+2 或多分类标准并排）
    // ─────────────────────────────────────────────────────────────
    private func twoRowHorizontalScrollView(_ topics: [(icon: String, name: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(
                rows: [
                    GridItem(.fixed(38), spacing: 8),
                    GridItem(.fixed(38), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(topics, id: \.name) { item in
                    neutralTagView(icon: item.icon, name: item.name)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 2)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 形态 3：<= 3 个时的单行靠左自然排列（不拉长、不压缩）
    // ─────────────────────────────────────────────────────────────
    private func singleRowNaturalView(_ topics: [(icon: String, name: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topics, id: \.name) { item in
                    neutralTagView(icon: item.icon, name: item.name)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 2)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 纯净灰色标签组件（自然字长，无橙色方框，纸色/浅灰质感）
    // ─────────────────────────────────────────────────────────────
    @ViewBuilder
    private func neutralTagView(icon: String, name: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)

            Text(name)
                .font(AppTheme.Font.actionNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: true, vertical: false) // 依据文字自然宽度，绝不故意拉长底纹
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background {
            if tagShapeStyle == .capsule {
                Capsule()
                    .fill(AppTheme.Color.cardBg)
                    .strokeBorder(AppTheme.Color.cardBorder.opacity(0.6), lineWidth: 0.8)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Color.cardBg)
                    .strokeBorder(AppTheme.Color.cardBorder.opacity(0.6), lineWidth: 0.8)
            }
        }
        .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1)
    }

    // MARK: - 模拟数据源

    private var availableTopics: [(icon: String, name: String)] = [
        ("sun.horizon", "Daily Routine"),
        ("briefcase", "Work & Study"),
        ("fork.knife", "Food & Drink"),
        ("bag", "Shopping"),
        ("tram", "Travel & Commute"),
        ("figure.run", "Health & Fitness"),
        ("gamecontroller", "Hobbies & Leisure"),
        ("cloud.sun", "Weather & Nature"),
        ("heart", "Social & Feelings"),
        ("house", "Home & Family")
    ]

    private var activeCategories: [Tab2CategoryData] {
        switch selectedDataVolume {
        case .singleWord:
            return [Tab2CategoryData(sceneCategory: "digital_tech", wordCount: 1, unlocked: false)]
        case .fewWords:
            return [Tab2CategoryData(sceneCategory: "digital_tech", wordCount: 5, unlocked: false)]
        case .twoTopics:
            return [
                Tab2CategoryData(sceneCategory: "digital_tech", wordCount: 8, unlocked: false),
                Tab2CategoryData(sceneCategory: "daily_routines", wordCount: 3, unlocked: false)
            ]
        }
    }

    // MARK: - 顶栏与底栏外壳

    private var floatingTopBar: some View {
        HStack {
            Circle()
                .fill(AppTheme.Color.cardBg)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

            Spacer()

            HStack(spacing: 0) {
                Text("Today")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)

                Text("Library")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
            }
            .padding(3)
            .background(Color.black.opacity(0.04))
            .clipShape(Capsule())

            Spacer()

            Circle()
                .fill(AppTheme.Color.cardBg)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, 10)
    }

    private var bottomBarContainer: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Capture something")
                        .font(AppTheme.Font.ctaLabel)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.Color.textPrimary)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.bottomBarActionBottom)
            }
            .padding(.top, AppTheme.Space.paddingS)
            .background(VariableBlurBackdrop(extraExtend: 16))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview("Tab2 Locked Gray Tags Sandbox") {
    Tab2LockedProgressExplorationPreviewView()
}
#endif
