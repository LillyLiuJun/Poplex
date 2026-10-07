#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab1 AI 学习卡片生产全景基线画布 (Tab1 AI Cards Production Baseline)
// 🎯 目标：100% 真实调用生产代码 AICardBody，无任何 mock/hack，完整覆盖 Word、Sentence、Passage
//    所有业务输入形态与数据分支，呈现真实的生产排版基线。

struct Tab1AICardBaselinePreviewView: View {
    @State private var selectedFilter: CardCategoryFilter = .all
    @State private var showSpecs: Bool = true
    @State private var expandedScenarioId: String? = nil

    enum CardCategoryFilter: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case all = "全部卡片"
        case word = "Word 词汇卡"
        case sentence = "Sentence 句子卡"
        case passage = "Passage 段落卡"
        case proposals = "Examples 方案对比"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 控制面板
            controlBar

            Divider().opacity(0.15)

            // 卡片展示滚动流
            ScrollView {
                if selectedFilter == .proposals {
                    LazyVStack(spacing: AppTheme.Space.paddingPage) {
                        examplesProposalsSection
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.vertical, AppTheme.Space.paddingPage)
                } else {
                    LazyVStack(spacing: AppTheme.Space.paddingPage) {
                        ForEach(filteredScenarios) { scenario in
                            scenarioCardView(scenario)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.vertical, AppTheme.Space.paddingPage)
                }
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
        }
    }

    // MARK: - 顶栏控制条
    private var controlBar: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 8, height: 8)
                    Text("Tab1 AI 卡片全景基线")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSpecs.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showSpecs ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 12))
                        Text(showSpecs ? "隐藏规格" : "显示规格")
                            .font(AppTheme.Font.pos)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.cardBorder.opacity(0.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Color.textSecondary)
            }

            // 分类筛选切换
            Picker("卡片类型", selection: $selectedFilter) {
                ForEach(CardCategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 单个场景卡片组合（AICardBody + 规格胶囊）
    private func scenarioCardView(_ scenario: CardScenario) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            // 场景标题栏
            HStack(alignment: .firstTextBaseline) {
                Text(scenario.title)
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(scenario.badge)
                    .font(AppTheme.Font.pos)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(scenario.badgeColor.opacity(0.12))
                    .foregroundStyle(scenario.badgeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                if scenario.hasExamplesFocus {
                    HStack(spacing: 3) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 10))
                        Text("关注 Examples 字重")
                            .font(AppTheme.Font.pos)
                    }
                    .foregroundStyle(AppTheme.Color.brandStrong)
                }
            }

            // 1:1 生产正版 AICardBody
            AICardBody(content: scenario.content)

            // 规格参数说明区（可展开/隐藏）
            if showSpecs {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        specItem(label: "输入", value: scenario.inputDesc)
                        specItem(label: "粒度", value: "\(scenario.content.granularity) · \(scenario.content.direction)")
                        if let rev = scenario.content.revisionType {
                            specItem(label: "Revision", value: rev)
                        }
                    }

                    if let note = scenario.designNote {
                        Text(note)
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Color.cardBg.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .stroke(AppTheme.Color.cardBorder.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            }
        }
    }

    private func specItem(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label + ":")
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
            Text(value)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
    }

    private var filteredScenarios: [CardScenario] {
        switch selectedFilter {
        case .all:
            return CardScenario.allScenarios
        case .word:
            return CardScenario.allScenarios.filter { $0.category == .word }
        case .sentence:
            return CardScenario.allScenarios.filter { $0.category == .sentence }
        case .passage:
            return CardScenario.allScenarios.filter { $0.category == .passage }
        case .proposals:
            return []
        }
    }

    @ViewBuilder
    private var examplesProposalsSection: some View {
        WordCardProposalView(
            proposalTitle: "现状基线 · Baseline",
            proposalBadge: "Hiragino 15pt W3",
            isRecommended: false,
            enFont: AppTheme.Font.chineseBody,
            enColor: AppTheme.Color.textPrimary,
            rationale: "【现状问题】挪用中文冬青黑体渲染英文字符，西文墨迹发黑且缺乏西文字体韵味，视觉比重过大，抢夺了上方单词大标题的视觉焦点。"
        )

        WordCardProposalView(
            proposalTitle: "方案 A · 内容衬线同族 (Charter)",
            proposalBadge: "Charter 15pt Regular",
            isRecommended: true,
            enFont: .custom("Charter", size: 15, relativeTo: .subheadline),
            enColor: AppTheme.Color.textPrimary,
            rationale: "【首推方案】系统内置 Charter 粗衬线。与主词条（20pt Bold）同族，形成 20pt Bold (大词条) → 15pt Regular (例句) 的经典出版物阶梯。400 字重纤细透气，与整张卡片的 Warm Editorial 基因完全契合。"
        )

        WordCardProposalView(
            proposalTitle: "方案 B · 极简轻盈无衬线",
            proposalBadge: "Gothic A1 15pt Light (300)",
            isRecommended: false,
            enFont: .custom("GothicA1-Light", size: 15, relativeTo: .subheadline),
            enColor: AppTheme.Color.textPrimary,
            rationale: "【轻量方案】工程打包的 GothicA1-Light.ttf（同设置页长文 settingsDocumentBody）。字重降至 300 细档，彻底消除黑块感，呈现现代工笔感，衬线标题与无衬线例句形成主次分工。"
        )

        WordCardProposalView(
            proposalTitle: "方案 C · 标准现代无衬线",
            proposalBadge: "Gothic A1 15pt Regular (400)",
            isRecommended: false,
            enFont: .custom("GothicA1-Regular", size: 15, relativeTo: .subheadline),
            enColor: AppTheme.Color.textPrimary,
            rationale: "【标准无衬线】工程打包的 GothicA1-Regular.ttf（同气泡文本 userBubbleText）。正统 400 无衬线骨架，比冬青黑体更舒展规整，属于稳健保守的现代界面风。"
        )

        WordCardProposalView(
            proposalTitle: "方案 D · 衬线字色降档退后",
            proposalBadge: "Charter 15pt + textSecondary",
            isRecommended: false,
            enFont: .custom("Charter", size: 15, relativeTo: .subheadline),
            enColor: AppTheme.Color.textSecondary,
            rationale: "【双重退后】在方案 A 基础上，不仅字型回归 Charter 衬线，还将颜色从 textPrimary（近黑）降至 textSecondary（次级灰）。让辅助例句在“字重 + 灰度”双维度退到主词条身后。"
        )
    }
}

// MARK: - Word 卡片字型方案对比组件

private struct WordCardProposalView: View {
    let proposalTitle: String
    let proposalBadge: String
    let isRecommended: Bool
    let enFont: Font
    let enColor: Color
    let rationale: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            HStack {
                Text(proposalTitle)
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(proposalBadge)
                    .font(AppTheme.Font.pos)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isRecommended ? AppTheme.Color.brandStrong.opacity(0.12) : AppTheme.Color.cardBorder.opacity(0.5))
                    .foregroundStyle(isRecommended ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                if isRecommended {
                    Text("推荐方案")
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }
            }

            // Word 卡片仿真
            VStack(alignment: .leading, spacing: 0) {
                CardTypeChip(label: "Word")
                    .padding(.bottom, AppTheme.Space.paddingM)

                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("procrastinate")
                            .font(AppTheme.Font.wordTitle)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                            Text("/prəˈkræstɪneɪt/")
                                .font(AppTheme.Font.phonetic)
                                .foregroundStyle(AppTheme.Color.textMuted)
                            Text("v.")
                                .font(AppTheme.Font.pos)
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.top, AppTheme.Space.paddingXS)

                        Text("拖延；耽搁")
                            .font(AppTheme.Font.chineseBody)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .padding(.top, AppTheme.Space.paddingS)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                        Text("EXAMPLES")
                            .font(AppTheme.Font.sectionLabel)
                            .tracking(0.6)
                            .foregroundStyle(AppTheme.Color.textMuted)

                        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                                Text("I always procrastinate when it comes to doing taxes.")
                                    .font(enFont)
                                    .foregroundStyle(enColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("一到报税我就总是拖拖拉拉。")
                                    .font(AppTheme.Font.chineseFaint)
                                    .foregroundStyle(AppTheme.Color.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                                Text("Stop procrastinating and get to work.")
                                    .font(enFont)
                                    .foregroundStyle(enColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("别再拖延了，快去干活。")
                                    .font(AppTheme.Font.chineseFaint)
                                    .foregroundStyle(AppTheme.Color.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Space.paddingCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: AppTheme.Radius.large, fillColor: AppTheme.Color.cardBg)

            Text(rationale)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Color.cardBg.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .stroke(AppTheme.Color.cardBorder.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
    }
}

// MARK: - 场景数据契约

struct CardScenario: Identifiable {
    let id: String
    let category: Category
    let title: String
    let badge: String
    let badgeColor: Color
    let inputDesc: String
    let content: CardContent
    let designNote: String?
    var hasExamplesFocus: Bool = false

    enum Category {
        case word
        case sentence
        case passage
    }

    static let allScenarios: [CardScenario] = [
        // ==========================================
        // 1. WORD 卡片全场景
        // ==========================================
        CardScenario(
            id: "word-comp-full",
            category: .word,
            title: "Word · Comprehend 标准全量词条",
            badge: "查词 · 完整态",
            badgeColor: AppTheme.Color.brandStrong,
            inputDesc: "英文词 \"procrastinate\"",
            content: CardContent(
                granularity: "word",
                direction: "comprehend",
                userOriginal: "procrastinate",
                userOriginalLang: "target",
                targetExpression: "procrastinate",
                nativeMeaning: "拖延；耽搁",
                phonetic: "/prəˈkræstɪneɪt/",
                pos: ["v."],
                examples: [
                    BilingualExample(
                        en: "I always procrastinate when it comes to doing taxes.",
                        zh: "一到报税我就总是拖拖拉拉。"
                    ),
                    BilingualExample(
                        en: "Stop procrastinating and get to work.",
                        zh: "别再拖延了，快去干活。"
                    )
                ]
            ),
            designNote: "📌 重点观察 Examples：英文例句当前采用 chineseBody (Hiragino 15pt) + textPrimary，视觉上较黑较重；例句间距为 12pt (paddingM)。",
            hasExamplesFocus: true
        ),

        CardScenario(
            id: "word-comp-with-note",
            category: .word,
            title: "Word · Comprehend 变形词还原",
            badge: "查词 · 形式点拨",
            badgeColor: .blue,
            inputDesc: "变形词 \"swam\" (swim的过去式)",
            content: CardContent(
                granularity: "word",
                direction: "comprehend",
                userOriginal: "swam",
                userOriginalLang: "target",
                targetExpression: "swim",
                nativeMeaning: "游泳；游动",
                phonetic: "/swɪm/",
                pos: ["v."],
                examples: [
                    BilingualExample(
                        en: "We swam across the lake yesterday morning.",
                        zh: "昨天早上我们游过了湖。"
                    )
                ],
                grammarNote: "swam 是 swim 的不规则过去式；过去分词为 swum。"
            ),
            designNote: "标题为规范词条 swim；Note 区块承载原词 swam 的词形变化点拨，通过 16pt 与上方例句区隔离。",
            hasExamplesFocus: true
        ),

        CardScenario(
            id: "word-comp-phrase",
            category: .word,
            title: "Word · Comprehend 动词短语 / 成语",
            badge: "短语 · 无音标",
            badgeColor: .indigo,
            inputDesc: "短语 \"bite the bullet\"",
            content: CardContent(
                granularity: "word",
                direction: "comprehend",
                userOriginal: "bite the bullet",
                userOriginalLang: "target",
                targetExpression: "bite the bullet",
                nativeMeaning: "咬紧牙关；硬着头皮面对",
                phonetic: nil,
                pos: ["phr."],
                examples: [
                    BilingualExample(
                        en: "I hate dentists, but I'll have to bite the bullet.",
                        zh: "我讨厌看牙医，但这次只能硬着头皮去了。"
                    ),
                    BilingualExample(
                        en: "Just bite the bullet and apologize to her.",
                        zh: "咬咬牙去跟她道歉吧。"
                    )
                ]
            ),
            designNote: "无音标时，词性 phr. 与大标题保持紧凑间距；下接两条例句。",
            hasExamplesFocus: true
        ),

        CardScenario(
            id: "word-express",
            category: .word,
            title: "Word · Express 中译英词条",
            badge: "表达 · 译词",
            badgeColor: .teal,
            inputDesc: "中文词 \"摸鱼\"",
            content: CardContent(
                granularity: "word",
                direction: "express",
                userOriginal: "摸鱼",
                userOriginalLang: "zh",
                targetExpression: "slack off",
                nativeMeaning: "摸鱼；偷懒；消极怠工",
                phonetic: "/slæk ɔːf/",
                pos: ["v."],
                examples: [
                    BilingualExample(
                        en: "Stop slacking off and get this report done.",
                        zh: "别摸鱼了，快把这份报告做完。"
                    )
                ]
            ),
            designNote: "用户输入母语词，AI 产出地道英文规范词条 + 释义 + 1条例句；express 侧从不产出 Note。",
            hasExamplesFocus: true
        ),

        CardScenario(
            id: "word-minimal",
            category: .word,
            title: "Word · 极简轻词态（无例句）",
            badge: "查词 · 仅释义",
            badgeColor: .secondary,
            inputDesc: "仅查单词释义 \"ephemeral\"",
            content: CardContent(
                granularity: "word",
                direction: "comprehend",
                userOriginal: "ephemeral",
                userOriginalLang: "target",
                targetExpression: "ephemeral",
                nativeMeaning: "短暂的；转瞬即逝的",
                phonetic: "/ɪˈfemərəl/",
                pos: ["adj."],
                examples: []
            ),
            designNote: "examples 为空时，EXAMPLES 区块自动隐去，卡片自然收口，无空白残留。"
        ),

        // ==========================================
        // 2. SENTENCE 卡片全场景
        // ==========================================
        CardScenario(
            id: "sent-comp-error",
            category: .sentence,
            title: "Sentence · Comprehend 语法错误纠错",
            badge: "场景 A-1 · Error 修正",
            badgeColor: .red,
            inputDesc: "错句 \"I am very sleep today\"",
            content: CardContent(
                granularity: "sentence",
                direction: "comprehend",
                revisionType: "error",
                userOriginal: "I am very sleep today",
                userOriginalLang: "target",
                targetExpression: "I'm very sleepy today.",
                nativeMeaning: "我今天非常困。",
                grammarNote: "sleepy 是形容词，表示困倦的感受；sleep 是动词或名词。"
            ),
            designNote: "三层平铺结构：原句+译文 (4pt) → 16pt (paddingCard) → POLISH 修正句 (4pt) → 16pt (paddingCard) → NOTE 语法说明 (4pt)。"
        ),

        CardScenario(
            id: "sent-comp-polish",
            category: .sentence,
            title: "Sentence · Comprehend 地道度润色",
            badge: "场景 A-2 · Polish 润色",
            badgeColor: .orange,
            inputDesc: "可理解但不地道 \"I want to ask a question to you\"",
            content: CardContent(
                granularity: "sentence",
                direction: "comprehend",
                revisionType: "polish",
                userOriginal: "I want to ask a question to you",
                userOriginalLang: "target",
                targetExpression: "I have a question for you.",
                nativeMeaning: "我有个问题想问你。",
                grammarNote: "ask someone a question 或 have a question for you 更自然，不习惯接 to you。"
            ),
            designNote: "有意义润色（revision_type: polish），结构与 Error 纠错完全一致，通过 POLISH 小标呈现地道版。"
        ),

        CardScenario(
            id: "sent-comp-no-revision",
            category: .sentence,
            title: "Sentence · Comprehend 完全正确无修正",
            badge: "场景 B · 正确原句",
            badgeColor: .green,
            inputDesc: "写得完全正确的英文 \"I'm heading out now.\"",
            content: CardContent(
                granularity: "sentence",
                direction: "comprehend",
                userOriginal: "I'm heading out now.",
                userOriginalLang: "target",
                targetExpression: "I'm heading out now.",
                nativeMeaning: "我现在出门了。"
            ),
            designNote: "无修正场景：原句深色常规字重居中主角，下方 4pt 紧跟中文译文；无 POLISH 小标，无多余说明。"
        ),

        CardScenario(
            id: "sent-comp-correct-with-note",
            category: .sentence,
            title: "Sentence · Comprehend 正确句 + 句式说明",
            badge: "场景 B · 带 Note",
            badgeColor: .mint,
            inputDesc: "高级句式 \"Rarely have I seen such dedication.\"",
            content: CardContent(
                granularity: "sentence",
                direction: "comprehend",
                userOriginal: "Rarely have I seen such dedication.",
                userOriginalLang: "target",
                targetExpression: "Rarely have I seen such dedication.",
                nativeMeaning: "我极少见到如此专注与投入。",
                grammarNote: "否定副词 Rarely 位于句首时，主谓进行部分倒装（have I seen）。"
            ),
            designNote: "句子完全正确无修正，但模型给出了句式结构点拨：双语主句 → 16pt 间距 → NOTE 语法说明。"
        ),

        CardScenario(
            id: "sent-express-native",
            category: .sentence,
            title: "Sentence · Express 纯中文输入",
            badge: "场景 C-1 · 意图表达",
            badgeColor: .blue,
            inputDesc: "中文意图 \"我打算下周请假两天\"",
            content: CardContent(
                granularity: "sentence",
                direction: "express",
                userOriginal: "我打算下周请假两天",
                userOriginalLang: "zh",
                targetExpression: "I'm planning to take two days off next week."
            ),
            designNote: "母语输入在上方浅灰弱化 (15pt textMuted)，下方 4pt 紧跟深色英文表达主角 (17pt Charter textPrimary)。"
        ),

        CardScenario(
            id: "sent-express-mixed",
            category: .sentence,
            title: "Sentence · Express 中英夹杂补全",
            badge: "场景 C-2 · 夹杂补全",
            badgeColor: .purple,
            inputDesc: "中英夹杂 \"I have a 会议 at 3pm\"",
            content: CardContent(
                granularity: "sentence",
                direction: "express",
                userOriginal: "I have a 会议 at 3pm",
                userOriginalLang: "zh",
                targetExpression: "I have a meeting at 3 PM."
            ),
            designNote: "用户表达卡词（英文嵌中文），AI 识别为 express 方向，母语原句在上位，补全完整英文在下位。"
        ),

        CardScenario(
            id: "sent-express-photo",
            category: .sentence,
            title: "Sentence · Express 纯图片识别描述",
            badge: "场景 C-3 · 拍照识景",
            badgeColor: .brown,
            inputDesc: "用户拍照（无附带文字）",
            content: CardContent(
                granularity: "sentence",
                direction: "express",
                userOriginal: nil,
                userOriginalLang: nil,
                targetExpression: "Sunlight is filtering through the cafe window.",
                nativeMeaning: "阳光正透过咖啡馆的百叶窗洒进来。"
            ),
            designNote: "纯图片无文字输入，userOriginal 为空，expressNativeRow 回退使用 nativeMeaning 置顶，英文场景描述居下主角。"
        ),

        // ==========================================
        // 3. PASSAGE 卡片全场景
        // ==========================================
        CardScenario(
            id: "passage-long",
            category: .passage,
            title: "Passage · 3句长段落（折叠/展开）",
            badge: "段落 · 可折叠",
            badgeColor: .cyan,
            inputDesc: "英文短篇随笔 (>300字符或多句)",
            content: CardContent(
                granularity: "passage",
                direction: "comprehend",
                userOriginal: "Morning light filtered through the blinds...",
                userOriginalLang: "target",
                targetExpression: "Morning light filtered through the blinds.\nA cool breeze stirred the curtain.\nThe city outside was slowly waking up.",
                nativeMeaning: "晨光透过百叶窗洒了进来。\n一阵凉风吹拂着窗帘。\n外面的城市正缓缓苏醒。",
                grammarNote: "Notice the sensory phrasing of 'filtered through' and 'stirred'.",
                passageLines: [
                    PassageLine(en: "Morning light filtered through the blinds.", zh: "晨光透过百叶窗洒了进来。"),
                    PassageLine(en: "A cool breeze stirred the curtain.", zh: "一阵凉风吹拂着窗帘。"),
                    PassageLine(en: "The city outside was slowly waking up.", zh: "外面的城市正缓缓苏醒。")
                ]
            ),
            designNote: "超过收起上限 (2对) 时展示「展开/收起」轻量动作条；收起态预览前 2 句，展开态平滑伸展；底部带 NOTE。"
        ),

        CardScenario(
            id: "passage-short",
            category: .passage,
            title: "Passage · 2句短段落（直接平铺）",
            badge: "段落 · 免折叠",
            badgeColor: .gray,
            inputDesc: "2句短文本",
            content: CardContent(
                granularity: "passage",
                direction: "comprehend",
                userOriginal: "Coffee first.\nThen the world.",
                userOriginalLang: "target",
                targetExpression: "Coffee first.\nThen the world.",
                nativeMeaning: "先喝咖啡。\n再去拯救世界。",
                passageLines: [
                    PassageLine(en: "Coffee first.", zh: "先喝咖啡。"),
                    PassageLine(en: "Then the world.", zh: "再去面对世界。")
                ]
            ),
            designNote: "未超过 2 句上限，直接平铺双语句对，句子对之间留 16pt，不显示展开/收起按钮。"
        )
    ]
}

// MARK: - Canvas Preview

#Preview("Tab1 AI 卡片全景基线") {
    Tab1AICardBaselinePreviewView()
}
#endif
