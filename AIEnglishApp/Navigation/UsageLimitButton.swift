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

/// Daily Limit 弹窗当前呈现哪一种状态。弹窗的内容分支与弹窗高度都只读这一处判定，
/// 单测按状态逐个锁定（改任一状态的高度或分支条件，测试会变红）。
///
/// 「离线」与「刷新失败」两种原因不在这里区分：它们布局、高度相同，只是图标与文案不同，
/// 由视图按网络状态挑文案。
enum UsageLimitSheetState: Equatable {
    /// 首次取数中：数字位置是菊花（usedCount 尚无值、也没失败）。
    case loading
    /// 正常：已知用量、未用完，脚注是「零点刷新」。
    case normal
    /// 已知用量、未用完，但这次刷新失败 / 离线：显示上次同步的数字 + 「Showing last synced usage」。
    case normalCached
    /// 已用完：达标说明 + 申请邀请码按钮。
    case reached
    /// 已用完，且这次刷新失败 / 离线：达标说明 + 按钮 + 「Showing last synced usage」。
    case reachedCached
    /// 从未取到过数字且这次失败：整张卡换成空态（You're offline / Couldn't refresh）+ Try again。
    case unavailable

    static func resolve(usedCount: Int?, dailyLimit: Int, loadFailed: Bool) -> Self {
        guard let usedCount else { return loadFailed ? .unavailable : .loading }
        if usedCount >= dailyLimit { return loadFailed ? .reachedCached : .reached }
        return loadFailed ? .normalCached : .normal
    }

    var isLimitReached: Bool { self == .reached || self == .reachedCached }

    /// 弹窗（detent）高度。
    var sheetHeight: CGFloat {
        switch self {
        case .unavailable:   AppTheme.Size.usageLimitSheetHeightLoadFailed
        case .reached:       AppTheme.Size.usageLimitSheetHeightReached
        case .reachedCached: AppTheme.Size.usageLimitSheetHeightReachedOffline
        case .loading, .normal, .normalCached: AppTheme.Size.usageLimitSheetHeight
        }
    }
}

/// 额度与使用次数轻量展示 Sheet。
/// 数字来自服务端（check_generation_quota RPC，经 UsageQuotaStore）：
/// usedCount/dailyLimit 是服务器口径的「成功生成次数 / 有效上限」。
struct UsageLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var dailyLimit: Int
    @State private var usedCount: Int?
    @State private var showFeedback = false
    @State private var loadFailed = false
    @State private var isRetrying = false
    private let isPreviewInjected: Bool
    private let mockIsConnected: Bool?
    /// 反馈提交成功后由宿主展示 toast（FeedbackView 不再自行发全局 toast，审计发现 ④）。
    private let onFeedbackSubmitted: (() -> Void)?

    init(
        usedCount: Int? = nil,
        dailyLimit: Int = 5,
        initialLoadFailed: Bool = false,
        simulateLoading: Bool = false,
        mockIsConnected: Bool? = nil,
        onFeedbackSubmitted: (() -> Void)? = nil
    ) {
        self.mockIsConnected = mockIsConnected
        self.onFeedbackSubmitted = onFeedbackSubmitted
        self._loadFailed = State(initialValue: initialLoadFailed)
        if simulateLoading {
            self._dailyLimit = State(initialValue: dailyLimit)
            self._usedCount = State(initialValue: nil)
            self.isPreviewInjected = true
        } else if let count = usedCount {
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

    private var isConnected: Bool {
        mockIsConnected ?? NetworkMonitor.shared.isConnected
    }

    private var state: UsageLimitSheetState {
        .resolve(usedCount: usedCount, dailyLimit: dailyLimit, loadFailed: loadFailed)
    }

    private var isLimitReached: Bool { state.isLimitReached }

    private var sheetHeight: CGFloat { state.sheetHeight }

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
                // 1. 顶栏：无多余按键，纯净留白
                headerRow

                if state == .unavailable {
                    // 状态 5：冷启动离线空状态卡片（区分 05-A 与 05-B）
                    offlineEmptyCard
                } else {
                    // 状态 1 / 2 / 3 / 4 / 6 / 7 主卡片 (方案 2-C 极细精工规范)
                    usageCard

                    if state.isLimitReached {
                        // 达标说明文案 (去焦虑、舒展排版)
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        // 申请邀请码高定 CTA 按钮 (方案 1 细线描边胶囊)
                        feedbackCTAButton

                        if state == .reachedCached {
                            offlineCachedNote
                                .padding(.top, AppTheme.Space.paddingXS)
                        }
                    } else if state == .normalCached {
                        offlineCachedNote
                            .padding(.top, AppTheme.Space.paddingS)
                    } else {
                        // 正常零点刷新注记 (左对齐出版物风)
                        normalFooterNote
                            .padding(.top, AppTheme.Size.usageLimitSectionNudge)
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
        .presentationBackground(AppTheme.Color.pageBg)
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

    // MARK: - Subviews & Elements (方案 2-C 与方案 1 全要素落地)

    /// 1. 顶栏：句首大写 Daily limit · Charter 22pt Bold 粗衬线（增强定力压轴） · 移除右上角关闭键
    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.usageLimitSheetTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
        }
        .padding(.top, AppTheme.Space.paddingXS)
    }

    /// 2. 用量卡片 (方案 2-C)：Charter 24pt 细衬线数字 + 15pt Light 副文 + 2.0pt 极薄连续微线 + 0.5pt 边框贴地双层阴影
    private var usageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingXS) {
                if let usedCount {
                    Text("\(usedCount)")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                } else if loadFailed {
                    Text("–")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    // 加载态占位：隐藏的数字（与数字态同一字体）撑出同样的行高、基线与宽度，数据返回时
                    // 副文纵横都不位移；菊花以 overlay 居中叠在其上——overlay 不参与布局，微调 offset
                    // 不会再改变行布局（此前菊花自己占位：行顶被副文贴住、副文比数字态高 9pt，
                    // 且 22pt 槽比数字宽，副文还会向左挪约 7pt）。
                    Text("0")
                        .font(AppTheme.Font.quotaHeroNumber)
                        .hidden()
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.Color.textSecondary)
                                .frame(
                                    width: AppTheme.Size.usageLimitSpinnerSlotSize,
                                    height: AppTheme.Size.usageLimitSpinnerSlotSize
                                )
                                .offset(y: AppTheme.Size.usageLimitSpinnerOpticalOffset)
                        }
                }

                Text("/ \(dailyLimit) generations today")
                    .font(AppTheme.Font.quotaSubtext(legibilityWeight: legibilityWeight))
                    .foregroundStyle(AppTheme.Color.settingsRowText)

                Spacer()
            }
            .frame(minHeight: AppTheme.Size.usageLimitQuotaRowMinHeight)

            // 方案 A 官方规范: 3.0pt 饱满通透连续微线轨 (底槽 opacity 0.20 通透纸感，满额深焦黑，未满次级灰)
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.usageLimitProgressTrack)
                        .frame(height: AppTheme.Size.usageLimitProgressBarHeight)
                    if usedCount != nil {
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                            .frame(
                                width: max(geo.size.width * ratio, AppTheme.Size.usageLimitProgressBarHeight),
                                height: AppTheme.Size.usageLimitProgressBarHeight
                            )
                    }
                }
            }
            .frame(height: AppTheme.Size.usageLimitProgressBarHeight)
            .padding(.top, AppTheme.Size.usageLimitSectionNudge)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(
            cornerRadius: AppTheme.Radius.large,
            fillColor: AppTheme.Color.settingsCardSurface
        )
    }

    /// 3. 达标说明段落 (方案 1 细衬线降重)：Charter 16.5pt Regular + Gothic A1 14pt Light
    private var limitReachedText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("You've reached today's limit.")
                .font(AppTheme.Font.quotaReachedTitle)
                .foregroundStyle(AppTheme.Color.settingsRowText)

            Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                .font(AppTheme.Font.quotaReachedBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 4. 申请邀请码 CTA 按钮 (选型 4 温润暖灰次级胶囊)：44pt · 暖灰底 + 细描边 + 焦黑文字，与纯净暖白卡片形成舒适明度差
    private var feedbackCTAButton: some View {
        Button {
            showFeedback = true
        } label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: AppTheme.Size.usageLimitCTAIconGlyph, weight: .medium))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.quotaFeedbackAction)
            }
            .foregroundStyle(AppTheme.Color.settingsRowText)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.usageLimitCTAHeight)
            .background(AppTheme.Color.usageLimitCTASecondaryBg, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.usageLimitCTASecondaryBorder, lineWidth: AppTheme.Size.usageLimitCTABorderWidth)
            }
            .shadow(
                color: AppTheme.Color.usageLimitCTAShadow,
                radius: AppTheme.Size.usageLimitCTAShadowRadius,
                x: 0,
                y: AppTheme.Size.usageLimitCTAShadowY
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// 5. 正常脚注：严格 16pt 左对齐出版物注记风
    private var normalFooterNote: some View {
        Text("Your daily generations refresh every day at midnight.")
            .font(AppTheme.Font.settingsFormIntro)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 6. 弱网与离线提示：左对齐，12pt 图标 + 13.5pt 柔和注记
    private var offlineCachedNote: some View {
        HStack(spacing: AppTheme.Space.paddingXS) {
            Image(systemName: isConnected ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: AppTheme.Size.usageLimitNoteIconGlyph, weight: .medium))
            Text(isConnected
                ? "Couldn't refresh. Showing last synced usage."
                : "You're offline. Showing last synced usage.")
                .font(AppTheme.Font.settingsFormIntro)
        }
        .foregroundStyle(AppTheme.Color.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Space.paddingXS)
    }

    /// 7. 冷启动离线空状态卡片：区分 05-A (真断网) 与 05-B (刷新失败)，均提供 Try again 按钮
    private var offlineEmptyCard: some View {
        VStack(spacing: AppTheme.Space.paddingM) {
            Image(systemName: isConnected ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: AppTheme.Size.usageLimitEmptyIconGlyph, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: AppTheme.Size.usageLimitEmptyIconFrame, height: AppTheme.Size.usageLimitEmptyIconFrame)

            VStack(spacing: AppTheme.Space.paddingXS) {
                Text(isConnected ? "Couldn't refresh" : "You're offline")
                    .font(AppTheme.Font.settingsDocumentTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(isConnected
                    ? "We couldn't check your remaining quota right now. Please try again."
                    : "Connect to the internet to check your remaining quota.")
                    .font(AppTheme.Font.settingsFormIntro)
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
                            .font(.system(size: AppTheme.Size.usageLimitNoteIconGlyph, weight: .semibold))
                    }
                    Text(isRetrying ? "Retrying..." : "Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.usageLimitRetryPillBg, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isRetrying)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity)
        .surfaceCard(
            cornerRadius: AppTheme.Radius.large,
            fillColor: AppTheme.Color.settingsCardSurface
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
            // 宿主背景模拟（Tab1 页面底色）
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

#Preview("01 · 在线未达标 (2/5 · 260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeight) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · 在线已达标 (5/5 · 365pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeightReached) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("03 · 离线有缓存未达标 (2/5 · 260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeight) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("04 · 离线有缓存且达标 (5/5 · 395pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeightReachedOffline) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-A · 冷启动真断网 (295pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeightLoadFailed) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-B · 冷启动刷新失败 (295pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeightLoadFailed) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: true)
    }
}

#Preview("06 · 初始零使用 (0/5 · 260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeight) {
        UsageLimitSheet(usedCount: 0, dailyLimit: 5)
    }
}

#Preview("07 · 加载过渡态 (260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: AppTheme.Size.usageLimitSheetHeight) {
        UsageLimitSheet(simulateLoading: true)
    }
}

/// 交互式调节滑块：可在 Xcode Canvas 中拖动观察正常态与达标态的平滑切换
private struct UsageLimitInteractivePreview: View {
    @State private var currentCount: Double = 5
    private let limit: Int = 5

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingPage) {
            SheetModalCanvasPreview(sheetHeight: currentCount >= Double(limit) ? AppTheme.Size.usageLimitSheetHeightReached : AppTheme.Size.usageLimitSheetHeight) {
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

#Preview("Usage Limit Sheet · 交互调节滑块", traits: .fixedLayout(width: 393, height: 700)) {
    UsageLimitInteractivePreview()
}

