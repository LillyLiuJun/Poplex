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
    private let isPreviewInjected: Bool
    /// 反馈提交成功后由宿主展示 toast（FeedbackView 不再自行发全局 toast，审计发现 ④）。
    private let onFeedbackSubmitted: (() -> Void)?

    init(usedCount: Int? = nil, dailyLimit: Int = 5, onFeedbackSubmitted: (() -> Void)? = nil) {
        self.onFeedbackSubmitted = onFeedbackSubmitted
        if let count = usedCount {
            self._dailyLimit = State(initialValue: dailyLimit)
            self._usedCount = State(initialValue: count)
            self.isPreviewInjected = true
        } else {
            // 先用缓存里的服务器数字渲染（429 达标后 store 已有数字），
            // 首帧即达标态、无加载态闪烁；.task 里的 refresh 随后仍以
            // 服务端为准覆盖——数字通常不变，也就没有跳变。
            // 冷启动从未取到过数字（usedCount == nil）时仍走加载态。
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

    var body: some View {
        // 标准字号下内容装不满 detent 高度 → ScrollView 不滚动，与旧版静态布局视觉一致；
        // 大字号（AX）下内容超高时，从「裁切看不到」变为「可滚动看到」。
        // basedOnSize 让内容不满时不出现橡皮筋拖拽，行为与静态布局相同。
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                headerRow

                usageCard

                if isLimitReached {
                    limitReachedText
                        .padding(.top, AppTheme.Space.paddingXS)

                    feedbackCTAButton
                } else if loadFailed && usedCount == nil {
                    refreshFailedNote
                        .padding(.top, AppTheme.Space.paddingS)
                } else {
                    normalFooterNote
                        .padding(.top, AppTheme.Space.paddingS)
                }
            }
            .padding(AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingM)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Color.pageBg)
        .presentationDetents([isLimitReached ? .height(375) : .height(260)])
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
            guard !isPreviewInjected else { return }
            // 服务端正本：check_generation_quota RPC（经 UsageQuotaStore）。
            // 旧实现数 LocalCache 里今天的 user 消息——快照滞后（冷启动缓存可能是
            // 昨天的），且统计口径错误：数的是用户消息而非成功生成，被拦截/失败的
            // 发送也会被算进去。
            let store = UsageQuotaStore.shared
            await store.refresh()
            if let used = store.usedCount { usedCount = used }
            dailyLimit = store.dailyLimit ?? 5
            loadFailed = store.refreshFailed
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
                        .font(SwiftUI.Font.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(isLimitReached ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
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
                    Capsule()
                        .fill(isLimitReached ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
                        .frame(width: max(geo.size.width * ratio, 6), height: 6)
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

    /// 首次加载即失败（如断网）时的真实反馈：比显示 0/5 更诚实。
    private var refreshFailedNote: some View {
        Text("Couldn't refresh right now. Check your connection and try again.")
            .font(AppTheme.Font.statusNote)
            .foregroundStyle(AppTheme.Color.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Space.paddingM)
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
            VStack(spacing: 0) {
                // 顶部系统拖拽把手指示条
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                content()
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

#Preview("Usage Limit Sheet · Limit Reached (5/5) · Modal View", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 375) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("Usage Limit Sheet · Normal (2/5) · Modal View", traits: .fixedLayout(width: 393, height: 852)) {
    SheetModalCanvasPreview(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
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
