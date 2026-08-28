import SwiftUI

/// 显式 @MainActor：TodayViewModel 已标 @MainActor（审查发现 #5），@State 默认值在
/// view init 里求值，init 必须是主线程隔离才能调用它的隔离构造器。
@MainActor
struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    @State private var inputText = ""
    /// 时间线末尾的 0 高锚点是否在视口内 → 用户是否处于（或接近）底部。
    /// 被动对齐时只在底部跟随滚动；用户在阅读中部内容时不被拽走。
    @State private var atBottomVisible = false
    /// InputBar 外层的实时渲染高度（含胶囊、缩略图/多行增长与底部 padding）。
    /// 首帧用单行基础态 52 + 8 = 60pt，实测回调随后接管；配合 32pt 内容净空，
    /// 基础态停靠线仍是此前验收过的 92pt。
    @State private var inputBarHeight = AppTheme.Size.inputBarMinHeight + AppTheme.Space.paddingS
    var onImagePreview: ((UIImage, UnitPoint) -> Void)?
    var topInset: CGFloat = 0
    /// Written by the scroll view; read by RootTabContainer to drive topBar compact mode
    @Binding var topBarCompact: Bool
    /// Only the visible tab may drive compact — a backgrounded TodayView must not
    /// keep writing compact and fight the tab-switch reset (caused labels to vanish on Mine)
    private let isActive: Bool

    init(topBarCompact: Binding<Bool> = .constant(false), isActive: Bool = true, onImagePreview: ((UIImage, UnitPoint) -> Void)? = nil, topInset: CGFloat = 0) {
        self._topBarCompact = topBarCompact
        self.isActive = isActive
        self.onImagePreview = onImagePreview
        self.topInset = topInset
    }

    var body: some View {
        @Bindable var vm = viewModel
        ZStack(alignment: .bottom) {
            timeline
                .task { await viewModel.loadHistory() }

            // InputBar 独立悬浮在内容上方；背后垫 Gemini 风格可变渐进式通透模糊底托（向下贯穿底部安全区，向上 16pt 平滑消融进入内容区），
            // 内容向下滚动穿过时自然失焦消融溶解进背景，保持极佳的通透感与景深
            InputBar(text: $inputText, image: $vm.pendingImage, isLoading: viewModel.isLoading) {
                let toSend = inputText
                inputText = ""
                Task { await viewModel.send(toSend) }
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
            // 首页画布装饰（网格点 + 底部橘色光晕），透明叠在 pageBg 之上、内容之下
            .background(CanvasBackground(showTopAura: false).ignoresSafeArea())
            .sheet(isPresented: $viewModel.showAIConsent) {
                AIConsentView { viewModel.onConsentAgreed() }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                viewModel.session.didEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.session.didBecomeActive()
                // 回前台自动补拉一次历史：断网启动/断网期间拉取失败后，网络恢复时
                // 用户切后台再回来即对齐服务器正本（loadHistory 有 isLoadingHistory 防重入）。
                Task { await viewModel.loadHistory() }
            }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                WarmRefreshControlHelper()
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // 下拉刷新：手动对齐服务器正本（断网启动后恢复网络时的主要恢复入口）
                await viewModel.loadHistory(showFailureHint: true)
            }
            .contentMargins(.top, topInset, for: .scrollContent)  // 可滚动进入的顶部 margin
            .topEdgeFade()
            .modifier(ScrollCompactDetector(compact: $topBarCompact, active: isActive))
            .scrollDismissesKeyboard(.interactively)
            // simultaneousGesture instead of onTapGesture: lets InputBar buttons
            // (e.g. the thumbnail × button) handle the tap first without
            // the scroll view's gesture recognizer cancelling them.
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
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

// GeometryReader+PreferenceKey doesn't fire during active scrolling (layout-only),
// so we use onScrollGeometryChange (iOS 18+) which runs on every scroll frame.
// iOS 17 gets no compact mode; the existing topEdgeFade keeps content readable there.
private struct ScrollCompactDetector: ViewModifier {
    @Binding var compact: Bool
    var active: Bool
    /// True only while the user is actively dragging or the scroll is decelerating.
    /// Geometry callbacks from tab switches / layout settles fire while idle — we skip
    /// those so they can't re-collapse the bar right after a tab switch resets it.
    @State private var isScrolling = false

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollPhaseChange { _, phase in
                    isScrolling = phase != .idle
                }
                .onScrollGeometryChange(
                    // Distance actually scrolled down from the top, normalised to start at 0.
                    // The ScrollView sits under the topBar's safe-area inset, so raw
                    // contentOffset.y rests at a negative value; adding contentInsets.top
                    // cancels that out so the thresholds below are measured from the top edge.
                    for: CGFloat.self,
                    of: { $0.contentOffset.y + $0.contentInsets.top }
                ) { _, scrolled in
                    // Only a visible tab AND a real user scroll may drive compact.
                    guard active, isScrolling else { return }
                    if scrolled > 40 && !compact {
                        withAnimation(AppTheme.Motion.topBarCompact) { compact = true }
                    } else if scrolled <= 8 && compact {
                        withAnimation(AppTheme.Motion.topBarCompact) { compact = false }
                    }
                }
        } else {
            content
        }
    }
}

#Preview {
    TodayView()
}
