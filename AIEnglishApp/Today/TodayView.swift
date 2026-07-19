import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    @State private var inputText = ""
    @State private var previewImage: UIImage?
    @State private var previewAnchor: UnitPoint = .center
    /// 真实网络状态：离线横幅只在设备确实无网时显示，不再被单次请求失败误触发
    @State private var network = NetworkMonitor.shared
    /// Written by the scroll view; read by RootTabContainer to drive topBar compact mode
    @Binding var topBarCompact: Bool
    /// Only the visible tab may drive compact — a backgrounded TodayView must not
    /// keep writing compact and fight the tab-switch reset (caused labels to vanish on Mine)
    private let isActive: Bool

    init(topBarCompact: Binding<Bool> = .constant(false), isActive: Bool = true) {
        self._topBarCompact = topBarCompact
        self.isActive = isActive
    }

    var body: some View {
        @Bindable var vm = viewModel
        timeline
            .task { await viewModel.loadHistory() }
            .safeAreaInset(edge: .top) {
                if !network.isConnected {
                    OfflineBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: network.isConnected)
            .safeAreaInset(edge: .bottom) {
                InputBar(text: $inputText, image: $vm.pendingImage, isLoading: viewModel.isLoading) {
                    let toSend = inputText
                    inputText = ""
                    Task { await viewModel.send(toSend) }
                }
            }
            .overlay {
            ZStack {
                if previewImage != nil {
                    Color.black
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) { previewImage = nil }
                        }
                }
                if let img = previewImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                        Button {
                            withAnimation(.spring(duration: 0.3)) { previewImage = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white, Color(uiColor: .systemGray3))
                                .padding()
                        }
                    }
                    .transition(.scale(scale: 0.1, anchor: previewAnchor).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.35), value: previewImage != nil)
        // 首页画布装饰（网格点 + 底部橘色光晕），透明叠在 pageBg 之上、内容之下
        .background(CanvasBackground().ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.session.didEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.session.didBecomeActive()
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.entries) { entry in
                        TimelineRow(entry: entry, onImageTap: { img, frame in
                            let screen = UIScreen.main.bounds.size
                            previewAnchor = UnitPoint(
                                x: frame.midX / screen.width,
                                y: frame.midY / screen.height
                            )
                            withAnimation(.spring(duration: 0.35)) { previewImage = img }
                        }, onRetry: { text, image, entryId in
                            Task { await viewModel.retrySend(text: text, image: image, failedEntryId: entryId) }
                        })
                        .id(entry.id)
                    }
                }
                .padding(AppTheme.Space.paddingPage)
            }
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
                if let last = viewModel.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
