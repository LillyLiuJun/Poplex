#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 全生命周期与全状态 DesignLab 沙盒 (Tab2 Lifecycle Sandbox)
// 🎯 核心原则：
//   1. 100% 消费线上生产组件与 AppTheme 语义 Token，坚决消灭任何手写色值与临时假样式；
//   2. 覆盖用户生命周期全部阶段与极端状态：
//      - State 1: 初始空态 (Initial / 0 素材 / 干净纯净负空间 / EmptyStateView)
//      - State 2: 待解锁态 (Locked / 进度积累 / 领跑分类 / 手风琴折叠与展开词条流水)
//      - State 3: 解锁跃迁 (Unlocking / 20满格 / 蓄力与晨曦柔光升腾 / 首次解锁能力宣言)
//      - State 4: 已解锁态 (Unlocked / Talk about today / 晨曦预设图 / 实拍封面 / 久未记录 / 仅单词)
//      - State 5: 异常态与骨架屏 (Skeleton 呼吸加载 / 全屏加载重试 / 手风琴弱网离线)
//   3. 完备的走查与交互控制台：支持任意切换主状态、子场景、模拟外壳顶栏避让。

struct Tab2LifecycleSandboxPreviewView: View {
    // 主生命周期状态
    @State private var selectedStage: LifecycleStage = .initialEmpty
    
    // 子场景细分控制
    @State private var lockedSubMode: LockedSubMode = .collapsed
    @State private var unlockedScenario: UnlockedScenario = .presetArt
    @State private var unlockingMode: UnlockingMode = .ready
    @State private var edgeErrorMode: EdgeErrorMode = .skeletonLoading
    
    // 全局外壳控制
    @State private var showTopBarShell: Bool = true
    @State private var selectedTab: AppTab = .mine
    @State private var toastMessage: String?
    
    // 手风琴展开分类 ID
    @State private var expandedCategoryId: String? = nil
    
    // 跃迁动效状态
    @State private var isAscentActive: Bool = false
    @State private var unlockButtonState: UnlockButtonState = .idle
    
    enum UnlockButtonState {
        case idle
        case charging
        case releasing
    }

    enum LifecycleStage: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case initialEmpty = "① 初始空态"
        case locked       = "② 待解锁态"
        case unlocking    = "③ 解锁跃迁"
        case unlocked     = "④ 已解锁态"
        case edgeErrors   = "⑤ 异常/骨架"
    }

    enum LockedSubMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case collapsed = "收起态 (预览词)"
        case expanded  = "展开手风琴 (全部词条)"
    }

    enum UnlockingMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case ready           = "满格待解锁 (You're all set)"
        case firstTimeBanner = "首次解锁宣言态"
    }

    enum UnlockedScenario: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case presetArt  = "晨曦暖光预设图"
        case photoCover = "实拍照片封面"
        case quietState = "久未记录沉静态"
        case onlyWords  = "无活动仅词空态"
    }

    enum EdgeErrorMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case skeletonLoading  = "首载骨架屏 (Skeleton)"
        case fullLoadError    = "全屏加载错误 (Load Error)"
        case accordionOffline = "手风琴网络断开 (Offline)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端走查控制台
            topControlPanel

            Divider().opacity(0.15)

            // 主画布视口 (全真模拟生产 iPhone 视口)
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mainLifecycleContent
                    }
                    .padding(.top, showTopBarShell ? 64 : AppTheme.Space.paddingPage)
                    .padding(.bottom, needsBottomDock ? 110 : AppTheme.Space.tab2FooterBottom)
                    .background(alignment: .bottom) {
                        if selectedStage == .unlocked {
                            BottomAuraFooter()
                        }
                    }
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .background(AppTheme.Color.pageBg.ignoresSafeArea())

                // 全真浮动顶栏
                if showTopBarShell {
                    floatingTopBar
                }

                // 常驻沉底操作栏 (在初始、待解锁、跃迁阶段展示)
                if needsBottomDock {
                    bottomDockContainer
                }

                // 晨曦升腾柔光动画层
                if isAscentActive {
                    sandboxAscentOverlay
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
                    toastOverlay(text: toast)
                }
            }
        }
    }

    private var needsBottomDock: Bool {
        selectedStage == .initialEmpty || selectedStage == .locked || selectedStage == .unlocking
    }

    // MARK: - 顶端交互走查控制台

    private var topControlPanel: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("DesignLab")
                        .font(AppTheme.Font.sectionLabel)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.brandTint)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .clipShape(Capsule())

                    Text("Tab2 全生命周期与全状态沙盒")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Toggle("模拟外壳顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            // 主阶段切换器
            Picker("阶段", selection: $selectedStage) {
                ForEach(LifecycleStage.allCases) { stage in
                    Text(stage.rawValue).tag(stage)
                }
            }
            .pickerStyle(.segmented)

            // 次级场景调节排
            subControlsBar
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    @ViewBuilder
    private var subControlsBar: some View {
        switch selectedStage {
        case .initialEmpty:
            HStack {
                Text("状态特性：0 素材纯净负空间 · 0 词分类不露噪 · 吸底引导 Capture 按钮")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Spacer()
            }

        case .locked:
            HStack {
                Picker("手风琴状态", selection: $lockedSubMode) {
                    ForEach(LockedSubMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

        case .unlocking:
            HStack {
                Picker("跃迁模式", selection: $unlockingMode) {
                    ForEach(UnlockingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    triggerAscentAnimation()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("触发跃迁升腾动效")
                    }
                    .font(AppTheme.Font.compactActionLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Color.brandTint)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .clipShape(Capsule())
                }
            }

        case .unlocked:
            HStack {
                Picker("Hero 业务场景", selection: $unlockedScenario) {
                    ForEach(UnlockedScenario.allCases) { sc in
                        Text(sc.rawValue).tag(sc)
                    }
                }
                .pickerStyle(.segmented)
            }

        case .edgeErrors:
            HStack {
                Picker("异常场景", selection: $edgeErrorMode) {
                    ForEach(EdgeErrorMode.allCases) { err in
                        Text(err.rawValue).tag(err)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - 主视口核心状态渲染

    @ViewBuilder
    private var mainLifecycleContent: some View {
        switch selectedStage {
        case .initialEmpty:
            initialEmptyView

        case .locked:
            lockedStateView

        case .unlocking:
            unlockingStateView

        case .unlocked:
            unlockedStateView

        case .edgeErrors:
            edgeErrorsStateView
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 1. 初始空态 (State 1)
    // ─────────────────────────────────────────────────────────────
    private var initialEmptyView: some View {
        EmptyStateView()
            .frame(minHeight: 520)
    }

    // ─────────────────────────────────────────────────────────────
    // 2. 待解锁态 (State 2)
    // ─────────────────────────────────────────────────────────────
    private var lockedStateView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
            // Header
            VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
                Text("Not open yet")
                    .font(AppTheme.Font.pageTitleSerif)
                    .tracking(AppTheme.Typography.trackingDisplay)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("Reach 20 words in any topic to start talking.")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // Topics in progress 卡片
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Topics in progress")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                let mockCategories = MockDataFactory.lockedCategories
                let activeExpandedId = (lockedSubMode == .expanded ? mockCategories.first?.id : expandedCategoryId)

                VStack(spacing: 0) {
                    ForEach(mockCategories) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isExpanded: activeExpandedId == cat.id,
                            onToggle: {
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    if lockedSubMode == .expanded {
                                        lockedSubMode = .collapsed
                                        expandedCategoryId = nil
                                    } else {
                                        expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                    }
                                }
                            },
                            loadWords: {
                                try await MockDataFactory.loadMockWords(for: cat.sceneCategory)
                            },
                            wordsRevision: 1,
                            milestonePresentations: []
                        )
                        .id(cat.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }
        }
        .padding(.top, AppTheme.Space.paddingSection)
    }

    // ─────────────────────────────────────────────────────────────
    // 3. 解锁跃迁态 (State 3)
    // ─────────────────────────────────────────────────────────────
    private var unlockingStateView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
            VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
                Text(unlockingMode == .firstTimeBanner ? "Talk about today" : "Not open yet")
                    .font(AppTheme.Font.pageTitleSerif)
                    .tracking(AppTheme.Typography.trackingDisplay)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(unlockingMode == .firstTimeBanner ? "You've got enough here to talk about it now." : "One of your topics has reached 20 words!")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(AppTheme.Typography.lineBody)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 跃迁领跑满格卡片
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Topics in progress")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                let readyCategory = MockDataFactory.readyCategory

                VStack(spacing: 0) {
                    CategoryProgressRow(
                        category: readyCategory,
                        isExpanded: false,
                        onToggle: {},
                        loadWords: { [] },
                        wordsRevision: 1,
                        milestonePresentations: []
                    )
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .strokeBorder(AppTheme.Color.brandStrong.opacity(0.35), lineWidth: 1)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 提示指引
            VStack(alignment: .center, spacing: 8) {
                Text("✨ 达标跃迁交互状态")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.brandStrong)

                Text("底栏已切换为 You're all set。点击上方「触发跃迁升腾动效」或直接点击底栏按钮，走查 360ms 蓄力凝聚 ➔ 晨曦微光升腾 ➔ 揭开已解锁新世界。")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Space.paddingPage)
            .background(AppTheme.Color.brandTint.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
        .padding(.top, AppTheme.Space.paddingSection)
    }

    // ─────────────────────────────────────────────────────────────
    // 4. 已解锁态 (State 4)
    // ─────────────────────────────────────────────────────────────
    private var unlockedStateView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) {
            // 1. 页面大标题：Talk about today
            Text("Talk about today")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingPage)

            // 2. Hero 卡片 (响应 4 种业务子场景)
            let heroData = MockDataFactory.heroForScenario(unlockedScenario)
            Tab2HeroCard(
                category: heroData,
                onTalk: {
                    triggerAction("Start conversation: \(heroData.englishLabel)")
                }
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 3. More to talk about 推荐列表行 (刀 6a 24pt 页面级衬线标题)
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("More to talk about")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                    ForEach(MockDataFactory.moreCategories) { cat in
                        Tab2ActivityRow(
                            category: cat,
                            onTap: {
                                triggerAction("Selected topic: \(cat.englishLabel)")
                            }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 4. Topics in progress 蓄水池
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Topics in progress")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(spacing: 0) {
                    ForEach(MockDataFactory.unlockedRemainingCategories) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isExpanded: expandedCategoryId == cat.id,
                            onToggle: {
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    expandedCategoryId = (expandedCategoryId == cat.id ? nil : cat.id)
                                }
                            },
                            loadWords: {
                                try await MockDataFactory.loadMockWords(for: cat.sceneCategory)
                            },
                            wordsRevision: 1,
                            milestonePresentations: []
                        )
                        .id(cat.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingS)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 5. 底部收尾宣言
            footerSignoff
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 5. 异常态与骨架屏 (State 5)
    // ─────────────────────────────────────────────────────────────
    @ViewBuilder
    private var edgeErrorsStateView: some View {
        switch edgeErrorMode {
        case .skeletonLoading:
            VStack(spacing: AppTheme.Space.paddingCard) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCardRow()
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingPage)

        case .fullLoadError:
            Tab2LoadErrorView(
                topInset: 20,
                isRetrying: false
            ) {
                triggerAction("Retrying initial load...")
            }
            .frame(minHeight: 520)

        case .accordionOffline:
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                Text("Not open yet")
                    .font(AppTheme.Font.pageTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    VStack(spacing: 0) {
                        // 展开呈现网络错误插画视图
                        VStack(spacing: 0) {
                            HStack {
                                Text("Work & study")
                                    .font(AppTheme.Font.tab2TopicLabel)
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                Spacer()
                                Text("14 of 20")
                                    .font(AppTheme.Font.pos)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                            }
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.vertical, AppTheme.Space.paddingM)

                            Divider().opacity(0.15)

                            Tab2AccordionNetworkErrorView(
                                message: "Check your connection and try again."
                            ) {
                                triggerAction("Retried accordion loader")
                            }
                            .padding(.vertical, AppTheme.Space.paddingPage)
                        }
                    }
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
            }
            .padding(.top, AppTheme.Space.paddingSection)
        }
    }

    // MARK: - 底部常驻栏 (Bottom Dock)

    private var bottomDockContainer: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Button {
                    handleBottomDockTap()
                } label: {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        if selectedStage == .unlocking {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                                .scaleEffect(unlockButtonState == .charging ? 0.9 : 1.0)
                        } else if selectedStage == .initialEmpty {
                            Image(systemName: "camera")
                                .font(.system(size: AppTheme.Size.emptyStateCaptureIconGlyph, weight: .regular))
                        }
                        Text(selectedStage == .unlocking ? "You're all set" : "Capture something")
                            .font(AppTheme.Font.ctaLabel)
                    }
                    .foregroundStyle(AppTheme.Color.cardBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .frame(minHeight: AppTheme.Size.inputBarMinHeight)
                    .background(selectedStage == .unlocking ? AppTheme.Color.brandStrong : AppTheme.Color.interactive)
                    .clipShape(Capsule())
                    .scaleEffect(unlockButtonState == .charging ? 0.95 : (unlockButtonState == .releasing ? 0.98 : 1.0))
                    .opacity(unlockButtonState == .releasing ? 0.0 : 1.0)
                    .shadow(
                        color: (selectedStage == .unlocking ? AppTheme.Color.brandStrong : AppTheme.Color.interactive).opacity(0.25),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.bottomBarActionBottom)
            }
            .padding(.top, AppTheme.Space.paddingS)
            .background {
                VariableBlurBackdrop(extraExtend: 16)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }

    private func handleBottomDockTap() {
        if selectedStage == .unlocking {
            triggerAscentAnimation()
        } else {
            triggerAction("Switched to Tab1: Takes you to Today")
        }
    }

    private func triggerAscentAnimation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(AppTheme.Motion.unlockCharging) {
            unlockButtonState = .charging
        }

        Task {
            try? await Task.sleep(nanoseconds: 360_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isAscentActive = true
            withAnimation(AppTheme.Motion.unlockDissolve) {
                unlockButtonState = .releasing
            }

            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(AppTheme.Motion.unlockReveal) {
                selectedStage = .unlocked
                unlockButtonState = .idle
                isAscentActive = false
            }
        }
    }

    // MARK: - 升腾微光层

    private var sandboxAscentOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: AppTheme.Color.brandTint.opacity(0.20), location: 0.35),
                .init(color: AppTheme.Color.brandStrong.opacity(0.18), location: 0.70),
                .init(color: AppTheme.Color.brandTint.opacity(0.08), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 48)
        .ignoresSafeArea()
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: - 浮动顶栏 (100% 对齐 RootTabContainer)

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton {
                    triggerAction("Tapped Settings")
                }
                .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)

                Spacer()

                UsageLimitButton {
                    triggerAction("Tapped Quota")
                }
                .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
    }

    // MARK: - 底部收尾宣言

    private var footerSignoff: some View {
        VStack(spacing: 6) {
            PoplexWordmark(
                capHeight: 12.5,
                style: .mono(AppTheme.Color.textMuted),
                showsPeriod: true
            )

            Text("English from your everyday life.")
                .font(AppTheme.Font.libraryFooterTagline)
                .tracking(0.5)
                .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.tab2FooterTop)
    }

    // MARK: - Toast 提示

    private func triggerAction(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message {
                withAnimation { toastMessage = nil }
            }
        }
    }

    private func toastOverlay(text: String) -> some View {
        Text(text)
            .font(AppTheme.Font.statusNote)
            .foregroundStyle(AppTheme.Color.cardBg)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background(AppTheme.Color.interactive.opacity(0.92))
            .clipShape(Capsule())
            .padding(.bottom, 96)
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Mock Data Factory (生产同源数据结构工厂)

private enum MockDataFactory {
    static var lockedCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "work_study",
                wordCount: 14,
                unlocked: false,
                notSpokenCount: 9,
                lastMaterialAt: Date(),
                newMaterialCount: 3,
                activityCount: 4,
                activities: [
                    Tab2Activity(sceneDetail: "Setting up conference room", occurrenceCount: 5),
                    Tab2Activity(sceneDetail: "Running late for sync", occurrenceCount: 3)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "food_drink",
                wordCount: 6,
                unlocked: false,
                notSpokenCount: 4,
                lastMaterialAt: Date().addingTimeInterval(-86400),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Making dinner with family", occurrenceCount: 2)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "daily_routines",
                wordCount: 3,
                unlocked: false,
                notSpokenCount: 2,
                lastMaterialAt: Date().addingTimeInterval(-172800),
                newMaterialCount: 0,
                activityCount: 1,
                activities: [
                    Tab2Activity(sceneDetail: "Morning coffee", occurrenceCount: 1)
                ]
            )
        ]
    }

    static var readyCategory: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "work_study",
            wordCount: 20,
            unlocked: true,
            notSpokenCount: 12,
            lastMaterialAt: Date(),
            newMaterialCount: 4,
            activityCount: 5,
            activities: [
                Tab2Activity(sceneDetail: "Project sprint planning", occurrenceCount: 6),
                Tab2Activity(sceneDetail: "Client review meeting", occurrenceCount: 4)
            ]
        )
    }

    static func heroForScenario(_ sc: Tab2LifecycleSandboxPreviewView.UnlockedScenario) -> Tab2CategoryData {
        switch sc {
        case .presetArt:
            return Tab2CategoryData(
                sceneCategory: "daily_routines",
                wordCount: 47,
                unlocked: true,
                notSpokenCount: 20,
                lastTalkedAt: Date(),
                lastMaterialAt: Date(),
                newMaterialCount: 3,
                activityCount: 4,
                activities: [
                    Tab2Activity(sceneDetail: "Morning coffee & commute", occurrenceCount: 6),
                    Tab2Activity(sceneDetail: "Taking line 2 subway", occurrenceCount: 4)
                ]
            )

        case .photoCover:
            return Tab2CategoryData(
                sceneCategory: "work_study",
                wordCount: 52,
                unlocked: true,
                notSpokenCount: 16,
                lastTalkedAt: Date(),
                lastMaterialAt: Date(),
                newMaterialCount: 2,
                activityCount: 3,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Sprint planning and coffee",
                        occurrenceCount: 5,
                        cover: Tab2Activity.Cover(
                            materialId: "m1",
                            imageUrl: "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&w=750&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Late for the 9am sync", occurrenceCount: 3)
                ]
            )

        case .quietState:
            return Tab2CategoryData(
                sceneCategory: "food_drink",
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 15,
                lastTalkedAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                lastMaterialAt: Date().addingTimeInterval(-86400 * 5),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Making homemade ramen", occurrenceCount: 4)
                ]
            )

        case .onlyWords:
            return Tab2CategoryData(
                sceneCategory: "social_life",
                wordCount: 24,
                unlocked: true,
                notSpokenCount: 14,
                lastTalkedAt: nil,
                lastMaterialAt: Date().addingTimeInterval(-86400 * 2),
                newMaterialCount: 0,
                activityCount: 0,
                activities: []
            )
        }
    }

    static var moreCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "food_drink",
                wordCount: 32,
                unlocked: true,
                notSpokenCount: 12,
                lastTalkedAt: Date().addingTimeInterval(-86400),
                lastMaterialAt: Date().addingTimeInterval(-86400),
                newMaterialCount: 0,
                activityCount: 3,
                activities: [
                    Tab2Activity(sceneDetail: "Making dinner with family", occurrenceCount: 4)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "work_study",
                wordCount: 28,
                unlocked: true,
                notSpokenCount: 8,
                lastTalkedAt: Date().addingTimeInterval(-86400 * 2),
                lastMaterialAt: Date().addingTimeInterval(-86400 * 2),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Project retrospective", occurrenceCount: 3)
                ]
            )
        ]
    }

    static var unlockedRemainingCategories: [Tab2CategoryData] {
        [
            Tab2CategoryData(
                sceneCategory: "home_family",
                wordCount: 11,
                unlocked: false,
                notSpokenCount: 5,
                lastMaterialAt: Date().addingTimeInterval(-86400 * 3),
                newMaterialCount: 0,
                activityCount: 2,
                activities: [
                    Tab2Activity(sceneDetail: "Weekend grocery shopping", occurrenceCount: 2)
                ]
            )
        ]
    }

    static func loadMockWords(for cat: String) async throws -> [Tab2WordEntry] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return [
            Tab2WordEntry(
                lemma: "set up",
                displayForm: "set up",
                entryKind: "phrasal_verb",
                pos: "phr.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "I need to set up the conference room before 9am.",
                nativeMeaning: "布置，准备",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "run late",
                displayForm: "run late",
                entryKind: "phrasal_verb",
                pos: "phr.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "Sorry, the client call ran over, I'm running late.",
                nativeMeaning: "迟到，耽搁",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "agenda",
                displayForm: "agenda",
                entryKind: "word",
                pos: "n.",
                granularity: "sentence",
                sourceType: "material",
                sampleSentence: "Did everyone receive the meeting agenda?",
                nativeMeaning: "议程",
                imageUrl: nil
            ),
            Tab2WordEntry(
                lemma: "invoice",
                displayForm: "invoice",
                entryKind: "word",
                pos: "n.",
                granularity: "word",
                sourceType: "material",
                sampleSentence: "looked up",
                nativeMeaning: "发票",
                imageUrl: nil
            )
        ]
    }
}

// MARK: - SwiftUI Preview

#Preview("Tab2 全生命周期沙盒") {
    Tab2LifecycleSandboxPreviewView()
}
#endif
