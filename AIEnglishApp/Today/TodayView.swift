import SwiftUI

/// 显式 @MainActor：TodayViewModel 已标 @MainActor（审查发现 #5），@State 默认值在
/// view init 里求值，init 必须是主线程隔离才能调用它的隔离构造器。
@MainActor
struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    /// 时间线末尾的 0 高锚点是否在视口内 → 用户是否处于（或接近）底部。
    /// 被动对齐时只在底部跟随滚动；用户在阅读中部内容时不被拽走。
    @State private var atBottomVisible = false
    /// InputBar 外层的实时渲染高度（含胶囊、缩略图/多行增长与底部 padding）。
    /// 首帧用单行基础态 52 + 8 = 60pt，实测回调随后接管；配合 32pt 内容净空，
    /// 基础态停靠线仍是此前验收过的 92pt。
    @State private var inputBarHeight = AppTheme.Size.inputBarMinHeight + AppTheme.Space.paddingS
    @State private var refreshHaptics = PullToRefreshHaptics()
    /// 生成次数额度的共享展示状态：达标时 InputBar 锁输入 + 出 banner，数字从这读。
    /// 只有服务端裁决会把 isAllowed 置 false：429、refresh 的 allowed 字段，
    /// 以及成功响应的落账后裁决（方案 B——最后一次生成用完额度即锁定）。
    @State private var quotaStore = UsageQuotaStore.shared
    var onImagePreview: ((UIImage, UnitPoint) -> Void)?
    /// 达标 banner 点击 → 打开额度 Sheet（由 RootTabContainer 呈现，顶栏仪表盘同款）。
    var onOpenUsageLimit: (() -> Void)?
    var topInset: CGFloat = 0

    init(onImagePreview: ((UIImage, UnitPoint) -> Void)? = nil,
         onOpenUsageLimit: (() -> Void)? = nil,
         topInset: CGFloat = 0) {
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
    }

    /// 空时间线和已有历史的时间线必须是两个独立的首次布局。
    ///
    /// 冷启动时若先创建一个空 ScrollView、再把历史行异步插进去，SwiftUI 会在某些
    /// 帧里先采用「空内容的顶部偏移」，随后才计算真实内容高度。此前再用 proxy 补一次
    /// scrollTo，便会形成用户看到的「先显示、再定位」；若补定位恰好错过布局，还可能
    /// 留在空白位置。这里先保留一个无内容的画布，等 entries 到位后才创建真正的
    /// ScrollView——它首次出现时内容已经就位，`.onAppear` 里补的 `scrollTo` 因而是
    /// 该次布局落定后的第一件事，不会有「先显示、再定位」的可见跳动。
    ///
    /// 这里刻意不用 `.defaultScrollAnchor(.bottom)`：那是布局层面的容器锚点，内容不足
    /// 一屏时它会把内容整体推到底部（顶上空出一大截），而不是让内容像其他消息一样自然
    /// 贴顶——历史行数少的会话会看到顶部一大块空白（审查发现）。`scrollTo(id:anchor:)`
    /// 只移动滚动位置：内容超过一屏时定位到底部，内容不足一屏时是无操作，天然贴顶。
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
            ScrollView {
                WarmRefreshControlHelper(haptics: refreshHaptics)
                    .frame(width: 0, height: 0)
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.entries) { entry in
                        TimelineRow(entry: entry, onImageTap: { img, frame in
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
                        })
                        .id(entry.id)
                    }
                    // 底部探针：出现在视口内 → 用户已处于（或接近）底部。
                    // 0 高不占位、不影响布局；被动对齐的「底部跟随」判定全靠它。
                    Color.clear
                        .frame(height: 0)
                        .onAppear { atBottomVisible = true }
                        .onDisappear { atBottomVisible = false }
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
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable {
                refreshHaptics.fire()
                // 下拉刷新：手动对齐服务器正本（断网启动后恢复网络时的主要恢复入口）
                await viewModel.loadHistory(showFailureHint: true)
            }
            .contentMargins(.top, topInset, for: .scrollContent)  // 可滚动进入的顶部 margin
            .topEdgeFade()
            .scrollDismissesKeyboard(.interactively)
            // simultaneousGesture instead of onTapGesture: lets InputBar buttons
            // (e.g. the thumbnail × button) handle the tap first without
            // the scroll view's gesture recognizer cancelling them.
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .onAppear {
                // 冷启动/时间线首次有内容 → 无动画瞬间定位底部。entries 已经就位
                // （由上方两段式挂载保证），先同步尝试，再延后一个 runloop tick 兜底一次，
                // 防止这一帧的布局还没吃到最新内容；两次目标相同、无动画，视觉上幂等。
                // 内容不足一屏时 scrollTo 是无操作，天然贴顶——不复用 defaultScrollAnchor
                // 是因为它会把不足一屏的内容整体推到底部（顶部空出一大截，审查发现）。
                guard viewModel.takeInstantJumpFlag(), let last = viewModel.entries.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.entries.count) {
                // 重试期间视图锚在原地（scrollTargetId 非空）：条目的原地增删
                // 不触发「自动滚到最后一条」，否则用户会被拽离重试现场
                guard viewModel.scrollTargetId == nil else { return }
                // 最后一条 entry 是新增时已实例化的稳定目标。底部的 safeAreaInset
                // 已把 InputBar 遮住的区域从滚动视口扣除，故 bottom 锚点就是用户
                // 手动滚到底时的停靠线。
                guard let last = viewModel.entries.last else { return }
                // ① 冷启动/首启：时间线首次有内容 → 无动画瞬间定位底部，
                //    没有「从顶部划到底部」的滑动（不包 withAnimation 即瞬间定格）。
                //    审查发现 #10：同步 scrollTo 可能赶在本次更新的布局落定之前执行
                //    （目标新位置尚未计算），flag 已消费无法重试 → 用户停在顶部。
                //    先同步尝试（布局已就位时立即生效），再延后一个 runloop tick
                //    兜底一次。两次目标相同、无动画，视觉上幂等。
                if viewModel.takeInstantJumpFlag() {
                    proxy.scrollTo(last.id, anchor: .bottom)
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    return
                }
                // ② 被动对齐（进页面/下拉刷新/回前台的 loadHistory 改动）：
                //    只在用户已处于底部时跟随，正在阅读时不拽走；
                //    用短促 easeOut（0.15s）跟随，新内容到达不拖沓
                if viewModel.isPassiveAlignment {
                    guard atBottomVisible else { return }
                    withAnimation(AppTheme.Motion.timelinePassiveFollow) { proxy.scrollTo(last.id, anchor: .bottom) }
                    return
                }
                // ③ 主动变化（发送消息、待重试记录重试成功等）：照旧动画跟随到底
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: viewModel.bottomScrollTargetId) {
                guard viewModel.scrollTargetId == nil,
                      let target = viewModel.bottomScrollTargetId else { return }
                // loading → 最终卡片是同 id、同 count 的原位替换，但高度会显著增长。
                // 延后一个 runloop tick，等新卡片完成布局后再读取正确的底部位置；
                // 否则 scrollTo 会按 loading 的旧高度计算，看起来像完全没有滚动。
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        withAnimation { proxy.scrollTo(target, anchor: .bottom) }
                    }
                }
            }
            .onChange(of: viewModel.scrollTargetId) {
                if let target = viewModel.scrollTargetId {
                    withAnimation { proxy.scrollTo(target, anchor: .center) }
                }
            }
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
                    VStack(spacing: AppTheme.Space.paddingCard) {
                        sampleUserBubble("I was sitting by the window having my warm morning coffee.")
                        sampleAIBubble("I was sitting by the window, sipping my hot morning coffee.")
                        sampleUserBubble("How do I say '今天的会议推迟到下午三点' naturally?")
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
