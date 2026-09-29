#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 方案 C (采用方案 2-C 极细精工规范) 全要素全状态落地沙箱
// =====================================================================
// 🎯 核心原则与全要素设计系统蓝图 (基于方案 2-C)：
//   1. 独立沙箱：本文件为方案 C 独立沙箱，完全不污染原版复印件 (UsageLimitExplorationPreview.swift)；
//   2. 方案 2-C 极细精工核心升级：
//      - 【计数字体修身】：数字从 28pt 压降一档至 Charter 24pt Regular 细衬线 (settingsRowText #0A0705 焦黑)，
//        字形修长文雅，彻底告别所有视觉膨胀与黑块感；
//      - 【用量副文对齐】：保持 Gothic A1 15pt Light (/ 5 generations today)，与 24pt 细衬线形成黄金基线配合；
//      - 【极薄微线轨道】：全面优化为 2.0pt 极薄连续微线 (底轨 neutralFaint 30% 浅灰槽，日常填充暖中灰 #4B4640，
//        满额深焦黑 #0A0705 满格填充)，轻若铅笔标线，绝不抢戏；
//      - 【卡片质感升级】：全面接入 surfaceCard(20pt)，补齐 0.5pt cardBorder 细描边与贴地双层阴影；
//      - 【无多余字段】：彻底剔除任何多余的 X left 字段，保持业务字段最纯净的形态；
//      - 【顶栏规范】：句首大写 Daily limit · Charter 20pt Regular 细衬线 · 移除右上角关闭键，
//        仅保留顶部系统抓手，通过 iOS 原生向下滑动手势自然关闭；
//      - 【达标态去焦虑】：5/5 满额卸下刺眼警报红 (#DC2626)，采用温润克制的深焦黑满额客观陈述；
//        标题降重为 Charter 16.5pt Regular 细衬线，说明文案 14pt Light 左对齐舒展排版；
//      - 【CTA 按钮升级 (方案 1 细线描边胶囊)】：申请邀请码采用暖近白底 + 0.8pt 细描边 (cardBorder) + 焦黑文字，
//        44pt 优雅胶囊彻底卸下纯黑大杠铃，高度从 375pt 轻量化优化至 365pt；
//      - 【弱网提示条】：严格 16pt 左对齐出版物弱化提示条 (12pt 图标 + 13.5pt Light)；
//      - 【离线空状态】：卡片接入 surfaceCard(20pt)，标题采用 Charter 20pt 细衬线，配备规范的 Try again 重试胶囊；
//      - 【底部脚注】：严格 16pt 左对齐出版物注记风 (14.5pt Light · #7C7773)。

// =====================================================================
// MARK: - 方案 C 生产级复刻组件 (UsageLimitSheetProposalC)
// =====================================================================

struct UsageLimitSheetProposalC: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dailyLimit: Int
    @State private var usedCount: Int?
    @State private var showFeedback = false
    @State private var loadFailed = false
    @State private var isRetrying = false
    private let isPreviewInjected: Bool
    private let mockIsConnected: Bool?
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
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                // 1. 顶栏：无多余按键，纯净留白
                headerRow

                if usedCount == nil && loadFailed {
                    // 状态 5：冷启动离线空状态卡片
                    offlineEmptyCard
                } else {
                    // 状态 1 / 2 / 3 / 4 / 6 / 7 主卡片 (采用方案 2-C 规范)
                    usageCard

                    if isLimitReached {
                        // 达标说明文案 (去焦虑、舒展排版)
                        limitReachedText
                            .padding(.top, AppTheme.Space.paddingXS)

                        // 申请邀请码高定 CTA 按钮
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
    }

    // MARK: - Subviews & Elements (方案 2-C 全要素落地)

    /// 1. 顶栏：句首大写 Daily limit · Charter 20pt Regular 细衬线 · 移除右上角关闭键
    private var headerRow: some View {
        HStack {
            Text("Daily limit")
                .font(AppTheme.Font.settingsDocumentTitleSerif) // Charter 20pt Regular
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
        }
        .padding(.top, 4)
    }

    /// 2. 用量卡片 (方案 2-C)：Charter 24pt 细衬线数字 + 15pt Light 副文 + 2.0pt 极薄连续微线 + 0.5pt 边框贴地双层阴影
    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let usedCount {
                    // ★ 方案 2-C: 从 28pt 压小到 24pt Charter 细衬线，深焦黑 #0A0705，文雅轻巧
                    Text("\(usedCount)")
                        .font(.custom("Charter", size: 24, relativeTo: .title2))
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                } else if loadFailed {
                    Text("–")
                        .font(.custom("Charter", size: 24, relativeTo: .title2))
                        .foregroundStyle(AppTheme.Color.textMuted)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.Color.textSecondary)
                        .frame(width: 22, height: 22)
                        .offset(y: -10)
                }

                Text("/ \(dailyLimit) generations today")
                    .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Spacer()
            }

            // ★ 方案 2-C: 2.0pt 极薄连续微线轨 (绝不抢戏，未满用暖中灰，满额用深焦黑，告别危险红)
            GeometryReader { geo in
                let ratio = min(max(CGFloat(usedCount ?? 0) / CGFloat(dailyLimit), 0), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                        .frame(height: 2.0)
                    if usedCount != nil {
                        Capsule()
                            .fill(isLimitReached ? AppTheme.Color.settingsRowText : AppTheme.Color.textSecondary)
                            .frame(width: max(geo.size.width * ratio, 2.0), height: 2.0)
                    }
                }
            }
            .frame(height: 2.0)
            .padding(.top, 2)
        }
        .padding(AppTheme.Space.paddingCard)
        // 核心升级：0.5pt cardBorder 微描边 + 贴地双层紧阴影
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
    }

    /// 3. 达标说明段落 (方案 1 细衬线降重)：Charter 16.5pt Regular + Gothic A1 14pt Light
    private var limitReachedText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("You've reached today's limit.")
                .font(.custom("Charter", size: 16.5, relativeTo: .body))
                .foregroundStyle(AppTheme.Color.settingsRowText)

            Text("Want to keep generating? Send feedback to request an invite code for extra quota.")
                .font(.custom("GothicA1-Light", size: 14, relativeTo: .subheadline))
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
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 14, weight: .medium))
                Text("Send feedback for invite code")
                    .font(.custom("GothicA1-Medium", size: 14, relativeTo: .subheadline))
            }
            .foregroundStyle(AppTheme.Color.settingsRowText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppTheme.Color.cardBg, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
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

    /// 7. 冷启动离线空状态卡片：区分 05-A (真断网 · 无重试按钮) 与 05-B (刷新失败 · 带 Try again)
    private var offlineEmptyCard: some View {
        VStack(spacing: AppTheme.Space.paddingM) {
            Image(systemName: isConnected ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(width: 36, height: 36)

            VStack(spacing: AppTheme.Space.paddingXS) {
                Text(isConnected ? "Couldn't refresh" : "You're offline")
                    .font(AppTheme.Font.settingsDocumentTitleSerif) // Charter 20pt Regular 细衬线
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
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
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

// =====================================================================
// MARK: - 业务状态枚举定义 (完整 7 种状态)
// =====================================================================

enum ProposalCVisualState: String, CaseIterable, Identifiable {
    case normalOnline         = "01 · 正常在线 (2/5 · 260pt)"
    case limitReached         = "02 · 在线达标 (5/5 · 365pt)"
    case offlineCacheNormal   = "03 · 离线未达标 (2/5 · 260pt)"
    case offlineCacheReached  = "04 · 离线且达标 (5/5 · 395pt)"
    case offlineEmptyNoNet    = "05-A · 冷启动真断网 (无网无缓存 · 295pt)"
    case offlineEmptyApiFail  = "05-B · 冷启动刷新失败 (有网接口超时 · 295pt)"
    case zeroInitial          = "06 · 初始零使用 (0/5 · 260pt)"
    case loadingState         = "07 · 加载过渡态 (拉取中 · 260pt)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .normalOnline:        return "2/5 在线"
        case .limitReached:        return "5/5 达标"
        case .offlineCacheNormal:  return "2/5 离线"
        case .offlineCacheReached: return "5/5 离线"
        case .offlineEmptyNoNet:   return "05-A 真断网"
        case .offlineEmptyApiFail: return "05-B 接口失败"
        case .zeroInitial:         return "0/5 初始"
        case .loadingState:        return "加载中"
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .normalOnline, .zeroInitial, .offlineCacheNormal, .loadingState:
            return 260
        case .limitReached:
            return 365
        case .offlineCacheReached:
            return 395
        case .offlineEmptyNoNet, .offlineEmptyApiFail:
            return 295
        }
    }

    var usedCount: Int? {
        switch self {
        case .normalOnline, .offlineCacheNormal:
            return 2
        case .limitReached, .offlineCacheReached:
            return 5
        case .zeroInitial:
            return 0
        case .offlineEmptyNoNet, .offlineEmptyApiFail, .loadingState:
            return nil
        }
    }

    var isFailed: Bool {
        switch self {
        case .offlineCacheNormal, .offlineCacheReached, .offlineEmptyNoNet, .offlineEmptyApiFail:
            return true
        default:
            return false
        }
    }

    var mockIsConnected: Bool? {
        switch self {
        case .normalOnline, .limitReached, .zeroInitial, .loadingState, .offlineEmptyApiFail:
            return true
        case .offlineCacheNormal, .offlineCacheReached, .offlineEmptyNoNet:
            return false
        }
    }
}

// =====================================================================
// MARK: - 1:1 像素级系统 Sheet 仿真画板 (ProposalCCanvasFrame)
// =====================================================================

struct ProposalCCanvasFrame<SheetContent: View>: View {
    let sheetHeight: CGFloat
    @ViewBuilder let sheetContent: () -> SheetContent

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 底层宿主界面模拟 (Tab1 暖纸底色)
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 模拟 Tab1 顶部栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageGaugeIcon()
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .surfacePill(in: Circle())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                // 宿主背景模拟卡片
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.6))
                        .frame(height: 180)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.4))
                        .frame(height: 120)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.bottom, 60)

                Spacer()
            }

            // 2. 真实系统 Sheet 暗色遮罩 (Scrim)
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            // 3. 底部 Sheet 仿真容器 (严格对齐 iOS 17 系统级圆角与物理阴影)
            ZStack(alignment: .top) {
                sheetContent()

                // 系统原生顶部拖拽把手指示条 (Drag Indicator)
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
        .frame(width: 393, height: 852)
        .clipped()
    }
}

// =====================================================================
// MARK: - 方案 C 全状态交互实验室 (UsageLimitProposalCInteractiveLab)
// =====================================================================

struct UsageLimitProposalCInteractiveLab: View {
    @State private var selectedState: ProposalCVisualState = .normalOnline
    @State private var dynamicCount: Double = 2
    @State private var isOffline: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    private var computedHeight: CGFloat {
        if selectedState == .offlineEmptyNoNet || selectedState == .offlineEmptyApiFail {
            return 295
        }
        let count = Int(dynamicCount)
        if count >= 5 {
            return isOffline ? 395 : 365
        } else {
            return 260
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部控制台 ──
            VStack(spacing: 8) {
                // 1. 状态快捷选择胶囊
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ProposalCVisualState.allCases) { state in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    applyState(state)
                                }
                            } label: {
                                Text(state.shortTag)
                                    .font(.system(size: 11.5, weight: selectedState == state ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedState == state ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                    .foregroundStyle(selectedState == state ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedState == state ? AppTheme.Color.brandTint : AppTheme.Color.border,
                                            lineWidth: 0.8
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // 2. 动效滑块与离线切换
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("生成次数: \(Int(dynamicCount)) / 5")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Spacer()
                            Text(Int(dynamicCount) >= 5 ? "达标展开态 (365pt)" : "未满额度 (260pt)")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        }

                        Slider(value: $dynamicCount, in: 0...5, step: 1)
                            .tint(AppTheme.Color.settingsRowText)
                    }

                    Divider().frame(height: 28)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isOffline.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isOffline ? "wifi.slash" : "wifi")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isOffline ? "离线" : "在线")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(isOffline ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                        .foregroundStyle(isOffline ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 3. 方案 C (方案 2-C + 方案 1 规范) 特征简述
                HStack(spacing: 6) {
                    Text("方案 C (方案 2-C + 方案 1):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("无关闭键 · 仅抓手(下滑关闭) · 24细衬线/2.0pt微线 · 细线描边胶囊(365pt) · 焦黑满额")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
            .padding(.vertical, 8)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) { Divider() }

            // ── 393×852 真机仿真视口 ──
            ProposalCCanvasFrame(sheetHeight: computedHeight) {
                if selectedState == .offlineEmptyNoNet {
                    UsageLimitSheetProposalC(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
                } else if selectedState == .offlineEmptyApiFail {
                    UsageLimitSheetProposalC(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: true)
                } else if selectedState == .loadingState {
                    UsageLimitSheetProposalC(simulateLoading: true)
                } else {
                    UsageLimitSheetProposalC(
                        usedCount: Int(dynamicCount),
                        dailyLimit: 5,
                        initialLoadFailed: isOffline,
                        mockIsConnected: selectedState.mockIsConnected ?? !isOffline
                    )
                }
            }
            .scaleEffect(0.92, anchor: .top)
            .frame(maxHeight: .infinity)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func applyState(_ state: ProposalCVisualState) {
        selectedState = state
        if let count = state.usedCount {
            dynamicCount = Double(count)
        }
        isOffline = state.isFailed
    }
}

// =====================================================================
// MARK: - 真实原生手势体验器 (UsageLimitProposalCSwipeDismissLauncher)
// =====================================================================

struct UsageLimitProposalCSwipeDismissLauncher: View {
    @State private var showSheet = false
    @State private var testCount: Int = 2
    @State private var isOffline: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingSection) {
                // 模拟 Tab1 顶栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageLimitButton {
                        showSheet = true
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: AppTheme.Space.paddingM) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 42))
                        .foregroundStyle(AppTheme.Color.brandStrong)

                    Text("方案 C (方案 2-C 规范)：原生半屏 Sheet\n向下滑动把手即可自然关闭")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Stepper("测试生成次数: \(testCount) / 5", value: $testCount, in: 0...5)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Toggle("模拟弱网离线态", isOn: $isOffline)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Button {
                        showSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("唤起方案 C 弹窗")
                                .font(AppTheme.Font.ctaLabel)
                        }
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.Color.interactive, in: Capsule())
                        .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSheet) {
            UsageLimitSheetProposalC(
                usedCount: testCount,
                dailyLimit: 5,
                initialLoadFailed: isOffline
            )
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵 (方案 C 方案 2-C 全状态落地)
// =====================================================================

#Preview("00 · ★ 方案 C 全状态交互实验室 (方案 2-C 规范)") {
    UsageLimitProposalCInteractiveLab()
}

#Preview("01 · 方案 C · 状态 1: 正常在线 (2/5 · 24pt细衬线 · 2.0pt微线)") {
    ProposalCCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProposalC(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · 方案 C · 状态 2: 额度已达标 (5/5 · 焦黑满额 · 细线描边胶囊 · 365pt)") {
    ProposalCCanvasFrame(sheetHeight: 365) {
        UsageLimitSheetProposalC(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("03 · 方案 C · 状态 3: 离线未达标带缓存 (2/5 · 260pt · 弱网提示)") {
    ProposalCCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProposalC(usedCount: 2, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("04 · 方案 C · 状态 4: 离线且达标带缓存 (5/5 · 细线描边胶囊 · 395pt)") {
    ProposalCCanvasFrame(sheetHeight: 395) {
        UsageLimitSheetProposalC(usedCount: 5, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-A · 方案 C · 状态 05-A: 冷启动真断网 (无网无缓存 · 295pt · 带Try again)") {
    ProposalCCanvasFrame(sheetHeight: 295) {
        UsageLimitSheetProposalC(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: false)
    }
}

#Preview("05-B · 方案 C · 状态 05-B: 冷启动刷新失败 (有网接口超时 · 295pt · 带Try again)") {
    ProposalCCanvasFrame(sheetHeight: 295) {
        UsageLimitSheetProposalC(usedCount: nil, dailyLimit: 5, initialLoadFailed: true, mockIsConnected: true)
    }
}

#Preview("06 · 方案 C · 状态 6: 0次初始未用态 (0/5 · 260pt · 空轨道)") {
    ProposalCCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProposalC(usedCount: 0, dailyLimit: 5)
    }
}

#Preview("07 · 方案 C · 状态 7: 首次加载拉取中 (菊花微动效 · 260pt)") {
    ProposalCCanvasFrame(sheetHeight: 260) {
        UsageLimitSheetProposalC(simulateLoading: true)
    }
}

#Preview("08 · 方案 C 真实原生手势体验 (向下滑动手势关闭)") {
    UsageLimitProposalCSwipeDismissLauncher()
}

#endif
