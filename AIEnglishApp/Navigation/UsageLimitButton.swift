import SwiftUI

/// 主界面右上角的使用次数/额度入口。与左侧 Settings 按钮同尺寸（44pt）且同享 pill 双层阴影。
struct UsageLimitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UsageGaugeIcon()
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .surfacePill(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.iconControl)
        .accessibilityLabel("Usage Limit")
    }
}

/// 轻量线性表意用量图标（仪表盘与指针）：与汉堡按钮同一套线宽与视觉重量。
struct UsageGaugeIcon: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let rect = proxy.frame(in: .local)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = rect.width * 0.40

                // 260度仪表圆弧 (从 140° 到 40°)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(140),
                    endAngle: .degrees(40),
                    clockwise: false
                )

                // 仪表中心指向右上方的刻度指针
                path.move(to: center)
                let pointerAngle = Double.pi * 0.28
                path.addLine(to: CGPoint(
                    x: center.x + radius * 0.62 * CGFloat(cos(pointerAngle)),
                    y: center.y - radius * 0.62 * CGFloat(sin(pointerAngle))
                ))
            }
            .stroke(
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.topBarMenuIconStroke,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(
            width: AppTheme.Size.topBarMenuIconGlyph,
            height: AppTheme.Size.topBarMenuIconGlyph
        )
        .accessibilityHidden(true)
    }
}

/// 额度与使用次数轻量展示 Sheet。
/// 数字来自服务端（check_generation_quota RPC，经 UsageQuotaStore）：
/// usedCount/dailyLimit 是服务器口径的「成功生成次数 / 有效上限」。
struct UsageLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dailyLimit: Int
    @State private var usedCount: Int?
    @State private var showFeedback = false
    @State private var loadFailed = false
    @State private var isRetrying = false
    private let isPreviewInjected: Bool
    /// 反馈提交成功后由宿主展示 toast（FeedbackView 不再自行发全局 toast，审计发现 ④）。
    private let onFeedbackSubmitted: (() -> Void)?

    init(
        usedCount: Int? = nil,
        dailyLimit: Int = 5,
        initialLoadFailed: Bool = false,
        onFeedbackSubmitted: (() -> Void)? = nil
    ) {
        self.onFeedbackSubmitted = onFeedbackSubmitted
        self._loadFailed = State(initialValue: initialLoadFailed)
        if let count = usedCount {
            self._dailyLimit = State(initialValue: dailyLimit)
            self._usedCount = State(initialValue: count)
            self.isPreviewInjected = true
        } else if initialLoadFailed {
            self._dailyLimit = State(initialValue: dailyLimit)
            self._usedCount = State(initialValue: nil)
            self.isPreviewInjected = true
        } else {
            // 先用缓存里的服务器数字渲染（429 达标后或当天已同步过，store 已有数字），
            // 首帧即达标态/已知数字，无加载态闪烁；.task 里的 refresh 随后仍以
            // 服务端为准覆盖——数字通常不变，也就没有跳变。
            // 冷启动从未取到过数字（usedCount == nil）时仍走加载态或离线空态。
            let store = UsageQuotaStore.shared
            self._usedCount = State(initialValue: store.usedCount)
            self._dailyLimit = State(initialValue: store.dailyLimit ?? dailyLimit)
            self.isPreviewInjected = false
        }
    }

    private var isLimitReached: Bool {
        guard let usedCount else { return false }
        return usedCount >= dailyLimit
    }

    private var sheetHeight: CGFloat {
        if isLimitReached {
            return loadFailed ? 405 : 375
        } else if usedCount == nil && loadFailed {
            return 310
        } else {
            return 260
        }
    }

    private func refreshQuota() async {
        guard !isPreviewInjected else { return }
        guard NetworkMonitor.shared.isConnected else {
            loadFailed = true
            return
        }
        isRetrying = true
        defer { isRetrying = false }
        let store = UsageQuotaStore.shared
        await store.refresh()
        if let used = store.usedCount { usedCount = used }
        dailyLimit = store.dailyLimit ?? 5
        loadFailed = store.refreshFailed
    }

    var body: some View {
        // 标准字号下内容装不满 detent 高度 → ScrollView 不滚动，与旧版静态布局视觉一致；
        // 大字号（AX）下内容超高时，从「裁切看不到」变为「可滚动看到」。
        // basedOnSize 让内容不满时不出现橡皮筋拖拽，行为与静态布局相同。
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                headerRow

                if usedCount == nil && loadFailed {
                    offlineEmptyCard
                } else {
                    usageCard

                    if isLimitReached {
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        feedbackCTAButton

                        if loadFailed {
                            offlineCachedNote
                                .padding(.top, AppTheme.Space.paddingXS)
                        }
                    } else if loadFailed {
                        offlineCachedNote
                            .padding(.top, AppTheme.Space.paddingS)
                    } else {
                        normalFooterNote
                            .padding(.top, AppTheme.Space.paddingS)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.titleToContent)
            .padding(.bottom, AppTheme.Space.paddingPage)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Color.pageBg)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showFeedback) {
            NavigationStack {
                FeedbackView(
                    initialCategory: .suggestion,
                    initialBody: "I would like to request an invite code to increase my daily generation quota.",
                    onSuccess: {
                        onFeedbackSubmitted?()
                        showFeedback = false
                        dismiss()
                    }
                )
            }
        }
        .task {
            await refreshQuota()
        }
        .onChange(of: NetworkMonitor.shared.isConnected) { _, isConnected in
            guard isConnected, !isPreviewInjected else { return }
            Task { await refreshQuota() }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("Daily Limit")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .surfacePill(in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            HStack(alignment: .firstTextBaseline) {
                if let usedCount {
                    Text("\(usedCount)")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(isLimitReached ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
                } else if loadFailed {
                    // 断网或加载失败：显示占位破折号，停止无休止的转圈
                    Text("–")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    // 服务器数字还没到：轻量加载态，不显示误导性的 0
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.Color.textSecondary)
                        .frame(width: 36, height: 36)
                }
                Text("/ \(dailyLimit) generations today")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                Spacer()
            }

            // 进度条
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.4))
                        .frame(height: 6)
                    if usedCount != nil {
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
                            .frame(width: max(geo.size.width * ratio, 6), height: 6)
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(AppTheme.Space.paddingCard)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .fill(AppTheme.Color.cardBg)
        }
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: 12,
            x: 0,
            y: 4
        )
    }

    /// 达标文案：去卡片化轻量排版（暖纸底上直接承载，避免双层卡片嵌套造成的厚重感）
    private var limitReachedText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("You've reached today's limit.")
                .font(AppTheme.Font.cardSentence)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    private var feedbackCTAButton: some View {
        Button {
            showFeedback = true
        } label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 16, weight: .semibold))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.ctaLabel)
            }
            .foregroundStyle(AppTheme.Color.textOnChip)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.paddingCard)
            .background(AppTheme.Color.interactive, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var normalFooterNote: some View {
        Text("Your daily generations refresh every day at midnight.")
            .font(AppTheme.Font.statusNote)
            .foregroundStyle(AppTheme.Color.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Space.paddingM)
    }

    /// 离线或刷新失败时且已有今日缓存（如 2/5 或 5/5 达标）：
    /// 真实数字与进度条正常呈现，底部告知网络状态并展示上次同步数据。
    private var offlineCachedNote: some View {
        let isConnected = NetworkMonitor.shared.isConnected
        return HStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: isConnected ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: 13, weight: .medium))
            Text(isConnected
                ? "Couldn't refresh. Showing last synced usage."
                : "You're offline. Showing last synced usage.")
                .font(AppTheme.Font.statusNote)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppTheme.Space.paddingM)
    }

    /// 冷启动且无今日缓存时的离线/刷新失败专用空状态卡片：
    /// 拒绝破损的「– / 5」与空轨道，根据实际网络状态呈现精准文案与重试入口。
    private var offlineEmptyCard: some View {
        let isConnected = NetworkMonitor.shared.isConnected
        return VStack(spacing: AppTheme.Space.paddingM) {
            Image(systemName: isConnected ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 44, height: 44)

            VStack(spacing: AppTheme.Space.paddingXS) {
                Text(isConnected ? "Couldn't Refresh" : "You're Offline")
                    .font(AppTheme.Font.cardSentence)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(isConnected
                    ? "We couldn't check your remaining quota right now. Please try again."
                    : "Connect to the internet to check your remaining quota and generate content.")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }

            Button {
                Task { await refreshQuota() }
            } label: {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.Color.textPrimary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(isRetrying ? "Retrying..." : "Try again")
                        .font(AppTheme.Font.compactActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.neutralFaint.opacity(0.6), in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isRetrying)
            .padding(.top, AppTheme.Space.paddingXS)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Space.paddingPage)
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .fill(AppTheme.Color.cardBg)
        }
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: 12,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Xcode Canvas Previews

/// 真实底部弹窗宿主容器：在 Canvas 中精准模拟真实 iOS 底部 Sheet 弹起与半透明遮罩效果
private struct SheetModalCanvasPreview<Content: View>: View {
    let sheetHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            // 宿主背景模拟（Tab1 页面底色；原 Canvas 光晕层已随 CanvasBackground 一并移除）
            AppTheme.Color.pageBg.ignoresSafeArea()

            // 背景暗色遮罩（模拟系统 Sheet 弹出时的 scrim）
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            // 底部 Sheet 容器
            ZStack(alignment: .top) {
                content()

                // 顶部系统拖拽把手指示条
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .frame(height: sheetHeight)
            .background(AppTheme.Color.pageBg)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.large,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppTheme.Radius.large,
                style: .continuous
            ))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -4)
        }
    }
}

#Preview("Usage Limit Sheet · Limit Reached (5/5)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 375) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("Usage Limit Sheet · Limit Reached Offline (5/5)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 405) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5, initialLoadFailed: true)
    }
}

#Preview("Usage Limit Sheet · Normal Online (2/5)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("Usage Limit Sheet · Offline With Cache (2/5)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5, initialLoadFailed: true)
    }
}

#Preview("Usage Limit Sheet · Offline Empty State", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 310) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true)
    }
}

/// 交互式调节滑块：可在 Xcode Canvas 中拖动观察正常态与达标态的平滑切换
private struct UsageLimitInteractivePreview: View {
    @State private var currentCount: Double = 5
    private let limit: Int = 5

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingPage) {
            SheetModalCanvasPreview(sheetHeight: currentCount >= Double(limit) ? 375 : 260) {
                UsageLimitSheet(usedCount: Int(currentCount), dailyLimit: limit)
            }
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

            VStack(spacing: AppTheme.Space.paddingS) {
                Text("Drag slider to simulate usage: \(Int(currentCount)) / \(limit)")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Slider(value: $currentCount, in: 0...5, step: 1)
                    .tint(AppTheme.Color.interactive)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .padding(AppTheme.Space.paddingPage)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview("Usage Limit Sheet · Interactive Slider", traits: .fixedLayout(width: 393, height: 700)) {
    UsageLimitInteractivePreview()
}
