import SwiftUI

/// 显式 @MainActor：TodayViewModel 已标 @MainActor（审查发现 #5），@State 默认值在
/// view init 里求值，init 必须是主线程隔离才能调用它的隔离构造器。
@MainActor
struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = TodayViewModel(service: LiveAIService())

    /// InputBar 外层的实时渲染高度（含胶囊、缩略图/多行增长与底部 padding）。
    /// 首帧用单行基础态 52 + 8 = 60pt，实测回调随后接管；配合 32pt 内容净空，
    /// 基础态停靠线仍是此前验收过的 92pt。
    @State private var inputBarHeight = AppTheme.Size.inputBarMinHeight + AppTheme.Space.paddingS
    @State private var refreshHaptics = PullToRefreshHaptics()
    @State private var timelineViewportFrame: CGRect = .zero
    @State private var passageTabResetGeneration = 0
    /// 生成次数额度的共享展示状态：达标时 InputBar 锁输入 + 出 banner，数字从这读。
    /// 只有服务端裁决会把 isAllowed 置 false：429、refresh 的 allowed 字段，
    /// 以及成功响应的落账后裁决（方案 B——最后一次生成用完额度即锁定）。
    @State private var quotaStore = UsageQuotaStore.shared
    var activationToken: UUID? = nil
    var isActive = true
    var onImagePreview: ((UIImage, UnitPoint) -> Void)?
    /// 达标 banner 点击 → 打开额度 Sheet（由 RootTabContainer 呈现，顶栏仪表盘同款）。
    var onOpenUsageLimit: (() -> Void)?
    var topInset: CGFloat = 0

    init(activationToken: UUID? = nil,
         isActive: Bool = true,
         onImagePreview: ((UIImage, UnitPoint) -> Void)? = nil,
         onOpenUsageLimit: (() -> Void)? = nil,
         topInset: CGFloat = 0) {
        self.activationToken = activationToken
        self.isActive = isActive
        self.onImagePreview = onImagePreview
        self.onOpenUsageLimit = onOpenUsageLimit
        self.topInset = topInset
    }

    var body: some View {
        @Bindable var vm = viewModel
        ZStack(alignment: .bottom) {
            timeline
                .task { await viewModel.loadHistory() }

            // InputBar 独立悬浮在内容上方；背后垫纸色渐进式底托（向下贯穿底部安全区，向上 16pt 平滑消融进入内容区），
            // 内容向下滚动穿过时溶入暖纸底色而非虚化——当前是纯色渐变，不含模糊/失焦（那是方案 B
            // 真·可变模糊要做的事，见 VariableBlurBackdrop 类型注释）。
            InputBar(
                text: $vm.inputText,
                image: $vm.pendingImage,
                isLoading: viewModel.isLoading,
                // 达标态 = 服务端明确裁决过「不允许」（429 或 refresh）。
                // isAllowed == nil（未知）不锁——onboarding 豁免用户服务端永远放行，
                // 前端绝不能自己数数去锁。
                isLimitReached: quotaStore.isAllowed == false,
                showLimitBanner: quotaStore.isAllowed == false,
                usedCount: quotaStore.usedCount ?? 5,
                dailyLimit: quotaStore.dailyLimit ?? 5,
                onLimitTap: onOpenUsageLimit
            ) {
                Task { await viewModel.send() }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { measuredHeight in
                guard measuredHeight > 0,
                      abs(measuredHeight - inputBarHeight) > 0.5 else { return }
                inputBarHeight = measuredHeight
            }
            .background {
                VariableBlurBackdrop(extraExtend: 16)
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            // 轻提示（如无网点 Retry）：底部浮出，4s 自动消失
            AutoDismissingAppToast(
                message: $vm.offlineHint,
                systemImage: "wifi.slash"
            )
            .padding(.bottom, AppTheme.Space.paddingHero)
        }
            // 首页背景（暖纸底色），底部暖光由 InputBar 的 VariableBlurBackdrop 承担
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
            .sheet(isPresented: $viewModel.showAIConsent) {
                AIConsentView { viewModel.onConsentAgreed() }
                    // N1 设计决策：Tab1 属于日常主界面，用户可能开启 Dynamic Type 或 AX 大字号，
                    // 默认 410pt 高度下正文阅读区受限；传入 allowsLarge: true 允许向上拖动把手展开至 .large，
                    // 保障无障碍阅读体验；而 Onboarding 处于强引导流，按产品决策锁定单档 .height(410)。
                    .aiConsentSheetPresentation(allowsLarge: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                viewModel.session.didEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.session.didBecomeActive()
                // 回前台自动补拉一次历史：断网启动/断网期间拉取失败后，网络恢复时
                // 用户切后台再回来即对齐服务器正本（loadHistory 有 isLoadingHistory 防重入）。
                Task { await viewModel.loadHistory() }
                // 回前台静默同步一次额度（方案 C）：App 在后台跨天/跨重置窗口，
                // 回来立即纠正锁定状态——不用等下一次发送撞 429 或手动点开 Sheet。
                Task { await quotaStore.refresh() }
            }
            .task {
                // 启动/首次出现时静默同步一次额度（方案 C）：覆盖「昨天用完、今天
                // 打开 App」的场景。静默 = 失败保持原状（refresh 只标 refreshFailed，
                // 不动旧裁决），不打扰用户。
                await quotaStore.refresh()
            }
            .onChange(of: activationToken) { _, token in
                guard let token else { return }
                viewModel.activateTab(token: token)
            }
            .onChange(of: isActive) { wasActive, isNowActive in
                guard wasActive, !isNowActive else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    passageTabResetGeneration &+= 1
                }
            }
    }

    /// 空时间线和已有历史的时间线必须是两个独立的首次布局。
    ///
    /// 冷启动时若先创建一个空 ScrollView、再把历史行异步插进去，SwiftUI 会在某些
    /// 帧里先采用「空内容的顶部偏移」，随后才计算真实内容高度。此前再用 proxy 补一次
    /// scrollTo，便会形成用户看到的「先显示、再定位」；若补定位恰好错过布局，还可能
    /// 留在空白位置。这里先保留一个无内容的画布，等 entries 到位后才创建真正的
    /// ScrollView。历史列表创建时使用布局级的默认底部锚点，让 SwiftUI 在首次
    /// 布局里就计算底部位置，而不是等 `.onAppear` 后再用 `scrollTo` 纠正。
    ///
    /// `.defaultScrollAnchor(.bottom)` 单独使用会把不足一屏的内容整体推到底部。
    /// 因此内容容器同时保持至少一个视口的高度：长列表初始在底部，短列表仍贴顶。
    @ViewBuilder
    private var timeline: some View {
        if !viewModel.entries.isEmpty {
            historyTimeline
        } else if viewModel.historyLoadFailed {
            // 冷启动无缓存又断网时，entries 会一直空着：没有这一支，用户看到的是
            // 一个既无内容也无法重试的空白页（审查发现）。isRetrying 让重试点击后
            // 这块视图留在原地播 spinner，而不是先塌成 Color.clear 再弹回来。
            Tab2LoadErrorView(topInset: topInset, isRetrying: viewModel.isLoadingHistory) {
                await viewModel.loadHistory(showFailureHint: true)
            }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }

    private var historyTimeline: some View {
        ScrollViewReader { proxy in
            InitialBottomScrollView(
                topContentMargin: topInset,
                bottomContentInset: inputBarHeight + AppTheme.Space.paddingSection
            ) {
                WarmRefreshControlHelper(haptics: refreshHaptics)
                    .frame(width: 0, height: 0)
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                        TimelineRow(
                            entry: entry,
                            timelineViewportFrame: timelineViewportFrame,
                            passageTabResetGeneration: passageTabResetGeneration,
                            onImageTap: { img, frame in
                            let screen = UIScreen.main.bounds.size
                            let anchor = UnitPoint(
                                x: frame.midX / screen.width,
                                y: frame.midY / screen.height
                            )
                            onImagePreview?(img, anchor)
                        }, onRetry: { text, image, entryId, requestId, bubbleEntryId in
                            Task { await viewModel.retrySend(text: text, image: image, failedEntryId: entryId, requestId: requestId, bubbleEntryId: bubbleEntryId) }
                        }, onRetryPending: { record in
                            guard NetworkMonitor.shared.isConnected else {
                                viewModel.offlineHint = "You're offline. Check your connection and try again."
                                return
                            }
                            Task { await viewModel.retryPending(record: record) }
                        }, onCollapse: { entryId in
                            // 直接用本作用域的 proxy 同步滚动，不走 ViewModel 中转 +
                            // onChange 异步链路：篇章卡片折叠时视口对齐到卡片顶部这个
                            // 动作，本质和 Tab2 分类手风琴展开时的滚动锚定
                            // （MineView.toggleExpand，proxy 与状态翻转同函数内直接调用）
                            // 是同一件事——之前改走「VM 状态 → onChange 反应」链路，
                            // 状态变化虽然发生在同一个 withAnimation 事务里，但滚动动作
                            // 本身要等下一次视图更新才触发，和 AICardBody 里本地的折叠
                            // 动画不再保证同一帧起播，两个动画各播各的、观感上就是跳动。
                            // proxy 在这里（ScrollViewReader 作用域）本来就可直接拿到，
                            // 没有必要绕一圈。
                            withAnimation(PassageTimelineLayout.toggleMotion(reduceMotion: reduceMotion).animation) {
                                proxy.scrollTo(entryId, anchor: .top)
                            }
                        })
                        .id(entry.id)
                        .padding(.bottom, Self.timelineSpacing(after: index, in: viewModel.entries))
                    }
                }
                .padding(AppTheme.Space.paddingPage)
            }
            // InputBar 是 ZStack 中的悬浮兄弟视图。把它应占的高度声明为 ScrollView
            // 的安全区域，才能让 scrollTo(last, .bottom) 与用户手动滚到底时的停靠线
            // 一致；不再依赖屏外的透明目标视图（LazyVStack 下该目标会不可靠）。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // 实测 InputBar 高度 + 固定视觉净空。InputBar 的多行/缩略图状态或
                // 后续重设计改变几何时，停靠线自动同步，不再依赖 92pt 经验常数。
                Color.clear.frame(height: inputBarHeight + AppTheme.Space.paddingSection)
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                timelineViewportFrame = frame
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable {
                refreshHaptics.fire()
                // 下拉刷新：手动对齐服务器正本（断网启动后恢复网络时的主要恢复入口）
                await viewModel.loadHistory(showFailureHint: true)
            }
            .contentMargins(.top, topInset, for: .scrollContent)  // 可滚动进入的顶部 margin
            .topEdgeFade()
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // 严格判定垂直主导滚动（垂直位移 > 水平位移的 1.2 倍且位移 >= 10pt），
                        // 避免把用户的轻微横向滑动手势（如 Tab 侧滑预备）误判为垂直阅读而误取消进入对齐会话
                        let dy = abs(value.translation.height)
                        let dx = abs(value.translation.width)
                        if dy >= 10 && dy > dx * 1.2 {
                            viewModel.userDidScroll()
                        }
                    }
            )
            // simultaneousGesture instead of onTapGesture: lets InputBar buttons
            // (e.g. the thumbnail × button) handle the tap first without
            // the scroll view's gesture recognizer cancelling them.
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .onAppear {
                if let request = viewModel.pendingScrollRequest {
                    // 首次进入的底部位置已经由 InitialBottomScrollView 在第一轮布局中
                    // 建立；这里只消费请求，避免再走一次「出现后纠正」的命令式滚动。
                    if request.reason == .initialEntry {
                        viewModel.consumeScrollRequest(id: request.id)
                    } else {
                        executeScrollRequest(request, with: proxy)
                    }
                }
            }
            .onChange(of: viewModel.pendingScrollRequest) { _, newRequest in
                guard let request = newRequest else { return }
                executeScrollRequest(request, with: proxy)
            }
        }
    }

    private func executeScrollRequest(_ request: TimelineScrollRequest, with proxy: ScrollViewProxy) {
        let target = request.targetEntryId
        let anchor: UnitPoint = {
            switch request.anchor {
            case .top: return .top
            case .center: return .center
            case .bottom: return .bottom
            }
        }()

        switch request.animation {
        case .instant:
            // 无动画瞬间定位：先立即执行一次；再延后一个 runloop tick 兜底补发一次，
            // 确保首帧或更新后布局落定。两次目标相同且无动画，视觉上幂等。
            proxy.scrollTo(target, anchor: anchor)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    proxy.scrollTo(target, anchor: anchor)
                    viewModel.consumeScrollRequest(id: request.id)
                }
            }
        case .animated:
            switch request.reason {
            case .finalCardLayout:
                // loading → 最终卡片是同 id 的原位替换，高度显著增长。
                // 延后一个 runloop tick，等新卡片完成布局后再执行平滑滚动
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        withAnimation(AppTheme.Motion.timelineActiveFollow) {
                            proxy.scrollTo(target, anchor: anchor)
                        }
                        viewModel.consumeScrollRequest(id: request.id)
                    }
                }
            default:
                withAnimation(AppTheme.Motion.timelineActiveFollow) {
                    proxy.scrollTo(target, anchor: anchor)
                }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        viewModel.consumeScrollRequest(id: request.id)
                    }
                }
            }
        }
    }

    /// 计算时间线中相邻条目之间的外部间距（严格遵循 Tab1 时间线外部间距规范）：
    /// - 上一组内容 → 日期胶囊：32pt
    /// - 日期胶囊 → 当天第一条输入：16pt
    /// - 用户输入 → 对应 AI 结果 / 失败行：12pt
    /// - AI 结果／失败行 → 下一次输入：28pt
    /// - 首个日期不额外增加 32pt；末尾条目下方不留额外间距。
    static func timelineSpacing(after index: Int, in entries: [TimelineEntry]) -> CGFloat {
        guard index + 1 < entries.count else { return 0 }
        let current = entries[index]
        let next = entries[index + 1]

        // 1. 上一组内容 → 日期胶囊：32pt（下一个是日期胶囊）
        if case .dateSeparator = next.content {
            // N4: 若当前也为日期胶囊（连续两枚胶囊空天场景），返回 16pt 避免空档过大
            if case .dateSeparator = current.content {
                return AppTheme.Space.timelineDateToFirstInput
            }
            return AppTheme.Space.timelineContentToDate
        }
        // 2. 日期胶囊 → 当天第一条输入：16pt（当前是日期胶囊）
        if case .dateSeparator = current.content {
            return AppTheme.Space.timelineDateToFirstInput
        }
        // N1: pendingRetry 重试时紧随追加的 loading 属于同组生成延续：12pt
        if case .pendingRetry = current.content, case .aiLoading = next.content {
            return AppTheme.Space.timelineUserToAI
        }
        // 3. 用户输入 → 对应 AI 结果 / 失败行：12pt（当前是用户输入）
        if case .userBubble = current.content {
            // N2 守卫：若用户输入紧跟另一个用户输入或待重试行（未闭环场景），按组间间距 28pt 对待
            if case .userBubble = next.content {
                return AppTheme.Space.timelineResultToNextInput
            }
            if case .pendingRetry = next.content {
                return AppTheme.Space.timelineResultToNextInput
            }
            return AppTheme.Space.timelineUserToAI
        }
        // 4. AI 结果／失败行 → 下一次输入：28pt
        return AppTheme.Space.timelineResultToNextInput
    }
}

/// 只负责历史时间线的首次摆放：长内容由布局系统直接从底部开始，不等
/// `onAppear` 后再发 `scrollTo`。内容不足一屏时，最小高度把内容保持在顶部，不会被
/// `.defaultScrollAnchor(.bottom)` 推到屏幕下方。后续发送、重试和卡片高度变化仍由外层
/// ScrollViewReader 的显式滚动请求处理。
struct InitialBottomScrollView<Content: View>: View {
    private let topContentMargin: CGFloat
    private let bottomContentInset: CGFloat
    private let content: Content

    init(
        topContentMargin: CGFloat = 0,
        bottomContentInset: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.topContentMargin = max(0, topContentMargin)
        self.bottomContentInset = max(0, bottomContentInset)
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    // 顶部 content margin 与底部 safe-area inset 都占用视口空间。
                    // 若仍按完整视口高度撑开短内容，默认底部锚点会滚掉顶部 margin，
                    // 使首行进入浮动顶栏。
                    .frame(
                        minHeight: max(
                            0,
                            geometry.size.height - topContentMargin - bottomContentInset
                        ),
                        alignment: .top
                    )
            }
            .defaultScrollAnchor(.bottom)
        }
    }
}

#Preview {
    TodayView()
}

// MARK: - Xcode Canvas

/// Tab1 达到每日额度限制时的完整上下文呈现（含历史气泡、底部内联提示条与锁定输入框、右上角仪表盘点击弹出达标 Sheet）
private struct Tab1LimitReachedContextPreview: View {
    @State private var inputText = ""
    @State private var pendingImage: UIImage?
    @State private var showLimitSheet = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.Color.pageBg.ignoresSafeArea()

                // 示例时间线内容
                ScrollView {
                    VStack(spacing: 0) {
                        sampleUserBubble("I was sitting by the window having my warm morning coffee.")
                            .padding(.bottom, AppTheme.Space.timelineUserToAI)
                        sampleAIBubble("I was sitting by the window, sipping my hot morning coffee.")
                            .padding(.bottom, AppTheme.Space.timelineResultToNextInput)
                        sampleUserBubble("How do I say '今天的会议推迟到下午三点' naturally?")
                            .padding(.bottom, AppTheme.Space.timelineUserToAI)
                        sampleAIBubble("Today's meeting got pushed back to 3 PM.")
                    }
                    .padding(AppTheme.Space.paddingPage)
                    .padding(.top, 60) // 避让顶栏
                    .padding(.bottom, 140) // 避让底部输入区
                }

                // 底部内联输入栏（达标态 + 内联 Banner）
                InputBar(
                    text: $inputText,
                    image: $pendingImage,
                    isLoading: false,
                    isLimitReached: true,
                    showLimitBanner: true,
                    usedCount: 5,
                    dailyLimit: 5,
                    onLimitTap: { showLimitSheet = true },
                    onSend: {}
                )
                .background {
                    VariableBlurBackdrop(extraExtend: 16)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .overlay(alignment: .topTrailing) {
                UsageLimitButton { showLimitSheet = true }
                    .padding(.trailing, AppTheme.Space.paddingPage)
                    .padding(.top, 12)
            }
            .sheet(isPresented: $showLimitSheet) {
                UsageLimitSheet(usedCount: 5, dailyLimit: 5)
            }
        }
    }

    private func sampleUserBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.bubbleUserText)
                .padding(AppTheme.Space.paddingCard)
                .background(AppTheme.Color.bubbleUserBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
    }

    private func sampleAIBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(AppTheme.Font.cardSentence)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(AppTheme.Space.paddingCard)
                .background(AppTheme.Color.cardBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 3)
            Spacer(minLength: 60)
        }
    }
}

#Preview("Tab1 · Limit Reached Full Screen Context", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1LimitReachedContextPreview()
}

/// Offline-cold-start-with-no-cache state (`Tab2LoadErrorView` shown in `timeline`
/// when `entries.isEmpty && historyLoadFailed`), rendered in the real Tab1 canvas +
/// input bar chrome. Doesn't create a `TodayViewModel` or hit the network — the
/// default `TodayView()` preview above always tries a real `loadHistory()`, which
/// can't be steered into this state from a preview.
private struct Tab1HistoryLoadErrorContextPreview: View {
    var isRetrying = false
    @State private var inputText = ""
    @State private var pendingImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            Tab2LoadErrorView(isRetrying: isRetrying) { }

            InputBar(text: $inputText, image: $pendingImage, isLoading: false, onSend: {})
                .background {
                    VariableBlurBackdrop(extraExtend: 16)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
        }
    }
}

#Preview("Tab1 · History load failed", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1HistoryLoadErrorContextPreview()
}

#Preview("Tab1 · History load failed · Retrying", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1HistoryLoadErrorContextPreview(isRetrying: true)
}

// MARK: - 全状态与极端场景专属目检画布预览（供 Xcode Canvas 直接目检）
private struct Tab1EdgeCasesContextPreview: View {
    @State private var inputText = ""
    @State private var pendingImage: UIImage?

    private let sampleEntries: [TimelineEntry] = [
        TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
        TimelineEntry.userBubble(text: "晨光透过百叶窗照了进来，微风吹动着窗帘。", image: nil),
        TimelineEntry.aiCard(AICard.card(CardContent(
            granularity: "passage",
            direction: "comprehend",
            targetExpression: "Morning light filtered through the blinds.\nA cool breeze stirred the curtain.",
            nativeMeaning: "晨光透过百叶窗洒了进来。\n一阵凉风吹拂着窗帘。",
            passageLines: [
                PassageLine(en: "Morning light filtered through the blinds.", zh: "晨光透过百叶窗洒了进来。"),
                PassageLine(en: "A cool breeze stirred the curtain.", zh: "一阵凉风吹拂着窗帘。"),
                PassageLine(en: "The city outside was slowly waking up.", zh: "外面的城市正缓缓苏醒。")
            ]
        ))),
        TimelineEntry.userBubble(text: "Something unsafe or invalid format", image: nil),
        TimelineEntry.aiCard(AICard.error(ErrorContent(errorType: "content_filter", message: "This content can't be processed. Try another one."))),
        TimelineEntry.userBubble(text: "Can you send this photo while offline?", image: nil),
        TimelineEntry(id: UUID(), createdAt: .now, content: .sendFailed(text: "Can you send this photo while offline?", image: nil, requestId: nil, bubbleEntryId: nil))
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(sampleEntries.enumerated()), id: \.offset) { index, entry in
                        TimelineRow(entry: entry)
                            .id(entry.id)
                            .padding(.bottom, TodayView.timelineSpacing(after: index, in: sampleEntries))
                    }
                }
                .padding(AppTheme.Space.paddingPage)
                .padding(.top, 40)
                .padding(.bottom, 120)
            }

            InputBar(text: $inputText, image: $pendingImage, isLoading: false, onSend: {})
                .background {
                    VariableBlurBackdrop(extraExtend: 16)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
        }
    }
}

#Preview("Tab1 · Edge Cases & Spacing", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1EdgeCasesContextPreview()
}
