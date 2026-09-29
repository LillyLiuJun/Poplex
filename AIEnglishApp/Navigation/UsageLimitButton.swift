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

    private var isLimitReached: Bool {
        guard let usedCount else { return false }
        return usedCount >= dailyLimit
    }

    private var sheetHeight: CGFloat {
        if usedCount == nil && loadFailed {
            // 状态 05-A 与 05-B 统一包含 Try again 按钮，高度统一为 295pt
            return 295
        }
        if isLimitReached {
            // 状态 2 & 4：额度已达标 (采用方案 1 细线描边胶囊，高度轻量化为 365pt / 离线 395pt)
            return loadFailed ? 395 : 365
        }
        return 260
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
                // 1. 顶栏：无多余按键，纯净留白
                headerRow

                if usedCount == nil && loadFailed {
                    // 状态 5：冷启动离线空状态卡片（区分 05-A 与 05-B）
                    offlineEmptyCard
                } else {
                    // 状态 1 / 2 / 3 / 4 / 6 / 7 主卡片 (方案 2-C 极细精工规范)
                    usageCard

                    if isLimitReached {
                        // 达标说明文案 (去焦虑、舒展排版)
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        // 申请邀请码高定 CTA 按钮 (方案 1 细线描边胶囊)
                        feedbackCTAButton

                        if loadFailed {
                            offlineCachedNote
                                .padding(.top, AppTheme.Space.paddingXS)
                        }
                    } else if loadFailed {
                        offlineCachedNote
                            .padding(.top, AppTheme.Space.paddingS)
                    } else {
                        // 正常零点刷新注记 (左对齐出版物风)
                        normalFooterNote
                            .padding(.top, 2)
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

    // MARK: - Subviews & Elements (方案 2-C 与方案 1 全要素落地)

    /// 1. 顶栏：句首大写 Daily limit · Charter 20pt Regular 细衬线 · 移除右上角关闭键
    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.settingsDocumentTitleSerif)
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
                    ZStack {
                        Text("0")
                            .font(AppTheme.Font.quotaHeroNumber)
                            .hidden()
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.Color.textSecondary)
                    }
                }

                Text("/ \(dailyLimit) generations today")
                    .font(AppTheme.Font.quotaSubtext)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()
            }

            // 方案 2-C: 2.0pt 极薄连续微线轨 (绝不抢戏，未满用暖中灰，满额用深焦黑，告别危险红)
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.3))
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
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
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

    /// 4. 申请邀请码 CTA 按钮 (方案 1 细线描边胶囊)：44pt · 暖白底 + 0.8pt 细描边 + 焦黑文字，彻底卸除黑块下沉感
    private var feedbackCTAButton: some View {
        Button {
            showFeedback = true
        } label: {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 14, weight: .medium))
                Text("Send feedback for invite code")
                    .font(AppTheme.Font.quotaFeedbackAction)
            }
            .foregroundStyle(AppTheme.Color.settingsRowText)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.usageLimitCTAHeight)
            .background(AppTheme.Color.cardBg, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.cardBorder, lineWidth: AppTheme.Size.usageLimitCTABorderWidth)
            }
            .shadow(
                color: AppTheme.Shadow.pillContactColor,
                radius: AppTheme.Shadow.pillContactRadius,
                x: AppTheme.Shadow.pillContactX,
                y: AppTheme.Shadow.pillContactY
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
                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 36, height: 36)

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
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isRetrying ? "Retrying..." : "Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.neutralFaint.opacity(0.4), in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isRetrying)
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
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
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · 在线已达标 (5/5 · 365pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 365) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("03 · 离线有缓存未达标 (2/5 · 260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("04 · 离线有缓存且达标 (5/5 · 395pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 395) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-A · 冷启动真断网 (295pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 295) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-B · 冷启动刷新失败 (295pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 295) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: true)
    }
}

#Preview("06 · 初始零使用 (0/5 · 260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 0, dailyLimit: 5)
    }
}

#Preview("07 · 加载过渡态 (260pt)", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(simulateLoading: true)
    }
}

/// 交互式调节滑块：可在 Xcode Canvas 中拖动观察正常态与达标态的平滑切换
private struct UsageLimitInteractivePreview: View {
    @State private var currentCount: Double = 5
    private let limit: Int = 5

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingPage) {
            SheetModalCanvasPreview(sheetHeight: currentCount >= Double(limit) ? 365 : 260) {
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

