#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab1 生产全真正版画布 (Tab1 Production Baseline)
// ⚠️ 规则：【正版以线上生产代码为准——本画布不做任何探索性篡改；生产变了，画布随之同步】
// 🎯 组件级别 1:1 直接调用生产代码，内容区顶部留白为视觉近似值（非同一套算法，见下方说明）：
//   1. 视图外壳与框架：
//      - 顶栏：TopBarProgressiveMask 渐进遮罩 + SettingsMenuButton + TopTabSelector (选中 Today) + UsageLimitButton
//        —— 与 RootTabContainer.floatingTopBar 逐行同构（同一套 Token/偏移量）
//      - 背景基底：AppTheme.Color.pageBg (#FCF8F3 暖纸底色)
//      - 底部输入：真实 InputBar 浮动胶囊 + VariableBlurBackdrop 真实暖纸微光渐变承托底
//      - ⚠️ 内容区顶部留白用的是写死的 64pt（见 body 内 .padding(.top,...)），生产 TodayView
//        实际用 GeometryReader 动态推导的 topInset（随安全区/顶栏实际高度变化）——这一处只是
//        视觉近似，不是同一套机制；线上改了 topInset 算法，这个画布不会自动跟着变。
//   2. 真实时间线组件调用：
//      - 用户气泡：生产原版 TimelineRow(.userBubble) -> 方案2温润书卷（15pt userBubbleText、neutral700 书卷暖石墨、半透暖纸灰 68%、0.5pt 细微边缘、14x8pt 呼吸内边距）
//      - AI 卡片：生产原版 TimelineRow(.aiCard) -> AICardView -> AICardBody（Charter 衬线大标题、双层微阴影、精细边框）
//      - 间距节奏：TodayView.timelineSpacing 生产算法对齐

struct Tab1ProductionPreviewView: View {
    @State private var previewScenario: PreviewScenario = .correction
    @State private var showTopBarShell: Bool = true
    @State private var inputText: String = ""
    @State private var pendingImage: UIImage? = nil
    @State private var selectedTab: AppTab = .today

    enum PreviewScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fullTimeline = "完整时间线流 (3组真实交互)"
        case workMeeting  = "工作日程「推迟到下午三点」"
        case shortDaily   = "高频短句「下班了」"
        case correction   = "错词纠错「I am very sleep」"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端控制面板 (仅供切换场景与顶栏外壳，不侵入真实视口)
            controlPanel

            Divider().opacity(0.15)

            // 真实 Tab1 主视口
            ZStack(alignment: .bottom) {
                // 时间线内容滚动区
                ScrollView {
                    VStack(spacing: 0) {
                        let entries = currentEntries
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            TimelineRow(entry: entry)
                                .id(entry.id)
                                .padding(.bottom, TodayView.timelineSpacing(after: index, in: entries))
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, showTopBarShell ? 64 : AppTheme.Space.paddingPage)
                    .padding(.bottom, 120) // 避让底部 InputBar
                }

                // 底部浮动 InputBar (100% 对齐 TodayView)
                InputBar(
                    text: $inputText,
                    image: $pendingImage,
                    isLoading: false,
                    onSend: {}
                )
                .background {
                    VariableBlurBackdrop(extraExtend: 16)
                        .ignoresSafeArea(.container, edges: .bottom)
                }

                // 全真浮动顶栏 (100% 对齐 RootTabContainer)
                if showTopBarShell {
                    VStack {
                        floatingTopBar
                        Spacer()
                    }
                    .ignoresSafeArea(.container, edges: .top)
                }
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
        }
    }

    // MARK: - 顶端控制面板

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 7, height: 7)
                    Text("Tab1 生产正版基线 (1:1 Production Baseline)")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Toggle("外壳顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Picker("场景", selection: $previewScenario) {
                ForEach(PreviewScenario.allCases) { sc in
                    Text(sc.rawValue).tag(sc)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 浮动顶栏 (100% 对齐 RootTabContainer)

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton { }
                    .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)

                Spacer()

                UsageLimitButton { }
                    .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
    }

    // MARK: - 生产环境全真数据

    private var currentEntries: [TimelineEntry] {
        switch previewScenario {
        case .fullTimeline:
            return [
                TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
                meetingUserBubble,
                meetingAICard,
                shortUserBubble,
                shortAICard,
                correctionUserBubble,
                correctionAICard
            ]
        case .workMeeting:
            return [
                TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
                meetingUserBubble,
                meetingAICard
            ]
        case .shortDaily:
            return [
                TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
                shortUserBubble,
                shortAICard
            ]
        case .correction:
            return [
                TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
                correctionUserBubble,
                correctionAICard
            ]
        }
    }

    // 条目 1：工作日程（中文输入：场景 C express）
    private var meetingUserBubble: TimelineEntry {
        TimelineEntry.userBubble(text: "今天的会议推迟到下午三点", image: nil)
    }

    private var meetingAICard: TimelineEntry {
        TimelineEntry.aiCard(AICard.card(CardContent(
            granularity: "sentence",
            direction: "express",
            revisionType: nil,
            learnableUnits: [],
            userOriginal: "今天的会议推迟到下午三点",
            userOriginalLang: "native",
            targetExpression: "Today's meeting got pushed back to 3 PM.",
            nativeMeaning: "今天的会议延到了下午三点。"
        )))
    }

    // 条目 2：高频短句（中文输入：场景 C express）
    private var shortUserBubble: TimelineEntry {
        TimelineEntry.userBubble(text: "下班了", image: nil)
    }

    private var shortAICard: TimelineEntry {
        TimelineEntry.aiCard(AICard.card(CardContent(
            granularity: "sentence",
            direction: "express",
            revisionType: nil,
            learnableUnits: [],
            userOriginal: "下班了",
            userOriginalLang: "native",
            targetExpression: "I'm off work now.",
            nativeMeaning: "我现在下班了。"
        )))
    }

    // 条目 3：错词纠错
    private var correctionUserBubble: TimelineEntry {
        TimelineEntry.userBubble(text: "I am very sleep today", image: nil)
    }

    private var correctionAICard: TimelineEntry {
        TimelineEntry.aiCard(AICard.card(CardContent(
            granularity: "sentence",
            direction: "comprehend",
            revisionType: "error",
            learnableUnits: [],
            userOriginal: "I am very sleep today",
            userOriginalLang: "target",
            targetExpression: "I'm very sleepy today.",
            nativeMeaning: "我今天很困。",
            phonetic: nil,
            pos: [],
            examples: [
                BilingualExample(en: "The warm room made me feel sleepy.", zh: "温暖的房间让我感到昏昏欲睡。")
            ],
            grammarNote: "sleep 是动词或名词，表示'困倦的状态'需要使用形容词 sleepy。"
        )))
    }
}

// MARK: - Xcode Canvas 预览装配

#Preview("Tab1 · Production Baseline (全真正版)", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1ProductionPreviewView()
}
#endif
