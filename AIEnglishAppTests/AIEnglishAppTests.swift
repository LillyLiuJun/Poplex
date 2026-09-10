import Testing
import Foundation
import UIKit
import SwiftUI
import Observation
@testable import AIEnglishApp

@MainActor
@Observable
private final class SignedURLTestState {
    var value: String

    init(_ value: String) {
        self.value = value
    }
}

@MainActor
private struct CachedRemoteImageRefreshFixture: View {
    let signedURL: SignedURLTestState
    let stableKey: String
    let download: (URL) async throws -> Data

    var body: some View {
        var image = CachedRemoteImage(
            signedUrl: signedURL.value,
            stableKey: stableKey,
            placeholder: Color.clear
        )
        image.download = download
        return image
    }
}

private actor Tab2RefreshGate {
    private var continuation: CheckedContinuation<Result<Data, any Error>, Never>?
    private var pendingResult: Result<Data, any Error>?

    func wait() async throws -> Data {
        if let pendingResult {
            self.pendingResult = nil
            return try pendingResult.get()
        }
        let result = await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return try result.get()
    }

    func resolve(_ result: Result<Data, any Error>) {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: result)
        } else {
            pendingResult = result
        }
    }
}

private actor AsyncCompletionFlag {
    private(set) var isComplete = false
    func markComplete() { isComplete = true }
}

private actor Tab2CacheGate {
    private var continuation: CheckedContinuation<Data?, Never>?
    private var pendingResolution: (resolved: Bool, data: Data?) = (false, nil)

    func wait() async -> Data? {
        if pendingResolution.resolved {
            let data = pendingResolution.data
            pendingResolution = (false, nil)
            return data
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ data: Data? = nil) {
        continuation?.resume(returning: data)
        if continuation == nil {
            pendingResolution = (true, data)
        } else {
            continuation = nil
        }
    }
}

private actor AsyncCallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

// MARK: - AppTab navigation state tests

struct AppTabTests {

    @Test func defaultTabIsToday() {
        let tab = AppTab.today
        #expect(tab == .today)
    }

    @Test func tabSwitchesToMine() {
        var selected: AppTab = .today
        selected = .mine
        #expect(selected == .mine)
    }

    @Test func tabSwitchesBackToToday() {
        var selected: AppTab = .mine
        selected = .today
        #expect(selected == .today)
    }

    @Test func inputBarVisibleOnlyForToday() {
        let isVisible: (AppTab) -> Bool = { $0 == .today }
        #expect(isVisible(.today) == true)
        #expect(isVisible(.mine) == false)
    }
}

// MARK: - Tab2 refresh lifecycle tests

@MainActor
// 这一组会同时驱动同一个 MainActor 上的异步 ViewModel 状态；若组内并行，
// CI 负载高时启动任务可能迟于测试的短轮询窗口，产生并非产品行为的假失败。
@Suite(.serialized)
struct Tab2RefreshLifecycleTests {
    private let payload = """
    {
        "unlocked": false,
        "input_count": 4,
        "categories": []
    }
    """.data(using: .utf8)!

    @Test func successfulRefreshUpdatesDataAndClearsFailureState() async {
        let payload = self.payload
        let vm = Tab2HomeViewModel(
            homeDataLoader: { payload },
            homeLoadTimeout: .seconds(1),
            isConnected: { true }
        )
        vm.errorMessage = "old error"
        vm.toastMessage = "old toast"

        await vm.load(showFailureHint: true)

        #expect(vm.data?.inputCount == 4)
        #expect(vm.errorMessage == nil)
        #expect(vm.toastMessage == nil)
        #expect(vm.isLoading == false)
        #expect(vm.categoryWordsRevision == 1)
    }

    @Test func manualRefreshJoinsInFlightLoadAndPromotesFailureFeedback() async {
        let gate = Tab2RefreshGate()
        let completion = AsyncCompletionFlag()
        let vm = Tab2HomeViewModel(
            homeDataLoader: { try await gate.wait() },
            homeLoadTimeout: .seconds(1),
            isConnected: { true }
        )
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [])

        let automaticLoad = Task { await vm.load() }
        await waitUntil { vm.isLoading }
        vm.toastMessage = "Previous failure"

        let manualRefresh = Task {
            await vm.load(showFailureHint: true)
            await completion.markComplete()
        }
        await Task.yield()

        let completedEarly = await completion.isComplete
        #expect(vm.toastMessage == nil)
        #expect(completedEarly == false)

        await gate.resolve(.failure(URLError(.timedOut)))
        await automaticLoad.value
        await manualRefresh.value

        let completedAfterLoad = await completion.isComplete
        #expect(completedAfterLoad)
        #expect(vm.toastMessage == "Unable to sync right now. Pull to try again.")
        #expect(vm.isLoading == false)
    }

    @Test func manualRefreshDuringCacheReadJoinsBeforeNetworkRequestStarts() async {
        let payload = self.payload
        let cacheGate = Tab2CacheGate()
        let networkCalls = AsyncCallCounter()
        let manualCompletion = AsyncCompletionFlag()
        let vm = Tab2HomeViewModel(
            homeDataLoader: {
                await networkCalls.increment()
                return payload
            },
            homeCacheLoader: { await cacheGate.wait() },
            homeLoadTimeout: .seconds(1),
            isConnected: { true }
        )

        let automaticLoad = Task { await vm.load() }
        await waitUntil { vm.isLoading }

        let manualRefresh = Task {
            await vm.load(showFailureHint: true)
            await manualCompletion.markComplete()
        }
        await Task.yield()

        #expect(await manualCompletion.isComplete == false)
        #expect(await networkCalls.count == 0)

        await cacheGate.resolve()
        await automaticLoad.value
        await manualRefresh.value

        #expect(await manualCompletion.isComplete)
        #expect(await networkCalls.count == 1)
        #expect(vm.data?.inputCount == 4)
        #expect(vm.isLoading == false)
    }

    @Test func timedOutManualRefreshKeepsDataAndShowsRetryHint() async {
        let vm = Tab2HomeViewModel(
            homeDataLoader: {
                try await Task.sleep(for: .seconds(1))
                return Data()
            },
            homeLoadTimeout: .milliseconds(10),
            isConnected: { true }
        )
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [])

        await vm.load(showFailureHint: true)

        #expect(vm.data?.inputCount == 2)
        #expect(vm.toastMessage == "Unable to sync right now. Pull to try again.")
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(vm.categoryWordsRevision == 0)
    }

    @Test func backgroundRefreshFailureKeepsCacheWithoutToast() async {
        let vm = Tab2HomeViewModel(
            homeDataLoader: { throw URLError(.badServerResponse) },
            isConnected: { true }
        )
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [])
        vm.toastMessage = "Previous failure"

        await vm.load()

        #expect(vm.data?.inputCount == 2)
        #expect(vm.toastMessage == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test func cancelledManualRefreshKeepsDataWithoutFailureToast() async {
        let vm = Tab2HomeViewModel(
            homeDataLoader: { throw CancellationError() },
            isConnected: { true }
        )
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [])

        await vm.load(showFailureHint: true)

        #expect(vm.data?.inputCount == 2)
        #expect(vm.toastMessage == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test func offlineManualRefreshReturnsImmediateOfflineHintWithoutReplacingData() async {
        let payload = self.payload
        let vm = Tab2HomeViewModel(
            homeDataLoader: { payload },
            isConnected: { false }
        )
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [])

        await vm.load(showFailureHint: true)

        #expect(vm.data?.inputCount == 2)
        #expect(vm.toastMessage == "You're offline. Check your connection and try again.")
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test func offlineInitialRetryKeepsErrorPageAndShowsFeedback() async {
        let vm = Tab2HomeViewModel(
            homeDataLoader: { Data() },
            homeCacheLoader: { nil },
            isConnected: { false }
        )
        vm.errorMessage = "Failed to load"

        await vm.retryInitialLoad()

        #expect(vm.data == nil)
        #expect(vm.errorMessage == "Failed to load")
        #expect(vm.toastMessage == "You're offline. Check your connection and try again.")
        #expect(vm.isLoading == false)
    }

    @Test func connectedInitialRetryFailureKeepsErrorPageAndShowsFeedback() async {
        let vm = Tab2HomeViewModel(
            homeDataLoader: { throw URLError(.badServerResponse) },
            homeCacheLoader: { nil },
            isConnected: { true }
        )
        vm.errorMessage = "Failed to load"

        await vm.retryInitialLoad()

        #expect(vm.data == nil)
        #expect(vm.errorMessage == "Failed to load")
        #expect(vm.toastMessage == "Unable to sync right now. Try again in a moment.")
        #expect(vm.isLoading == false)
    }

    @Test func successfulInitialRetryKeepsRecoveryVisibleUntilContentArrives() async {
        let payload = self.payload
        let gate = Tab2RefreshGate()
        let completion = AsyncCompletionFlag()
        let vm = Tab2HomeViewModel(
            homeDataLoader: { try await gate.wait() },
            homeCacheLoader: { nil },
            homeLoadTimeout: .seconds(1),
            isConnected: { true }
        )
        vm.errorMessage = "Failed to load"

        let retry = Task {
            await vm.retryInitialLoad()
            await completion.markComplete()
        }
        await waitUntil { vm.isLoading }

        #expect(vm.errorMessage == "Failed to load")
        #expect(await completion.isComplete == false)

        await gate.resolve(.success(payload))
        await retry.value

        #expect(await completion.isComplete)
        #expect(vm.data?.inputCount == 4)
        #expect(vm.errorMessage == nil)
        #expect(vm.toastMessage == nil)
        #expect(vm.isLoading == false)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Timed out waiting for Tab2 refresh state")
    }
}

// MARK: - Root tab swipe intent tests

struct RootTabSwipeIntentTests {
    @Test func verticalPullDoesNotBecomeTabSwipe() {
        #expect(RootTabSwipeIntent.isHorizontal(CGSize(width: 3, height: 60)) == false)
    }

    @Test func horizontalDragBecomesTabSwipe() {
        #expect(RootTabSwipeIntent.isHorizontal(CGSize(width: 60, height: 3)) == true)
    }

    @Test func diagonalDragDoesNotBecomeTabSwipe() {
        // 45°~55° 的斜向划动（如 dx=50, dy=50 或 dx=60, dy=40）不得被判定为水平切 Tab
        #expect(RootTabSwipeIntent.isHorizontal(CGSize(width: 50, height: 50)) == false)
        #expect(RootTabSwipeIntent.isHorizontal(CGSize(width: 60, height: 40)) == false)
        // 只有超过 1.7 倍（约 60°）的明确水平手势才被判定为水平
        #expect(RootTabSwipeIntent.isHorizontal(CGSize(width: 80, height: 40)) == true)
    }

    // MARK: - nextLock（手势进行中的锁定判定）

    @Test func nextLockStaysUndeterminedBelowMinimumDistance() {
        // 9pt 总位移不到 10pt 最低确认门槛——哪怕方向已经是明确水平，也先不锁。
        let lock = RootTabSwipeIntent.nextLock(current: .undetermined, translation: CGSize(width: 9, height: 0))
        #expect(lock == .undetermined)
    }

    @Test func nextLockLocksHorizontalPastThreshold() {
        let lock = RootTabSwipeIntent.nextLock(current: .undetermined, translation: CGSize(width: 20, height: 0))
        #expect(lock == .horizontal)
    }

    @Test func nextLockLocksVerticalPastThreshold() {
        let lock = RootTabSwipeIntent.nextLock(current: .undetermined, translation: CGSize(width: 0, height: 20))
        #expect(lock == .vertical)
    }

    @Test func nextLockIgnoresFurtherTranslationOnceLocked() {
        // 已经锁定水平后，哪怕后续帧的位移看起来像垂直，也不会被重新判定——
        // 意图只在手势早期判一次，锁定后到手势结束前保持不变。
        let lock = RootTabSwipeIntent.nextLock(current: .horizontal, translation: CGSize(width: 0, height: 200))
        #expect(lock == .horizontal)

        let stillVertical = RootTabSwipeIntent.nextLock(current: .vertical, translation: CGSize(width: 200, height: 0))
        #expect(stillVertical == .vertical)
    }

    // MARK: - resolveAction（松手时的触发判定）

    @Test func resolveActionIgnoresVerticalLockRegardlessOfDistance() {
        // 从未锁定为水平的手势，哪怕松手位移巨大，也一律不触发切 Tab。
        let action = RootTabSwipeIntent.resolveAction(
            lock: .vertical,
            translation: CGSize(width: -200, height: 0),
            predictedTranslation: CGSize(width: -400, height: 0),
            selectedTab: .today,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .none)
    }

    @Test func resolveActionSwitchesToMineOnLeftSwipePastHardThreshold() {
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: -81, height: 0),
            predictedTranslation: .zero,
            selectedTab: .today,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .switchToMine)
    }

    @Test func resolveActionSwitchesToMineOnInertialLeftFlick() {
        // 实测位移只到 36pt（过 35pt 软门槛），但惯性预测位移到 -161pt（过 160pt）也应触发。
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: -36, height: 0),
            predictedTranslation: CGSize(width: -161, height: 0),
            selectedTab: .today,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .switchToMine)
    }

    @Test func resolveActionDoesNotTriggerBelowBothThresholds() {
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: -34, height: 0),
            predictedTranslation: CGSize(width: -159, height: 0),
            selectedTab: .today,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .none)
    }

    @Test func resolveActionSwitchesToTodayOnRightSwipeFromMine() {
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: 81, height: 0),
            predictedTranslation: .zero,
            selectedTab: .mine,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .switchToToday)
    }

    @Test func resolveActionResetsListInsteadOfSwitchingWhenSwipeOpenWasCaptured() {
        // 手势开始时 Tab2 的滑动删除态是打开的：右滑应该先收起它、重置列表，
        // 而不是真的切回 Today——用户此刻的右滑意图是关掉删除条。
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: 81, height: 0),
            predictedTranslation: .zero,
            selectedTab: .mine,
            capturedSwipeOpen: true,
            mineDetailActive: false
        )
        #expect(action == .resetMineListForOpenDelete)
    }

    @Test func resolveActionDoesNothingWhenMineDetailIsActive() {
        // 详情页展开时右滑不该把用户甩回 Today。
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: 81, height: 0),
            predictedTranslation: .zero,
            selectedTab: .mine,
            capturedSwipeOpen: false,
            mineDetailActive: true
        )
        #expect(action == .none)
    }

    @Test func resolveActionIgnoresLeftSwipeWhileAlreadyOnMine() {
        // 已经在 Mine 上时左滑不该有任何动作（没有更左的 Tab）。
        let action = RootTabSwipeIntent.resolveAction(
            lock: .horizontal,
            translation: CGSize(width: -200, height: 0),
            predictedTranslation: .zero,
            selectedTab: .mine,
            capturedSwipeOpen: false,
            mineDetailActive: false
        )
        #expect(action == .none)
    }
}

// MARK: - Navigation chrome token tests

private extension DynamicTypeSize {
    /// 测试用：把 SwiftUI 的字号档映射到 UIKit 的对应档，供 UIFontMetrics 按档位测量。
    var uiCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

struct NavigationChromeTokenTests {
    // 最窄的在售 iPhone 点宽（SE / mini 系列），用作「顶栏在最紧屏幕上是否还装得下」的下限。
    private let narrowestSupportedScreenWidth: CGFloat = 375

    @Test func labelTabRowFitsNarrowestSupportedScreenAtMaxDynamicTypeSize() throws {
        // 双面包夹：从 AX1 到 AX5 逐档实测 Tab 行宽，最大放得下的档必须恰为 token
        // 声明的那一档——token 调高到放不下的档，或调低到还能再放一档的档，这里都会红。
        // 文案取自 AppTab.title、字体配方取自 AppTheme.Font 的 tabLabel 配方 token
        // （两处改动都会自动重测）；宽度独立于 topBarSideClearance 公式实测，
        // clearance 改坏时也会红。
        let fittingCategory = try #require(largestFittingAccessibilityCategory())
        #expect(fittingCategory == AppTheme.Typography.topTabLabelMaxDynamicTypeSize.uiCategory)
    }

    /// AX1→AX5 逐档实测 Tab 行宽，返回最大放得下的档；一档都放不下时返回 nil。
    /// 字体配方读自 AppTheme.Font 的 tabLabel 配方 token——与生产共用同一份，
    /// 改 tabLabel 的 TextStyle / 字重 / design 时本测试自动按新配方重测（放不下会红）。
    private func largestFittingAccessibilityCategory() -> UIContentSizeCategory? {
        let categories: [UIContentSizeCategory] = [
            .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
        ]
        var largest: UIContentSizeCategory?
        for category in categories {
            guard labelRowWidth(at: category) <= availableWidth else { break }
            largest = category
        }
        return largest
    }

    private var availableWidth: CGFloat {
        narrowestSupportedScreenWidth - AppTheme.Size.topBarSideClearance * 2
    }

    private func labelRowWidth(at category: UIContentSizeCategory) -> CGFloat {
        let style = uiTextStyle(AppTheme.Font.tabLabelStyle)
        // 固定按 .large（系统默认档）取基准字号，不读 UIFont.preferredFont(forTextStyle:)
        // 的无参数重载——那个重载读的是进程当前"活的"系统字号设置，在并行跑全量测试时
        // 会被同一模拟器上其他用例污染，导致基准字号本身就已经被放大过一次，
        // 叠加下面的 UIFontMetrics 二次缩放，测出的可放档位会不确定地偏低（间歇性变红）。
        let baseTrait = UITraitCollection(preferredContentSizeCategory: .large)
        let baseSize = UIFont.preferredFont(forTextStyle: style, compatibleWith: baseTrait).pointSize
        let trait = UITraitCollection(preferredContentSizeCategory: category)
        let size = UIFontMetrics(forTextStyle: style).scaledValue(for: baseSize, compatibleWith: trait)
        let weight = uiWeight(AppTheme.Font.tabLabelWeight)
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            .withDesign(uiDesign(AppTheme.Font.tabLabelDesign))
            ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        let font = UIFont(descriptor: descriptor, size: size)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let labelsWidth = AppTab.allCases
            .map { ($0.title as NSString).size(withAttributes: attributes).width }
            .reduce(0, +)
        return labelsWidth
            + AppTheme.Space.paddingM * 4          // 两个 tab 各水平内边距 paddingM ×2
            + AppTheme.Size.topTabItemSpacing
    }

    /// 测试用：SwiftUI Font.TextStyle → UIKit UIFont.TextStyle。
    private func uiTextStyle(_ style: SwiftUI.Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }

    /// 测试用：SwiftUI Font.Weight → UIKit UIFont.Weight。
    /// Font.Weight 不公开 rawValue，无法直接换算，只能按静态成员逐档匹配。
    private func uiWeight(_ weight: SwiftUI.Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    /// 测试用：SwiftUI Font.Design → UIKit UIFontDescriptor.SystemDesign。
    private func uiDesign(_ design: SwiftUI.Font.Design) -> UIFontDescriptor.SystemDesign {
        switch design {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        @unknown default: return .default
        }
    }

    @Test func topBarMenuIconStrokeMatchesDesignedWeight() {
        // 锁定 Theme.swift 注释里记录的设计目标（1.8 描边换算到顶栏 20pt glyph = 1.5pt），
        // 而不是重新复述换算公式本身——公式或输入值算错时，这个字面值才会暴露差异。
        #expect(abs(AppTheme.Size.topBarMenuIconStroke - 1.5) < 0.0001)
    }

    @Test func topBarSymmetricSideClearanceProtectsBothControls() {
        // 验证两侧避让槽对称计算：左侧 Settings 与右侧 Usage 均占用 barControl
        let expectedClearance = AppTheme.Space.paddingPage + AppTheme.Size.barControl
        #expect(AppTheme.Size.topBarSideClearance == expectedClearance)
    }

    @Test func pillShadowTokensMatchDesignedSpec() {
        // 第一层：贴地接触阴影（中性黑 4%，radius 3, y 1）
        #expect(AppTheme.Shadow.pillContactRadius == 3)
        #expect(AppTheme.Shadow.pillContactY == 1)
        #expect(AppTheme.Shadow.pillContactX == 0)
        #expect(AppTheme.Shadow.pillContactColor == AppTheme.Color.textPrimary.opacity(0.04))

        // 第二层：扩散柔光（暖棕 5%，radius 8, y 2）
        #expect(AppTheme.Shadow.pillAmbientRadius == 8)
        #expect(AppTheme.Shadow.pillAmbientY == 2)
        #expect(AppTheme.Shadow.pillAmbientX == 0)
    }
}

// MARK: - AIEnvelope JSON decode tests
// 第5刀后：s1–s4 统一解码为 .card(CardContent)，字段为 granularity/direction/
// target_expression/native_meaning/learnable_units 等统一 schema。

struct AIEnvelopeDecodeTests {

    // s1 = word + comprehend：音标、词性数组、释义、例句、可学单元
    @Test func decodesWordComprehendCard() throws {
        let json = """
        {
            "card_type": "s1",
            "card_content": {
                "granularity": "word",
                "direction": "comprehend",
                "user_original": "overtime",
                "target_expression": "overtime",
                "native_meaning": "加班",
                "phonetic": "/ˈoʊvərtaɪm/",
                "pos": ["n."],
                "examples": [{"en": "I work overtime tonight.", "zh": "我今晚加班。"}],
                "learnable_units": [
                    {"form": "overtime", "kind": "word", "note": "", "is_primary": true}
                ]
            },
            "extracted_concept": "overtime"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.isWord)
        #expect(c.isComprehend)
        #expect(c.targetExpression == "overtime")
        #expect(c.nativeMeaning == "加班")
        #expect(c.phonetic == "/ˈoʊvərtaɪm/")
        #expect(c.pos == ["n."])
        #expect(c.examples.count == 1)
        #expect(c.examples[0].en == "I work overtime tonight.")
        #expect(c.primaryUnit?.form == "overtime")
        #expect(c.primaryUnit?.isPrimary == true)
        #expect(envelope.extractedConcept == "overtime")
    }

    // s2 = sentence + comprehend，原句有误：revision_type=error、修正版、语法观察
    @Test func decodesSentenceComprehendWithRevision() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "revision_type": "error",
                "user_original": "I am very sleep today",
                "target_expression": "I am very sleepy today",
                "native_meaning": "我今天很困。",
                "grammar_note": "sleepy is the adjective for that drowsy feeling; sleep stays a verb or noun.",
                "learnable_units": [
                    {"form": "sleepy", "kind": "word", "note": "形容词", "is_primary": true}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(!c.isWord)
        #expect(c.isComprehend)
        #expect(c.revisionType == "error")
        #expect(c.userOriginal == "I am very sleep today")
        #expect(c.displayTarget == "I am very sleepy today")
        #expect(c.nativeMeaning == "我今天很困。")
        #expect(c.grammarNote != nil)
    }

    // s2 = sentence + comprehend，原句无误：target_expression 为 nil，displayTarget 落到 user_original
    @Test func decodesSentenceComprehendNoRevision() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "revision_type": null,
                "user_original": "I have to work overtime tonight.",
                "target_expression": null,
                "native_meaning": "我今晚又得加班了。",
                "grammar_note": null,
                "learnable_units": [
                    {"form": "have to", "kind": "phrase", "note": "比 must 更口语", "is_primary": true}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.revisionType == nil)
        #expect(c.targetExpression == nil)
        #expect(c.displayTarget == "I have to work overtime tonight.")
        #expect(c.grammarNote == nil)
    }

    // displayableGrammarNote：word/sentence/passage 共用同一条门控（AICardBody 曾经三处各写一遍，
    // 一度与自己的头注释矛盾——收敛到 CardContent 上后用这一处测试锁住规则）
    @Test func displayableGrammarNoteOnlyForComprehend() {
        let comprehend = CardContent(direction: "comprehend", grammarNote: "note")
        #expect(comprehend.displayableGrammarNote == "note")

        let express = CardContent(direction: "express", grammarNote: "note")
        #expect(express.displayableGrammarNote == nil)

        let emptyNote = CardContent(direction: "comprehend", grammarNote: "")
        #expect(emptyNote.displayableGrammarNote == nil)

        let noNote = CardContent(direction: "comprehend", grammarNote: nil)
        #expect(noNote.displayableGrammarNote == nil)
    }

    // hasMeaningfulRevision：只有 target_expression 确实不同于 user_original 才算修正，
    // 防止模型漂移（设了 revision_type 却回传同一句话）导致原句与修正句重复展示。
    @Test func hasMeaningfulRevisionRequiresActualChange() {
        let revised = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: "error",
            userOriginal: "I am very sleep today", targetExpression: "I am very sleepy today"
        )
        #expect(revised.hasMeaningfulRevision)

        let driftedSame = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: "polish",
            userOriginal: "I have to work overtime tonight.",
            targetExpression: "I have to work overtime tonight."
        )
        #expect(!driftedSame.hasMeaningfulRevision)

        let noRevision = CardContent(
            granularity: "sentence", direction: "comprehend",
            userOriginal: "I have to work overtime tonight.", targetExpression: nil
        )
        #expect(!noRevision.hasMeaningfulRevision)

        let expressCase = CardContent(
            granularity: "sentence", direction: "express",
            userOriginal: "今天工作好 stress", targetExpression: "Work is so stressful today"
        )
        #expect(!expressCase.hasMeaningfulRevision)

        // 首尾空白漂移（模型常见抖动）不应算作有意义的修正
        let whitespaceDrift = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: "polish",
            userOriginal: "I have to work overtime tonight.",
            targetExpression: "I have to work overtime tonight. \n"
        )
        #expect(!whitespaceDrift.hasMeaningfulRevision)

        // userOriginal 为空时绝不能误判为有修正（避免 != nil 伪命中）
        let nilOriginal = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: "polish",
            userOriginal: nil, targetExpression: "I'm heading out."
        )
        #expect(!nilOriginal.hasMeaningfulRevision)

        // revisionType 为空或非法时绝不能误判为有修正
        let nilRevisionType = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: nil,
            userOriginal: "I am sleep", targetExpression: "I am sleepy"
        )
        #expect(!nilRevisionType.hasMeaningfulRevision)

        let invalidRevisionType = CardContent(
            granularity: "sentence", direction: "comprehend", revisionType: "unknown",
            userOriginal: "I am sleep", targetExpression: "I am sleepy"
        )
        #expect(!invalidRevisionType.hasMeaningfulRevision)
    }

    // s3 = word + express：母语词 → 目标语表达
    @Test func decodesWordExpressCard() throws {
        let json = """
        {
            "card_type": "s3",
            "card_content": {
                "granularity": "word",
                "direction": "express",
                "user_original": "摸鱼",
                "target_expression": "slack off",
                "native_meaning": "摸鱼",
                "phonetic": "/slæk ɔːf/",
                "pos": ["v."],
                "examples": [{"en": "I've been slacking off all day.", "zh": "我摸了一天鱼。"}],
                "learnable_units": [
                    {"form": "slack off", "kind": "phrase", "note": "", "is_primary": true}
                ]
            },
            "extracted_concept": "摸鱼"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.isWord)
        #expect(!c.isComprehend)
        #expect(c.displayTarget == "slack off")
        #expect(c.nativeMeaning == "摸鱼")
        #expect(c.examples[0].zh == "我摸了一天鱼。")
        #expect(envelope.extractedConcept == "摸鱼")
    }

    // s4 = sentence + express：母语句子 → 目标语句子
    @Test func decodesSentenceExpressCard() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "user_original": "今天地铁挤死了。",
                "target_expression": "The subway was absolutely packed this morning.",
                "native_meaning": null,
                "learnable_units": [
                    {"form": "absolutely packed", "kind": "phrase", "note": "比 very crowded 更有力", "is_primary": true},
                    {"form": "commute", "kind": "word", "note": "", "is_primary": false}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.displayTarget == "The subway was absolutely packed this morning.")
        #expect(c.learnableUnits.count == 2)
        // primaryUnit 优先取 is_primary=true 的那个，而不是数组第一个
        #expect(c.primaryUnit?.form == "absolutely packed")
        #expect(c.passageLines.isEmpty)
    }

    // s5 = passage + comprehend：长文本（目标语言）→ 逐行翻译对照
    @Test func decodesPassageComprehendCard() throws {
        let json = """
        {
            "card_type": "s5",
            "card_content": {
                "granularity": "passage",
                "direction": "comprehend",
                "user_original": "The subway was packed today. I could barely breathe.",
                "target_expression": "The subway was packed today. I could barely breathe.",
                "native_meaning": "一段关于地铁拥挤的描述",
                "revision_type": null,
                "learnable_units": [
                    {"form": "packed", "kind": "word", "note": "拥挤的", "is_primary": true},
                    {"form": "could barely breathe", "kind": "phrase", "note": "几乎喘不过气", "is_primary": false}
                ],
                "passage_lines": [
                    {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
                    {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "passage")
        #expect(c.isPassage == true)
        #expect(c.isWord == false)
        #expect(c.passageLines.count == 2)
        #expect(c.passageLines[0].en == "The subway was packed today.")
        #expect(c.passageLines[0].zh == "今天地铁挤死了。")
        #expect(c.learnableUnits.count == 2)
        #expect(c.primaryUnit?.form == "packed")
    }

    // s6 = passage + express：长文本（母语）→ 逐行翻译对照
    @Test func decodesPassageExpressCard() throws {
        let json = """
        {
            "card_type": "s6",
            "card_content": {
                "granularity": "passage",
                "direction": "express",
                "user_original": "今天地铁挤死了。我几乎喘不过气。",
                "target_expression": "The subway was packed today. I could barely breathe.",
                "native_meaning": null,
                "learnable_units": [
                    {"form": "packed", "kind": "word", "note": "拥挤的", "is_primary": true}
                ],
                "passage_lines": [
                    {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
                    {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
                ],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "passage")
        #expect(c.isPassage == true)
        #expect(c.direction == "express")
        #expect(c.passageLines.count == 2)
        #expect(c.passageLines[1].zh == "我几乎喘不过气。")
        #expect(c.nativeMeaning == nil)
    }

    // 纯场景图 → sentence + comprehend（s2）：native_meaning 承载母语翻译
    @Test func decodesPureScenePhotoCard() throws {
        let json = """
        {
            "card_type": "s2",
            "card_content": {
                "granularity": "sentence",
                "direction": "comprehend",
                "user_original": null,
                "user_original_lang": null,
                "target_expression": "A cup of coffee sits on a wooden desk next to a laptop.",
                "native_meaning": "一杯咖啡放在木桌上，旁边是一台笔记本电脑。",
                "revision_type": null,
                "learnable_units": [
                    {"form": "wooden desk", "kind": "phrase", "note": "木桌", "is_primary": true}
                ],
                "passage_lines": [],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "sentence")
        #expect(c.direction == "comprehend")
        #expect(c.userOriginal == nil)
        #expect(c.targetExpression == "A cup of coffee sits on a wooden desk next to a laptop.")
        #expect(c.nativeMeaning == "一杯咖啡放在木桌上，旁边是一台笔记本电脑。")
        #expect(c.passageLines.isEmpty)
    }

    // error 卡：安全/无效拦截走 ErrorContent
    @Test func decodesErrorCard() throws {
        let json = """
        {
            "card_type": "error",
            "card_content": {
                "error_type": "meaningless",
                "message": "好像没有接收到内容，再说一次？"
            },
            "extracted_concept": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .error(let c) = envelope.card else {
            Issue.record("Expected .error card"); return
        }
        #expect(c.errorType == "meaningless")
        #expect(c.message == "好像没有接收到内容，再说一次？")
    }

    // error 卡缺 message（模型漂移）：解码不失败，message 为 nil，渲染层用兜底文案
    @Test func decodesErrorCardWithoutMessage() throws {
        let json = """
        {
            "card_type": "error",
            "card_content": {
                "error_type": "unsafe"
            },
            "extracted_concept": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .error(let c) = envelope.card else {
            Issue.record("Expected .error card"); return
        }
        #expect(c.errorType == "unsafe")
        #expect(c.message == nil)
        #expect(envelope.card.primaryEnglish == "This content can't be processed. Try another one.")
    }

    // 容错：granularity/direction 缺失时用默认值（sentence + express），不抛错
    @Test func missingRoutingFieldsFallBackToDefaults() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "user_original": "好累",
                "target_expression": "So tired."
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.granularity == "sentence")
        #expect(c.direction == "express")
        #expect(c.learnableUnits.isEmpty)
        #expect(c.pos.isEmpty)
        #expect(c.displayTarget == "So tired.")
    }
}

// MARK: - Reliable generation service contract tests

struct AIServiceContractTests {

    // Catches a client that accepts a stable request ID but silently omits it
    // from the actual HTTP JSON contract.
    @Test func requestBodyEncodesRequestIDAsSnakeCase() throws {
        let requestID = UUID(uuidString: "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001")!

        let data = try LiveAIService.requestBody(
            text: "A photo from my commute",
            image: nil,
            context: nil,
            presetCardId: nil,
            requestId: requestID,
            source: "onboarding"
        )
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(body["request_id"] as? String == "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001")
    }

    // 方案丙契约：重试时把气泡的写作时刻作为 original_created_at（ISO8601 带小数秒）
    // 传给服务器；不传时请求体里不得出现该字段（正常发送行为不变）。
    @Test func requestBodyEncodesOriginalCreatedAt() throws {
        let original = Date(timeIntervalSince1970: 1_700_000_000.123)

        let withTimestamp = try LiveAIService.requestBody(
            text: "今天会议推迟了", image: nil, context: nil, presetCardId: nil,
            requestId: nil, source: "tab1", originalCreatedAt: original
        )
        let body = try #require(JSONSerialization.jsonObject(with: withTimestamp) as? [String: Any])
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(body["original_created_at"] as? String == fmt.string(from: original))

        let withoutTimestamp = try LiveAIService.requestBody(
            text: "今天会议推迟了", image: nil, context: nil, presetCardId: nil,
            requestId: nil, source: "tab1"
        )
        let plainBody = try #require(JSONSerialization.jsonObject(with: withoutTimestamp) as? [String: Any])
        #expect(plainBody["original_created_at"] == nil)
    }

    // 生成次数分桶契约：请求体带设备相对 UTC 的分钟偏移（时区方案 A）。
    // 服务端据此换算「设备的今天」作为计数日期；这里锁定字段名与合法范围。
    @Test func requestBodyEncodesUtcOffsetMinutes() throws {
        let data = try LiveAIService.requestBody(
            text: "今天会议推迟了", image: nil, context: nil, presetCardId: nil,
            requestId: nil, source: "tab1"
        )
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let offset = try #require(body["utc_offset_minutes"] as? Int)
        // 服务端校验范围 -720~+840；设备真实时区必在此内
        #expect((-720...840).contains(offset))
        #expect(offset == TimeZone.current.secondsFromGMT() / 60)
    }

    // 成功响应的 usage 字段（服务端报告的最新用量，含本次生成）→ 解码进信封，
    // 落账后裁决 allowed（方案 B：最后一次生成用完额度时客户端立即锁定）一并落地。
    @Test func decodesUsageFieldFromSuccessResponse() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            },
            "usage": {"used": 3, "limit": 5, "allowed": false, "resets_at": "2026-09-03T00:00:00+08:00"}
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.usage == UsageInfo(used: 3, limit: 5, allowed: false, resetsAt: "2026-09-03T00:00:00+08:00"))
    }

    // 旧版服务端（部署回滚或尚未升级）不返回 allowed → 解码为 nil，客户端保持未知态，
    // 行为与方案 B 上线前一致——新旧服务端与新旧 App 任意组合都不崩。
    @Test func usageFieldWithoutAllowedStillDecodes() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            },
            "usage": {"used": 3, "limit": 5, "resets_at": "2026-09-03T00:00:00+08:00"}
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.usage == UsageInfo(used: 3, limit: 5, allowed: nil, resetsAt: "2026-09-03T00:00:00+08:00"))
    }

    // 旧响应（无 usage 字段）依旧正常解码——usage 是信息性字段，缺了不影响信封。
    @Test func successResponseWithoutUsageStillDecodes() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.usage == nil)
    }

    // Catches a client that loses the server proof required for durable success.
    @Test func decodesDurableResponseMetadataFromSnakeCase() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            },
            "request_id": "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001",
            "user_message_id": "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002",
            "assistant_message_id": "C7B5C2D0-5B2A-4C5B-A60D-7C901B303003",
            "material_id": "D6A4B1CF-4C1B-4B4C-950E-6B801A404004"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.requestId == UUID(uuidString: "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001"))
        #expect(envelope.userMessageId == UUID(uuidString: "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002"))
        #expect(envelope.assistantMessageId == UUID(uuidString: "C7B5C2D0-5B2A-4C5B-A60D-7C901B303003"))
        #expect(envelope.materialId == UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404004"))
    }

    // Catches an additive response change that would break existing callers and mocks.
    @Test func cardOnlyResponseStillDecodesWithoutDurableMetadata() throws {
        let json = """
        {
            "card_type": "s4",
            "card_content": {
                "granularity": "sentence",
                "direction": "express",
                "target_expression": "The train was packed.",
                "learnable_units": [],
                "examples": []
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)

        #expect(envelope.requestId == nil)
        #expect(envelope.userMessageId == nil)
        #expect(envelope.assistantMessageId == nil)
        #expect(envelope.materialId == nil)
        guard case .card = envelope.card else {
            Issue.record("Expected legacy card to decode"); return
        }
    }
}

// MARK: - Mocks

private struct SuccessMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

private func makeSuccessEnvelope(
    requestId: UUID? = nil,
    userMessageId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404002"),
    assistantMessageId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404003"),
    materialId: UUID? = UUID(uuidString: "D6A4B1CF-4C1B-4B4C-950E-6B801A404004"),
    alreadyCommitted: Bool = false
) throws -> AIEnvelope {
    var payload: [String: Any] = [
        "card_type": "s4",
        "card_content": [
            "granularity": "sentence",
            "direction": "express",
            "user_original": "今天会议推迟了",
            "target_expression": "Today's meeting got postponed.",
            "learnable_units": [
                ["form": "got postponed", "kind": "phrase", "note": "", "is_primary": true]
            ],
            "examples": []
        ],
        "extracted_concept": NSNull()
    ]
    if let requestId { payload["request_id"] = requestId.uuidString }
    if let userMessageId { payload["user_message_id"] = userMessageId.uuidString }
    if let assistantMessageId { payload["assistant_message_id"] = assistantMessageId.uuidString }
    if let materialId { payload["material_id"] = materialId.uuidString }
    if alreadyCommitted { payload["already_committed"] = true }
    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder().decode(AIEnvelope.self, from: data)
}

private final class RecordingResponseMock: AIServicing, @unchecked Sendable {
    enum Response: String, Sendable {
        case matchingDurable
        case mismatchedDurable
        case absentRequestDurable
        case missingUserMessage
        case missingAssistantMessage
        case missingMaterial
    }

    private(set) var requestIds: [UUID?] = []
    let response: Response

    init(response: Response = .matchingDurable) {
        self.response = response
    }

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        switch response {
        case .matchingDurable:
            return try makeSuccessEnvelope(requestId: requestId)
        case .mismatchedDurable:
            return try makeSuccessEnvelope(
                requestId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            )
        case .absentRequestDurable:
            return try makeSuccessEnvelope(requestId: nil)
        case .missingUserMessage:
            return try makeSuccessEnvelope(requestId: requestId, userMessageId: nil)
        case .missingAssistantMessage:
            return try makeSuccessEnvelope(requestId: requestId, assistantMessageId: nil)
        case .missingMaterial:
            return try makeSuccessEnvelope(requestId: requestId, materialId: nil)
        }
    }
}

private final class FailOnceRecordingMock: AIServicing, @unchecked Sendable {
    private(set) var requestIds: [UUID?] = []
    /// 每次调用收到的 originalCreatedAt——用于断言重试携带了气泡的写作时刻。
    private(set) var originalCreatedAts: [Date?] = []

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        originalCreatedAts.append(originalCreatedAt)
        if requestIds.count == 1 { throw URLError(.notConnectedToInternet) }
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

/// 模拟「第一次其实已落库、但响应丢失」：重试时服务端幂等回放已存内容
/// （响应里 already_committed=true，客户端不再解码该字段——方案丙下回放与
/// 全新落库摆放行为一致，都放原位）。真实服务器仍会发送该字段，契约保持兼容。
private final class FailOnceThenReplayMock: AIServicing, @unchecked Sendable {
    private(set) var requestIds: [UUID?] = []
    private var callCount = 0

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        callCount += 1
        if callCount == 1 { throw URLError(.notConnectedToInternet) }
        return try makeSuccessEnvelope(requestId: requestId, alreadyCommitted: true)
    }
}

/// 把外部生成请求悬停到测试主动释放，用于稳定复现 A/B 逆序完成。
private actor ControllableGenerationMock: AIServicing {
    private var continuations: [UUID: CheckedContinuation<AIEnvelope, any Error>] = [:]
    private var startedRequestIds: [UUID] = []

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        guard let requestId else { throw AIServiceError.requestFailed }
        return try await withCheckedThrowingContinuation { continuation in
            startedRequestIds.append(requestId)
            continuations[requestId] = continuation
        }
    }

    func waitForStartedRequests(_ count: Int) async -> [UUID] {
        while startedRequestIds.count < count {
            await Task.yield()
        }
        return startedRequestIds
    }

    func succeed(_ requestId: UUID) {
        guard let continuation = continuations.removeValue(forKey: requestId) else { return }
        do {
            continuation.resume(returning: try makeSuccessEnvelope(requestId: requestId))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    func fail(_ requestId: UUID, with error: AIServiceError) {
        continuations.removeValue(forKey: requestId)?.resume(throwing: error)
    }
}

private struct FailingMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        throw URLError(.badServerResponse)
    }
}

/// 每次生成都被服务端额度裁决拒绝（429 daily_limit_reached）。
private struct QuotaReachedMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        throw AIServiceError.dailyLimitReached(used: 5, limit: 5, resetsAt: "2026-09-03T00:00:00+08:00")
    }
}

/// 每次生成都失败、同时记录 requestIds——用于断言重试幂等键的延续。
private final class AlwaysFailRecordingMock: AIServicing, @unchecked Sendable {
    private(set) var requestIds: [UUID?] = []

    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        requestIds.append(requestId)
        throw URLError(.badServerResponse)
    }
}

/// 预设卡落库 mock：按配置返回成功/失败。
private struct PresetCardSavingMock: PresetCardSaving {
    let succeeds: Bool
    func save(card: PresetCard, requestId: UUID) async -> Bool { succeeds }
}

/// 计数 saver：记录被调用次数与收到的 requestId，可配置成败——供断网跳过落库断言用。
private final class CountingPresetCardSaver: PresetCardSaving, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastRequestId: UUID?
    private let succeeds: Bool
    init(succeeds: Bool = true) { self.succeeds = succeeds }
    func save(card: PresetCard, requestId: UUID) async -> Bool {
        callCount += 1
        lastRequestId = requestId
        return succeeds
    }
}

/// 第一次抛错、之后成功——模拟"断网发送失败 → 恢复网络后重试成功"。
/// 用 class（引用语义）才能在多次 generate 调用间共享计数。
private final class FailOnceMock: AIServicing {
    private var callCount = 0
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        callCount += 1
        if callCount == 1 { throw URLError(.notConnectedToInternet) }
        return try makeSuccessEnvelope(requestId: requestId)
    }
}

/// 总是抛断网错误的 mock。
private struct OfflineMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        throw URLError(.notConnectedToInternet)
    }
}

/// 生成时被服务端安全过滤拦截（Edge Function 返回 422 content_blocked，
/// AIService 解析后抛 AIServiceError.contentBlocked）。
private struct ContentBlockedMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, requestId: UUID?, source: String?, originalCreatedAt: Date?) async throws -> AIEnvelope {
        throw AIServiceError.contentBlocked
    }
}

// MARK: - TodayViewModel tests

// TodayViewModel 已标 @MainActor（审查发现 #5）：实例状态与方法的访问必须在主线程隔离。
@MainActor
struct TodayViewModelTests {

    /// Fresh, isolated pendingRetryStore/successStore for a test — `loadHistory()`
    /// unconditionally injects from both in its `defer` block (even on the early
    /// offline-return path), and both default to real `.shared` singletons.
    /// Without this, any state left over from a real app run on the same
    /// simulator/host (or another test) leaks into `entries`, making
    /// `entries.isEmpty` assertions flaky.
    private func isolatedStores(suite: String) -> (PendingRetryStore, LocalSuccessStore) {
        let pendingDefaults = UserDefaults(suiteName: "\(suite)-pending")!
        pendingDefaults.removePersistentDomain(forName: "\(suite)-pending")
        let pendingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-vm-tests-pending-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let successDefaults = UserDefaults(suiteName: "\(suite)-success")!
        successDefaults.removePersistentDomain(forName: "\(suite)-success")
        let successDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-vm-tests-success-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: successDir, withIntermediateDirectories: true)

        return (
            PendingRetryStore(defaults: pendingDefaults, documentsDir: pendingDir),
            LocalSuccessStore(defaults: successDefaults, documentsDir: successDir)
        )
    }

    private func isolatedCache(suite: String) -> LocalCache {
        LocalCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("today-vm-tests-cache-\(suite)-\(UUID())", isDirectory: true))
    }

    @Test func startingNewHistoryLoadClearsPreviousFailureHint() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { Data() },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "clear-failure-hint")
        )
        vm.offlineHint = "Previous failure"

        await vm.loadHistory()

        #expect(vm.offlineHint == nil)
    }

    @Test func manualHistoryRefreshJoinsInFlightLoadAndPromotesFailureFeedback() async {
        let gate = Tab2RefreshGate()
        let completion = AsyncCompletionFlag()
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { try await gate.wait() },
            historyTimeout: .seconds(1),
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "join-in-flight")
        )

        let automaticLoad = Task { await vm.loadHistory() }
        await waitUntil { vm.isLoadingHistory }
        vm.offlineHint = "Previous failure"

        let manualRefresh = Task {
            await vm.loadHistory(showFailureHint: true)
            await completion.markComplete()
        }
        await Task.yield()

        #expect(vm.offlineHint == nil)
        #expect(await completion.isComplete == false)

        await gate.resolve(.failure(URLError(.timedOut)))
        await automaticLoad.value
        await manualRefresh.value

        #expect(await completion.isComplete)
        #expect(vm.offlineHint == "Unable to sync right now. Pull to try again.")
        #expect(vm.isLoadingHistory == false)
    }

    @Test func cancelledManualHistoryRefreshRemainsSilent() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { throw CancellationError() },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "cancelled-refresh")
        )

        await vm.loadHistory(showFailureHint: true)

        #expect(vm.offlineHint == nil)
        #expect(vm.isLoadingHistory == false)
    }

    @Test func manualHistoryRefreshUsesOfflineMessageWhenConnectionDrops() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { throw URLError(.networkConnectionLost) },
            isConnected: { false },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "offline-message")
        )

        await vm.loadHistory(showFailureHint: true)

        #expect(vm.offlineHint == "You're offline. Check your connection and try again.")
    }

    @Test func manualHistoryRefreshUsesGenericMessageForConnectedFailure() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { throw URLError(.timedOut) },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "connected-failure")
        )

        await vm.loadHistory(showFailureHint: true)

        #expect(vm.offlineHint == "Unable to sync right now. Pull to try again.")
    }

    @Test func invalidManualHistoryResponseShowsGenericFailure() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { Data("not-json".utf8) },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "invalid-manual")
        )

        await vm.loadHistory(showFailureHint: true)

        #expect(vm.offlineHint == "Unable to sync right now. Pull to try again.")
    }

    @Test func invalidBackgroundHistoryResponseRemainsSilent() async {
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { Data("not-json".utf8) },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "invalid-background")
        )

        await vm.loadHistory()

        #expect(vm.offlineHint == nil)
    }

    // 冷启动无缓存又断网时，entries 会一直空着：这四条锁定 historyLoadFailed，
    // 视图靠它在「真的没内容」和「加载失败没内容」之间选空态还是错误重试态
    // （审查发现——此前两者对视图来说无法区分，用户永远看不到重试入口）。

    @Test func offlineColdStartWithNoCacheMarksHistoryLoadFailed() async {
        let (pending, success) = isolatedStores(suite: "history-failed-offline-cold-start")
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { throw URLError(.networkConnectionLost) },
            isConnected: { false },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "offline-cold-start")
        )
        vm.pendingRetryStore = pending
        vm.successStore = success

        await vm.loadHistory()

        #expect(vm.entries.isEmpty)
        #expect(vm.historyLoadFailed == true)
        // 冷启动（非手动刷新）不弹 toast——静默降级是既有约定，这条只锁 historyLoadFailed。
        #expect(vm.offlineHint == nil)
    }

    @Test func successfulLoadClearsHistoryLoadFailed() async {
        let (pending, success) = isolatedStores(suite: "history-failed-successful-load")
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { Data("[]".utf8) },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "successful-load")
        )
        vm.pendingRetryStore = pending
        vm.successStore = success
        vm.historyLoadFailed = true

        await vm.loadHistory()

        // 0 条记录是「新账号还没内容」的真实状态，不是失败——historyLoadFailed 照样清零。
        #expect(vm.entries.isEmpty)
        #expect(vm.historyLoadFailed == false)
    }

    @Test func decodeFailureMarksHistoryLoadFailed() async {
        let (pending, success) = isolatedStores(suite: "history-failed-decode-failure")
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { Data("not-json".utf8) },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "decode-failure")
        )
        vm.pendingRetryStore = pending
        vm.successStore = success

        await vm.loadHistory()

        #expect(vm.entries.isEmpty)
        #expect(vm.historyLoadFailed == true)
    }

    @Test func retrySucceedingAfterFailureClearsHistoryLoadFailed() async {
        let (pending, success) = isolatedStores(suite: "history-failed-retry-succeeds")
        var shouldFail = true
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: {
                if shouldFail { throw URLError(.networkConnectionLost) }
                return Data("[]".utf8)
            },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: isolatedCache(suite: "retry-success")
        )
        vm.pendingRetryStore = pending
        vm.successStore = success

        await vm.loadHistory()
        #expect(vm.historyLoadFailed == true)

        shouldFail = false
        await vm.loadHistory(showFailureHint: true)
        #expect(vm.historyLoadFailed == false)
    }

    @Test func historyTimeoutReturnsCompletedOperation() async throws {
        let expected = Data([0x50, 0x4F, 0x50])

        let result = try await TodayViewModel.withTimeout(.seconds(1)) {
            expected
        }

        #expect(result == expected)
    }

    @Test func historyTimeoutCancelsSlowOperation() async {
        do {
            _ = try await TodayViewModel.withTimeout(.milliseconds(20)) {
                try await Task.sleep(for: .seconds(1))
                return Data()
            }
            Issue.record("Expected history refresh to time out")
        } catch let error as TodayViewModel.HistoryLoadError {
            #expect(error == .timedOut)
        } catch {
            Issue.record("Expected timedOut, got \(error)")
        }
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Timed out waiting for Tab1 history refresh state")
    }

    @Test func sendAppendsUserBubbleAndAICard() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        let bubbleEntry = vm.entries.first {
            if case .userBubble = $0.content { return true }
            return false
        }
        guard let bubbleEntry,
              case .userBubble(let text, _, _, _) = bubbleEntry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "今天会议推迟了")

        let hasCard = vm.entries.contains {
            if case .aiCard = $0.content { return true }
            return false
        }
        #expect(hasCard)
        #expect(vm.isLoading == false)
    }

    // 断网/失败：保留用户气泡 + 产生可重试的 sendFailed（携带原始输入），不再是 aiError
    @Test func sendFailureKeepsBubbleAndProducesRetryableEntry() async {
        let vm = TodayViewModel(service: FailingMock(), isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        // 用户气泡仍在
        let hasBubble = vm.entries.contains {
            if case .userBubble = $0.content { return true }
            return false
        }
        #expect(hasBubble)

        // 失败态是 sendFailed，且带着原始文本以便重发
        let failed = vm.entries.first {
            if case .sendFailed = $0.content { return true }
            return false
        }
        guard let failed, case .sendFailed(let text, let image, _, _) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        #expect(text == "今天会议推迟了")
        #expect(image == nil)
        #expect(vm.isLoading == false)
    }

    // 额度拒绝（429 daily_limit_reached）：保留用户气泡、不产生 sendFailed 行
    // （重试今天只会再撞 429），服务端裁决写入共享额度状态（输入栏锁定依据）。
    @Test func sendQuotaRejectedKeepsBubbleWithoutRetryRowAndRecordsVerdict() async {
        let store = UsageQuotaStore()
        let vm = TodayViewModel(service: QuotaReachedMock(), isConsentGranted: { true })
        vm.quotaStore = store
        await vm.send("今天会议推迟了")

        // 用户气泡仍在（那是用户说过的话）
        let hasBubble = vm.entries.contains {
            if case .userBubble = $0.content { return true }
            return false
        }
        #expect(hasBubble)

        // 没有 sendFailed 行、没有卡片
        #expect(!vm.entries.contains { if case .sendFailed = $0.content { return true }; return false })
        #expect(!vm.entries.contains { if case .aiCard = $0.content { return true }; return false })
        #expect(vm.isLoading == false)

        // 服务端裁决进入共享额度状态
        #expect(store.isAllowed == false)
        #expect(store.usedCount == 5)
        #expect(store.dailyLimit == 5)
    }

    // 重试：移除失败提示、不新增用户气泡、成功后出现卡片
    @Test func retryAfterFailureReplacesWithCard() async {
        let vm = TodayViewModel(service: FailOnceMock(), isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry after first send"); return
        }

        let bubbleCountBefore = vm.entries.filter {
            if case .userBubble = $0.content { return true }
            return false
        }.count

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id, requestId: requestId, bubbleEntryId: bubbleEntryId)

        // 失败提示已移除
        let stillFailed = vm.entries.contains {
            if case .sendFailed = $0.content { return true }
            return false
        }
        #expect(stillFailed == false)

        // 出现卡片
        let hasCard = vm.entries.contains {
            if case .aiCard = $0.content { return true }
            return false
        }
        #expect(hasCard)

        // 用户气泡数量不变（重试不重复气泡）
        let bubbleCountAfter = vm.entries.filter {
            if case .userBubble = $0.content { return true }
            return false
        }.count
        #expect(bubbleCountAfter == bubbleCountBefore)
    }

    // 修复 C：send 时生成幂等键，重试复用同一个 requestId——服务端按它去重，
    // 超时重试只会拿回第一次已落库的内容，不产生第二组记录
    @Test func retryReusesOriginalRequestId() async {
        let service = FailOnceRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        #expect(requestId != nil)   // 失败行已携带本次尝试的幂等键
        #expect(service.requestIds == [requestId])

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: requestId, bubbleEntryId: bubbleEntryId)

        #expect(service.requestIds == [requestId, requestId])   // 重试复用同一个幂等键
        let hasCard = vm.entries.contains {
            if case .aiCard = $0.content { return true }
            return false
        }
        #expect(hasCard)
    }

    // 修复 B（方案丙 · 写作时刻语义）：迟到重试成功后，卡片放回气泡原位而不是
    // 挪到时间线末尾。客户端把气泡的原始发送时刻一并发给服务器按写作时刻落库，
    // 原位摆放与服务器时间线一致，刷新永不跳。回放与全新落库行为相同（都原位）。
    @Test func lateRetryKeepsGroupInPlace() async {
        let service = FailOnceRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        await vm.send("旧消息")            // 第 1 次调用失败 → 气泡 + sendFailed
        await vm.send("新消息")            // 第 2 次调用成功 → 气泡 + 卡片

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: requestId, bubbleEntryId: bubbleEntryId)

        // 旧气泡仍在原位，卡片紧跟其后：[sep, 旧气泡, 旧卡, 新气泡, 新卡]
        let oldBubbleIdx = vm.entries.firstIndex(where: {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "旧消息" }
            return false
        })
        guard let idx = oldBubbleIdx else { Issue.record("Expected old bubble in place"); return }
        guard idx + 1 < vm.entries.count,
              case .aiCard = vm.entries[idx + 1].content else {
            Issue.record("Expected card right after the old bubble"); return
        }
        // 组没有被挪到末尾：末尾仍是「新消息」的卡片
        guard case .aiCard = vm.entries[vm.entries.count - 1].content else {
            Issue.record("Expected newest card still at the end"); return
        }
        #expect(vm.entries.count == 5)

        // 「旧消息」气泡唯一，且没有残留 sendFailed
        let oldBubbles = vm.entries.filter {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "旧消息" }
            return false
        }
        #expect(oldBubbles.count == 1)
        #expect(hasSendFailed(vm) == false)

        // 重试请求携带气泡的写作时刻（前两次正常发送不带）——服务端据此按写作时刻落库
        #expect(service.originalCreatedAts.count == 3)   // 旧消息失败 + 新消息成功 + 重试
        #expect(service.originalCreatedAts[0] == nil)
        #expect(service.originalCreatedAts[1] == nil)
        let bubbleCreatedAt = vm.entries[idx].createdAt
        #expect(service.originalCreatedAts[2] == bubbleCreatedAt)
    }

    // 修复 B（回放侧契约）：第一次发送其实已落库、响应丢失时，服务端幂等回放
    // （already_committed=true）。方案丙下客户端对回放与全新落库不做区分——
    // 两者都放原位，本测试锁住「回放响应不会把卡片挪到别处」。
    @Test func replayedRetryKeepsCardInPlace() async {
        let service = FailOnceThenReplayMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        await vm.send("旧消息")            // 第 1 次失败（模拟响应丢失，服务端其实已落库）
        await vm.send("新消息")            // 第 2 次成功

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: requestId, bubbleEntryId: bubbleEntryId)

        // 旧气泡仍在原位，卡片紧跟在它后面（[sep, 旧气泡, 旧卡, 新气泡, 新卡]）
        let oldBubbleIdx = vm.entries.firstIndex(where: {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "旧消息" }
            return false
        })
        guard let idx = oldBubbleIdx else { Issue.record("Expected old bubble"); return }
        guard idx + 1 < vm.entries.count,
              case .aiCard = vm.entries[idx + 1].content else {
            Issue.record("Expected card right after the old bubble"); return
        }
        // 组没有被挪到末尾：末尾仍是「新消息」的卡片
        guard case .aiCard = vm.entries[vm.entries.count - 1].content else {
            Issue.record("Expected newest card still at the end"); return
        }
        #expect(vm.entries.count == 5)
        #expect(hasSendFailed(vm) == false)
    }

    // 重试再次失败：新 sendFailed 行继续携带原幂等键（下一次重试仍复用），气泡不重复
    @Test func retryFailureKeepsRequestIdAndBubble() async {
        let service = AlwaysFailRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        await vm.send("今天会议推迟了")

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        let originalRequestId = requestId

        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: requestId, bubbleEntryId: bubbleEntryId)

        #expect(service.requestIds == [originalRequestId, originalRequestId])
        guard let retried = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(_, _, let retriedRequestId, _) = retried.content else {
            Issue.record("Expected sendFailed entry after retry"); return
        }
        #expect(retriedRequestId == originalRequestId)
        let bubbleCount = vm.entries.filter {
            if case .userBubble = $0.content { return true }
            return false
        }.count
        #expect(bubbleCount == 1)   // 气泡不重复
    }

    // 防重入：生成进行中（isLoading）连点 Retry 只发起一次，失败行也不会被移除
    @Test func retryWhileGeneratingIsIgnored() async {
        let service = FailOnceRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        let failedId = UUID()
        vm.entries = [TimelineEntry(
            id: failedId, createdAt: .now,
            content: .sendFailed(text: "今天会议推迟了", image: nil, requestId: UUID(), bubbleEntryId: nil)
        )]
        vm.isLoading = true   // 模拟另一生成正在进行

        await vm.retrySend(text: "今天会议推迟了", image: nil, failedEntryId: failedId,
                           requestId: nil, bubbleEntryId: nil)

        #expect(service.requestIds.isEmpty)   // 未发起第二次生成
        #expect(vm.entries.count == 1)        // 失败行未被移除（仍可再点）
        #expect(vm.isLoading == true)
    }

    @Test func sendIgnoresBlankInput() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("   ")
        #expect(vm.entries.isEmpty)
    }

    private func makePendingRetryStore(suite: String) -> PendingRetryStore {
        makePendingRetryStoreComponents(suite: suite).store
    }

    private func makePendingRetryStoreComponents(
        suite: String
    ) -> (store: PendingRetryStore, directory: URL, defaults: UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func removeRequestIdFromStoredMetadata(_ defaults: UserDefaults) throws {
        let data = try #require(defaults.data(forKey: "pending_retry_records"))
        var records = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        records[0].removeValue(forKey: "requestId")
        defaults.set(
            try JSONSerialization.data(withJSONObject: records),
            forKey: "pending_retry_records"
        )
    }

    private func hasSendFailed(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .sendFailed = $0.content { return true }; return false }
    }

    // retryPending（photo）失败：记录与照片文件保留（不误删唯一副本）
    @Test func retryPendingPhotoFailureKeepsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo-fail")
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555551")!
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
        let record = store.load()[0]

        let service = FailOnceRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().count == 1)             // 记录保留
        #expect(store.photoImage(for: record) != nil) // 照片文件仍在
        #expect(vm.entries.contains { if case .pendingRetry(let r) = $0.content { return r.id == record.id }; return false })
        #expect(hasSendFailed(vm) == false)   // 单入口语义：失败不产生 sendFailed 行
        #expect(service.requestIds == [requestId])
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
    }

    // 同 request 且三项 durable ID 齐全，才可删除本地唯一副本并展示成功结果。
    @Test func retryPendingPhotoMatchingDurableSuccessClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo-matching-durable")
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555552")!
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
        let record = store.load()[0]
        let service = RecordingResponseMock(response: .matchingDurable)
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(service.requestIds == [requestId])
        #expect(store.load().isEmpty)
        #expect(store.photoImage(for: record) == nil)
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
        #expect(vm.entries.contains { if case .userBubble = $0.content { return true }; return false })
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false })
    }

    // 不同或缺失 request ID 的成功响应不能认领当前 pending 照片。
    @Test func retryPendingPhotoMismatchedRequestKeepsUniqueCopy() async throws {
        let responses: [RecordingResponseMock.Response] = [
            .mismatchedDurable,
            .absentRequestDurable
        ]

        for response in responses {
            let store = makePendingRetryStore(suite: "retry-photo-\(response.rawValue)")
            let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555553")!
            try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
            let record = store.load()[0]
            let service = RecordingResponseMock(response: response)
            let vm = TodayViewModel(service: service, isConsentGranted: { true })
            vm.pendingRetryStore = store
            vm.entries = [TimelineEntry.pendingRetry(record)]

            await vm.retryPending(record: record)

            #expect(service.requestIds == [requestId])
            #expect(store.load().map(\.id) == [record.id])
            #expect(store.photoImage(for: record) != nil)
            #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == record.id }; return false })
            #expect(vm.entries.contains { if case .userBubble = $0.content { return true }; return false } == false)
            #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
        }
    }

    // 任一 durable ID 缺失都不是已提交成功；三种字段分别防回归。
    @Test func retryPendingPhotoMissingAnyDurableIDKeepsUniqueCopy() async throws {
        let responses: [RecordingResponseMock.Response] = [
            .missingUserMessage,
            .missingAssistantMessage,
            .missingMaterial
        ]

        for (index, response) in responses.enumerated() {
            let store = makePendingRetryStore(suite: "retry-photo-\(response.rawValue)-\(index)")
            let requestId = UUID()
            try store.savePhoto(UIImage(systemName: "photo")!, requestId: requestId)
            let record = store.load()[0]
            let service = RecordingResponseMock(response: response)
            let vm = TodayViewModel(service: service, isConsentGranted: { true })
            vm.pendingRetryStore = store
            vm.entries = [TimelineEntry.pendingRetry(record)]

            await vm.retryPending(record: record)

            #expect(service.requestIds == [requestId])
            #expect(store.load().map(\.id) == [record.id])
            #expect(store.photoImage(for: record) != nil)
            #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == record.id }; return false })
            #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
        }
    }

    // 旧记录首次 Retry 先持久升级 request ID；失败与 app 重启后仍复用同一 ID。
    @Test func retryPendingLegacyPhotoPersistsAndReusesRequestIDAcrossRestart() async throws {
        let components = makePendingRetryStoreComponents(suite: "retry-photo-legacy-round-trip")
        try components.store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        try removeRequestIdFromStoredMetadata(components.defaults)
        let legacyRecord = try #require(components.store.load().first)
        #expect(legacyRecord.requestId == nil)

        let service = FailOnceRecordingMock()
        let firstVM = TodayViewModel(service: service, isConsentGranted: { true })
        firstVM.pendingRetryStore = components.store
        firstVM.entries = [TimelineEntry.pendingRetry(legacyRecord)]
        await firstVM.retryPending(record: legacyRecord)

        let reloadedStore = PendingRetryStore(
            defaults: components.defaults,
            documentsDir: components.directory
        )
        let upgradedRecord = try #require(reloadedStore.load().first)
        let persistedRequestId = try #require(upgradedRecord.requestId)
        #expect(service.requestIds == [persistedRequestId])
        #expect(reloadedStore.photoImage(for: upgradedRecord) != nil)

        let restartedVM = TodayViewModel(service: service, isConsentGranted: { true })
        restartedVM.pendingRetryStore = reloadedStore
        restartedVM.entries = [TimelineEntry.pendingRetry(upgradedRecord)]
        await restartedVM.retryPending(record: upgradedRecord)

        #expect(service.requestIds == [persistedRequestId, persistedRequestId])
        #expect(reloadedStore.load().isEmpty)
        #expect(reloadedStore.photoImage(for: upgradedRecord) == nil)
        #expect(restartedVM.entries.contains { if case .aiCard = $0.content { return true }; return false })
    }

    // legacy metadata 升级写失败时，不能发 AI 请求，也不能覆盖记录或删除 JPEG。
    @Test func retryPendingLegacyPhotoUpgradePersistFailureStopsBeforeGeneration() async throws {
        let components = makePendingRetryStoreComponents(suite: "retry-photo-legacy-persist-failure")
        try components.store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        try removeRequestIdFromStoredMetadata(components.defaults)
        let legacyRecord = try #require(components.store.load().first)
        let failingStore = PendingRetryStore(
            defaults: components.defaults,
            documentsDir: components.directory,
            metadataWriter: { _ in
                throw NSError(domain: "test", code: 1)
            }
        )
        let service = RecordingResponseMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = failingStore
        vm.entries = [TimelineEntry.pendingRetry(legacyRecord)]

        await vm.retryPending(record: legacyRecord)

        #expect(service.requestIds.isEmpty)
        #expect(failingStore.load().map(\.id) == [legacyRecord.id])
        #expect(failingStore.load().first?.requestId == nil)
        #expect(failingStore.photoImage(for: legacyRecord) != nil)
        #expect(vm.entries.contains { if case .pendingRetry(let value) = $0.content { return value.id == legacyRecord.id }; return false })
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false } == false)
    }
}

// MARK: - AI consent gate + content-blocked tests (App Store 合规切片)
//
// 门控行为：未同意 AI 数据处理时 send() 只暂存输入 + 弹同意页，绝不发起任何
// generate 请求（合规硬要求："同意前零请求"）。同意后放行照常生成。
// 内容被服务端安全过滤拦截时，展示友好提示、不产出卡片、不残留 loading。
//
// consent 通过注入闭包驱动（生产读 UserDefaults），因此无需触碰全局状态、可并行安全。

@MainActor
struct AIConsentGateTests {

    private func hasBubble(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .userBubble = $0.content { return true }; return false }
    }
    private func hasCard(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .aiCard = $0.content { return true }; return false }
    }
    private func hasLoading(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .aiLoading = $0.content { return true }; return false }
    }

    private func hasSendFailed(_ vm: TodayViewModel) -> Bool {
        vm.entries.contains { if case .sendFailed = $0.content { return true }; return false }
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for consent gate state")
    }

    /// 与 TodayViewModel.dayLabel 同逻辑的测试版副本：测试构造的日期标题
    /// 必须与注入逻辑计算的标签一致（locale 无关）。
    private func dayLabelInTest(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func makePendingRetryStore(suite: String) -> PendingRetryStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRetryStore(defaults: defaults, documentsDir: dir)
    }

    // 待重试记录注入：injectPendingRetry 后时间线顶部有 pendingRetry 条目（不重复注入）
    @Test func pendingRetryRecordInjectedOnce() {
        let store = makePendingRetryStore(suite: "inject")
        store.savePreset(cardId: "1", imageName: "card_scene_1", requestId: UUID())

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.injectPendingRetry()
        vm.injectPendingRetry()

        let count = vm.entries.filter { if case .pendingRetry = $0.content { return true }; return false }.count
        #expect(count == 1)
    }

    // 自动刷新用服务器历史重建时间线后，待重试记录仍应位于最新端；
    // 否则页面的自动滚底会把它留在视口外，看起来像刷新后消失。
    @Test func pendingRetryRemainsVisibleAtLatestEndAfterHistoryReplacement() {
        let store = makePendingRetryStore(suite: "inject-after-refresh")
        store.savePreset(cardId: "1", imageName: "card_scene_1", requestId: UUID())

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.userBubble(text: "Older server history", image: nil)]

        vm.injectPendingRetry()

        guard let last = vm.entries.last else {
            Issue.record("Expected a pending retry entry after refresh replacement")
            return
        }
        guard case .pendingRetry = last.content else {
            Issue.record("Pending retry must stay at the latest end of the timeline")
            return
        }
    }

    // retryPending（photo）：成功后生成卡片、记录被移除
    @Test func retryPendingPhotoGeneratesAndClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-photo")
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        let record = store.load()[0]

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().isEmpty)
        #expect(hasCard(vm) == true)
        #expect(hasBubble(vm) == true)   // 就地替换为「气泡 + 卡片」——图片不再消失
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
    }

    // 预设卡 Retry：落库成功 → 记录移除、就地变「气泡 + 卡片」（静态卡内容），
    // 且发给 saver 的 requestId 与持久化记录里的一致（幂等键不能在重试时被换掉）。
    @Test func retryPendingPresetCardGeneratesAndClearsRecord() async throws {
        let store = makePendingRetryStore(suite: "retry-preset")
        store.savePreset(cardId: "2", imageName: "card_scene_2", requestId: UUID())
        let record = store.load()[0]

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        let saver = CountingPresetCardSaver(succeeds: true)
        vm.presetCardSaver = saver
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().isEmpty)
        #expect(hasCard(vm) == true)
        #expect(hasBubble(vm) == true)
        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false } == false)
        #expect(saver.lastRequestId == record.requestId)
    }

    // MARK: - 统一 attempt 抽象（Tab1 失败行持久化）

    // 文字发送失败：持久化一条 .tab1 记录——携带原文、幂等键与气泡写作时刻，
    // 与失败行上的信息一致（重试与重启归位都靠它）。
    @Test func sendFailurePersistsTab1TextAttempt() async throws {
        let store = makePendingRetryStore(suite: "tab1-fail-persist-text")
        let vm = TodayViewModel(service: FailingMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store

        await vm.send("今天会议推迟了")

        let records = store.load()
        #expect(records.count == 1)
        #expect(records[0].source == .tab1)
        #expect(records[0].text == "今天会议推迟了")
        #expect(records[0].photoFileName == nil)

        let bubble = try #require(vm.entries.first {
            if case .userBubble = $0.content { return true }
            return false
        })
        #expect(records[0].createdAt == bubble.createdAt)   // 写作时刻，不是失败时刻

        let failed = try #require(vm.entries.first {
            if case .sendFailed = $0.content { return true }
            return false
        })
        guard case .sendFailed(_, _, let rowRequestId, let rowBubbleId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        #expect(rowRequestId == records[0].requestId)
        #expect(rowBubbleId == bubble.id)
    }

    // 照片发送失败：JPEG 落盘 + 记录可回读（重启注入时气泡能拿到图片）。
    @Test func sendFailurePersistsTab1PhotoAttempt() async throws {
        let store = makePendingRetryStore(suite: "tab1-fail-persist-photo")
        let vm = TodayViewModel(service: FailingMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.pendingImage = UIImage(systemName: "photo")!

        await vm.send("")

        let records = store.load()
        #expect(records.count == 1)
        #expect(records[0].text == nil)
        #expect(records[0].photoFileName != nil)
        #expect(store.photoImage(for: records[0]) != nil)
    }

    // 重试再次失败：同 requestId 幂等跳过——不产生第二条记录、写作时刻不被改写。
    @Test func retryFailureKeepsSinglePersistedAttempt() async throws {
        let store = makePendingRetryStore(suite: "tab1-fail-idempotent")
        let service = AlwaysFailRecordingMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.pendingRetryStore = store

        await vm.send("今天会议推迟了")
        let first = try #require(store.load().first)
        let originalCreatedAt = first.createdAt
        let requestId = try #require(first.requestId)

        let failed = try #require(vm.entries.first {
            if case .sendFailed = $0.content { return true }
            return false
        })
        guard case .sendFailed(let text, let image, let rowRequestId, let rowBubbleId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: rowRequestId, bubbleEntryId: rowBubbleId)

        let after = store.load()
        #expect(after.count == 1)                                // 幂等：无第二条记录
        #expect(after[0].createdAt == originalCreatedAt)         // 写作时刻保持首次发送时的值
        #expect(after[0].requestId == requestId)
        #expect(service.requestIds == [requestId, requestId])    // 重试复用同一幂等键
    }

    // 重试成功：按 requestId 清除持久化记录——重启后从服务端回放，不再注入失败行。
    @Test func retrySendSuccessRemovesPersistedTab1Attempt() async throws {
        let store = makePendingRetryStore(suite: "tab1-retry-success")
        let requestId = UUID()
        try store.saveTab1(text: "今天会议推迟了", image: nil,
                           requestId: requestId, createdAt: .now)
        let record = try #require(store.load().first)

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        // 模拟重启后注入的状态：气泡 + 失败行
        let bubbleId = UUID()
        vm.entries = [
            TimelineEntry(id: bubbleId, createdAt: record.createdAt,
                          content: .userBubble(text: record.text, image: nil,
                                               imageUrl: nil, imageStableKey: nil)),
            TimelineEntry(id: UUID(), createdAt: record.createdAt,
                          content: .sendFailed(text: record.text, image: nil,
                                               requestId: requestId, bubbleEntryId: bubbleId))
        ]
        let failedEntryId = vm.entries[1].id

        await vm.retrySend(text: record.text, image: nil, failedEntryId: failedEntryId,
                           requestId: requestId, bubbleEntryId: bubbleId)

        #expect(store.load().isEmpty)
        #expect(hasCard(vm) == true)
        #expect(hasSendFailed(vm) == false)
    }

    // 重启注入：Tab1 失败行按写作时刻归位——同一天已有标题时不重复补、
    // 没有该日标题时补一个，失败对夹在更早与更晚的服务端记录之间。
    @Test func restartInjectsTab1AttemptChronologically() async throws {
        let store = makePendingRetryStore(suite: "tab1-restart-inject")
        let base = Date(timeIntervalSince1970: 1_800_000_000)   // 固定日期，避免跨零点抖动
        let day1 = base
        let day2 = base.addingTimeInterval(86_400)

        let requestIdDayBefore = UUID()
        try store.saveTab1(text: "day before failed", image: nil,
                           requestId: requestIdDayBefore,
                           createdAt: day1.addingTimeInterval(3_600))
        let requestIdDay2 = UUID()
        try store.saveTab1(text: "day2 failed", image: nil,
                           requestId: requestIdDay2,
                           createdAt: day2.addingTimeInterval(3_600))

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        // 服务端历史：只有 day2 一条（带该日标题）
        vm.entries = [
            TimelineEntry(id: UUID(), createdAt: day2,
                          content: .dateSeparator(dayLabelInTest(for: day2))),
            TimelineEntry(id: UUID(), createdAt: day2,
                          content: .userBubble(text: "server history", image: nil,
                                               imageUrl: nil, imageStableKey: nil))
        ]

        vm.injectPendingRetry()

        func kind(_ entry: TimelineEntry) -> String {
            switch entry.content {
            case .dateSeparator: return "sep"
            case .userBubble: return "bubble"
            case .sendFailed: return "failed"
            default: return "other"
            }
        }
        #expect(vm.entries.map(kind) == ["sep", "bubble", "failed", "sep", "bubble", "bubble", "failed"])
        // day1 补了自己的标题；day2 复用已有标题（不重复）
        if case .dateSeparator(let label) = vm.entries[0].content {
            #expect(label == dayLabelInTest(for: day1))
        } else {
            Issue.record("Expected day1 separator"); return
        }
        if case .dateSeparator(let label) = vm.entries[3].content {
            #expect(label == dayLabelInTest(for: day2))
        } else {
            Issue.record("Expected day2 separator"); return
        }
        // 失败对：气泡 + 失败行成对，requestId 与 bubbleEntryId 正确挂钩
        guard case .userBubble(let textB, _, _, _) = vm.entries[1].content else {
            Issue.record("Expected day1 bubble"); return
        }
        #expect(textB == "day before failed")
        guard case .sendFailed(_, _, let rowRequestIdB, let rowBubbleIdB) = vm.entries[2].content else {
            Issue.record("Expected day1 failed row"); return
        }
        #expect(rowRequestIdB == requestIdDayBefore)
        #expect(rowBubbleIdB == vm.entries[1].id)
        guard case .sendFailed(_, _, let rowRequestIdA, let rowBubbleIdA) = vm.entries[6].content else {
            Issue.record("Expected day2 failed row"); return
        }
        #expect(rowRequestIdA == requestIdDay2)
        #expect(rowBubbleIdA == vm.entries[5].id)
    }

    // 重启注入去重：幂等键已在服务端历史 → 本地记录清除、不注入失败行。
    @Test func restartInjectionSkipsServerCommittedRequestIds() async throws {
        let store = makePendingRetryStore(suite: "tab1-restart-dedup")
        let requestId = UUID()
        try store.saveTab1(text: "already on server", image: nil,
                           requestId: requestId, createdAt: .now)

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.userBubble(text: "server history", image: nil)]

        vm.injectPendingRetry(serverRequestIds: [requestId])

        #expect(store.load().isEmpty)            // 服务端有正本：本地副本清除
        #expect(hasSendFailed(vm) == false)
        #expect(vm.entries.count == 1)
    }

    // H1 修复：同一 requestId 的失败对已在时间线里（本会话二次 loadHistory，
    // 如回前台刷新）→ 再次注入被跳过，不出现重复的气泡 + 失败行。
    @Test func repeatedInjectionSkipsAlreadyInjectedTab1Pair() async throws {
        let store = makePendingRetryStore(suite: "tab1-repeat-inject")
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let requestId = UUID()
        try store.saveTab1(text: "failed once", image: nil,
                           requestId: requestId, createdAt: base.addingTimeInterval(3_600))

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        let bubbleId = UUID()
        // 首次注入后的形态：标题 + 气泡 + 失败行（失败行携带同一 requestId）
        vm.entries = [
            TimelineEntry(id: UUID(), createdAt: base,
                          content: .dateSeparator(dayLabelInTest(for: base))),
            TimelineEntry(id: bubbleId, createdAt: base.addingTimeInterval(3_600),
                          content: .userBubble(text: "failed once", image: nil,
                                               imageUrl: nil, imageStableKey: nil)),
            TimelineEntry(id: UUID(), createdAt: base.addingTimeInterval(3_600),
                          content: .sendFailed(text: "failed once", image: nil,
                                               requestId: requestId, bubbleEntryId: bubbleId))
        ]

        vm.injectPendingRetry()

        let failedRows = vm.entries.filter { entry in
            if case .sendFailed = entry.content { return true }
            return false
        }
        #expect(vm.entries.count == 3)     // 不重复注入：标题 + 气泡 + 失败行各一条
        #expect(failedRows.count == 1)
        #expect(store.load().count == 1)   // 记录仍在（重试成功才清除）
    }

    // D 同族竞态（onboarding）：照片响应迟到被误判失败 → 服务端其实已落库。
    // 注入时按幂等键识别 → pendingRetry 行不注入、记录与本地照片文件清除，
    // 避免与服务端回放的「气泡 + 卡片」重复。
    @Test func restartInjectionRemovesStaleOnboardingPendingRecords() async throws {
        let store = makePendingRetryStore(suite: "tab1-stale-onboarding")
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        let record = try #require(store.load().first)
        let requestId = try #require(record.requestId)

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.userBubble(text: "server history", image: nil)]

        vm.injectPendingRetry(serverRequestIds: [requestId])

        #expect(store.load().isEmpty)
        #expect(store.photoImage(for: record) == nil)   // 本地 JPEG 一并清除
        #expect(vm.entries.count == 1)
    }

    // seed 去重决策（D）：幂等键在服务端 → 不注入；无键/无记录 → 照旧注入。
    @Test func shouldInjectSeedDecision() {
        let entry = TimelineEntry.userBubble(text: "Describe this image", image: nil)
        let requestId = UUID()

        #expect(TodayViewModel.shouldInjectSeed(
            seedEntries: [], seedRequestId: requestId,
            serverRequestIds: [requestId]) == false)
        #expect(TodayViewModel.shouldInjectSeed(
            seedEntries: [entry], seedRequestId: requestId,
            serverRequestIds: [requestId]) == false)
        #expect(TodayViewModel.shouldInjectSeed(
            seedEntries: [entry], seedRequestId: UUID(),
            serverRequestIds: [requestId]) == true)
        #expect(TodayViewModel.shouldInjectSeed(
            seedEntries: [entry], seedRequestId: nil,
            serverRequestIds: [requestId]) == true)
    }

    // item 3：兜底找不到待重试行时，气泡 + 卡片追加到末尾——
    // 待重试记录本就注入在最新端（视图停在底部），插 index 0 会让结果出现在历史最顶。
    @Test func retryPendingFallbackAppendsAtEnd() async throws {
        let store = makePendingRetryStore(suite: "retry-fallback-end")
        try store.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        let record = try #require(store.load().first)

        let vm = TodayViewModel(service: RecordingResponseMock(response: .matchingDurable),
                                isConsentGranted: { true })
        vm.pendingRetryStore = store
        let serverEntry = TimelineEntry.userBubble(text: "server history", image: nil)
        vm.entries = [serverEntry]   // 时间线已被刷新重建，找不到待重试行

        await vm.retryPending(record: record)

        #expect(vm.entries.count == 3)
        #expect(vm.entries[0].id == serverEntry.id)   // 原有历史不动
        guard case .userBubble = vm.entries[1].content else {
            Issue.record("Expected appended userBubble"); return
        }
        guard case .aiCard = vm.entries[2].content else {
            Issue.record("Expected appended aiCard"); return
        }
    }

    private func rejectedEntry(_ vm: TodayViewModel) -> (text: String?, wasImage: Bool)? {
        for e in vm.entries {
            if case .userRejected(let t, let w) = e.content { return (t, w) }
        }
        return nil
    }

    // 未同意：只弹同意页 + 暂存输入，不追加气泡 / 卡片 / loading，不触发生成，且保留 inputText
    @Test func sendWithoutConsentShowsSheetAndSkipsGeneration() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { false })
        vm.inputText = "今天会议推迟了"
        await vm.send()

        #expect(vm.showAIConsent == true)
        #expect(vm.inputText == "今天会议推迟了")   // 防丢测试：未同意时草稿完好保留
        #expect(hasBubble(vm) == false)
        #expect(hasCard(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 同意后自动发送并清空 inputText
    @Test func consentAgreedSendsAndClearsInputText() async {
        var consentGranted = false
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { consentGranted })
        vm.inputText = "今天会议推迟了"
        await vm.send()

        #expect(vm.showAIConsent == true)
        #expect(vm.inputText == "今天会议推迟了")

        consentGranted = true
        vm.onConsentAgreed()
        // 等待异步 send 任务落位
        await waitUntil { hasBubble(vm) }

        #expect(vm.showAIConsent == false)
        #expect(vm.inputText == "")              // 放行后输入框被清空
        // 载荷断言：锁住「发的是谁」而不只「是否发」——气泡必须携带暂存原文
        #expect(vm.entries.contains {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "今天会议推迟了" }
            return false
        })
    }

    // 外部传参（如快捷卡片）在同意后发送，不误清输入框内的用户草稿
    @Test func consentAgreedWithExternalTextPreservesDraftInputText() async {
        var consentGranted = false
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { consentGranted })
        vm.inputText = "未发出的草稿"
        await vm.send("外部快捷短语")

        #expect(vm.showAIConsent == true)
        #expect(vm.inputText == "未发出的草稿")

        consentGranted = true
        vm.onConsentAgreed()
        // 等待异步 send 任务落位
        await waitUntil { hasBubble(vm) }

        #expect(vm.showAIConsent == false)
        #expect(vm.inputText == "未发出的草稿")   // 外部发送成功后，用户草稿完好保留
        // 载荷断言：发出的是外部传参文本，而不是用户输入框里的半成品草稿
        #expect(vm.entries.contains {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "外部快捷短语" }
            return false
        })
        #expect(vm.entries.contains {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "未发出的草稿" }
            return false
        } == false)
    }

    // 已同意：门控放行，send() 照常走生成 → 气泡 + 卡片，同意页不弹，inputText 清空
    @Test func sendWithConsentProceedsToGeneration() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.inputText = "今天会议推迟了"
        await vm.send()

        #expect(vm.showAIConsent == false)
        #expect(vm.inputText == "")              // 放行后草稿清空
        #expect(hasBubble(vm) == true)
        #expect(hasCard(vm) == true)
        #expect(vm.isLoading == false)
    }

    // 已同意 + 外部显式传参直发：发送成功且不清空用户输入框内的草稿（第三轮复审 #5：
    // 封住未来快捷卡片调用方按直觉 send(vm.inputText) 导致的「发出但框不清 → 重复发送」）
    @Test func sendWithConsentAndExternalTextPreservesDraftInputText() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.inputText = "正在打的草稿"
        await vm.send("外部快捷短语")

        #expect(vm.showAIConsent == false)
        #expect(vm.inputText == "正在打的草稿")   // 外部直发绝不清用户草稿
        #expect(vm.entries.contains {
            if case .userBubble(let t, _, _, _) = $0.content { return t == "外部快捷短语" }
            return false
        })
        #expect(vm.isLoading == false)
    }

    // onConsentAgreed 同步关闭同意页（无暂存输入时不生成任何内容）
    @Test func consentAgreedClosesSheet() async {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.showAIConsent = true
        vm.onConsentAgreed()
        #expect(vm.showAIConsent == false)
    }

    // 图片被拒：userBubble 就地转 userRejected(wasImage: true)、loading 移除、不再有弹窗字段
    @Test func contentBlockedImageConvertsBubbleToRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == true)
        #expect(r?.text == "Describe this image")
        #expect(hasBubble(vm) == false)     // 原气泡已转换，时间线不再有 userBubble
        #expect(hasCard(vm) == false)       // 回归护栏：被拒路径不应产生卡片
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 文本被拒：气泡文本原样保留、wasImage == false
    @Test func contentBlockedTextKeepsBubbleTextAsRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        await vm.send("something the filter rejects")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == false)
        #expect(r?.text == "something the filter rejects")
        #expect(hasBubble(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 图文混合被拒：文本原样 + wasImage == true
    @Test func contentBlockedMixedKeepsTextAndMarksImage() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("check this photo")

        let r = rejectedEntry(vm)
        #expect(r?.wasImage == true)
        #expect(r?.text == "check this photo")
        #expect(hasBubble(vm) == false)
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }
}

// MARK: - AIService HTTP response classification tests (App Store 合规切片)
//
// LiveAIService.decodeResponse 把服务端响应映射为解码结果或 AIServiceError。
// 这是「服务端安全过滤 → 客户端友好提示」链路的客户端解析半边（Step 5）。
// 用 do/catch 断言具体 case，不依赖 AIServiceError 的 Equatable 合成。

struct AIServiceResponseTests {

    private let validEnvelopeJSON = """
    {
        "card_type": "s4",
        "card_content": {
            "granularity": "sentence",
            "direction": "express",
            "user_original": "今天会议推迟了",
            "target_expression": "Today's meeting got postponed.",
            "learnable_units": [],
            "examples": []
        }
    }
    """.data(using: .utf8)!

    // 422 + {"error":"content_blocked"} → .contentBlocked（安全过滤命中）
    @Test func status422ContentBlockedThrowsContentBlocked() {
        let data = #"{"error":"content_blocked","blockReason":"OUTPUT_SAFETY"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 422, data: data)
            Issue.record("Expected contentBlocked to be thrown")
        } catch AIServiceError.contentBlocked {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 429 + {"error":"daily_limit_reached",…} → .dailyLimitReached(载荷完整)。
    // 前端据此展示达标态（banner + 锁定），而不是误导性的「No connection」。
    @Test func status429DailyLimitReachedCarriesQuotaPayload() {
        let data = #"{"error":"daily_limit_reached","used":5,"limit":5,"resets_at":"2026-09-03T00:00:00+08:00"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 429, data: data)
            Issue.record("Expected dailyLimitReached to be thrown")
        } catch let AIServiceError.dailyLimitReached(used, limit, resetsAt) {
            #expect(used == 5)
            #expect(limit == 5)
            #expect(resetsAt == "2026-09-03T00:00:00+08:00")
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 429 但不是 daily_limit_reached（如网关限流）→ 照旧 .requestFailed，
    // 不把任何 429 都当成额度耗尽。
    @Test func status429OtherErrorThrowsRequestFailed() {
        let data = #"{"error":"rate_limited"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 429, data: data)
            Issue.record("Expected requestFailed to be thrown")
        } catch AIServiceError.dailyLimitReached {
            Issue.record("Must NOT classify a non-daily_limit_reached 429 as quota exhaustion")
        } catch AIServiceError.requestFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 422 但不是 content_blocked → 落到非 2xx 分支 → .requestFailed（不误报被拦）
    @Test func status422OtherErrorThrowsRequestFailed() {
        let data = #"{"error":"rate_limited"}"#.data(using: .utf8)!
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 422, data: data)
            Issue.record("Expected requestFailed to be thrown")
        } catch AIServiceError.contentBlocked {
            Issue.record("Must NOT classify a non-content_blocked 422 as contentBlocked")
        } catch AIServiceError.requestFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 非 2xx（如 500）→ .requestFailed
    @Test func status500ThrowsRequestFailed() {
        let data = Data("Internal Server Error".utf8)
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 500, data: data)
            Issue.record("Expected requestFailed to be thrown")
        } catch AIServiceError.requestFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    // 2xx + 合法 JSON → 正常返回 AIEnvelope
    @Test func status200ValidJSONReturnsEnvelope() throws {
        let envelope = try LiveAIService.decodeResponse(statusCode: 200, data: validEnvelopeJSON)
        guard case .card(let c) = envelope.card else {
            Issue.record("Expected .card"); return
        }
        #expect(c.displayTarget == "Today's meeting got postponed.")
    }

    // 2xx + 坏 JSON → .decodingFailed
    @Test func status200GarbageThrowsDecodingFailed() {
        let data = Data("not json at all".utf8)
        do {
            _ = try LiveAIService.decodeResponse(statusCode: 200, data: data)
            Issue.record("Expected decodingFailed to be thrown")
        } catch AIServiceError.decodingFailed {
            // 通过
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
}

// MARK: - Usage quota store tests (slice 4)

// UsageQuotaStore 已标 @MainActor：实例状态与方法的访问必须在主线程隔离。
@MainActor
struct UsageQuotaStoreTests {

    // refresh 成功：服务器数字与裁决全部落地，refreshFailed 复位。
    @Test func refreshAppliesServerNumbersAndVerdict() async {
        let store = UsageQuotaStore()
        store.fetchQuota = { UsageQuotaStore.QuotaRow(usedCount: 4, limit: 5, allowed: true) }
        await store.refresh()

        #expect(store.usedCount == 4)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == true)
        #expect(store.refreshFailed == false)
    }

    // refresh 失败：标记失败、保留旧值（不把旧数字抹成 nil，也不显示假 0）。
    @Test func refreshFailureKeepsPreviousValuesAndFlags() async {
        let store = UsageQuotaStore()
        store.fetchQuota = { UsageQuotaStore.QuotaRow(usedCount: 2, limit: 5, allowed: true) }
        await store.refresh()

        store.fetchQuota = { throw URLError(.notConnectedToInternet) }
        await store.refresh()

        #expect(store.usedCount == 2)
        #expect(store.dailyLimit == 5)
        #expect(store.refreshFailed == true)
    }

    // 方案 B：成功响应的落账后裁决 false（额度在本次生成用尽）→ 立即锁定，
    // 数字同步更新——用户不用等下一次发送撞 429 才发现。
    @Test func applyUsageWithAllowedFalseLocksImmediately() {
        let store = UsageQuotaStore()
        store.apply(usage: UsageInfo(used: 5, limit: 5, allowed: false, resetsAt: nil))

        #expect(store.usedCount == 5)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == false)
    }

    // 落账后裁决 true（还能继续生成）：旧锁定状态被正确的服务端裁决覆盖。
    @Test func applyUsageWithAllowedTrueOverridesPreviousLock() {
        let store = UsageQuotaStore()
        store.applyServerVerdict(used: 5, limit: 5, allowed: false)
        #expect(store.isAllowed == false)

        store.apply(usage: UsageInfo(used: 1, limit: 5, allowed: true, resetsAt: nil))

        #expect(store.usedCount == 1)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == true)
    }

    // 旧版服务端不返回 allowed → 保持未知态（不锁）：与方案 B 上线前行为一致，
    // 生成成功本身已证明服务端刚放行过一次。
    @Test func applyUsageWithoutAllowedFallsBackToUnknown() {
        let store = UsageQuotaStore()
        store.applyServerVerdict(used: 5, limit: 5, allowed: false)
        #expect(store.isAllowed == false)

        store.apply(usage: UsageInfo(used: 1, limit: 5, allowed: nil, resetsAt: nil))

        #expect(store.usedCount == 1)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == nil)
    }

    // 429 裁决：数字 + allowed=false（输入栏锁定依据）。
    @Test func serverVerdictSetsNumbersAndLocks() {
        let store = UsageQuotaStore()
        store.applyServerVerdict(used: 5, limit: 5, allowed: false)

        #expect(store.usedCount == 5)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == false)
    }

    // 本地日期串必须与「设备的今天」一致（yyyy-MM-dd，gregorian 格式稳定）。
    @Test func localDateStringMatchesDeviceCalendar() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        #expect(UsageQuotaStore.localDateString() == formatter.string(from: Date()))
    }

    // 竞态守卫：refresh 先出发、429 裁决后落地——迟到的 refresh 带着旧数字
    // 回来时必须被丢弃，不得把更新的裁决倒退回旧态。
    @Test func staleRefreshResultDoesNotClobberNewerVerdict() async {
        let store = UsageQuotaStore()
        let (releaseStream, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        let (startedStream, startedContinuation) = AsyncStream.makeStream(of: Void.self)
        var gate = releaseStream.makeAsyncIterator()
        store.fetchQuota = {
            startedContinuation.yield(())
            _ = await gate.next()
            return UsageQuotaStore.QuotaRow(usedCount: 1, limit: 5, allowed: true)
        }

        let refreshTask = Task { await store.refresh() }
        // 等 refresh 已认领世代并挂起在网关上（started 信号 = fetch 已开始）。
        _ = await startedStream.first(where: { _ in true })

        // 更近的 429 裁决先落地。
        store.applyServerVerdict(used: 5, limit: 5, allowed: false)

        releaseContinuation.yield(())
        await refreshTask.value

        #expect(store.usedCount == 5)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == false)
        #expect(store.refreshFailed == false)
    }

    // 同守卫的失败侧：迟到的 refresh 失败也不能把 refreshFailed 从
    // false（更近的裁决已复位）改回 true。
    @Test func staleRefreshFailureDoesNotClobberNewerVerdict() async {
        let store = UsageQuotaStore()
        let (releaseStream, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        let (startedStream, startedContinuation) = AsyncStream.makeStream(of: Void.self)
        var gate = releaseStream.makeAsyncIterator()
        store.fetchQuota = {
            startedContinuation.yield(())
            _ = await gate.next()
            throw URLError(.notConnectedToInternet)
        }

        let refreshTask = Task { await store.refresh() }
        _ = await startedStream.first(where: { _ in true })

        store.applyServerVerdict(used: 5, limit: 5, allowed: false)

        releaseContinuation.yield(())
        await refreshTask.value

        #expect(store.usedCount == 5)
        #expect(store.dailyLimit == 5)
        #expect(store.isAllowed == false)
        #expect(store.refreshFailed == false)
    }

    // 离线缓存：当天缓存存在时，初始化能正确还原数字。
    @Test func cachedUsageRestoredWhenDateMatchesToday() {
        let suiteName = "test_usage_quota_cache_today_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(UsageQuotaStore.localDateString(), forKey: UsageQuotaStore.cachedDateKey)
        defaults.set(3, forKey: UsageQuotaStore.cachedUsedCountKey)
        defaults.set(5, forKey: UsageQuotaStore.cachedDailyLimitKey)

        let store = UsageQuotaStore(defaults: defaults)
        #expect(store.usedCount == 3)
        #expect(store.dailyLimit == 5)
    }

    // 离线缓存过期：非当天（如昨天）缓存被忽略，数字保持 nil。
    @Test func cachedUsageIgnoredWhenDateDoesNotMatchToday() {
        let suiteName = "test_usage_quota_cache_expired_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("2020-01-01", forKey: UsageQuotaStore.cachedDateKey)
        defaults.set(4, forKey: UsageQuotaStore.cachedUsedCountKey)
        defaults.set(5, forKey: UsageQuotaStore.cachedDailyLimitKey)

        let store = UsageQuotaStore(defaults: defaults)
        #expect(store.usedCount == nil)
        #expect(store.dailyLimit == nil)
    }

    // 刷新成功后同步写入持久化缓存。
    @Test func refreshPersistsCacheToDefaults() async {
        let suiteName = "test_usage_quota_cache_persist_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UsageQuotaStore(defaults: defaults)
        store.fetchQuota = { UsageQuotaStore.QuotaRow(usedCount: 2, limit: 5, allowed: true) }

        await store.refresh()

        #expect(defaults.string(forKey: UsageQuotaStore.cachedDateKey) == UsageQuotaStore.localDateString())
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedUsedCountKey) == 2)
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedDailyLimitKey) == 5)
    }

    // 生成成功落账（apply）同步写入持久化缓存（W4）。
    @Test func applyPersistsCacheToDefaults() {
        let suiteName = "test_usage_quota_cache_apply_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UsageQuotaStore(defaults: defaults)
        store.apply(usage: UsageInfo(used: 3, limit: 5, allowed: true, resetsAt: nil))

        #expect(defaults.string(forKey: UsageQuotaStore.cachedDateKey) == UsageQuotaStore.localDateString())
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedUsedCountKey) == 3)
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedDailyLimitKey) == 5)
    }

    // 429 达标裁决（applyServerVerdict）同步写入持久化缓存（W4）。
    @Test func applyServerVerdictPersistsCacheToDefaults() {
        let suiteName = "test_usage_quota_cache_verdict_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UsageQuotaStore(defaults: defaults)
        store.applyServerVerdict(used: 5, limit: 5, allowed: false)

        #expect(defaults.string(forKey: UsageQuotaStore.cachedDateKey) == UsageQuotaStore.localDateString())
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedUsedCountKey) == 5)
        #expect(defaults.integer(forKey: UsageQuotaStore.cachedDailyLimitKey) == 5)
    }
}

// MARK: - Onboarding gate three-state parsing tests

struct OnboardingStateParsingTests {

    // 有行且有完成时间 → completed（同机重装的老用户直接进主界面）
    @Test func rowWithDateMeansCompleted() {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let state = ProfileService.parseOnboardingState(completedDates: [date])
        #expect(state == .completed(date))
    }

    // 有行但完成时间为空 → notCompleted（唯一允许进引导的情况）
    @Test func rowWithNilDateMeansNotCompleted() {
        let state = ProfileService.parseOnboardingState(completedDates: [nil])
        #expect(state == .notCompleted)
    }

    // 查不到行 → missingProfile（数据缺失 ≠ 没走过引导，与 notCompleted 严格区分）
    @Test func emptyRowsMeansMissingProfile() {
        let state = ProfileService.parseOnboardingState(completedDates: [])
        #expect(state == .missingProfile)
    }
}

// MARK: - LocalCache tombstone tests
// LocalCache 已是 actor：所有调用都要 await。
// .serialized 防止并发测试对 LocalCache.shared 的清空/写入相互踩踏。

@Suite(.serialized)
struct LocalCacheTombstoneTests {

    // 加墓碑 → 读缓存时该 ID 被过滤（不再出现）
    @Test func tombstonedIdIsFilteredFromCache() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        let tombstones = await LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString))
        await LocalCache.shared.removeTombstone(id, key: .scenes)
    }

    // 撤销：移除墓碑后 ID 重新出现
    @Test func removeTombstoneRestoresVisibility() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        await LocalCache.shared.removeTombstone(id, key: .scenes)
        let tombstones = await LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.contains(id.uuidString) == false)
    }

    // 成功拉取服务器后清空墓碑（服务器为正本，已不含被删条目）
    @Test func clearTombstonesEmptiesAll() async {
        let id1 = UUID()
        let id2 = UUID()
        await LocalCache.shared.addTombstone(id1, key: .scenes)
        await LocalCache.shared.addTombstone(id2, key: .scenes)
        await LocalCache.shared.clearTombstones(for: .scenes)
        let tombstones = await LocalCache.shared.tombstones(for: .scenes)
        #expect(tombstones.isEmpty)
    }

    // 不同缓存 key 各自独立（不互相污染）
    @Test func tombstonesAreScopedPerKey() async {
        let id = UUID()
        await LocalCache.shared.addTombstone(id, key: .scenes)
        let tab2Tombstones = await LocalCache.shared.tombstones(for: .tab2Home)
        #expect(tab2Tombstones.contains(id.uuidString) == false)
        await LocalCache.shared.removeTombstone(id, key: .scenes)
    }
}

// MARK: - LocalCache tests

@Suite(.serialized)
struct LocalCacheTests {

    @Test func saveThenLoadRoundTrips() async {
        let payload = #"[{"hello":"world"}]"#.data(using: .utf8)!
        await LocalCache.shared.save(payload, key: .tab2Home)
        let loaded = await LocalCache.shared.load(key: .tab2Home)
        #expect(loaded == payload)
        await LocalCache.shared.remove(key: .tab2Home)   // 清理，避免污染其它用例
    }

    @Test func removeThenLoadReturnsNil() async {
        let payload = #"{"x":1}"#.data(using: .utf8)!
        await LocalCache.shared.save(payload, key: .scenes)
        await LocalCache.shared.remove(key: .scenes)
        #expect(await LocalCache.shared.load(key: .scenes) == nil)
    }

    @Test func saveOverwritesPrevious() async {
        await LocalCache.shared.save("old".data(using: .utf8)!, key: .messages)
        await LocalCache.shared.save("new".data(using: .utf8)!, key: .messages)
        let loaded = await LocalCache.shared.load(key: .messages)
        #expect(loaded == "new".data(using: .utf8)!)
        await LocalCache.shared.remove(key: .messages)
    }
}

// MARK: - PendingRetryStore tests

struct PendingRetryStoreTests {

    private func makeStore(suite: String) -> (PendingRetryStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-retry-tests-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    // 删号 / 注销后：记录与其照片文件都必须消失，不能只清索引留下孤儿图片
    @Test func clearAllRemovesRecordsAndTheirPhotoFiles() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-clear-all")
        // 1×1 图即可：这里验的是「文件被连带删除」，不是图片内容
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        try store.saveTab1(text: "hello", image: image, requestId: UUID(), createdAt: Date())
        store.savePreset(cardId: "2", imageName: "card_scene_2", requestId: UUID())
        #expect(store.load().count == 2)

        let filesBefore = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.count ?? 0
        #expect(filesBefore > 0)   // 确认确实落了照片文件，否则这个断言没意义

        store.clearAll()

        #expect(store.load().isEmpty)
        // 新实例读取（杀 app 语义）：确认清除是持久化的，不只是内存态
        #expect(PendingRetryStore(defaults: defaults, documentsDir: dir).load().isEmpty)
        // 照片文件必须一起走，否则 Documents 里会留下永不被引用的孤儿文件
        let filesAfter = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.count ?? 0
        #expect(filesAfter == 0)
    }

    @Test func clearAllOnEmptyStoreIsSafe() {
        // 删号时大概率一条记录都没有——不能因此崩或抛
        let (store, _, _) = makeStore(suite: "pending-retry-clear-empty")
        store.clearAll()
        #expect(store.load().isEmpty)
    }

    // 预设卡记录：写入 → 新实例读取（杀 app 语义）→ 字段完整
    @Test func presetRecordSurvivesReload() {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-preset")
        store.savePreset(cardId: "2", imageName: "card_scene_2", requestId: UUID())

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .presetCard)
        #expect(records[0].presetCardId == "2")
        #expect(records[0].presetImageName == "card_scene_2")
    }

    // 照片记录：照片落盘 → 新实例读取 → 图片往返一致
    @Test func photoRecordSurvivesReloadWithImage() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-photo")
        let image = UIImage(systemName: "photo")!
        let requestId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        try store.savePhoto(image, requestId: requestId)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .photo)
        #expect(records[0].requestId == requestId)
        let restored = reloaded.photoImage(for: records[0])
        #expect(restored != nil)
        // SF Symbol 原图的 point 尺寸与 JPEG 重解码后的像素尺寸不同，只断言图回来了且非空
        #expect(restored?.size != .zero)
    }

    // remove：删除后 load 为空，且照片文件被清理
    @Test func removeClearsRecordAndFile() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-remove")
        let image = UIImage(systemName: "photo")!
        try store.savePhoto(image, requestId: UUID())
        let record = store.load()[0]

        store.remove(id: record.id)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        #expect(reloaded.load().isEmpty)
        #expect(reloaded.photoImage(for: record) == nil)
    }

    // 旧版本 JSON 没有 requestId：升级后仍能读取，身份留空等待后续 Retry 升级。
    @Test func legacyRecordWithoutRequestIdStillDecodes() {
        let (store, _, defaults) = makeStore(suite: "pending-retry-legacy")
        let legacyJSON = """
        [{
          "id":"11111111-2222-3333-4444-555555555555",
          "source":"photo",
          "presetCardId":null,
          "presetImageName":null,
          "photoFileName":"legacy.jpg",
          "createdAt":0
        }]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "pending_retry_records")

        let records = store.load()

        #expect(records.count == 1)
        #expect(records[0].requestId == nil)
    }
}

// MARK: - ImageCache tests

/// **必须串行**：这些测试共用 `ImageCache.shared` 这一个全局单例（同一个磁盘目录）。
/// Swift Testing 默认并行，于是「写入并读回」与「全部清空并断言残留为 0」会互相破坏：
/// 清空方因对方刚写入而报残留，写入方因文件被清空而读不到。两个方向都会红，
/// 而且是间歇性的——2026-08-28 全量跑里真的红过一次，单独跑却过。
///
/// `clearAll()` 那条原本住在 `LocalUserDataTests`（语义上属删号链路），但
/// `.serialized` 只在**同一个 Suite 内**生效，跨 Suite 仍并行。把所有碰
/// `ImageCache.shared` 的测试收进同一个串行 Suite，是改动最小的根治办法。
@MainActor
@Suite(.serialized)
struct ImageCacheTests {

    @Test(arguments: [false, true])
    func refreshedSignedURLRetriesFailedHistoricalImageWithoutChangingRowIdentity(invalidImageData: Bool) async throws {
        let key = "history-url-refresh-\(UUID())"
        let expired = "https://example.com/photo?token=expired"
        let refreshed = "https://example.com/photo?token=refreshed"
        let signedURL = SignedURLTestState(expired)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let data = try #require(image.pngData())
        var requests: [String] = []
        let host = UIHostingController(rootView: CachedRemoteImageRefreshFixture(
            signedURL: signedURL,
            stableKey: key,
            download: { requestedURL in
                requests.append(requestedURL.absoluteString)
                if requestedURL.absoluteString == expired {
                    if invalidImageData { return Data("expired signature".utf8) }
                    throw URLError(.userAuthenticationRequired)
                }
                return data
            }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        for _ in 0..<100 where requests.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(requests == [expired])
        #expect(ImageCache.shared.get(key) == nil)

        // 服务端正本替换缓存：宿主与视图身份保持不变，只更新签名 URL。
        signedURL.value = refreshed
        host.view.layoutIfNeeded()
        for _ in 0..<100 where ImageCache.shared.get(key) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(requests == [expired, refreshed])
        #expect(ImageCache.shared.get(key) != nil)

        // 后续再次重签仍使用已有缓存；链接变化不能造成重复下载。
        signedURL.value = "https://example.com/photo?token=third"
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(requests == [expired, refreshed])
        #expect(ImageCache.shared.get(key) != nil)
    }

    private func makeLocalSuccessStore(suite: String) -> (LocalSuccessStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-success-inject-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (LocalSuccessStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func makePendingRetryStore(suite: String) -> PendingRetryStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-inject-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRetryStore(defaults: defaults, documentsDir: dir)
    }

    @Test func getUnknownKeyReturnsNil() {
        #expect(ImageCache.shared.get("no_such_key_\(UUID().uuidString)") == nil)
    }

    @Test func setThenGetHitsMemory() {
        let key = "mem_\(UUID().uuidString)"
        let image = UIImage(systemName: "star")!
        ImageCache.shared.set(image, forKey: key)
        #expect(ImageCache.shared.get(key) != nil)
    }

    @Test func setThenGetFromDiskAfterMemoryClear() {
        let key = "disk_\(UUID().uuidString)"
        let image = UIImage(systemName: "heart")!
        ImageCache.shared.set(image, forKey: key)
        ImageCache.shared.clearMemoryForTesting()
        // 内存已清，必须从磁盘读
        #expect(ImageCache.shared.get(key) != nil)
    }

    // 图片缓存里存的是用户自己上传的照片。删号后不清 = 一边留着用户照片、
    // 一边宣称「全部数据已删除」。这条锁的是「清完必须真的没了，且能自报残留」。
    // 归属上它是删号链路的一环（原在 LocalUserDataTests），放这里纯粹是为了
    // 和其它碰 ImageCache.shared 的测试共享同一个串行 Suite——见上方说明。
    @Test func clearAllRemovesEverythingAndReportsLeftovers() {
        let cache = ImageCache.shared
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        cache.set(image, forKey: "bucket/user/clear-all-test.jpg")
        #expect(cache.get("bucket/user/clear-all-test.jpg") != nil)

        let leftovers = cache.clearAll()

        #expect(leftovers == 0, "清理应报告 0 残留，否则 UI 不该宣称已清空")
        #expect(cache.get("bucket/user/clear-all-test.jpg") == nil, "内存与磁盘两层都必须清掉")
    }

    // 锁住的是 setIfCurrent 这条「check-then-write 必须原子」的契约本身，而不是
    // 真的起并发线程去撞——generation 不匹配的判断逻辑用单线程就能验证到位；
    // 真正的原子性由 setIfCurrent/clearAll 共用同一把锁保证，这里测的是行为。
    @Test func setIfCurrentRejectsWriteAfterGenerationMoved() {
        let cache = ImageCache.shared
        let key = "bucket/user/set-if-current-\(UUID().uuidString).jpg"
        let staleGeneration = cache.generation
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        cache.clearAll()  // 模拟删号：中途发生的一次清空

        let wrote = cache.setIfCurrent(image, forKey: key, expectedGeneration: staleGeneration)

        #expect(wrote == false, "generation 已变化，不该再写入——否则就是把清完的照片又写回去")
        #expect(cache.get(key) == nil, "被拒绝的写入不能留下任何痕迹")
    }

    @Test func setIfCurrentWritesWhenGenerationStillMatches() {
        let cache = ImageCache.shared
        let key = "bucket/user/set-if-current-\(UUID().uuidString).jpg"
        let currentGeneration = cache.generation
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        let wrote = cache.setIfCurrent(image, forKey: key, expectedGeneration: currentGeneration)

        #expect(wrote == true)
        #expect(cache.get(key) != nil, "generation 未变，应正常写入")
    }

    // 它同样碰到进程级缓存，必须与上方清理测试放在同一个串行 Suite；否则
    // 全量并行时 clearAll() 会在图片移交和断言之间将照片清掉。
    @Test func confirmedPhotoIsPromotedToStableImageCacheBeforeLocalCopyIsRemoved() async throws {
        let (store, _, _) = makeLocalSuccessStore(suite: "promote-confirmed-photo")
        let requestId = UUID()
        let userMessageId = UUID()
        let stableKey = "user_images/test/\(UUID().uuidString).jpg"
        let image = UIImage(systemName: "photo")!
        try store.saveTab1(
            text: nil, image: image, requestId: requestId,
            userMessageId: userMessageId, assistantMessageId: UUID(),
            createdAt: .now, card: .card(CardContent(targetExpression: "A photo."))
        )

        let response = Data("""
        [{
          "id": "\(userMessageId.uuidString)",
          "role": "user",
          "input_type": "image",
          "user_content": "[photo]",
          "signed_image_url": "https://example.com/signed-photo?token=<REDACTED>",
          "image_url": "\(stableKey)",
          "request_id": "\(requestId.uuidString)",
          "created_at": "2026-08-28T12:00:00.000Z"
        }]
        """.utf8)
        let vm = TodayViewModel(
            service: SuccessMock(), historyDataLoader: { response },
            isConsentGranted: { true },
            localCache: LocalCache(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("confirmed-photo-history-cache-\(UUID())", isDirectory: true))
        )
        vm.successStore = store
        vm.pendingRetryStore = makePendingRetryStore(suite: "promote-confirmed-photo-pending")

        await vm.loadHistory()

        #expect(store.load().isEmpty)
        #expect(ImageCache.shared.get(stableKey) != nil)
    }
}

// MARK: - MessageRecord image field propagation tests

struct MessageRecordImageFieldsTests {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let str = try c.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(str)")
        }
        return d
    }()

    @Test func imageRecordPassesBothUrlsToTimelineEntry() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "role": "user",
            "input_type": "image",
            "user_content": "[photo]",
            "signed_image_url": "https://example.com/signed?token=abc",
            "image_url": "user_images/uid123/photo.jpg",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        #expect(record.imagePath == "user_images/uid123/photo.jpg")
        #expect(record.signedImageUrl == "https://example.com/signed?token=abc")

        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, let imageUrl, let stableKey) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Describe this image")
        #expect(imageUrl == "https://example.com/signed?token=abc")
        #expect(stableKey == "user_images/uid123/photo.jpg")
    }

    @Test func textRecordHasNilImageFields() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "role": "user",
            "input_type": "text",
            "user_content": "Hello world",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        #expect(record.imagePath == nil)
        #expect(record.signedImageUrl == nil)

        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, let imageUrl, let stableKey) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Hello world")
        #expect(imageUrl == nil)
        #expect(stableKey == nil)
    }

    @Test func presetCardDefaultsToDescribeThisImage() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "role": "user",
            "input_type": "preset_card",
            "user_content": "[photo]",
            "signed_image_url": "https://example.com/signed?token=xyz",
            "image_url": "user_images/uid123/card.jpg",
            "created_at": "2026-07-08T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let record = try Self.decoder.decode(MessageRecord.self, from: json)
        guard let entry = record.asTimelineEntry(),
              case .userBubble(let text, _, _, _) = entry.content else {
            Issue.record("Expected userBubble entry"); return
        }
        #expect(text == "Describe this image")
    }
}

// MARK: - OnboardingErrorKind classify tests

struct OnboardingErrorKindTests {

    // contentBlocked 优先于一切：即使网络正常也判被拒
    @Test func contentBlockedWinsEvenWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.contentBlocked, isConnected: true) == .contentBlocked)
    }

    // 断网类 URLError 码逐个归 offline
    @Test func offlineURLErrorCodesMapToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.notConnectedToInternet), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.networkConnectionLost), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.dataNotAllowed), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.internationalRoamingOff), isConnected: true) == .offline)
    }

    // NetworkMonitor 兜底：非断网码但设备无网 → offline
    @Test func disconnectedFallbackMapsToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: false) == .offline)
    }

    // 有网时的超时 / 服务器错误 → generic
    @Test func serverAndTimeoutMapToGenericWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: URLError(.badServerResponse), isConnected: true) == .generic)
    }

    // 服务层其它错误与未知错误 → generic
    @Test func otherErrorsMapToGeneric() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.decodingFailed, isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: NSError(domain: "test", code: 1), isConnected: true) == .generic)
    }

    // 状态条文案映射：断网/其它有文案且常驻；被拒不映射（走 toast）
    @Test func failureBarCopyMapping() {
        #expect(OnboardingErrorKind.offline.failureBarCopy == "Network unavailable. Check your network and try again.")
        #expect(OnboardingErrorKind.generic.failureBarCopy == "Something went wrong. Please try again.")
        #expect(OnboardingErrorKind.contentBlocked.failureBarCopy == nil)
    }
}

// MARK: - OnboardingViewModel tests

struct OnboardingViewModelTests {

    private let sampleCard = PresetCard.all[0]   // "Morning coffee"

    // 初始态：全部清零，未选中任何输入
    @Test func initialStateIsEmpty() {
        let vm = OnboardingViewModel(service: SuccessMock())
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorKind == nil)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // 同一张照片第一次生成分配一个 request ID；失败后的 Retry 必须复用它。
    @Test func retryReusesRequestIdForCurrentPhoto() async {
        let service = FailOnceRecordingMock()
        let vm = OnboardingViewModel(service: service, isConnected: { false })

        await vm.startWithImage(UIImage(systemName: "photo")!)
        let firstId = vm.currentRequestId
        await vm.retry()

        #expect(firstId != nil)
        #expect(service.requestIds.count == 2)
        #expect(service.requestIds[0] == firstId)
        #expect(service.requestIds[1] == firstId)
        #expect(vm.currentRequestId == firstId)
    }

    // 换一张图就是新的用户动作，不能复用上一张图的幂等键。
    @Test func replacementPhotoCreatesDifferentRequestId() async {
        let service = RecordingResponseMock()
        let vm = OnboardingViewModel(service: service)

        await vm.startWithImage(UIImage(systemName: "photo")!)
        let firstId = vm.currentRequestId
        await vm.startWithImage(UIImage(systemName: "camera")!)

        #expect(firstId != nil)
        #expect(vm.currentRequestId != nil)
        #expect(vm.currentRequestId != firstId)
        #expect(service.requestIds == [firstId, vm.currentRequestId])
    }

    // generic/解码/401 等失败仍保留当前照片，Continue 时必须可进入 pending。
    @Test func genericFailureLeavesPhotoUnconfirmed() async {
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(vm.currentRequestId != nil)
    }

    // 只有同 request ID 且三个 durable ID 齐全的响应，才是可展示的确认成功。
    @Test func matchingDurableResponseConfirmsPhoto() async {
        let vm = OnboardingViewModel(service: RecordingResponseMock(response: .matchingDurable))

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
        // #8：服务端消息行 ID 被 VM 捕获，随 S1 落库透传（coordinator 读取）。
        #expect(vm.generationUserMessageId != nil)
        #expect(vm.generationAssistantMessageId != nil)
    }

    @Test func mismatchedResponseRequestIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .mismatchedDurable),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func absentResponseRequestIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .absentRequestDurable),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingMaterialIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingMaterial),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingUserMessageIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingUserMessage),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    @Test func missingAssistantMessageIdIsGenericFailureEvenWhenOffline() async {
        let vm = OnboardingViewModel(
            service: RecordingResponseMock(response: .missingAssistantMessage),
            isConnected: { false }
        )

        await vm.startWithImage(UIImage(systemName: "photo")!)

        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
    }

    // A 成功晚于 B 启动时，A 不能把 B 的 loading 收掉，也不能写入 A 的结果/错误。
    @Test @MainActor func staleSuccessCannotMutateReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requests = await service.waitForStartedRequests(2)
        let requestB = requests[1]

        await service.succeed(requestA)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // A 的 contentBlocked 晚到时不能 reject/清空当前 B。
    @Test @MainActor func staleContentBlockedCannotRejectReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requestB = await service.waitForStartedRequests(2)[1]

        await service.fail(requestA, with: .contentBlocked)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // A 的普通失败晚到时不能覆盖 B 的错误态，也不能提前结束 B 的 loading。
    @Test @MainActor func staleGenericFailureCannotMutateReplacementAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service, isConnected: { true })

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]
        vm.reset()
        let taskB = Task { await vm.startWithImage(UIImage(systemName: "camera")!) }
        let requestB = await service.waitForStartedRequests(2)[1]

        await service.fail(requestA, with: .requestFailed)
        await taskA.value

        #expect(vm.currentRequestId == requestB)
        #expect(vm.selectedImage != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading)

        await service.succeed(requestB)
        await taskB.value
        #expect(vm.currentRequestId == requestB)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // loading 期间重复选图必须在改 selection/request ID 前拒绝，不能让活跃请求失去所属输入。
    @Test @MainActor func reentrantImageSelectionDoesNotReplaceActiveAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]

        await vm.startWithImage(UIImage(systemName: "camera")!)

        #expect(vm.currentRequestId == requestA)
        #expect(vm.selectedCard == nil)
        #expect(vm.isLoading)

        await service.succeed(requestA)
        await taskA.value
        #expect(vm.currentRequestId == requestA)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // loading 期间切预设卡也必须在改 selection 前拒绝，旧照片请求仍拥有当前状态。
    @Test @MainActor func reentrantCardSelectionDoesNotReplaceActiveAttempt() async {
        let service = ControllableGenerationMock()
        let vm = OnboardingViewModel(service: service)

        let taskA = Task { await vm.startWithImage(UIImage(systemName: "photo")!) }
        let requestA = await service.waitForStartedRequests(1)[0]

        await vm.startWithCard(sampleCard)

        #expect(vm.currentRequestId == requestA)
        #expect(vm.selectedImage != nil)
        #expect(vm.selectedCard == nil)
        #expect(vm.isLoading)

        await service.succeed(requestA)
        await taskA.value
        #expect(vm.currentRequestId == requestA)
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // startWithCard 成功：selectedCard 已设、selectedImage 清空、generationResult 有值、loading 回 false
    @Test func startWithCardSuccessSetsResult() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: true)
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.selectedCard?.id == sampleCard.id)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult != nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorKind == nil)
    }

    // startWithImage 成功：selectedImage 已设、selectedCard 清空
    @Test func startWithImageSuccessClearsCard() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        // 先选一张卡，再用图片覆盖
        vm.selectedCard = sampleCard
        let image = UIImage(systemName: "photo")!
        await vm.startWithImage(image)
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage != nil)
        #expect(vm.generationResult != nil)
        #expect(vm.isLoading == false)
    }

    // startWithCard 会清掉之前设的 selectedImage
    @Test func startWithCardClearsPreviousImage() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        vm.selectedImage = UIImage(systemName: "photo")!
        await vm.startWithCard(sampleCard)
        #expect(vm.selectedImage == nil)
    }

    // generate 失败（服务器错误类）：errorKind == .generic、generationResult 为 nil、loading 回 false
    @Test func generateFailureSetsErrorKind() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .generic)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
    }

    // retry 成功（第一次断网失败后 retry）：generationResult 有值、errorKind 清空
    @Test func retryAfterFailureSucceeds() async {
        let vm = OnboardingViewModel(service: FailOnceMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        await vm.retry()
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }

    // 预设卡落库成功：presetSavedToServer = true → completeOnboarding 不注入 seed
    // （服务端记录会被 loadHistory 拉到，再注入就重复了）
    @Test func startWithCardSaveSuccessMarksSaved() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: true)
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.generationResult != nil)
        #expect(vm.presetSavedToServer == true)
    }

    // 预设卡落库失败：与自选图「请求失败」同规则——断网档失败态，不展示完整卡片、
    // 粘性标记置位（离开写待重试记录）。不再信 NetworkMonitor（真机飞行模式可能误报有网）。
    @Test func startWithCardSaveFailureFallsToOfflineState() async {
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: false),
            isConnected: { true }   // 监控说有网，但落库失败——以落库结果为真相
        )
        await vm.startWithCard(sampleCard)
        #expect(vm.generationResult == nil)          // 不展示完整卡片
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)            // 断网档
        #expect(vm.offlineFailureOccurred == true)   // 写待重试记录
        #expect(vm.isLoading == false)
    }

    // 预设卡断网：始终真实尝试落库（不预判网络——真机监控不可靠），落库失败 → 不生成内容、
    // errorKind == .offline、粘性标记置位。与自选图断网完全同构。
    @Test func presetCardOfflineFailsSaveAndDoesNotGenerate() async {
        let saver = CountingPresetCardSaver(succeeds: false)   // 模拟断网时落库失败
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { false }
        )
        await vm.startWithCard(PresetCard.all[0])
        #expect(vm.generationResult == nil)          // 落库失败不生成内容
        #expect(saver.callCount == 1)                // 始终真实尝试（不预判）
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
        #expect(vm.isLoading == false)
    }

    // 预设卡有网：落库照常（回归 #28 语义）
    @Test func presetCardOnlineStillSaves() async {
        let saver = CountingPresetCardSaver(succeeds: true)
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { true }
        )
        await vm.startWithCard(sampleCard)
        #expect(saver.callCount == 1)
        #expect(vm.presetSavedToServer == true)
        #expect(vm.errorKind == nil)
        #expect(vm.generationResult != nil)   // 有网生成静态卡内容（#28 显式守护）
    }

    // 断网：errorKind == .offline
    @Test func offlineFailureClassifiedAsOffline() async {
        let vm = OnboardingViewModel(service: OfflineMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
    }

    // 内容被拒：errorKind == .contentBlocked
    @Test func contentBlockedClassifiedAsBlocked() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
    }

    // 被拒：rejectSelection 清空选中（图片不上屏、回空上传区）、errorKind 保留驱动 toast、
    // 粘性标记不受影响
    @Test func contentBlockedRejectsSelectionAndKeepsErrorKind() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
        #expect(vm.selectedImage == nil)
        #expect(vm.selectedCard == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.offlineFailureOccurred == false)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // Try again 链路：断网失败 → 网络恢复 → retry() 原素材重新生成成功
    @Test func retryWhileOfflineFailsSafely() async {
        let vm = OnboardingViewModel(service: OfflineMock(), isConnected: { false })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.generationResult == nil)

        // 模拟网络恢复后的重试：同 VM 不可换 mock——改用「恢复后重新生成」语义：
        // retry() 仍走同一个 OfflineMock 会再失败，因此这里验证 retry 入口存在且再次落 offline。
        await vm.retry()
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
    }

    // reset：所有状态回到初始值
    @Test func resetClearsAllState() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.startWithCard(sampleCard)
        vm.reset()
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorKind == nil)
        #expect(vm.currentRequestId == nil)
        #expect(vm.hasUnconfirmedPhotoGeneration == false)
    }

    // 无选中时 generate 早退：isLoading 回 false，不修改其他状态
    @Test func generateWithNoSelectionExitsEarly() async {
        let vm = OnboardingViewModel(service: SuccessMock())
        await vm.generate()
        #expect(vm.isLoading == false)
        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == nil)
    }

    // 断网失败的粘性标记：状态条不随恢复消失（errorKind 保留到用户行动），
    // 粘性标记只在 reset() 时抹掉——离开时仍写待重试记录（防内容丢失窗口）
    @Test func offlineFailureFlagIsStickyUntilReset() async {
        let vm = OnboardingViewModel(service: OfflineMock(), isConnected: { false })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)

        // 失败态保留：不自动清除（重试入口稳定）
        #expect(vm.errorKind == .offline)

        vm.reset()
        #expect(vm.errorKind == nil)
        #expect(vm.offlineFailureOccurred == false)
    }
}

// MARK: - Onboarding completion ordering tests

struct OnboardingCompletionCoordinatorTests {

    private func makeStore(suite: String) -> (PendingRetryStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-completion-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func makeSuccessStore(suite: String) -> (LocalSuccessStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-success-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (LocalSuccessStore(defaults: defaults, documentsDir: dir), defaults)
    }

    // pending 照片必须先落盘，之后才能写本地完成/同步标记并离开 onboarding。
    @Test func unconfirmedPhotoPersistsBeforeCompletionMarkersAndExit() async {
        let (store, _, defaults) = makeStore(suite: "completion-order")
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        let requestId = vm.currentRequestId
        var events: [String] = []
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            successStore: makeSuccessStore(suite: "completion-order").0,
            defaults: defaults,
            setSyncPending: {
                #expect(store.load().first?.requestId == requestId)
                #expect(defaults.double(forKey: "onboarding_completed_at") > 0)
                events.append("sync-pending")
            },
            startRemoteSync: {
                #expect(store.load().first?.requestId == requestId)
                events.append("remote-sync")
            }
        )

        let completed = coordinator.complete(viewModel: vm) {
            #expect(store.load().first?.requestId == requestId)
            #expect(defaults.double(forKey: "onboarding_completed_at") > 0)
            events.append("complete")
        }

        #expect(completed)
        #expect(events == ["sync-pending", "remote-sync", "complete"])
        #expect(store.load().count == 1)
    }

    // JPEG 写失败时必须留在 onboarding；完成标记、同步和退出都不可发生。
    @Test func jpegPersistenceFailureKeepsOnboardingOpen() async {
        let suite = "completion-jpeg-failure"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let missingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        let store = PendingRetryStore(defaults: defaults, documentsDir: missingDir)
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var sideEffectCount = 0
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            successStore: makeSuccessStore(suite: "completion-jpeg-failure").0,
            defaults: defaults,
            setSyncPending: { sideEffectCount += 1 },
            startRemoteSync: { sideEffectCount += 1 }
        )

        let completed = coordinator.complete(viewModel: vm) { sideEffectCount += 1 }

        #expect(completed == false)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(defaults.double(forKey: "onboarding_completed_at") == 0)
        #expect(sideEffectCount == 0)
    }

    // 元数据写失败与 JPEG 失败同等处理，不能只保住文件却误报 onboarding 已完成。
    @Test func metadataPersistenceFailureKeepsOnboardingOpen() async {
        let (_, dir, defaults) = makeStore(suite: "completion-metadata-failure")
        let store = PendingRetryStore(
            defaults: defaults,
            documentsDir: dir,
            metadataWriter: { _ in throw NSError(domain: "test", code: 9) }
        )
        let vm = OnboardingViewModel(service: FailingMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var sideEffectCount = 0
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            successStore: makeSuccessStore(suite: "completion-metadata-failure").0,
            defaults: defaults,
            setSyncPending: { sideEffectCount += 1 },
            startRemoteSync: { sideEffectCount += 1 }
        )

        let completed = coordinator.complete(viewModel: vm) { sideEffectCount += 1 }

        #expect(completed == false)
        #expect(vm.errorKind == .generic)
        #expect(vm.hasUnconfirmedPhotoGeneration)
        #expect(defaults.double(forKey: "onboarding_completed_at") == 0)
        #expect(store.load().isEmpty)
        #expect(sideEffectCount == 0)
    }

    // 预设卡落库失败（断网档）：待重试记录必须带上 startWithCard 分配的 requestId，
    // 与照片路径同构——这是预设卡接入原子提交 RPC 后幂等键的落地验证。
    @Test func unconfirmedPresetCardPersistsWithRequestIdBeforeCompletionMarkersAndExit() async {
        let (store, _, defaults) = makeStore(suite: "completion-preset-order")
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: PresetCardSavingMock(succeeds: false),
            isConnected: { true }
        )
        await vm.startWithCard(PresetCard.all[0])
        let requestId = vm.currentRequestId
        var events: [String] = []
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            successStore: makeSuccessStore(suite: "completion-preset-order").0,
            defaults: defaults,
            setSyncPending: {
                #expect(store.load().first?.requestId == requestId)
                events.append("sync-pending")
            },
            startRemoteSync: { events.append("remote-sync") }
        )

        let completed = coordinator.complete(viewModel: vm) { events.append("complete") }

        #expect(completed)
        #expect(requestId != nil)
        #expect(events == ["sync-pending", "remote-sync", "complete"])
        #expect(store.load().count == 1)
        #expect(store.load().first?.source == .presetCard)
    }

    // 已由匹配 durable 响应确认的照片不需要 pending 副本；
    // S1：确认成功要写入本地成功增量（冷启动秒显的来源）。
    @Test func confirmedPhotoCompletesWithoutPendingRecord() async {
        let (store, _, defaults) = makeStore(suite: "completion-confirmed")
        let successStore = makeSuccessStore(suite: "completion-confirmed").0
        let vm = OnboardingViewModel(service: RecordingResponseMock(response: .matchingDurable))
        await vm.startWithImage(UIImage(systemName: "photo")!)
        var didComplete = false
        let coordinator = OnboardingCompletionCoordinator(
            pendingRetryStore: store,
            successStore: successStore,
            defaults: defaults,
            setSyncPending: {},
            startRemoteSync: {}
        )

        let completed = coordinator.complete(viewModel: vm) { didComplete = true }

        #expect(completed)
        #expect(didComplete)
        #expect(store.load().isEmpty)
        #expect(successStore.load().count == 1)   // 成功增量已落本地
    }
}

// MARK: - ProfileService pending sync tests

struct ProfileServicePendingSyncTests {

    // 待办标记的生命周期：默认无 → 置位 → 清除。用独立 suite 隔离 .standard。
    @Test func pendingSyncLifecycle() {
        let suite = "profile-service-pending-tests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == false)

        ProfileService.setOnboardingSyncPending(true, defaults: defaults)
        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == true)

        ProfileService.setOnboardingSyncPending(false, defaults: defaults)
        #expect(ProfileService.hasPendingOnboardingSync(defaults: defaults) == false)
    }
}

// MARK: - MessageRecord asset 前缀解析

struct MessageRecordAssetPathTests {

    // "asset:<imageName>" 是预设卡图片的本地素材引用（storage 签名对其无意义）
    @Test func assetPrefixExtractsImageName() {
        #expect(MessageRecord.assetImageName(fromPath: "asset:card_scene_1") == "card_scene_1")
    }

    // storage 路径与空值不误判为素材引用
    @Test func nonAssetPathsReturnNil() {
        #expect(MessageRecord.assetImageName(fromPath: nil) == nil)
        #expect(MessageRecord.assetImageName(fromPath: "materials/abc.jpg") == nil)
        #expect(MessageRecord.assetImageName(fromPath: "asset:") == nil)
        #expect(MessageRecord.assetImageName(fromPath: "asset") == nil)
    }

    // get-messages 契约新增 request_id（幂等键）：新行正常解码；
    // 老行缺该字段 → nil，不得打断整组 [MessageRecord] 的解码。
    @Test func requestIdDecodesWithNullFallback() throws {
        // 与 TodayViewModel.decodeRecords 相同的日期策略（ISO8601 带小数秒）
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Bad date: \(str)"
            )
        }

        let base: [String: Any] = [
            "id": "A9D7E4B2-7B4C-4E7A-A81D-9E122D101001",
            "role": "user",
            "input_type": "text",
            "user_content": "今天会议推迟了",
            "image_url": NSNull(),
            "card_type": NSNull(),
            "card_content": NSNull(),
            "created_at": "2026-08-21T12:00:00.000Z"
        ]

        var withId = base
        withId["request_id"] = "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002"
        let dataWithId = try JSONSerialization.data(withJSONObject: withId)
        let recordWithId = try #require(
            try decoder.decode(MessageRecord.self, from: dataWithId)
        )
        #expect(recordWithId.requestId == UUID(uuidString: "B8C6D3A1-6A3B-4D6A-B70C-8D011C202002"))

        // 老行无 request_id：解码为 nil，且同批新行不受影响
        var withoutId = base
        withoutId["id"] = "C7B5C2D0-5B2A-4C5B-A60D-7C901B303003"
        let mixed: [[String: Any]] = [withId, withoutId]
        let dataMixed = try JSONSerialization.data(withJSONObject: mixed)
        let records = try decoder.decode([MessageRecord].self, from: dataMixed)
        #expect(records.count == 2)
        #expect(records[1].requestId == nil)
    }
}

// MARK: - Tab2WordEntry decode tests

struct Tab2WordEntryDecodeTests {

    // 辅助：从字段字典构造 Tab2WordEntry
    private func entry(
        lemma: String = "blanch",
        entryKind: String? = nil,
        granularity: String? = "sentence",
        sourceType: String? = "material",
        nativeMeaning: String? = nil,
        imageUrl: String? = nil
    ) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": lemma]
        if let v = entryKind    { fields["entry_kind"]     = v }
        if let v = granularity  { fields["granularity"]    = v }
        if let v = sourceType   { fields["source_type"]    = v }
        if let v = nativeMeaning { fields["native_meaning"] = v }
        if let v = imageUrl     { fields["image_url"]      = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // native_meaning 有值时正确解码
    @Test func nativeMeaningDecoded() throws {
        let e = try entry(nativeMeaning: "焯水")
        #expect(e.nativeMeaning == "焯水")
    }

    // native_meaning 缺失时为 nil，不抛错
    @Test func nativeMeaningMissingIsNil() throws {
        let e = try entry()
        #expect(e.nativeMeaning == nil)
    }

    // granularity=word → sourceTag=.word
    @Test func sourceTagWordForWordGranularity() throws {
        let e = try entry(granularity: "word", sourceType: "material")
        #expect(e.sourceTag == .word)
    }

    // granularity=passage → sourceTag=.passage
    @Test func sourceTagPassageForPassageGranularity() throws {
        let e = try entry(granularity: "passage", sourceType: "material")
        #expect(e.sourceTag == .passage)
    }

    // sourceType=dialogue 优先级高于 granularity
    @Test func sourceTagDialogueTakesPriority() throws {
        let e = try entry(granularity: "sentence", sourceType: "dialogue")
        #expect(e.sourceTag == .dialogue)
    }

    // 默认（granularity=sentence）→ sourceTag=.sentence
    @Test func sourceTagDefaultIsSentence() throws {
        let e = try entry(granularity: "sentence", sourceType: "material")
        #expect(e.sourceTag == .sentence)
    }

    // granularity=nil → 默认 .sentence（不崩溃）
    @Test func sourceTagFallsBackToSentenceWhenNil() throws {
        let e = try entry(granularity: nil)
        #expect(e.sourceTag == .sentence)
    }
}

// MARK: - Tab2WordEntry badge icon tests

struct Tab2WordEntryBadgeTests {

    private func entry(
        granularity: String? = "sentence",
        sourceType: String? = "material",
        entryKind: String? = nil
    ) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": "test"]
        if let v = granularity  { fields["granularity"] = v }
        if let v = sourceType   { fields["source_type"] = v }
        if let v = entryKind    { fields["entry_kind"]  = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // 分类型图标家族：查词→放大镜；句中单词→衬线 A；短语→text.quote；习语/俚语→bubble.left。

    // 主动查词 (.word sourceTag) → 放大镜
    @Test func lookupWordUsesMagnifier() throws {
        let e = try entry(granularity: "word", sourceType: "material")
        #expect(e.badgeGlyph == .symbol("magnifyingglass"))
    }

    // 对话来源 (.dialogue) → 声波（未上线，保留）
    @Test func dialogueUsesWaveform() throws {
        let e = try entry(granularity: "sentence", sourceType: "dialogue")
        #expect(e.badgeGlyph == .symbol("waveform"))
    }

    // 句子/段落里的单词 → 衬线字母 A
    @Test func sentenceWordUsesSerifLetter() throws {
        #expect(try entry(granularity: "sentence", entryKind: "word").badgeGlyph == .serifLetter("A"))
        #expect(try entry(granularity: "passage", entryKind: "word").badgeGlyph == .serifLetter("A"))
    }

    // 短语 / 搭配 / 句型 → text.quote
    @Test func phraseKindUsesTextQuote() throws {
        for kind in ["phrase", "collocation", "pattern"] {
            #expect(try entry(entryKind: kind).badgeGlyph == .symbol("text.quote"))
        }
    }

    // 习语 / 俚语 → bubble.left
    @Test func idiomSlangUsesBubble() throws {
        for kind in ["idiom", "slang"] {
            #expect(try entry(entryKind: kind).badgeGlyph == .symbol("bubble.left"))
        }
    }

    // 未知 entryKind / nil → 默认 text.quote（当短语处理）
    @Test func unknownOrNilKindDefaultsTextQuote() throws {
        #expect(try entry(entryKind: "unknown_future_kind").badgeGlyph == .symbol("text.quote"))
        #expect(try entry(entryKind: nil).badgeGlyph == .symbol("text.quote"))
    }
}

// MARK: - SceneCategoryMap tests

struct SceneCategoryMapTests {

    @Test func knownCategoryMapsToCorrectCase() {
        #expect(SceneCategory.from("工作与学业") == .workStudy)
        #expect(SceneCategory.from("饮食") == .food)
        #expect(SceneCategory.from("家庭与人际") == .homeFamily)
        #expect(SceneCategory.from("休闲娱乐") == .leisure)
    }

    @Test func nilRawValueFallsToOther() {
        #expect(SceneCategory.from(nil) == .other)
    }

    @Test func unknownRawValueFallsToOther() {
        #expect(SceneCategory.from("不存在的分类") == .other)
    }

    @Test func englishLabelsMatchExpected() {
        #expect(SceneCategory.workStudy.englishLabel == "Work & study")
        #expect(SceneCategory.food.englishLabel == "Food")
        #expect(SceneCategory.homeFamily.englishLabel == "Home & people")
        #expect(SceneCategory.other.englishLabel == "Other")
        #expect(SceneCategory.leisure.englishLabel == "Leisure")
    }
}

// MARK: - Tab2HomeData JSON decode tests

struct Tab2HomeDataDecodeTests {

    private let decoder = JSONDecoder()

    @Test func decodesFullPayloadWithSubScenesAndDate() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 12,
            "categories": [
                {
                    "scene_category": "工作与学业",
                    "word_count": 8,
                    "unlocked": true,
                    "last_material_at": "2026-07-25T10:00:00.000Z",
                    "sub_scenes": [
                        {
                            "scene_detail": "Team meeting",
                            "occurrence_count": 3,
                            "quote": "We had a long meeting",
                            "image_url": null
                        }
                    ],
                    "preview_words": ["overtime", "deadline"]
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.unlocked == true)
        #expect(home.inputCount == 12)
        #expect(home.categories.count == 1)

        let cat = home.categories[0]
        #expect(cat.sceneCategory == "工作与学业")
        #expect(cat.wordCount == 8)
        #expect(cat.unlocked == true)
        #expect(cat.lastMaterialAt != nil)
        #expect(cat.englishLabel == "Work & study")
        #expect(cat.previewWords.map(\.lemma) == ["overtime", "deadline"])

        let scene = cat.subScenes[0]
        #expect(scene.sceneDetail == "Team meeting")
        #expect(scene.occurrenceCount == 3)
        #expect(scene.quote == "We had a long meeting")
        #expect(scene.imageUrl == nil)
    }

    @Test func missingOptionalFieldsDefaultToEmpty() throws {
        let json = """
        {
            "unlocked": false,
            "input_count": 3,
            "categories": [
                {
                    "scene_category": "饮食",
                    "word_count": 2,
                    "unlocked": false
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        let cat = home.categories[0]
        #expect(cat.subScenes.isEmpty)
        #expect(cat.previewWords.isEmpty)
        #expect(cat.lastMaterialAt == nil)
    }

    @Test func decodesLegacyStringPreviewWords() throws {
        let json = """
        {
            "scene_category": "科技数码",
            "word_count": 2,
            "unlocked": true,
            "preview_words": ["back up", "glitch"]
        }
        """.data(using: .utf8)!

        let category = try decoder.decode(Tab2CategoryData.self, from: json)

        #expect(category.previewWords.map(\.lemma) == ["back up", "glitch"])
        #expect(category.previewWords.allSatisfy { $0.displayForm == nil })
    }

    @Test func decodesObjectPreviewWords() throws {
        let json = """
        {
            "scene_category": "科技数码",
            "word_count": 1,
            "unlocked": true,
            "preview_words": [
                {
                    "lemma": "back up",
                    "display_form": "backed up",
                    "pos": "verb",
                    "native_meaning": "备份"
                }
            ]
        }
        """.data(using: .utf8)!

        let category = try decoder.decode(Tab2CategoryData.self, from: json)

        #expect(category.previewWords.count == 1)
        #expect(category.previewWords[0].lemma == "back up")
        #expect(category.previewWords[0].displayForm == "backed up")
        #expect(category.previewWords[0].pos == "verb")
        #expect(category.previewWords[0].nativeMeaning == "备份")
    }

    @Test func malformedPreviewWordsFallsBackToEmpty() throws {
        let json = """
        {
            "scene_category": "科技数码",
            "word_count": 1,
            "unlocked": true,
            "preview_words": { "lemma": "back up" }
        }
        """.data(using: .utf8)!

        let category = try decoder.decode(Tab2CategoryData.self, from: json)

        #expect(category.previewWords.isEmpty)
    }

    @Test func lastMaterialAtParsesISO8601() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 5,
            "categories": [
                {
                    "scene_category": "其他",
                    "word_count": 1,
                    "unlocked": true,
                    "last_material_at": "2026-07-20T08:30:00.000Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        let date = home.categories[0].lastMaterialAt
        #expect(date != nil)
        let after = ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z")!
        #expect(date! > after)
    }

    @Test func emptyCategoriesArray() throws {
        let json = """
        {"unlocked": false, "input_count": 0, "categories": []}
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.categories.isEmpty)
    }

    @Test func unknownSceneCategoryFallsToOtherLabel() throws {
        let json = """
        {
            "unlocked": true,
            "input_count": 1,
            "categories": [
                {"scene_category": "未知分类", "word_count": 1, "unlocked": true}
            ]
        }
        """.data(using: .utf8)!

        let home = try decoder.decode(Tab2HomeData.self, from: json)
        #expect(home.categories[0].englishLabel == "Other")
    }
}

// MARK: - Tab2HomeViewModel.heroCategory() tests

struct Tab2HeroCategoryTests {

    private let now = Date(timeIntervalSince1970: 1_788_153_600)

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "tab2-hero-tests-\(UUID().uuidString)")!
    }

    private func makeCategory(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        lastMaterialAt: Date? = nil,
        featuredCreatedAt: Date? = nil,
        subSceneDetails: [String] = []
    ) -> Tab2CategoryData {
        let featured: Tab2FeaturedMoment? = featuredCreatedAt.map { createdAt in
            Tab2FeaturedMoment(
                sceneDetail: subSceneDetails.first ?? "Scene", occurrenceCount: 1,
                materialId: "m-\(sceneCategory)",
                userOriginal: "some original", targetExpression: "some target",
                nativeMeaning: nil, imageUrl: nil, inputLang: "native",
                sourceDirection: "express", sourceGranularity: "sentence",
                createdAt: createdAt, spokenCount: 0
            )
        }
        return Tab2CategoryData(
            sceneCategory: sceneCategory,
            wordCount: wordCount,
            unlocked: unlocked,
            lastMaterialAt: lastMaterialAt,
            subScenes: subSceneDetails.map {
                Tab2SubScene(
                    sceneDetail: $0, occurrenceCount: 1, quote: nil,
                    targetExpression: nil, imageUrl: nil
                )
            },
            featured: featured
        )
    }

    @Test func nilDataReturnsNil() {
        let vm = Tab2HomeViewModel()
        vm.data = nil
        #expect(vm.heroCategory() == nil)
    }

    @Test func noUnlockedCategoriesReturnsNil() {
        let vm = Tab2HomeViewModel()
        vm.data = Tab2HomeData(unlocked: false, inputCount: 2, categories: [
            makeCategory(sceneCategory: "工作与学业", wordCount: 5, unlocked: false),
            makeCategory(sceneCategory: "饮食", wordCount: 3, unlocked: false)
        ])
        #expect(vm.heroCategory() == nil)
    }

    @Test func noFeaturedFallsBackToHighestWordCount() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let low  = makeCategory(sceneCategory: "工作与学业", wordCount: 10, unlocked: true)
        let high = makeCategory(sceneCategory: "饮食", wordCount: 20, unlocked: true)
        vm.data = Tab2HomeData(unlocked: true, inputCount: 5, categories: [low, high])
        let hero = vm.heroCategory()
        #expect(hero?.sceneCategory == "饮食")
        #expect(hero?.wordCount == 20)
    }

    @Test func prefersCategoryWithFeaturedOverHigherWordCount() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let featuredCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 5, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Team meeting"]
        )
        let wordRichCat = makeCategory(
            sceneCategory: "饮食", wordCount: 50, unlocked: true
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 8, categories: [wordRichCat, featuredCat])
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")
    }

    @Test func recentFeaturedWinsWhenBothCategoriesHaveFeaturedMoments() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let older = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let newer = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let oldCat = makeCategory(
            sceneCategory: "家庭与人际", wordCount: 15, unlocked: true,
            featuredCreatedAt: older, subSceneDetails: ["Family dinner"]
        )
        let newCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: newer, subSceneDetails: ["Team meeting"]
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 10, categories: [oldCat, newCat])
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")
    }

    @Test func moreMomentsWinsInsideRecentBucket() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let oneMoment = makeCategory(
            sceneCategory: "工作与学业", wordCount: 20, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 24 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        let twoMoments = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            subSceneDetails: ["Making breakfast", "Ordering lunch"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 10, categories: [oneMoment, twoMoments]
        )

        #expect(vm.heroCategory()?.sceneCategory == "饮食")
    }

    @Test func recentLastMaterialAtDoesNotOverrideFeaturedRecency() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let pollutedByLookup = makeCategory(
            sceneCategory: "科技与数码", wordCount: 30, unlocked: true,
            lastMaterialAt: now,
            featuredCreatedAt: now.addingTimeInterval(-20 * 24 * 60 * 60),
            subSceneDetails: ["Fixing a device"]
        )
        let genuinelyRecent = makeCategory(
            sceneCategory: "休闲娱乐", wordCount: 5, unlocked: true,
            lastMaterialAt: now.addingTimeInterval(-30 * 24 * 60 * 60),
            featuredCreatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            subSceneDetails: ["Watching a game"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 12, categories: [pollutedByLookup, genuinelyRecent]
        )

        #expect(vm.heroCategory()?.sceneCategory == "休闲娱乐")
    }

    @Test func heroStaysStableUntilANewMomentArrives() {
        let defaults = makeDefaults()
        let vm = Tab2HomeViewModel(defaults: defaults, now: { now })
        let first = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-2 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        let second = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-3 * 60 * 60),
            subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 6, categories: [first, second])
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")

        let refreshedSecond = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 60 * 60),
            subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 6, categories: [first, refreshedSecond]
        )
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")

        let secondWithNewMoment = makeCategory(
            sceneCategory: "饮食", wordCount: 11, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 60 * 60),
            subSceneDetails: ["Making breakfast", "Ordering lunch"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 7, categories: [first, secondWithNewMoment]
        )
        #expect(vm.heroCategory()?.sceneCategory == "饮食")
    }

    @Test func heroRemainsStableEvenAfterRecencyWindowPasses() {
        var currentNow = now
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { currentNow })
        let recent = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-6 * 24 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        let olderWithMoreMoments = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
            subSceneDetails: ["Making breakfast", "Ordering lunch"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 8, categories: [recent, olderWithMoreMoments]
        )
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")

        // 时间越过 7 天窗口（若重排会翻到 moment 更多的 饮食），
        // 但没有新 moment 出现 → 复用 heroMaterialID 保持稳定。
        currentNow = now.addingTimeInterval(2 * 24 * 60 * 60)
        #expect(vm.heroCategory()?.sceneCategory == "工作与学业")
    }
}

// MARK: - Tab2HomeViewModel.moreCategories() tests

struct Tab2MoreCategoriesTests {

    private let now = Date(timeIntervalSince1970: 1_788_153_600)

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "tab2-more-tests-\(UUID().uuidString)")!
    }

    private func makeCategory(
        sceneCategory: String,
        wordCount: Int,
        unlocked: Bool,
        lastMaterialAt: Date? = nil,
        featuredCreatedAt: Date? = nil,
        subSceneDetails: [String] = []
    ) -> Tab2CategoryData {
        let featured: Tab2FeaturedMoment? = featuredCreatedAt.map { createdAt in
            Tab2FeaturedMoment(
                sceneDetail: subSceneDetails.first ?? "Scene", occurrenceCount: 1,
                materialId: "m-\(sceneCategory)",
                userOriginal: "some original", targetExpression: "some target",
                nativeMeaning: nil, imageUrl: nil, inputLang: "native",
                sourceDirection: "express", sourceGranularity: "sentence",
                createdAt: createdAt, spokenCount: 0
            )
        }
        return Tab2CategoryData(
            sceneCategory: sceneCategory,
            wordCount: wordCount,
            unlocked: unlocked,
            lastMaterialAt: lastMaterialAt,
            subScenes: subSceneDetails.map {
                Tab2SubScene(
                    sceneDetail: $0, occurrenceCount: 1, quote: nil,
                    targetExpression: nil, imageUrl: nil
                )
            },
            featured: featured
        )
    }

    @Test func twoGroupsFeaturedBeforeWordsOnlyReturnGroupOrder() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let featuredOlder = makeCategory(
            sceneCategory: "工作与学业", wordCount: 5, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 24 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        let featuredNewer = makeCategory(
            sceneCategory: "家庭与人际", wordCount: 9, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 60 * 60),
            subSceneDetails: ["Calling family"]
        )
        let wordsOnly = makeCategory(
            sceneCategory: "饮食", wordCount: 99, unlocked: true
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 3, categories: [wordsOnly, featuredNewer, featuredOlder]
        )

        let more = vm.moreCategories(hero: nil)
        // 组 1 有 featured：同处 7 天新近桶、moment 数打平 → featured 时间定序；
        // 组 2 纯查词（无 featured）即使词更多也整组排后。
        #expect(more.map(\.sceneCategory) == ["家庭与人际", "工作与学业", "饮食"])
    }

    @Test func heroCategoryIsExcluded() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let heroCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Team meeting"]
        )
        let other = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [heroCat, other]
        )

        let more = vm.moreCategories(hero: heroCat)
        #expect(more.map(\.sceneCategory) == ["饮食"])
    }

    @Test func excludedCategoryIDsAreFiltered() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let milestone = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Team meeting"]
        )
        let visible = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [milestone, visible]
        )

        let more = vm.moreCategories(excluding: ["工作与学业"], hero: nil)
        #expect(more.map(\.sceneCategory) == ["饮食"])
    }

    @Test func lockedCategoriesAreFiltered() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let locked = makeCategory(
            sceneCategory: "科技与数码", wordCount: 40, unlocked: false,
            featuredCreatedAt: now, subSceneDetails: ["Fixing a device"]
        )
        let visible = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [locked, visible]
        )

        let more = vm.moreCategories(hero: nil)
        #expect(more.map(\.sceneCategory) == ["饮食"])
    }

    @Test func group1RecentFeaturedBeatsOlder() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let older = makeCategory(
            sceneCategory: "家庭与人际", wordCount: 15, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
            subSceneDetails: ["Family dinner"]
        )
        let recent = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [older, recent]
        )

        let more = vm.moreCategories(hero: nil)
        #expect(more.map(\.sceneCategory) == ["工作与学业", "家庭与人际"])
    }

    @Test func group1MoreMomentsFirstInsideRecentBucket() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let oneMoment = makeCategory(
            sceneCategory: "工作与学业", wordCount: 20, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-1 * 24 * 60 * 60),
            subSceneDetails: ["Team meeting"]
        )
        let twoMoments = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            subSceneDetails: ["Making breakfast", "Ordering lunch"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [oneMoment, twoMoments]
        )

        let more = vm.moreCategories(hero: nil)
        #expect(more.map(\.sceneCategory) == ["饮食", "工作与学业"])
    }

    @Test func recentLastMaterialAtDoesNotOverrideFeaturedRecency() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let pollutedByLookup = makeCategory(
            sceneCategory: "科技与数码", wordCount: 30, unlocked: true,
            lastMaterialAt: now,
            featuredCreatedAt: now.addingTimeInterval(-20 * 24 * 60 * 60),
            subSceneDetails: ["Fixing a device"]
        )
        let genuinelyRecent = makeCategory(
            sceneCategory: "休闲娱乐", wordCount: 5, unlocked: true,
            lastMaterialAt: now.addingTimeInterval(-30 * 24 * 60 * 60),
            featuredCreatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            subSceneDetails: ["Watching a game"]
        )
        vm.data = Tab2HomeData(
            unlocked: true, inputCount: 2, categories: [pollutedByLookup, genuinelyRecent]
        )

        let more = vm.moreCategories(hero: nil)
        #expect(more.map(\.sceneCategory) == ["休闲娱乐", "科技与数码"])
    }

    @Test func emptyCandidatesReturnsEmpty() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        #expect(vm.moreCategories(hero: nil).isEmpty)

        let heroCat = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Team meeting"]
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 1, categories: [heroCat])
        #expect(vm.moreCategories(hero: heroCat).isEmpty)
    }

    @Test func nilHeroExcludesNothing() {
        let vm = Tab2HomeViewModel(defaults: makeDefaults(), now: { now })
        let a = makeCategory(
            sceneCategory: "工作与学业", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Team meeting"]
        )
        let b = makeCategory(
            sceneCategory: "饮食", wordCount: 10, unlocked: true,
            featuredCreatedAt: now, subSceneDetails: ["Making breakfast"]
        )
        vm.data = Tab2HomeData(unlocked: true, inputCount: 2, categories: [a, b])

        #expect(vm.moreCategories(hero: nil).count == 2)
    }
}

// MARK: - Tab2HeroCard 模式判据 tests（§4.2）

struct Tab2HeroCardModeTests {

    // 英文输入（input_lang=target）→ 模式 A（引号）
    @Test func targetInputIsModeA() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "I'm exhausted.", inputLang: "target", hasFeatured: true) == .a)
    }

    // 母语输入（native）→ 模式 B（无引号 + 注脚）
    @Test func nativeInputIsModeB() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "太累了", inputLang: "native", hasFeatured: true) == .b)
    }

    // 第三语言（other）按非目标语言 → 模式 B（不加引号）
    @Test func otherLangIsModeB() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "疲れた", inputLang: "other", hasFeatured: true) == .b)
    }

    // user_original 为空（纯图片）→ 模式 C
    @Test func nilUserOriginalIsModeC() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: nil, inputLang: nil, hasFeatured: true) == .c)
    }

    // user_original 空字符串也当纯图片 → 模式 C
    @Test func emptyUserOriginalIsModeC() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "", inputLang: nil, hasFeatured: true) == .c)
    }

    // 无 featured（分类全查词）→ 模式 D
    @Test func noFeaturedIsModeD() {
        #expect(Tab2HeroCard.featuredMode(userOriginal: "x", inputLang: "target", hasFeatured: false) == .d)
    }
}

// MARK: - Tab2MomentRow 行高的 minHeight 策略
//
// rowHeight 是「内容比这矮时兜底不塌陷」的下限，不是要死守的固定高度：装得下
// 就锁死在这个高度（对多数用户，观感等同固定行高），装不下才放开长高、不裁字。
// 不按字号档位分支判断——minHeight 本身就是「够用就不长，不够用才长」，
// 不需要额外的无障碍档位门控。见 2026-09-01 讨论。
// UIHostingController 必须在主线程创建（SwiftUI GraphHost.init 的断言，
// 后台线程触发即 SIGTRAP）：Swift Testing 默认 testsMustRunOnMainThread:NO，
// 测试会调度到哪个线程是随机的——曾经整宿主进程崩溃、283 个用例连带 0.000s
// 失败。整组标 @MainActor 后三个测试串行跑在主 actor 上，与文件里其他 UI
// 相关测试组（TodayViewModelTests 等）同一模式。
@MainActor
struct Tab2MomentRowHeightTests {

    private func mockRow(sentence: String, momentCount: Int = 6) -> Tab2MomentRow {
        Tab2MomentRow(
            category: Tab2CategoryData(
                sceneCategory: "工作与学业", wordCount: 41, unlocked: true,
                momentCount: momentCount,
                featured: Tab2FeaturedMoment(
                    sceneDetail: "Meetings", occurrenceCount: 1, materialId: "m1",
                    userOriginal: nil, targetExpression: sentence,
                    nativeMeaning: nil, imageUrl: nil, inputLang: nil,
                    sourceDirection: "express", sourceGranularity: "sentence",
                    createdAt: nil, spokenCount: 0
                )
            ),
            onTap: {}
        )
    }

    private func height(_ row: Tab2MomentRow, category: ContentSizeCategory) -> CGFloat {
        let host = UIHostingController(rootView: row.environment(\.sizeCategory, category))
        return host.sizeThatFits(in: CGSize(width: 350, height: CGFloat.infinity)).height
    }

    private let twoLineSentence = "I totally blanked when they asked for the timeline."

    // 字号调到最大（XXXL，标准档最后一级——不是无障碍边缘情况）：行高必须
    // 大于默认下限，否则意味着内容被摁在 rowHeight 里裁掉了。
    @Test func largestStandardSizeGrowsPastFloorInsteadOfClipping() {
        let row = mockRow(sentence: twoLineSentence)
        #expect(height(row, category: .extraExtraExtraLarge) > AppTheme.Tab2MoreRow.Layout.rowHeight)
    }

    // 2026-09-01 三稿：More 列表的 meta 行不再渲染 scene_detail（Hero 卡才有），
    // 只保留 +N moments；momentCount == 1（moreCount == 0）时 meta 整行不渲染，
    // 不留空行——锁住「不渲染」不只是视觉上不显示，而是真的不占垂直空间。
    // 用 XXXL 档位比较（不是 .large）：默认字号下两种内容都可能被 rowHeight
    // 下限一起摁平、测不出差异，字号调大让内容超过下限、真实撑开高度时才能
    // 看出 meta 行到底占不占地方。
    @Test func metaRowOmittedWhenNoMoreMoments() {
        let withMeta = mockRow(sentence: twoLineSentence, momentCount: 6)
        let withoutMeta = mockRow(sentence: twoLineSentence, momentCount: 1)
        #expect(height(withoutMeta, category: .extraExtraExtraLarge) < height(withMeta, category: .extraExtraExtraLarge))
    }

    // 2026-09-01 真机复现：缩略图曾经只锁宽度、不锁高度，极端长宽比的真实照片
    // （如手机整屏截图 9:19.5）会让 Image.resizable().scaledToFill() 按图片自身
    // 比例反推出一个远超文字内容所需的高度，把整行撑高——五行图片比例不同，
    // 行高就跟着各不相同。锁住修复：无论缩略图长宽比多极端，行高必须只由
    // 文字内容决定，与图片比例无关。
    private func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in
            UIColor.systemBlue.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func mockRowWithPhoto(stableKey: String) -> Tab2MomentRow {
        Tab2MomentRow(
            category: Tab2CategoryData(
                sceneCategory: "工作与学业", wordCount: 41, unlocked: true,
                momentCount: 6,
                featured: Tab2FeaturedMoment(
                    sceneDetail: "Meetings", occurrenceCount: 1, materialId: "m1",
                    userOriginal: nil,
                    targetExpression: "I totally blanked when they asked for the timeline.",
                    nativeMeaning: nil,
                    imageUrl: "https://example.com/\(stableKey).jpg?token=x",
                    inputLang: nil,
                    sourceDirection: "express", sourceGranularity: "sentence",
                    createdAt: nil, spokenCount: 0
                )
            ),
            onTap: {}
        )
    }

    @Test func rowHeightIsIndependentOfThumbnailAspectRatio() {
        ImageCache.shared.clearMemoryForTesting()
        // key 必须是 stableImageKey（= imageUrl 去掉查询参数），跟生产代码
        // Tab2FeaturedMoment.stableImageKey 的计算方式保持一致，否则测试会
        // 命中不了缓存、停在占位态，测不出真正的问题。
        ImageCache.shared.set(solidImage(width: 1200, height: 900), forKey: "https://example.com/landscape.jpg")
        ImageCache.shared.set(solidImage(width: 900, height: 1950), forKey: "https://example.com/phone-screenshot.jpg")

        let landscape = mockRowWithPhoto(stableKey: "landscape")
        let extremePortrait = mockRowWithPhoto(stableKey: "phone-screenshot")

        #expect(height(landscape, category: .large) == height(extremePortrait, category: .large))
        #expect(height(extremePortrait, category: .large) == AppTheme.Tab2MoreRow.Layout.rowHeight)
    }
}

// MARK: - Tab2WordEntry stableImageKey tests

struct Tab2WordEntryStableImageKeyTests {

    private func entry(imageUrl: String?) throws -> Tab2WordEntry {
        var fields: [String: Any] = ["lemma": "test"]
        if let v = imageUrl { fields["image_url"] = v }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(Tab2WordEntry.self, from: data)
    }

    // 有签名 token 的 URL → 截掉查询参数，只保留路径
    @Test func stripsTokenQueryParam() throws {
        let e = try entry(imageUrl: "https://example.com/storage/img.jpg?token=abc123")
        #expect(e.stableImageKey == "https://example.com/storage/img.jpg")
    }

    // 多个查询参数也一并截掉
    @Test func stripsMultipleQueryParams() throws {
        let e = try entry(imageUrl: "https://example.com/img.jpg?token=x&t=1234")
        #expect(e.stableImageKey == "https://example.com/img.jpg")
    }

    // 没有查询参数的 URL → 原样返回
    @Test func noQueryParamReturnsOriginal() throws {
        let e = try entry(imageUrl: "https://example.com/storage/img.jpg")
        #expect(e.stableImageKey == "https://example.com/storage/img.jpg")
    }

    // imageUrl=nil → stableImageKey=nil
    @Test func nilImageUrlReturnsNil() throws {
        let e = try entry(imageUrl: nil)
        #expect(e.stableImageKey == nil)
    }

    // imageUrl="" → stableImageKey=nil
    @Test func emptyImageUrlReturnsNil() throws {
        let e = try entry(imageUrl: "")
        #expect(e.stableImageKey == nil)
    }
}

// MARK: - CJK detection tests (finalizeFallbackSpeech language routing)

struct CJKDetectionTests {
    // Mirrors the predicate in ConversationViewModel.finalizeFallbackSpeech
    private func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    @Test func detectsChineseCharacters() {
        #expect(hasCJK("你好") == true)
    }

    @Test func detectsMixedChineseEnglish() {
        #expect(hasCJK("I'm 很累 today") == true)
    }

    @Test func ignoresPureLatin() {
        #expect(hasCJK("Hello world") == false)
    }

    @Test func ignoresEmptyString() {
        #expect(hasCJK("") == false)
    }

    @Test func ignoresPunctuation() {
        #expect(hasCJK("!@#$%") == false)
    }

    @Test func detectsRangeLowerBound() {
        // U+4E00 = 一 (first CJK Unified Ideograph)
        #expect(hasCJK("一") == true)
    }

    @Test func detectsRangeUpperBound() {
        let ch = String(UnicodeScalar(0x9FFF)!)
        #expect(hasCJK(ch) == true)
    }

    @Test func ignoresJapaneseKatakana() {
        // Katakana is U+30A0–U+30FF, outside the CJK block
        #expect(hasCJK("アイウエオ") == false)
    }

    @Test func ignoresKoreanHangul() {
        // Hangul is U+AC00–U+D7A3, outside the CJK block
        #expect(hasCJK("안녕") == false)
    }

    @Test func detectsKanjiInJapaneseSentence() {
        // Japanese sentences often mix kanji (CJK) with kana — should still detect
        #expect(hasCJK("今日はいい天気ですね") == true)
    }
}

// MARK: - DialogueService DTO decode tests

struct DialogueDTODecodeTests {

    @Test func decodesStartResponse() throws {
        let json = """
        {"session_id": "abc-123", "reply": "Hello!", "suggestions": []}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueStartResponse.self, from: json)
        #expect(r.sessionId == "abc-123")
        #expect(r.reply == "Hello!")
        #expect(r.suggestions.isEmpty)
    }

    @Test func decodesStartResponseWithSuggestions() throws {
        let json = """
        {
            "session_id": "s1",
            "reply": "What happened?",
            "suggestions": [{"lemma": "burnout", "hint": "extreme exhaustion"}]
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueStartResponse.self, from: json)
        #expect(r.suggestions.count == 1)
        #expect(r.suggestions[0].lemma == "burnout")
        #expect(r.suggestions[0].hint == "extreme exhaustion")
    }

    @Test func decodesTurnResponseNullSceneDetail() throws {
        let json = """
        {"reply": "That sounds tough.", "suggestions": [], "scene_detail": null}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueTurnResponse.self, from: json)
        #expect(r.reply == "That sounds tough.")
        #expect(r.sceneDetail == nil)
    }

    @Test func decodesTurnResponseWithSceneDetail() throws {
        let json = """
        {
            "reply": "Tell me more.",
            "suggestions": [
                {"lemma": "deadline", "hint": "due date"},
                {"lemma": "overtime", "hint": "extra hours"}
            ],
            "scene_detail": "Work stress meeting"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueTurnResponse.self, from: json)
        #expect(r.suggestions.count == 2)
        #expect(r.sceneDetail == "Work stress meeting")
    }

    @Test func decodesFallbackResponse() throws {
        let json = """
        {
            "translation": "I stayed late at work.",
            "key_words": [{"word": "stayed", "phonetic": "/steɪd/"}],
            "hint": "Try using 'stayed late'"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.translation == "I stayed late at work.")
        #expect(r.keyWords.count == 1)
        #expect(r.keyWords[0].word == "stayed")
        #expect(r.keyWords[0].phonetic == "/steɪd/")
        #expect(r.hint == "Try using 'stayed late'")
    }

    @Test func decodesFallbackResponseEmptyKeyWords() throws {
        let json = """
        {"translation": "Let's go.", "key_words": [], "hint": "Say it!"}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.keyWords.isEmpty)
    }

    @Test func decodesFallbackResponseMultipleKeyWords() throws {
        let json = """
        {
            "translation": "The projector wasn't working.",
            "key_words": [
                {"word": "projector", "phonetic": "/prəˈdʒektər/"},
                {"word": "working",   "phonetic": "/ˈwɜːrkɪŋ/"}
            ],
            "hint": "Focus on 'projector'"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackResponseDTO.self, from: json)
        #expect(r.keyWords.count == 2)
        #expect(r.keyWords[1].phonetic == "/ˈwɜːrkɪŋ/")
    }

    @Test func decodesSuggestionDTO() throws {
        let json = "{\"lemma\": \"overtime\", \"hint\": \"extra hours beyond schedule\"}".data(using: .utf8)!
        let r = try JSONDecoder().decode(DialogueSuggestionDTO.self, from: json)
        #expect(r.lemma == "overtime")
        #expect(r.hint == "extra hours beyond schedule")
    }

    @Test func decodesFallbackKeyWordDTO() throws {
        let json = "{\"word\": \"projector\", \"phonetic\": \"/pr\u{0259}\u{02C8}d\u{0292}ekt\u{0259}r/\"}".data(using: .utf8)!
        let r = try JSONDecoder().decode(FallbackKeyWordDTO.self, from: json)
        #expect(r.word == "projector")
        #expect(r.phonetic == "/prəˈdʒektər/")
    }
}

// MARK: - ConversationViewModel state machine tests

@MainActor
struct ConversationViewModelStateTests {

    @Test func initialPageStateIsPreparing() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.pageState == .preparing)
    }

    @Test func initialMicStateIsIdle() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.micState == .idle)
    }

    @Test func initialSessionIdIsNil() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.sessionId == nil)
    }

    @Test func initialFallbackListeningIsFalse() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        #expect(vm.isFallbackListening == false)
    }

    @Test func retryWithNoSessionReEntersPreparing() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.pageState = .failed
        vm.sessionId = nil
        vm.retry()
        #expect(vm.pageState == .preparing)
    }

    @Test func retryWithExistingSessionBecomesActive() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.pageState = .failed
        vm.sessionId = "existing-session-id"
        vm.retry()
        #expect(vm.pageState == .active)
    }

    @Test func dismissFallbackClearsFallbackResult() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.fallbackResult = FallbackResult(
            translation: "I'm tired.",
            keyWords: [],
            hint: "Try saying it."
        )
        vm.dismissFallback()
        #expect(vm.fallbackResult == nil)
    }

    // 停用原因：interruptAI() 会串接 startListening()，其最终 micState 取决于设备
    // 麦克风权限状态（授权环境下会推进到 .listening 而非 .idle）——期望值与权限耦合，
    // 是先于合规切片就存在的 flaky 老用例。待语音对话切片锁定时再修正期望并重新启用。
    @Test(.disabled("Voice-dialogue: interruptAI chains into startListening; final micState is coupled to mic-permission state. Revisit with the dialogue slice."))
    func interruptAISetsIdleWhenAISpeaking() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .aiSpeaking
        vm.interruptAI()
        #expect(vm.micState == .idle)
    }

    @Test func interruptAIDoesNothingWhenIdle() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .idle
        vm.interruptAI()
        #expect(vm.micState == .idle)
    }

    // startFallbackListening guard: already in fallback mode → early return, no state change
    @Test func startFallbackListeningNoOpWhenAlreadyFallback() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .idle
        vm.isFallbackListening = true
        vm.startFallbackListening()
        // guard !isFallbackListening fires — micState must remain idle, not change to .listening
        #expect(vm.micState == .idle)
        #expect(vm.isFallbackListening == true)
    }

    // startFallbackListening guard: aiSpeaking → early return
    @Test func startFallbackListeningNoOpWhenAISpeaking() {
        let vm = ConversationViewModel(sceneCategory: "Work")
        vm.micState = .aiSpeaking
        vm.startFallbackListening()
        // guard micState == .idle || .listening fails for .aiSpeaking
        #expect(vm.isFallbackListening == false)
        #expect(vm.micState == .aiSpeaking)
    }

    // NativeFallbackButton.isDisabled logic: only aiSpeaking disables the button
    @Test func fallbackButtonDisabledOnlyWhenAISpeaking() {
        let isDisabled: (MicState) -> Bool = { $0 == .aiSpeaking }
        #expect(isDisabled(.idle) == false)
        #expect(isDisabled(.listening) == false)
        #expect(isDisabled(.aiSpeaking) == true)
        #expect(isDisabled(.disabled) == false)
    }
}

// MARK: - PopsLabel formatting tests
// 锁定 pops 计数单位的复数处理（0/1/N），供 Topics 进度行胶囊与 Hero 卡共用。

struct PopsLabelTests {

    @Test func zeroUsesPlural() {
        #expect(PopsLabel.format(0) == "0 pops")
    }

    @Test func oneUsesSingular() {
        #expect(PopsLabel.format(1) == "1 pop")
    }

    @Test func manyUsePlural() {
        #expect(PopsLabel.format(2) == "2 pops")
        #expect(PopsLabel.format(18) == "18 pops")
    }
}

// MARK: - Category milestone crossing tests

struct CategoryMilestoneTrackerTests {

    @Test func existingAchievementsBecomeBaselineWithoutReplaying() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        let first = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        let later = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 21)],
            userID: "user-a"
        )

        #expect(first.isEmpty)
        #expect(later.isEmpty)
    }

    @Test func crossingFromNineteenToTwentyCreatesPresentation() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        let presentations = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        #expect(presentations == [CategoryMilestonePresentation(
            categoryID: "work",
            previousCount: 19,
            currentCount: 20
        )])
    }

    @Test func achievedCategoryNeverReplaysAfterCountRegression() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 8)],
            userID: "user-a"
        )
        let replay = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        #expect(replay.isEmpty)
    }

    @Test func simultaneousCrossingsReturnEveryPresentationAndPersistAll() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 19),
            CategoryMilestoneSnapshot(categoryID: "food", count: 18)
        ], userID: "user-a")

        let presentations = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 20),
            CategoryMilestoneSnapshot(categoryID: "food", count: 23)
        ], userID: "user-a")

        _ = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 10),
            CategoryMilestoneSnapshot(categoryID: "food", count: 10)
        ], userID: "user-a")
        let replay = tracker.observeBatch([
            CategoryMilestoneSnapshot(categoryID: "work", count: 20),
            CategoryMilestoneSnapshot(categoryID: "food", count: 23)
        ], userID: "user-a")

        #expect(presentations == [
            CategoryMilestonePresentation(
                categoryID: "work",
                previousCount: 19,
                currentCount: 20
            ),
            CategoryMilestonePresentation(
                categoryID: "food",
                previousCount: 18,
                currentCount: 23
            )
        ])
        #expect(replay.isEmpty)
    }

    @Test func baselinesAreIsolatedPerUser() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let tracker = CategoryMilestoneTracker(defaults: defaults)

        _ = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        let userACrossing = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )
        let userBFirstObservation = tracker.observeBatch(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-b"
        )

        #expect(!userACrossing.isEmpty)
        #expect(userBFirstObservation.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CategoryMilestoneTrackerTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }
}

struct CategoryWordsLoadingStateTests {

    @Test func offlineAndGenericFailuresUseDistinctSingleLineCopy() {
        #expect(CategoryWordsLoadFailure.offline.message == "You're offline.")
        #expect(CategoryWordsLoadFailure.unavailable.message == "Couldn't load these words.")
    }

    @Test func offlineNetworkErrorsAreClassifiedAsOffline() {
        #expect(CategoryWordsLoadFailure.classify(
            error: URLError(.notConnectedToInternet),
            isConnected: true
        ) == .offline)
        #expect(CategoryWordsLoadFailure.classify(
            error: URLError(.timedOut),
            isConnected: false
        ) == .offline)
    }

    @Test func otherErrorsRemainGenericWhenConnected() {
        #expect(CategoryWordsLoadFailure.classify(
            error: URLError(.timedOut),
            isConnected: true
        ) == .unavailable)
    }

    @MainActor
    @Test func collapsingCancelsLoadingWithoutCreatingFailure() async {
        let loader = CategoryWordsLoader()
        loader.synchronize(isExpanded: true, revision: 0) {
            try await Task.sleep(for: .seconds(5))
            return [Self.word("late")]
        }
        #expect(loader.isLoading)

        loader.synchronize(isExpanded: false, revision: 0) { [] }
        await Task.yield()

        #expect(loader.isLoading == false)
        #expect(loader.failure == nil)
        #expect(loader.words.isEmpty)
    }

    @MainActor
    @Test func newRevisionReplacesLoadedWordsEvenWhenRowRemainsExpanded() async {
        let loader = CategoryWordsLoader()
        loader.synchronize(isExpanded: true, revision: 0) {
            [Self.word("old")]
        }
        await waitUntil { loader.words.first?.lemma == "old" }

        loader.synchronize(isExpanded: true, revision: 1) {
            [Self.word("fresh")]
        }
        await waitUntil { loader.words.first?.lemma == "fresh" }

        #expect(loader.words.map(\.lemma) == ["fresh"])
        #expect(loader.failure == nil)
    }

    @MainActor
    @Test func cancelledOldRequestCannotOverwriteNewRevision() async {
        let loader = CategoryWordsLoader()
        loader.synchronize(isExpanded: true, revision: 0) {
            // 模拟不配合取消的依赖：吞掉 sleep 的 CancellationError 后仍返回旧结果。
            try? await Task.sleep(for: .milliseconds(30))
            return [Self.word("stale")]
        }

        loader.synchronize(isExpanded: true, revision: 1) {
            [Self.word("current")]
        }
        await waitUntil { loader.words.first?.lemma == "current" }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(loader.words.map(\.lemma) == ["current"])
        #expect(loader.failure == nil)
    }

    private static func word(_ lemma: String) -> Tab2WordEntry {
        Tab2WordEntry(
            lemma: lemma,
            entryKind: "word",
            granularity: "word"
        )
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Timed out waiting for category words state")
    }
}

struct LocalUserDataTests {

    private func makeDefaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // 本条锁的是踩过的坑：路由标志位若用 removeObject，磁盘确实清了，
    // 但 @AppStorage 接不到「键被移除」，界面不会切回 onboarding——
    // 表现为「账号删了、页面没变化」。必须显式归 0，产生一次明确的值变化。
    @Test func routingFlagsAreZeroedNotRemoved() async {
        let defaults = makeDefaults("local-user-data-routing")
        defaults.set(1_787_000_000.0, forKey: "onboarding_completed_at")
        defaults.set(1_787_000_000.0, forKey: "ai_consent_accepted_at")

        await LocalUserData.clearDefaults(defaults)

        for key in ["onboarding_completed_at", "ai_consent_accepted_at"] {
            // 键必须还在，且值为 0——RootView 判的是 `> 0`，0 即「未完成引导」
            #expect(defaults.object(forKey: key) != nil, "\(key) 不该被移除，移除后 @AppStorage 接不到变化")
            #expect(defaults.double(forKey: key) == 0)
        }
    }

    @Test func otherAccountKeysAreRemoved() async {
        let defaults = makeDefaults("local-user-data-other")
        defaults.set(true, forKey: Tab2Defaults.permanentlyUnlocked)
        defaults.set(true, forKey: Tab2Defaults.firstUnlockShown)
        defaults.set("material-a", forKey: Tab2Defaults.heroMaterialID)
        defaults.set(["Calling family"], forKey: Tab2Defaults.heroKnownMoments)
        defaults.set(42, forKey: "mine_last_scene_count")
        // 2026-08-27 review 发现的遗漏：引导完成待同步标记也是账号级状态
        defaults.set(true, forKey: ProfileService.onboardingSyncPendingKey)
        // 每日额度本地缓存（W3）：删号清理后不应残留
        defaults.set("2026-09-05", forKey: UsageQuotaStore.cachedDateKey)
        defaults.set(3, forKey: UsageQuotaStore.cachedUsedCountKey)
        defaults.set(5, forKey: UsageQuotaStore.cachedDailyLimitKey)
        // 聊过机制删除时枚举 case 一并没了，但字面量必须留在清理清单里——
        // 用字面量而非 Tab2Defaults.* 写入，模拟「更新前的旧设备本地已写入」这一场景。
        defaults.set(["Calling family"], forKey: "tab2_spoken_moments")
        defaults.set(["Calling family"], forKey: "tab2_hero_known_spoken_moments")

        await LocalUserData.clearDefaults(defaults)

        // 这些键没有视图直接观察，移除即可，不必留占位值
        #expect(defaults.object(forKey: Tab2Defaults.permanentlyUnlocked) == nil)
        #expect(defaults.object(forKey: Tab2Defaults.firstUnlockShown) == nil)
        #expect(defaults.object(forKey: Tab2Defaults.heroMaterialID) == nil)
        #expect(defaults.object(forKey: Tab2Defaults.heroKnownMoments) == nil)
        #expect(defaults.object(forKey: "mine_last_scene_count") == nil)
        #expect(defaults.object(forKey: ProfileService.onboardingSyncPendingKey) == nil)
        #expect(defaults.object(forKey: UsageQuotaStore.cachedDateKey) == nil)
        #expect(defaults.object(forKey: UsageQuotaStore.cachedUsedCountKey) == nil)
        #expect(defaults.object(forKey: UsageQuotaStore.cachedDailyLimitKey) == nil)
        #expect(defaults.object(forKey: "tab2_spoken_moments") == nil)
        #expect(defaults.object(forKey: "tab2_hero_known_spoken_moments") == nil)
    }

    // 这条锁的是 re-review 发现的 false success：
    // 两个 store 的 remove(id:) 先写元数据、再 try? 删 JPEG。删文件失败时
    // 记录已消失、文件还在，而 load().count 返回 0 —— clearAll 会谎报「已清空」。
    // 文件级残留必须靠扫目录才发现得了。
    @Test func sweepFindsOrphanPhotosThatIndexNoLongerKnowsAbout() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sweep-orphans-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // 没有任何索引指向它们——模拟「删文件失败」或「索引损坏」留下的孤儿
        try Data([0xFF]).write(to: dir.appendingPathComponent("\(UUID().uuidString).jpg"))
        try Data([0xFF]).write(to: dir.appendingPathComponent("\(UUID().uuidString).jpg"))
        // 非 jpg 不得误伤
        try Data([0x00]).write(to: dir.appendingPathComponent("keep.json"))

        let remaining = LocalUserData.sweepOrphanPhotos(in: dir)

        #expect(remaining == 0)
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left == ["keep.json"], "只清 .jpg，其它文件必须留着：\(left)")
    }

    // 索引写入被中断会留下坏掉的 JSON。此时 store 解不出记录、clearAll 报 0 残留，
    // 而照片文件其实还在 —— 只靠回读索引永远发现不了，必须靠扫目录兜底。
    @Test func corruptIndexStillLetsSweepFindTheFiles() throws {
        let suite = "corrupt-index-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // 索引坏掉，但照片文件还在
        defaults.set(Data("{ not valid json".utf8), forKey: "pending_retry_records")
        try Data([0xFF]).write(to: dir.appendingPathComponent("\(UUID().uuidString).jpg"))

        let store = PendingRetryStore(defaults: defaults, documentsDir: dir)
        // 不该崩；索引解不出来 → 它认为「没有记录」，报 0 残留
        #expect(store.clearAll() == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).count == 1,
                "索引层清不掉文件——这正是需要 sweep 兜底的原因")

        // 兜底扫描必须把它清掉
        #expect(LocalUserData.sweepOrphanPhotos(in: dir) == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test func sweepOnMissingDirectoryIsSafe() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("definitely-not-there-\(UUID().uuidString)")
        // 目录不存在 = 已是目标状态，不该报残留
        #expect(LocalUserData.sweepOrphanPhotos(in: missing) == 0)
    }

    @Test func milestoneProgressIsClearedAcrossAllUserIDs() async {
        let defaults = makeDefaults("local-user-data-milestones")
        // 里程碑按 userID 分键；删号后这些键永不再读，必须按前缀全清，否则无限累积
        defaults.set(["food": 20], forKey: "tab2_category_milestones_v1.USER-A.counts")
        defaults.set(["food"], forKey: "tab2_category_milestones_v1.USER-A.achieved")
        defaults.set(["work": 5], forKey: "tab2_category_milestones_v1.USER-B.counts")
        defaults.set("keep-me", forKey: "unrelated_key")

        await LocalUserData.clearDefaults(defaults)

        let leftovers = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("tab2_category_milestones_v1") }
        #expect(leftovers.isEmpty)
        // 只清账号相关的，别误伤其它键
        #expect(defaults.string(forKey: "unrelated_key") == "keep-me")
    }
}

struct AccountDeletionAndSessionTests {

    // MARK: - SessionAction（取会话走哪条路）

    @Test func expiredSessionMustRefreshInsteadOfBeingReused() {
        // 这条锁的就是那个 bug：有会话但已过期时，绝不能 .reuse。
        // 复用过期 JWT → Edge Function 验签失败返回 401 → 调用方静默吞掉，
        // 表现为「转圈一下什么都没发生」，且无从排查。
        #expect(SessionAction.decide(hasSession: true, isExpired: true) == .refresh)
    }

    @Test func validSessionIsReusedWithoutNetworkCall() {
        // 未过期必须直接复用：每次请求都去刷新会白白增加一次往返。
        #expect(SessionAction.decide(hasSession: true, isExpired: false) == .reuse)
    }

    @Test func missingSessionSignsInAnonymously() {
        // 新装 / Keychain 被清：没有 refresh token 可用，只能重新匿名注册。
        // isExpired 此时无意义，两种取值都必须落到 .signIn。
        #expect(SessionAction.decide(hasSession: false, isExpired: false) == .signIn)
        #expect(SessionAction.decide(hasSession: false, isExpired: true) == .signIn)
    }

    // MARK: - 服务端 storage 清理回报

    @Test func missingStorageFieldIsTreatedAsCleared() {
        // 老版本 Edge Function 不返回该字段。解不出来就吓唬用户是错的——
        // 兼容缺失 = 视为已清空。
        #expect(SettingsView.storageCleared(from: Data(#"{"success":true}"#.utf8)))
        #expect(SettingsView.storageCleared(from: Data()))
        #expect(SettingsView.storageCleared(from: Data("not json".utf8)))
    }

    @Test func storageClearedFalseIsDecoded() {
        let data = Data(#"{"success":true,"storage_cleared":false,"storage_leftover":3}"#.utf8)
        #expect(SettingsView.storageCleared(from: data) == false)
    }

    @Test func partialCleanupWarningNeverClaimsEverythingWasDeleted() {
        // 关键不变量：只要有残留，文案里就不能出现「全部数据已删除」的断言。
        for (local, server) in [(false, false), (false, true), (true, false)] {
            let msg = SettingsView.partialCleanupWarning(localCleared: local, serverCleared: server)
            #expect(!msg.lowercased().contains("all "), "残留时不得断言 all data deleted：\(msg)")
            #expect(msg.contains("deleted"))
        }
    }

    @Test func warningDistinguishesDeviceFromServerLeftovers() {
        // 本地残留 → 告诉用户重装可清；服务端残留 → 用户做不了什么，
        // 硬让他「重装试试」只会白折腾。两种措辞必须不同。
        let deviceOnly = SettingsView.partialCleanupWarning(localCleared: false, serverCleared: true)
        let serverOnly = SettingsView.partialCleanupWarning(localCleared: true, serverCleared: false)
        #expect(deviceOnly.contains("reinstalling"))
        #expect(!serverOnly.contains("reinstalling"))
        #expect(deviceOnly != serverOnly)
    }

    // MARK: - 删号失败文案（失败必须可见且可执行）

    @Test func unauthorizedStatusTellsUserToReopenTheApp() {
        // 401 = 会话过期的典型码，重开 App 即可恢复，值得单独给话术。
        let message = SettingsView.deleteErrorMessage(status: 401)
        #expect(message.contains("session expired"))
        #expect(message != SettingsView.genericDeleteError)
    }

    @Test func otherStatusCodesFallBackToGenericMessageWithoutLeakingNumbers() {
        for status in [400, 403, 404, 500, 503] {
            #expect(SettingsView.deleteErrorMessage(status: status) == SettingsView.genericDeleteError)
        }
        // 连 HTTPURLResponse 都没拿到（status 为 nil）也要有兜底文案。
        #expect(SettingsView.deleteErrorMessage(status: nil) == SettingsView.genericDeleteError)
    }

    @Test func offlineErrorsAreDistinguishedFromGenericFailure() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            let message = SettingsView.deleteErrorMessage(error: URLError(code))
            #expect(message.contains("offline"))
        }
    }

    @Test func timeoutWarnsThatDeletionMayHaveSucceeded() {
        // 服务端不会因客户端超时而停止：不提示「可能已删成功」，
        // 用户会反复重试一件其实已经完成的事。
        let message = SettingsView.deleteErrorMessage(error: URLError(.timedOut))
        #expect(message.contains("already deleted"))
        #expect(message != SettingsView.genericDeleteError)
    }

    @Test func unknownErrorsStillProduceAVisibleMessage() {
        // 关键不变量：任何失败路径都必须产出非空文案——绝不能再有静默失败。
        let message = SettingsView.deleteErrorMessage(error: NSError(domain: "test", code: 1))
        #expect(!message.isEmpty)
        #expect(message == SettingsView.genericDeleteError)
    }
}

struct Tab2MilestoneLifecycleTests {

    @Test func milestoneEmphasisScalesOnlyDuringStandardMotionPresentation() {
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: true,
            isEmphasized: true,
            reduceMotion: false
        ) == 1.08)
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: true,
            isEmphasized: true,
            reduceMotion: true
        ) == 1.0)
        #expect(CategoryProgressRow.milestoneScale(
            isPresenting: false,
            isEmphasized: true,
            reduceMotion: false
        ) == 1.0)
    }

    // MARK: - CategoryProgressRow.isHot（分类行「点亮」判定）

    @Test func unlockedCategoryStaysHotEvenBelowTarget() {
        // 已解锁的分类常驻点亮：即便 wordCount 因口径调整回落到 target 以下，
        // 也不该退回未点亮的样子（feat/page-visual-polish 有意引入的行为）。
        #expect(CategoryProgressRow.isHot(
            isPresentingMilestone: false,
            milestoneRevealed: false,
            unlocked: true,
            wordCount: 3,
            targetCount: 20,
            isHighlighted: false
        ))
    }

    @Test func lockedCategoryIsHotOnlyAtOrAboveTarget() {
        func hot(_ count: Int) -> Bool {
            CategoryProgressRow.isHot(
                isPresentingMilestone: false,
                milestoneRevealed: false,
                unlocked: false,
                wordCount: count,
                targetCount: 20,
                isHighlighted: false
            )
        }
        #expect(hot(19) == false)
        #expect(hot(20))          // 边界：达标即点亮
        #expect(hot(21))
    }

    @Test func highlightForcesHotOnLockedBelowTargetCategory() {
        #expect(CategoryProgressRow.isHot(
            isPresentingMilestone: false,
            milestoneRevealed: false,
            unlocked: false,
            wordCount: 1,
            targetCount: 20,
            isHighlighted: true
        ))
    }

    @Test func milestonePresentationOverridesAllOtherHotSources() {
        // 演出期间只听揭示节拍：即使已解锁且远超达标线，未揭示前也必须保持未点亮，
        // 否则数字还没跑完就抢先点亮，里程碑动效失去意义。
        #expect(CategoryProgressRow.isHot(
            isPresentingMilestone: true,
            milestoneRevealed: false,
            unlocked: true,
            wordCount: 99,
            targetCount: 20,
            isHighlighted: true
        ) == false)
        #expect(CategoryProgressRow.isHot(
            isPresentingMilestone: true,
            milestoneRevealed: true,
            unlocked: false,
            wordCount: 0,
            targetCount: 20,
            isHighlighted: false
        ))
    }

    @Test func milestoneToastLifetimeIsShorterThanReadingToastLifetime() {
        #expect(AppTheme.Motion.milestoneToastLifetime < AppTheme.Motion.toastLifetime)
    }

    @Test func onboardingPhotoToastLifetimeSitsBetweenMilestoneAndReadingFeedback() {
        #expect(
            AppTheme.Motion.milestoneToastLifetime
                < AppTheme.Motion.onboardingPhotoToastLifetime
        )
        #expect(
            AppTheme.Motion.onboardingPhotoToastLifetime
                < AppTheme.Motion.toastLifetime
        )
    }

    @Test func milestoneToastDescribesReachedCategory() {
        let vm = Tab2HomeViewModel()
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 20,
                unlocked: true
            )
        ])

        let message = vm.milestoneToastMessage(for: [CategoryMilestonePresentation(
            categoryID: "出行交通",
            previousCount: 19,
            currentCount: 20
        )])

        #expect(message == "Getting around reached 20 pops")
    }

    @Test func milestoneToastAggregatesSimultaneousTopicsAtThreshold() {
        let vm = Tab2HomeViewModel()
        let message = vm.milestoneToastMessage(for: [
            CategoryMilestonePresentation(
                categoryID: "出行交通",
                previousCount: 19,
                currentCount: 23
            ),
            CategoryMilestonePresentation(
                categoryID: "饮食",
                previousCount: 18,
                currentCount: 21
            )
        ])

        #expect(message == "2 topics reached 20 pops")
    }

    @Test func pendingPresentationRemainsUntilMatchingPresentationFinishes() {
        let defaults = UserDefaults(suiteName: "Tab2MilestoneLifecycleTests.\(UUID().uuidString)")!
        defer { defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:)) }
        let vm = Tab2HomeViewModel(
            milestoneTracker: CategoryMilestoneTracker(defaults: defaults)
        )

        vm.registerMilestones(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 19)],
            userID: "user-a"
        )
        vm.registerMilestones(
            [CategoryMilestoneSnapshot(categoryID: "work", count: 20)],
            userID: "user-a"
        )

        let expected = [CategoryMilestonePresentation(
            categoryID: "work",
            previousCount: 19,
            currentCount: 20
        )]
        #expect(vm.milestonePresentations == expected)

        vm.finishMilestonePresentations([CategoryMilestonePresentation(
            categoryID: "food",
            previousCount: 19,
            currentCount: 20
        )])
        #expect(vm.milestonePresentations == expected)

        vm.finishMilestonePresentations(expected)
        #expect(vm.milestonePresentations.isEmpty)
    }

    #if DEBUG
    @Test func debugDemoUsesTwoUnlockedCategoriesClosestToThreshold() {
        let categories = [
            Tab2CategoryData(sceneCategory: "工作与学业", wordCount: 12, unlocked: false),
            Tab2CategoryData(sceneCategory: "饮食", wordCount: 34, unlocked: true),
            Tab2CategoryData(sceneCategory: "出行交通", wordCount: 22, unlocked: true)
        ]

        let presentations = Tab2HomeViewModel.debugMilestoneDemoPresentations(
            in: categories
        )

        #expect(presentations == [
            CategoryMilestonePresentation(
                categoryID: "出行交通",
                previousCount: 19,
                currentCount: 20
            ),
            CategoryMilestonePresentation(
                categoryID: "饮食",
                previousCount: 19,
                currentCount: 20
            )
        ])
    }

    @Test func debugDemoCanStartFromAlreadyLoadedData() {
        let vm = Tab2HomeViewModel()
        let categories = [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 22,
                unlocked: true
            )
        ]
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: categories)

        vm.prepareDebugMilestoneDemoFromCurrentData()

        #expect(vm.milestonePresentations == [CategoryMilestonePresentation(
            categoryID: "出行交通",
            previousCount: 19,
            currentCount: 20
        )])
    }

    @Test func freshResponseDoesNotReplayDemoAlreadyStartedFromLoadedData() {
        let vm = Tab2HomeViewModel()
        let categories = [
            Tab2CategoryData(
                sceneCategory: "出行交通",
                wordCount: 22,
                unlocked: true
            )
        ]
        vm.data = Tab2HomeData(unlocked: true, inputCount: 20, categories: categories)

        vm.prepareDebugMilestoneDemoFromCurrentData()
        let presentations = vm.milestonePresentations
        vm.finishMilestonePresentations(presentations)
        vm.prepareDebugMilestoneDemoAfterRefresh(categories)

        #expect(vm.milestonePresentations.isEmpty)
    }
    #endif
}

// MARK: - Timeline stability tests（Tab1 加载跳动修复切片）
//
// 根因修复锁定：日期分隔符 ID 由 dayKey 确定性派生——缓存渲染与网络正本两次重建
// 产出相同 ID 序列，SwiftUI diff 不再「删旧插新」引发整列重排；
// 分组比较改用含年份的 dayKey，跨年同文案（"Aug 22"）不误并成一组。

@MainActor
struct TimelineStabilityTests {

    // 回归点：长 Passage 展开后不能再把 LazyVStack 的单行高度撑到不可控。
    // 删掉上限或直接返回 contentHeight 时，本测试必须失败。
    @Test func longPassageUsesBoundedExpandedViewportHeight() {
        let height = PassageTimelineLayout.expandedViewportHeight(contentHeight: 900)

        #expect(height == AppTheme.Size.passageExpandedViewportMaxHeight)
        #expect(height < 900)
    }

    // 短 Passage 不应为了稳定行高被强行撑大；只有超过上限的内容才在卡片内滚动。
    @Test func shortPassageKeepsItsNaturalExpandedHeight() {
        let height = PassageTimelineLayout.expandedViewportHeight(contentHeight: 180)

        #expect(height == 180)
    }

    @Test func passageReservesScrollbarGutterOnlyWhenExpanded() {
        #expect(PassageTimelineLayout.contentTrailingInset(isExpanded: false) == 0)
        #expect(
            PassageTimelineLayout.contentTrailingInset(isExpanded: true)
                == AppTheme.Size.passageScrollIndicatorGutter
        )
    }

    @Test func passageEdgeFadesFollowHiddenScrollableContent() {
        let atTop = PassageTimelineLayout.edgeVisibility(
            contentMinY: 0,
            contentMaxY: 900,
            viewportHeight: 360
        )
        let inMiddle = PassageTimelineLayout.edgeVisibility(
            contentMinY: -100,
            contentMaxY: 800,
            viewportHeight: 360
        )
        let atBottom = PassageTimelineLayout.edgeVisibility(
            contentMinY: -540,
            contentMaxY: 360,
            viewportHeight: 360
        )

        #expect(atTop == PassageTimelineLayout.bottomEdgeFadeFlag)
        #expect(
            inMiddle
                == PassageTimelineLayout.topEdgeFadeFlag | PassageTimelineLayout.bottomEdgeFadeFlag
        )
        #expect(atBottom == PassageTimelineLayout.topEdgeFadeFlag)
    }

    @Test func passageReadingEndsOnlyAfterCardFullyLeavesViewport() {
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 700)

        #expect(!PassageReadingLifecycle.isCompletelyOutside(
            cardFrame: CGRect(x: 16, y: -699, width: 358, height: 700),
            viewport: viewport
        ))
        #expect(PassageReadingLifecycle.isCompletelyOutside(
            cardFrame: CGRect(x: 16, y: -700, width: 358, height: 700),
            viewport: viewport
        ))
        #expect(!PassageReadingLifecycle.isCompletelyOutside(
            cardFrame: CGRect(x: 16, y: 699, width: 358, height: 700),
            viewport: viewport
        ))
        #expect(PassageReadingLifecycle.isCompletelyOutside(
            cardFrame: CGRect(x: 16, y: 700, width: 358, height: 700),
            viewport: viewport
        ))
    }

    // 首屏定位必须发生在 ScrollView 的初始布局阶段：长列表挂载后的第一个稳定布局
    // 已经位于最大可滚动偏移，不能依赖 onAppear 后再补一次 scrollTo。
    @Test func initialBottomScrollViewLaysOutLongContentAtBottom() async throws {
        let ids = (0..<12).map { _ in UUID() }
        let host = UIHostingController(rootView:
            InitialBottomScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(ids, id: \.self) { id in
                        Color.clear
                            .frame(height: 100)
                            .id(id)
                    }
                }
            }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // SwiftUI 在当前 runloop 提交默认锚点的初始布局事务；不等待任何业务层
        // DispatchQueue 补滚动，只让框架完成这一轮布局。
        await Task.yield()
        host.view.layoutIfNeeded()

        let scrollView = try #require(Self.firstScrollView(in: host.view))
        let maximumOffset = max(
            0,
            scrollView.contentSize.height
                - scrollView.bounds.height
                + scrollView.adjustedContentInset.bottom
        )
        #expect(maximumOffset > 0)
        #expect(scrollView.contentOffset.y >= maximumOffset - 1)

        window.isHidden = true
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let match = firstScrollView(in: subview) {
                return match
            }
        }
        return nil
    }

    // 与 TodayViewModel.decodeRecords 同策略的日期解码（ISO8601 带/不带小数秒）
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let str = try c.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(str)")
        }
        return d
    }()

    private func record(id: String, role: String, text: String, at isoDate: String) throws -> MessageRecord {
        let json = """
        {"id": "\(id)", "role": "\(role)", "user_content": "\(text)", "created_at": "\(isoDate)"}
        """
        return try Self.decoder.decode(MessageRecord.self, from: json.data(using: .utf8)!)
    }

    // 同一 dayKey 永远派生同一 UUID；不同 dayKey 派生不同 UUID（跨重建稳定）。
    @Test func deterministicSeparatorIdIsStablePerDay() {
        let a1 = TodayViewModel.deterministicSeparatorId(for: "2026-08-22")
        let a2 = TodayViewModel.deterministicSeparatorId(for: "2026-08-22")
        let b = TodayViewModel.deterministicSeparatorId(for: "2026-08-23")
        #expect(a1 == a2)
        #expect(a1 != b)
    }

    // 核心修复：同一批记录两次重建 → 整列 ID 序列逐位一致（含日期分隔符）。
    // 缓存渲染与网络正本不再被判为「全新列表」，0 次无效重排。
    @Test func rebuildProducesIdenticalEntryIds() throws {
        let records = try [
            record(id: "11111111-2222-3333-4444-555555555501", role: "user", text: "older", at: "2026-08-20T10:00:00Z"),
            record(id: "11111111-2222-3333-4444-555555555502", role: "user", text: "newer", at: "2026-08-22T10:00:00Z")
        ]
        let first = TodayViewModel.buildEntries(from: records)
        let second = TodayViewModel.buildEntries(from: records)
        #expect(first.count == 4)   // 两天 → 两个分隔符 + 两条气泡
        #expect(first.map(\.id) == second.map(\.id))
    }

    // 跨年同文案（"Mar 15"）但不同日历日：必须分成两组，各带自己的分隔符与 ID。
    @Test func crossYearSameLabelDoesNotMerge() throws {
        let records = try [
            record(id: "11111111-2222-3333-4444-555555555511", role: "user", text: "last year", at: "2024-03-15T10:00:00Z"),
            record(id: "11111111-2222-3333-4444-555555555512", role: "user", text: "this year", at: "2025-03-15T10:00:00Z")
        ]
        let entries = TodayViewModel.buildEntries(from: records)
        let separators = entries.filter {
            if case .dateSeparator = $0.content { return true }
            return false
        }
        #expect(separators.count == 2)
        #expect(separators[0].id != separators[1].id)
    }

    // 同一天的多条记录共享一个分隔符（按 dayKey 分组，不是按小时）
    @Test func sameDayRecordsShareOneSeparator() throws {
        let records = try [
            record(id: "11111111-2222-3333-4444-555555555521", role: "user", text: "morning", at: "2026-08-22T09:00:00Z"),
            record(id: "11111111-2222-3333-4444-555555555522", role: "user", text: "evening", at: "2026-08-22T21:00:00Z")
        ]
        let entries = TodayViewModel.buildEntries(from: records)
        let separators = entries.filter {
            if case .dateSeparator = $0.content { return true }
            return false
        }
        #expect(separators.count == 1)
    }

    // 滚动请求消费是一次性的：消费后 pendingScrollRequest 清空
    @Test func scrollRequestConsumedOnce() {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        let id = UUID()
        vm.postScrollRequest(TimelineScrollRequest(
            id: id,
            targetEntryId: UUID(),
            anchor: .bottom,
            animation: .instant,
            reason: .initialEntry
        ))
        #expect(vm.pendingScrollRequest?.id == id)
        vm.consumeScrollRequest(id: id)
        #expect(vm.pendingScrollRequest == nil)
    }

    // loading → 最终卡片是同 count、同 id 的原位替换；必须发明确的 finalCardLayout 滚动请求
    @Test func finalCardRequestsBottomScrollWithoutCountChange() async {
        let service = ControllableGenerationMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        let defaults = UserDefaults(suiteName: "diagnostic-scroll-trigger")!
        defaults.removePersistentDomain(forName: "diagnostic-scroll-trigger")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnostic-scroll-trigger", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        vm.successStore = LocalSuccessStore(defaults: defaults, documentsDir: dir)
        vm.pendingRetryStore = PendingRetryStore(defaults: defaults, documentsDir: dir)

        let sendTask = Task { await vm.send("hi") }
        let requestId = await service.waitForStartedRequests(1)[0]
        let loadingCount = vm.entries.count
        let loadingId = vm.entries.last?.id

        await service.succeed(requestId)
        await sendTask.value

        #expect(vm.entries.count == loadingCount)
        #expect(vm.entries.last?.id == loadingId)
        #expect(vm.pendingScrollRequest?.targetEntryId == loadingId)
        #expect(vm.pendingScrollRequest?.anchor == .bottom)
        #expect(vm.pendingScrollRequest?.reason == .finalCardLayout)
    }

    // 边界 1：历史中部条目重试遭遇失败时，生成的失败行依然发出 .center / .retry 请求，绝不拉拽到底部
    @Test func retryFailurePreservesCenterAnchorWithoutJumpingToBottom() async {
        let failingService = AlwaysFailRecordingMock()
        let vm = TodayViewModel(service: failingService, isConsentGranted: { true })
        let bubble = TimelineEntry.userBubble(text: "middle message", image: nil)
        let failedEntry = TimelineEntry(
            id: UUID(),
            createdAt: .now,
            content: .sendFailed(text: "middle message", image: nil, requestId: UUID(), bubbleEntryId: bubble.id)
        )
        let tailEntry = TimelineEntry.userBubble(text: "tail message", image: nil)
        vm.entries = [bubble, failedEntry, tailEntry]

        await vm.retrySend(
            text: "middle message",
            image: nil,
            failedEntryId: failedEntry.id,
            requestId: UUID(),
            bubbleEntryId: bubble.id
        )

        #expect(vm.pendingScrollRequest?.anchor == .center)
        #expect(vm.pendingScrollRequest?.reason == .retry)
        #expect(vm.pendingScrollRequest?.targetEntryId != tailEntry.id)
    }

    // 边界 2：普通发送消息时，runGeneration 追加 loading 后立即将滚动目标推进到 loadingEntry，确保呼吸动效可见
    @Test func sendUpdatesScrollTargetToLoadingEntry() async {
        let service = ControllableGenerationMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        let sendTask = Task { await vm.send("hello") }
        _ = await service.waitForStartedRequests(1)

        // 此时已进入 runGeneration，loading 已挂载，且滚动目标已推进为 loadingEntry.id
        let loadingEntry = vm.entries.last {
            if case .aiLoading = $0.content { return true }
            return false
        }
        #expect(loadingEntry != nil)
        #expect(vm.pendingScrollRequest?.targetEntryId == loadingEntry?.id)
        #expect(vm.pendingScrollRequest?.anchor == .bottom)
        #expect(vm.pendingScrollRequest?.reason == .send)

        sendTask.cancel()
    }

    // 边界 3：defer 中注入的本地成功增量，成为进入对齐会话的最终定位目标
    @Test func deferInjectedLocalSuccessBecomesFinalScrollTarget() async throws {
        let serverJson = """
        [{"id": "11111111-2222-3333-4444-555555555501", "role": "user", "user_content": "server record", "created_at": "2026-08-22T09:00:00Z"}]
        """
        let serverData = serverJson.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "defer-scroll-target-test")!
        defaults.removePersistentDomain(forName: "defer-scroll-target-test")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("defer-scroll-target-test", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let successStore = LocalSuccessStore(defaults: defaults, documentsDir: dir)
        let localCard = AICard.card(CardContent(targetExpression: "Local target"))
        let localReqId = UUID()
        // 模拟本地生成的成功增量（时间晚于服务器历史）
        try successStore.saveTab1(
            text: "local text",
            image: nil,
            requestId: localReqId,
            userMessageId: UUID(),
            assistantMessageId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1800000000),
            card: localCard
        )

        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { serverData },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: LocalCache(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("timeline-defer-cache-\(UUID())", isDirectory: true))
        )
        vm.successStore = successStore

        await vm.loadHistory()

        // 最终结算目标应为 defer 注入后的最新本地卡片，而不是服务器记录
        let lastEntry = vm.entries.last
        #expect(lastEntry != nil)
        #expect(vm.pendingScrollRequest?.targetEntryId == lastEntry?.id)
        #expect(vm.pendingScrollRequest?.anchor == .bottom)
        #expect(vm.pendingScrollRequest?.animation == .instant)
    }

    // 真机复现路径：entries 已由本轮 loadHistory 之前的缓存渲染填充（例如上一次
    // app 启动时的冷启动首刷），此次 loadHistory 的本地注入（S2：pendingRetry /
    // localSuccess）追加了一条比缓存里最新一条更晚的记录——它才是真正的时间线
    // 底部。回归点：旧代码只在“本次 loadHistory 是首次让 entries 从空变有”时才
    // 重新对齐滚动目标；entries 已非空（本测试模拟缓存已渲染）时，S2 注入完全不
    // 会更新 pendingScrollRequest，用户会先停在缓存渲染时的旧底部，直到网络请求
    // 返回、defer 兜底才纠正——表现为「刚进 App 展示的不是最新内容，要等一下」。
    // 用受控网关卡住网络请求，断言在网络完成前（S2 刚注入完）滚动目标已经正确。
    @Test func localInjectionAfterPriorRenderImmediatelyUpdatesScrollTarget() async throws {
        let gate = Tab2RefreshGate()
        let defaults = UserDefaults(suiteName: "local-injection-scroll-target-test")!
        defaults.removePersistentDomain(forName: "local-injection-scroll-target-test")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-injection-scroll-target-test", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pendingRetryStore = PendingRetryStore(defaults: defaults, documentsDir: dir)

        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { try await gate.wait() },
            historyTimeout: .seconds(5),
            isConnected: { true },
            isConsentGranted: { true },
            localCache: LocalCache(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("timeline-injection-cache-\(UUID())", isDirectory: true))
        )
        vm.pendingRetryStore = pendingRetryStore

        // 模拟「上一次冷启动缓存渲染」已把旧内容摆进时间线——本轮 loadHistory 的
        // 步骤 1（读缓存）因 entries 非空会跳过，直接进入步骤 2。
        let staleEntry = TimelineEntry.userBubble(text: "yesterday's cached message", image: nil)
        vm.entries = [staleEntry]

        // 一条比 staleEntry 更晚写作、尚未成功同步的失败发送记录——按写作时刻会被
        // 插到 staleEntry 之后，成为新的真实时间线底部。
        try pendingRetryStore.saveTab1(
            text: "unsynced failed send", image: nil,
            requestId: UUID(), createdAt: .now
        )

        let loadTask = Task { await vm.loadHistory() }
        await waitUntil { vm.entries.count > 1 }   // S2 注入已完成，网络仍被 gate 卡住

        let newLastEntry = vm.entries.last
        #expect(newLastEntry?.id != staleEntry.id)
        #expect(vm.pendingScrollRequest?.targetEntryId == newLastEntry?.id)
        #expect(vm.pendingScrollRequest?.anchor == .bottom)
        #expect(vm.pendingScrollRequest?.animation == .instant)

        await gate.resolve(.success(Data("[]".utf8)))
        await loadTask.value
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Timed out waiting for local injection scroll target")
    }

    // 用户冷启动进入会话后主动滚动，会话立即失效，后续正本替换不再发布滚动请求
    @Test func entryAlignmentSessionCancelsOnUserScroll() async {
        let json = """
        [{"id": "11111111-2222-3333-4444-555555555501", "role": "user", "user_content": "hello", "created_at": "2026-08-22T09:00:00Z"}]
        """
        let recordsData = json.data(using: .utf8)!
        let vm = TodayViewModel(
            service: SuccessMock(),
            historyDataLoader: { recordsData },
            isConnected: { true },
            isConsentGranted: { true },
            localCache: LocalCache(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("timeline-scroll-cache-\(UUID())", isDirectory: true))
        )
        #expect(vm.activeEntrySessionId != nil)
        #expect(vm.hasUserScrolledInCurrentSession == false)

        // 用户主动拖拽/滚动
        vm.userDidScroll()
        #expect(vm.activeEntrySessionId == nil)
        #expect(vm.hasUserScrolledInCurrentSession == true)

        // 后台历史加载完成，由于用户已主动滚动，不强拉到底部
        await vm.loadHistory()
        #expect(vm.pendingScrollRequest == nil)
    }

    // 从 Tab2 切回 Tab1 触发 activateTab，开启新会话并发布无动画滚动请求
    @Test func tabReturnActivatesSessionAndScrollsToLast() {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        let entry = TimelineEntry.userBubble(text: "testing", image: nil)
        vm.entries = [entry]

        vm.activateTab(token: UUID())
        #expect(vm.activeEntrySessionId != nil)
        #expect(vm.pendingScrollRequest?.reason == .tabReturn)
        #expect(vm.pendingScrollRequest?.animation == .instant)
        #expect(vm.pendingScrollRequest?.targetEntryId == entry.id)
    }
}

// MARK: - LocalSuccessStore tests（S1 生成即落本地）

struct LocalSuccessStoreTests {

    private func makeStore(suite: String) -> (LocalSuccessStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-success-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (LocalSuccessStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func sampleCard(_ target: String = "Today's meeting got postponed.") -> AICard {
        .card(CardContent(
            granularity: "sentence", direction: "express",
            targetExpression: target, nativeMeaning: "今天会议推迟了。"
        ))
    }

    // 文字成功记录：写入 → 新实例读取（杀 app 语义）→ 字段与卡片内容完整往返
    @Test func textRecordSurvivesReloadWithCard() throws {
        let (store, dir, defaults) = makeStore(suite: "success-text")
        let requestId = UUID()
        let userMessageId = UUID()
        let assistantMessageId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        try store.saveTab1(
            text: "今天会议推迟了", image: nil, requestId: requestId,
            userMessageId: userMessageId, assistantMessageId: assistantMessageId,
            createdAt: createdAt, card: sampleCard()
        )

        let reloaded = LocalSuccessStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].requestId == requestId)
        #expect(records[0].userMessageId == userMessageId)
        #expect(records[0].assistantMessageId == assistantMessageId)
        #expect(records[0].createdAt == createdAt)
        #expect(records[0].text == "今天会议推迟了")
        // 卡片 JSON 往返解码，内容一致
        guard let restored = reloaded.card(for: records[0]),
              case .card(let content) = restored else {
            Issue.record("Expected card content round-trip"); return
        }
        #expect(content.displayTarget == "Today's meeting got postponed.")
        #expect(content.nativeMeaning == "今天会议推迟了。")
    }

    // 照片成功记录：JPEG 落盘 → 新实例读回图片（气泡图来源）
    @Test func photoRecordSurvivesReloadWithImage() throws {
        let (store, dir, defaults) = makeStore(suite: "success-photo")
        try store.saveTab1(
            text: nil, image: UIImage(systemName: "photo")!, requestId: UUID(),
            userMessageId: nil, assistantMessageId: nil,
            createdAt: .now, card: sampleCard()
        )

        let reloaded = LocalSuccessStore(defaults: defaults, documentsDir: dir)
        let record = reloaded.load()[0]
        #expect(record.photoFileName != nil)
        #expect(reloaded.bubbleImage(for: record) != nil)
    }

    // 预设卡成功记录：asset 图名往返 + 气泡图来自内置素材
    @Test func presetRecordRoundTrips() {
        let (store, dir, defaults) = makeStore(suite: "success-preset")
        store.saveOnboardingPreset(
            imageName: "card_scene_1", requestId: UUID(),
            createdAt: .now, card: sampleCard()
        )

        let reloaded = LocalSuccessStore(defaults: defaults, documentsDir: dir)
        let record = reloaded.load()[0]
        #expect(record.presetImageName == "card_scene_1")
        #expect(record.photoFileName == nil)
        #expect(reloaded.bubbleImage(for: record) != nil)
    }

    // 幂等：同 requestId 重复保存（重试复用幂等键）只留一条
    @Test func sameRequestIdIsIdempotent() throws {
        let (store, _, _) = makeStore(suite: "success-idempotent")
        let requestId = UUID()
        try store.saveTab1(text: "hi", image: nil, requestId: requestId,
                           userMessageId: nil, assistantMessageId: nil,
                           createdAt: .now, card: sampleCard())
        try store.saveTab1(text: "hi", image: nil, requestId: requestId,
                           userMessageId: nil, assistantMessageId: nil,
                           createdAt: .now, card: sampleCard())
        #expect(store.load().count == 1)
    }

    // error 卡不是耐久内容：编码直接拒绝，不落本地
    @Test func errorCardIsRejected() throws {
        let json = #"{"card_type":"error","card_content":{"error_type":"unsafe"}}"#
            .data(using: .utf8)!
        let envelope = try JSONDecoder().decode(AIEnvelope.self, from: json)
        #expect(throws: (any Error).self) {
            try LocalSuccessStore.encodeCard(envelope.card)
        }
    }
}

// MARK: - S1/S2 注入时序 tests

@MainActor
struct LocalSuccessInjectionTests {

    private func makeStore(suite: String) -> (LocalSuccessStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-success-inject-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (LocalSuccessStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    private func makePendingStore(suite: String) -> PendingRetryStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-inject-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRetryStore(defaults: defaults, documentsDir: dir)
    }

    private func dayLabelInTest(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // 发送成功 → 成功增量落本地；同会话再注入被幂等跳过（不出现重复气泡+卡片）
    @Test func sendSuccessPersistsAndDoesNotDuplicateOnInjection() async throws {
        let store = makeStore(suite: "inject-send-success").0
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "inject-send-success-pending")

        await vm.send("今天会议推迟了")
        let records = store.load()
        #expect(records.count == 1)
        #expect(records[0].text == "今天会议推迟了")
        #expect(records[0].userMessageId != nil)   // Tab1 路径携带服务端消息行 ID
        #expect(records[0].assistantMessageId != nil)

        let countBefore = vm.entries.count
        vm.injectLocalSuccesses()   // 模拟同会话回前台刷新：displayed 集合挡住重复注入
        #expect(vm.entries.count == countBefore)
    }

    // 注入按写作时刻归位：day1 的成功对插进 day2 历史之前，且 day1 补自己的标题
    @Test func injectionPlacesPairChronologically() throws {
        let store = makeStore(suite: "inject-chronological").0
        let base = Date(timeIntervalSince1970: 1_800_000_000)   // 固定日期，避免跨零点抖动
        let day1 = base.addingTimeInterval(3_600)
        let day2 = base.addingTimeInterval(86_400)
        let userMessageId = UUID()
        let assistantMessageId = UUID()
        try store.saveTab1(
            text: "day before", image: nil, requestId: UUID(),
            userMessageId: userMessageId, assistantMessageId: assistantMessageId,
            createdAt: day1,
            card: .card(CardContent(granularity: "sentence", direction: "express",
                                    targetExpression: "Yesterday's note."))
        )

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "inject-chronological-pending")
        // 服务端历史：只有 day2 一条（带该日标题）
        vm.entries = [
            TimelineEntry(id: UUID(), createdAt: day2,
                          content: .dateSeparator(dayLabelInTest(for: day2))),
            TimelineEntry(id: UUID(), createdAt: day2,
                          content: .userBubble(text: "server history", image: nil,
                                               imageUrl: nil, imageStableKey: nil))
        ]

        vm.injectLocalSuccesses()

        func kind(_ entry: TimelineEntry) -> String {
            switch entry.content {
            case .dateSeparator: return "sep"
            case .userBubble: return "bubble"
            case .aiCard: return "card"
            default: return "other"
            }
        }
        #expect(vm.entries.map(kind) == ["sep", "bubble", "card", "sep", "bubble"])
        // 气泡 id 用服务端消息行 ID：对齐回放时同 ID，零重排
        #expect(vm.entries[1].id == userMessageId)
        #expect(vm.entries[2].id == assistantMessageId)
    }

    // 幂等键已在服务端历史 → 本地副本清除、不注入（对齐已带回正本）
    @Test func injectionSkipsServerCommittedRequestIds() throws {
        let store = makeStore(suite: "inject-committed").0
        let requestId = UUID()
        try store.saveTab1(text: "already on server", image: nil, requestId: requestId,
                           userMessageId: nil, assistantMessageId: nil,
                           createdAt: .now,
                           card: .card(CardContent(targetExpression: "On server.")))

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "inject-committed-pending")
        vm.entries = [TimelineEntry.userBubble(text: "server history", image: nil)]

        vm.injectLocalSuccesses(serverRequestIds: [requestId])

        #expect(store.load().isEmpty)            // 服务器有正本：本地副本清除
        #expect(vm.entries.count == 1)           // 不注入
    }

    // 气泡 id（服务端消息行 id）已在时间线 → 跳过注入（不重复）
    @Test func injectionSkipsAlreadyDisplayedUserMessageId() throws {
        let store = makeStore(suite: "inject-displayed").0
        let userMessageId = UUID()
        try store.saveTab1(text: "hi", image: nil, requestId: UUID(),
                           userMessageId: userMessageId, assistantMessageId: UUID(),
                           createdAt: .now,
                           card: .card(CardContent(targetExpression: "Hi.")))

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "inject-displayed-pending")
        vm.entries = [
            TimelineEntry(id: userMessageId, createdAt: .now,
                          content: .userBubble(text: "hi", image: nil,
                                               imageUrl: nil, imageStableKey: nil))
        ]

        vm.injectLocalSuccesses()

        #expect(vm.entries.count == 1)   // 已在时间线，不注入
        #expect(store.load().count == 1) // 记录保留（尚未被服务端确认）
    }

    // 重试成功：失败行清掉、成功增量落本地（冷启动秒显的来源），不重复
    @Test func retrySuccessWritesLocalSuccessAndClearsPending() async throws {
        let store = makeStore(suite: "retry-success-writes").0
        let pending = makePendingStore(suite: "retry-success-writes-pending")
        let service = FailOnceMock()
        let vm = TodayViewModel(service: service, isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = pending

        await vm.send("今天会议推迟了")   // 第一次失败 → pending 记录

        guard let failed = vm.entries.first(where: {
            if case .sendFailed = $0.content { return true }
            return false
        }), case .sendFailed(let text, let image, let requestId, let bubbleEntryId) = failed.content else {
            Issue.record("Expected sendFailed entry"); return
        }
        await vm.retrySend(text: text, image: image, failedEntryId: failed.id,
                           requestId: requestId, bubbleEntryId: bubbleEntryId)

        #expect(pending.load().isEmpty)        // 失败行已清
        #expect(store.load().count == 1)       // 成功增量已落
        #expect(store.load()[0].requestId == requestId)   // 复用原幂等键
    }

    // 幽灵对回归锁定：生成在途（重试已临时移除失败行、loading 在场）时，
    // 注入必须跳过——否则时间线上会凭空多出一对「气泡 + 失败行」（成功也清不掉）。
    // 真机复现路径：断网发送 → 点重试 → 重试在途时回前台/下拉刷新触发 loadHistory。
    @Test func tab1InjectionSkippedWhileGenerationInFlight() async throws {
        let pending = makePendingStore(suite: "inject-inflight-pending")
        let requestId = UUID()
        try pending.saveTab1(text: "inflight", image: nil, requestId: requestId, createdAt: .now)

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = pending
        vm.successStore = makeStore(suite: "inject-inflight-success").0
        // 模拟重试在途：失败行已移除、loading 在场、isLoading = true
        vm.entries = [
            TimelineEntry.userBubble(text: "inflight", image: nil),
            TimelineEntry.aiLoading()
        ]
        vm.isLoading = true

        vm.injectPendingRetry()

        #expect(vm.entries.count == 2)          // 无幽灵对
        #expect(pending.load().count == 1)      // 记录保留（本次尝试未结局，成败由它负责）
    }

    // ① 回归锁定：无服务端消息行 ID 的记录（onboarding 照片/预设卡路径）本会话只注入一次。
    // 真机复现：onboarding 后首次进 Tab1 恰逢断网——同一次 loadHistory 网络前注入一遍、
    // 拉取失败后 defer 兜底再注入一遍、每次回前台再翻倍，屏上卡片成对累积。
    @Test func onboardingRecordInjectedOnlyOncePerSession() {
        let store = makeStore(suite: "inject-onboarding-once").0
        let requestId = UUID()
        store.saveOnboardingPreset(
            imageName: "card_scene_1", requestId: requestId,
            createdAt: .now,
            card: .card(CardContent(granularity: "sentence", direction: "express",
                                    targetExpression: "A preset scene."))
        )

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "inject-onboarding-once-pending")

        vm.injectLocalSuccesses()   // 第一次：loadHistory 网络前注入
        #expect(vm.entries.count == 3)   // 日期标题 + 气泡 + 卡片，恰好一对
        vm.injectLocalSuccesses()   // 第二次：fetch 失败后 defer 兜底 / 下次回前台
        #expect(vm.entries.count == 3)   // 不翻倍
        #expect(store.load().count == 1) // 记录保留：未获服务端确认，杀 app 重启仍会注入一次
    }

    // 回归锁定：onboarding 照片待重试行重试成功 → 失败记录清除 + 成功增量落本地
    // （冷启动秒显的来源）。该写入由 runGeneration 的 S1 统一分支负责（requestId 非空
    // 即写，照片重试路径已带）——锁定它，防止未来改动把这条路径的 S1 覆盖弄丢。
    @Test func photoRetrySuccessWritesLocalSuccess() async throws {
        let store = makeStore(suite: "photo-retry-success").0
        let pending = makePendingStore(suite: "photo-retry-success-pending")
        try pending.savePhoto(UIImage(systemName: "photo")!, requestId: UUID())
        guard let record = pending.load().first else {
            Issue.record("Expected pending photo record"); return
        }

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = pending

        await vm.retryPending(record: record)

        #expect(pending.load().isEmpty)                    // 失败记录已清
        #expect(store.load().count == 1)                   // 成功增量已落
        #expect(store.load()[0].requestId == record.requestId)   // 复用原幂等键
    }

    // MARK: - 代码审查修复回归测试（2026-08-23）

    // #1：主动发送清掉进入对齐会话——冷启动历史在途时发送，新内容也要自动滚到底
    @Test func sendCancelsActiveEntrySession() async throws {
        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = makeStore(suite: "passive-clear").0
        vm.pendingRetryStore = makePendingStore(suite: "passive-clear-pending")
        vm.startEntryAlignmentSession()   // 模拟冷启动或切回 Tab1 建立的对齐会话
        #expect(vm.activeEntrySessionId != nil)

        await vm.send("hi")

        #expect(vm.activeEntrySessionId == nil)   // 发送是主动动作：会话清除，视图按主动交互滚动
    }

    // #2：同 requestId 的失败记录与成功记录并存（杀进程窗口）→ 失败侧不注入，成功侧照常
    @Test func pendingRecordWithSuccessTwinIsNotInjected() throws {
        let requestId = UUID()
        let userMessageId = UUID()
        let assistantMessageId = UUID()
        let pendingStore = makePendingStore(suite: "twin-pending")
        let successStore = makeStore(suite: "twin-success").0
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        try pendingStore.saveTab1(text: "hi", image: nil, requestId: requestId, createdAt: createdAt)
        try successStore.saveTab1(
            text: "hi", image: nil, requestId: requestId,
            userMessageId: userMessageId, assistantMessageId: assistantMessageId,
            createdAt: createdAt, card: .card(CardContent(targetExpression: "Hi."))
        )

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = successStore
        vm.pendingRetryStore = pendingStore

        vm.injectPendingRetry()
        // 失败侧不注入：不出现「气泡 + 失败行」幽灵对
        #expect(vm.entries.isEmpty)
        // 记录保留在 store（下次联网后由 stale 检查自然清除）
        #expect(pendingStore.load().count == 1)

        vm.injectLocalSuccesses()
        // 成功侧注入「日期分隔符 + 气泡 + 卡片」，气泡用服务端消息行 ID
        #expect(vm.entries.count == 3)
        #expect(vm.entries[1].id == userMessageId)
        #expect(vm.entries[2].id == assistantMessageId)
    }

    // #3：跨零点——昨天的分隔符文案同为 "Today"，dayKey 判定不误并
    @Test func hasTodaySeparatorUsesDayKeyNotLabel() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current

        // 昨天的 23:59：文案与今天同为 "Today"（跨零点后的昨天分组）
        let yesterdayLate = try #require(formatter.date(from: "2026-01-01 23:59"))
        let yesterdaySeparator = TimelineEntry(
            id: UUID(), createdAt: yesterdayLate,
            content: .dateSeparator("Today")
        )
        #expect(!TodayViewModel.hasTodaySeparator(
            lastSeparator: yesterdaySeparator, todayKey: "2026-01-02"))

        let today = try #require(formatter.date(from: "2026-01-02 08:00"))
        let todaySeparator = TimelineEntry(
            id: UUID(), createdAt: today,
            content: .dateSeparator("Today")
        )
        #expect(TodayViewModel.hasTodaySeparator(lastSeparator: todaySeparator, todayKey: "2026-01-02"))
        #expect(!TodayViewModel.hasTodaySeparator(lastSeparator: nil, todayKey: "2026-01-02"))
    }

    // #6c：一条记录损坏只丢那一条，其余记录存活且自愈写回
    @Test func corruptRecordDoesNotWipeSurvivingRecords() throws {
        let (store, _, defaults) = makeStore(suite: "corrupt-one")
        let goodRequestId = UUID()
        let badRequestId = UUID()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        try store.saveTab1(
            text: "good", image: nil, requestId: goodRequestId,
            userMessageId: nil, assistantMessageId: nil, createdAt: base,
            card: .card(CardContent(targetExpression: "Good."))
        )
        try store.saveTab1(
            text: "bad", image: nil, requestId: badRequestId,
            userMessageId: nil, assistantMessageId: nil, createdAt: base,
            card: .card(CardContent(targetExpression: "Bad."))
        )

        // 把其中一条的 requestId 换成非法 UUID 字符串 → 该条解码失败 → 整体数组解码失败
        let key = "local_success_records"
        let raw = try #require(defaults.data(forKey: key))
        var text = try #require(String(data: raw, encoding: .utf8))
        text = text.replacingOccurrences(of: badRequestId.uuidString, with: "not-a-uuid")
        defaults.set(Data(text.utf8), forKey: key)

        let records = store.load()
        #expect(records.count == 1)                    // 好记录存活
        #expect(records[0].requestId == goodRequestId)
        #expect(store.load().count == 1)               // 自愈写回：再次读取整体解码成功
    }

    // #7：cardData 解不出卡片（如升级后 schema 变化）→ 跳过注入但保留本地副本
    @Test func badCardRecordIsSkippedButRetained() throws {
        let (store, _, defaults) = makeStore(suite: "bad-card")
        let requestId = UUID()
        try store.saveTab1(
            text: "hi", image: nil, requestId: requestId,
            userMessageId: nil, assistantMessageId: nil, createdAt: .now,
            card: .card(CardContent(targetExpression: "Hi."))
        )

        // 把 cardData 换成「合法 base64 但解不出卡片」的内容：记录本身仍可解码，
        // 只有 card(for:) 会失败
        let record = store.load()[0]
        let originalBase64 = record.cardData.base64EncodedString()
        let key = "local_success_records"
        let raw = try #require(defaults.data(forKey: key))
        var text = try #require(String(data: raw, encoding: .utf8))
        text = text.replacingOccurrences(
            of: originalBase64,
            with: Data("corrupted card json".utf8).base64EncodedString()
        )
        defaults.set(Data(text.utf8), forKey: key)

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "bad-card-pending")

        vm.injectLocalSuccesses()
        #expect(vm.entries.isEmpty)                    // 坏记录不注入
        #expect(store.load().count == 1)               // 本地副本保留（服务端正本兜底前不毁底稿）

        vm.injectLocalSuccesses()                      // 再跑一次：行为一致，不反复失败也不删
        #expect(vm.entries.isEmpty)
        #expect(store.load().count == 1)
    }

    // #8：onboarding 照片的服务器消息行 ID 透传进 S1 记录，注入时用作条目身份证
    @Test func onboardingPhotoCarriesServerIdsIntoInjection() throws {
        let (store, _, _) = makeStore(suite: "onboarding-ids")
        let requestId = UUID()
        let userMessageId = UUID()
        let assistantMessageId = UUID()
        let image = try #require(UIImage(systemName: "camera"))
        try store.saveOnboardingPhoto(
            image, requestId: requestId, createdAt: .now,
            userMessageId: userMessageId, assistantMessageId: assistantMessageId,
            card: .card(CardContent(targetExpression: "My desk."))
        )

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = store
        vm.pendingRetryStore = makePendingStore(suite: "onboarding-ids-pending")
        vm.injectLocalSuccesses()

        #expect(vm.entries.count == 3)   // 日期分隔符 + 气泡 + 卡片
        #expect(vm.entries[1].id == userMessageId)     // 气泡用服务端消息行 ID：对齐零重排
        #expect(vm.entries[2].id == assistantMessageId)
    }

    // #12：整列替换放行判定——生成在途 / 会话已有实时对话 / 快照缺会话已展示键，任一命中不放行
    @Test func shouldReplaceHistoryGatesAllThreeConditions() {
        let sessionIds: Set<UUID> = [UUID(), UUID()]
        let serverIds: Set<UUID> = [UUID()]
        let unionIds = sessionIds.union(serverIds)

        // 三关全过 → 放行
        #expect(TodayViewModel.shouldReplaceHistory(
            isLoading: false, hasLiveActivity: false,
            displayedSuccessRequestIds: sessionIds, serverRequestIds: unionIds))

        // 生成在途 → 不放行
        #expect(!TodayViewModel.shouldReplaceHistory(
            isLoading: true, hasLiveActivity: false,
            displayedSuccessRequestIds: sessionIds, serverRequestIds: unionIds))

        // 本会话已有实时对话 → 不放行
        #expect(!TodayViewModel.shouldReplaceHistory(
            isLoading: false, hasLiveActivity: true,
            displayedSuccessRequestIds: sessionIds, serverRequestIds: unionIds))

        // 服务端快照缺了会话已展示的幂等键 → 不放行（会话内容被替换会冲掉）
        #expect(!TodayViewModel.shouldReplaceHistory(
            isLoading: false, hasLiveActivity: false,
            displayedSuccessRequestIds: sessionIds, serverRequestIds: serverIds))

        // 边界：无会话键（冷启动纯历史对齐）→ 放行
        #expect(TodayViewModel.shouldReplaceHistory(
            isLoading: false, hasLiveActivity: false,
            displayedSuccessRequestIds: [], serverRequestIds: []))
    }

    // #13：失败行整会话残留——服务端历史已有该幂等键（超时误判失败/他处重试成功）时，
    // 注入对账顺带移除屏上的错误失败行；气泡保留（消息确实发出去了）
    @Test func staleFailedRowIsRemovedButBubbleStays() throws {
        let requestId = UUID()
        let bubbleId = UUID()
        let failedId = UUID()

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.successStore = makeStore(suite: "stale-row").0
        vm.pendingRetryStore = makePendingStore(suite: "stale-row-pending")
        vm.entries = [
            TimelineEntry(
                id: bubbleId, createdAt: .now,
                content: .userBubble(text: "hi", image: nil, imageUrl: nil, imageStableKey: nil)
            ),
            TimelineEntry(
                id: failedId, createdAt: .now,
                content: .sendFailed(text: "hi", image: nil, requestId: requestId, bubbleEntryId: bubbleId)
            )
        ]

        vm.injectPendingRetry(serverRequestIds: [requestId])

        #expect(vm.entries.count == 1)          // 失败行移除
        #expect(vm.entries[0].id == bubbleId)   // 气泡保留

        // 反向：服务端没有该幂等键 → 失败行不动（仍是合法的待重试状态）
        vm.entries = [
            TimelineEntry(
                id: bubbleId, createdAt: .now,
                content: .userBubble(text: "hi", image: nil, imageUrl: nil, imageStableKey: nil)
            ),
            TimelineEntry(
                id: failedId, createdAt: .now,
                content: .sendFailed(text: "hi", image: nil, requestId: requestId, bubbleEntryId: bubbleId)
            )
        ]
        vm.injectPendingRetry(serverRequestIds: [])
        #expect(vm.entries.count == 2)          // 气泡 + 失败行都在
    }
}

// MARK: - Settings 页的两处单一真源
//
// 这一刀绝大部分是视图改动，没有可测的新逻辑。唯一值得钉住的是「把两份重复的
// 字面量合并成一份」这个动作本身——合并时写错一个 URL 是最可能、也最难发现的失误：
// 隐私政策打开旧地址不会崩、不会报错，只会在 App Review 5.1.2 那关被拒。

@Suite("Settings single sources of truth")
struct SettingsSingleSourceTests {

    @Test func legalLinksAreDistinctHTTPSURLs() {
        #expect(LegalLinks.privacy != LegalLinks.terms)
        for url in [LegalLinks.privacy, LegalLinks.terms] {
            #expect(url.scheme == "https")
            #expect(url.host?.isEmpty == false)
        }
        // 各自指向自己那份文档，不是两个名字指同一个地址
        #expect(LegalLinks.privacy.lastPathComponent == "privacy.html")
        #expect(LegalLinks.terms.lastPathComponent == "terms.html")
    }

    @Test func learningLanguagesAreDistinctAndNonEmpty() {
        #expect(!LearningLanguages.target.isEmpty)
        #expect(!LearningLanguages.native.isEmpty)
        // 目标语言与母语写串是这两个常量唯一可能出的错
        #expect(LearningLanguages.target != LearningLanguages.native)
    }
}

// MARK: - AI Consent Presentation Detents (N1 回归守卫)

@Suite("AI Consent presentation detents")
struct AIConsentPresentationDetentsTests {

    // Tab1 场景：allowsLarge: true 时产出两档（包含 .large 展开档与默认 410pt 高度），保证 AX 大字号可舒适阅读
    @Test func allowsLargeTrueIncludesLargeAndFixedDetent() {
        let detents = AIConsentPresentationDetents.detents(allowsLarge: true)
        #expect(detents.count == 2)
        #expect(detents.contains(.large))
        #expect(detents.contains(.height(AppTheme.Size.consentSheetHeight)))
    }

    // Onboarding 场景：allowsLarge: false 锁定单档 .height(410)，符合封闭引导流产品决策
    @Test func allowsLargeFalseLocksToSingleHeightDetent() {
        let detents = AIConsentPresentationDetents.detents(allowsLarge: false)
        #expect(detents.count == 1)
        #expect(!detents.contains(.large))
        #expect(detents.contains(.height(AppTheme.Size.consentSheetHeight)))
    }
}

// MARK: - 底部暖光规范验证（WarmAuraGlow 结构与 B 档专属参数）

@Suite("Bottom Warm Aura Spec Tests")
struct BottomWarmAuraSpecTests {

    @Test func warmAuraGlowGradientStopsEnforceFourPhaseContract() {
        let glow = WarmAuraGlow()
        let stops = glow.gradientStops
        #expect(stops.count == 4)
        #expect(stops.first?.location == 0.00)
        #expect(stops.last?.location == 1.00)
    }

    @Test func warmAuraGlowBtierDefaultDimensionsWithinScreenBounds() {
        let glow = WarmAuraGlow()
        // 方案 3D 规范定稿：宽度 320、高度 102（scaleY 0.32）、下沉 60pt、峰值 0.11、模糊 20pt
        // 严格收进最小 iPhone 屏宽（SE3: 375pt）以内，单层平滑各向同性衰减，消灭内外双层光圈
        #expect(glow.width == 320)
        #expect(glow.height == 102)
        #expect(glow.offsetY == 60)
        #expect(glow.peakOpacity == 0.11)
        #expect(glow.blurRadius == 20)
        #expect(glow.endRadius == 160)
    }
}

// MARK: - Tab1 Timeline Spacing Tests（时间线外部与内部间距规范验收）

@MainActor
struct Tab1TimelineSpacingTests {

    @Test func timelineSpacingTokensMatchSpecValues() {
        // 1. 用户输入 → 对应 AI 结果：12pt
        #expect(AppTheme.Space.timelineUserToAI == 12)
        // 2. AI 结果／失败行 → 下一次输入：28pt
        #expect(AppTheme.Space.timelineResultToNextInput == 28)
        // 3. 上一组内容 → 日期胶囊：32pt
        #expect(AppTheme.Space.timelineContentToDate == 32)
        // 4. 日期胶囊 → 当天第一条输入：16pt
        #expect(AppTheme.Space.timelineDateToFirstInput == 16)
        // 5. 同次输入的图片 → 文字：8pt
        #expect(AppTheme.Space.timelineImageToText == 8)
    }

    @Test func userInputToAIResultIs12pt() {
        let entries: [TimelineEntry] = [
            TimelineEntry.userBubble(text: "Hello", image: nil),
            TimelineEntry.aiLoading(),
            TimelineEntry.userBubble(text: "How are you", image: nil),
            TimelineEntry.aiCard(AICard.card(CardContent(granularity: "word", direction: "comprehend", targetExpression: "hello", nativeMeaning: "你好"))),
            TimelineEntry.userBubble(text: "Failed attempt", image: nil),
            TimelineEntry(id: UUID(), createdAt: .now, content: .sendFailed(text: "Failed attempt", image: nil, requestId: nil, bubbleEntryId: nil))
        ]

        // 用户输入 -> loading: 12pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 12)
        // 用户输入 -> aiCard: 12pt
        #expect(TodayView.timelineSpacing(after: 2, in: entries) == 12)
        // 用户输入 -> sendFailed: 12pt
        #expect(TodayView.timelineSpacing(after: 4, in: entries) == 12)
    }

    @Test func aiResultOrFailureToNextInputIs28pt() {
        let dummyPendingRecord = PendingRetryRecord(
            id: UUID(), source: .presetCard,
            requestId: UUID(), presetCardId: nil,
            presetImageName: nil, photoFileName: nil,
            text: nil, createdAt: .now
        )
        let entries: [TimelineEntry] = [
            TimelineEntry.aiCard(AICard.card(CardContent(granularity: "word", direction: "comprehend", targetExpression: "word", nativeMeaning: "单词"))),
            TimelineEntry.userBubble(text: "next input", image: nil),
            TimelineEntry(id: UUID(), createdAt: .now, content: .sendFailed(text: "err", image: nil, requestId: nil, bubbleEntryId: nil)),
            TimelineEntry.userBubble(text: "retry input", image: nil),
            TimelineEntry(id: UUID(), createdAt: .now, content: .userRejected(text: "blocked", wasImage: false)),
            TimelineEntry.userBubble(text: "another input", image: nil),
            TimelineEntry.aiCard(AICard.error(ErrorContent(errorType: "server_error", message: "Server error"))),
            TimelineEntry.userBubble(text: "after error input", image: nil),
            TimelineEntry.pendingRetry(dummyPendingRecord),
            TimelineEntry.userBubble(text: "after pending input", image: nil)
        ]

        // aiCard -> 下一次输入: 28pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 28)
        // sendFailed -> 下一次输入: 28pt
        #expect(TodayView.timelineSpacing(after: 2, in: entries) == 28)
        // userRejected -> 下一次输入: 28pt
        #expect(TodayView.timelineSpacing(after: 4, in: entries) == 28)
        // aiError -> 下一次输入: 28pt
        #expect(TodayView.timelineSpacing(after: 6, in: entries) == 28)
        // pendingRetry -> 下一次输入: 28pt
        #expect(TodayView.timelineSpacing(after: 8, in: entries) == 28)
    }

    @Test func previousContentToDateSeparatorIs32pt() {
        let entries: [TimelineEntry] = [
            TimelineEntry.aiCard(AICard.card(CardContent(granularity: "sentence", direction: "comprehend", targetExpression: "Yesterday's note", nativeMeaning: "昨天的笔记"))),
            TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
            TimelineEntry.userBubble(text: "Today's input", image: nil)
        ]

        // 上一组内容 -> 日期胶囊: 32pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 32)
    }

    @Test func dateSeparatorToFirstInputIs16pt() {
        let entries: [TimelineEntry] = [
            TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
            TimelineEntry.userBubble(text: "First input of today", image: nil)
        ]

        // 日期胶囊 -> 当天第一条输入: 16pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 16)
    }

    @Test func pendingRetryToAiLoadingIs12pt() {
        let dummyPendingRecord = PendingRetryRecord(
            id: UUID(), source: .presetCard,
            requestId: UUID(), presetCardId: nil,
            presetImageName: nil, photoFileName: nil,
            text: nil, createdAt: .now
        )
        let entries: [TimelineEntry] = [
            TimelineEntry.pendingRetry(dummyPendingRecord),
            TimelineEntry.aiLoading()
        ]
        // N1: pendingRetry 重试触发的 loading 属于同组延续 -> 12pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 12)
    }

    @Test func userBubbleToNextInputOrPendingRetryIs28pt() {
        let dummyPendingRecord = PendingRetryRecord(
            id: UUID(), source: .presetCard,
            requestId: UUID(), presetCardId: nil,
            presetImageName: nil, photoFileName: nil,
            text: nil, createdAt: .now
        )
        let entries: [TimelineEntry] = [
            TimelineEntry.userBubble(text: "First input", image: nil),
            TimelineEntry.userBubble(text: "Second input without AI response", image: nil),
            TimelineEntry.pendingRetry(dummyPendingRecord)
        ]
        // N2: 用户输入接用户输入 -> 28pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 28)
        // N2: 用户输入接待重试行 -> 28pt
        #expect(TodayView.timelineSpacing(after: 1, in: entries) == 28)
    }

    @Test func dateSeparatorToDateSeparatorIs16pt() {
        let entries: [TimelineEntry] = [
            TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Yesterday")),
            TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
            TimelineEntry.userBubble(text: "Today's input", image: nil)
        ]
        // N4: 两个日期胶囊相邻（空天）-> 16pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 16)
        // 日期胶囊到输入 -> 16pt
        #expect(TodayView.timelineSpacing(after: 1, in: entries) == 16)
    }

    @Test func lastItemHasNoExtraBottomSpacing() {
        let entries: [TimelineEntry] = [
            TimelineEntry(id: UUID(), createdAt: .now, content: .dateSeparator("Today")),
            TimelineEntry.userBubble(text: "Hello", image: nil),
            TimelineEntry.aiCard(AICard.card(CardContent(granularity: "word", direction: "comprehend", targetExpression: "hello", nativeMeaning: "你好")))
        ]

        // 最后一项 -> 0
        #expect(TodayView.timelineSpacing(after: 2, in: entries) == 0)
        // 越界索引 -> 0
        #expect(TodayView.timelineSpacing(after: 3, in: entries) == 0)
    }

    @Test func pureImageInputHasDescribeBubbleWith8ptAndBottomToResult12pt() {
        // 纯图片输入由 ViewModel 构造气泡为 text: "Describe this image", image != nil
        let bubble = TimelineEntry.userBubble(text: "Describe this image", image: UIImage())
        let card = TimelineEntry.aiCard(AICard.card(CardContent(granularity: "sentence", direction: "express", targetExpression: "A cozy room", nativeMeaning: "温馨的房间")))
        let entries = [bubble, card]

        // 验证气泡底部到结果严格遵守 12pt
        #expect(TodayView.timelineSpacing(after: 0, in: entries) == 12)
        // 验证内部图片到文字气泡为 8pt
        #expect(AppTheme.Space.timelineImageToText == 8)
    }
}

// MARK: - AICardBody Spacing & Structure Tests（AI 卡片内部间距与结构优化验证）

@MainActor
struct AICardBodySpacingTests {

    @Test func wordCardContentVariantsStructure() {
        // 完整 Word 卡片
        let fullWord = CardContent(
            granularity: "word",
            direction: "comprehend",
            targetExpression: "procrastinate",
            nativeMeaning: "拖延",
            phonetic: "/prəˈkræstɪneɪt/",
            pos: ["v."],
            examples: [
                BilingualExample(en: "Don't procrastinate.", zh: "别拖延。"),
                BilingualExample(en: "I procrastinated all day.", zh: "我拖了一整天。")
            ],
            grammarNote: "Latin origin."
        )
        #expect(fullWord.isWord)
        #expect(fullWord.phonetic != nil)
        #expect(!fullWord.pos.isEmpty)
        #expect(fullWord.examples.count == 2)
        #expect(fullWord.displayableGrammarNote == "Latin origin.")

        // 仅单条例句的 Word 卡片
        let singleExampleWord = CardContent(
            granularity: "word",
            direction: "comprehend",
            targetExpression: "serendipity",
            nativeMeaning: "机缘巧合",
            phonetic: nil,
            pos: [],
            examples: [BilingualExample(en: "It was pure serendipity.", zh: "纯属机缘巧合。")]
        )
        #expect(singleExampleWord.isWord)
        #expect(singleExampleWord.phonetic == nil)
        #expect(singleExampleWord.pos.isEmpty)
        #expect(singleExampleWord.examples.count == 1)

        // 无例句 Word 卡片
        let noExampleWord = CardContent(
            granularity: "word",
            direction: "comprehend",
            targetExpression: "ephemeral",
            nativeMeaning: "短暂的",
            examples: []
        )
        #expect(noExampleWord.examples.isEmpty)
    }

    @Test func sentenceRevisionVsNoRevisionStructure() {
        // 修正态：有意义修正
        let revised = CardContent(
            granularity: "sentence",
            direction: "comprehend",
            revisionType: "error",
            userOriginal: "I am very sleep today",
            targetExpression: "I'm very sleepy today",
            nativeMeaning: "我今天很困",
            grammarNote: "sleepy is adjective"
        )
        #expect(revised.hasMeaningfulRevision)
        #expect(revised.displayableGrammarNote != nil)

        // 无修正态：正确句
        let correct = CardContent(
            granularity: "sentence",
            direction: "comprehend",
            userOriginal: "I'm heading out now.",
            targetExpression: "I'm heading out now.",
            nativeMeaning: "我现在出门了。"
        )
        #expect(!correct.hasMeaningfulRevision)

        // Express 态：母语到目标语
        let express = CardContent(
            granularity: "sentence",
            direction: "express",
            userOriginal: "我想喝咖啡",
            targetExpression: "I'd like to have a coffee.",
            grammarNote: "express note should not show"
        )
        #expect(!express.hasMeaningfulRevision)
        #expect(express.displayableGrammarNote == nil)
    }

    @Test func passageCardStructureAndLimit() {
        let passage = CardContent(
            granularity: "passage",
            direction: "comprehend",
            targetExpression: "Line 1\nLine 2\nLine 3",
            grammarNote: "Passage note.",
            passageLines: [
                PassageLine(en: "First sentence.", zh: "第一句。"),
                PassageLine(en: "Second sentence.", zh: "第二句。"),
                PassageLine(en: "Third sentence.", zh: "第三句。")
            ]
        )
        #expect(passage.isPassage)
        #expect(passage.passageLines.count == 3)
        #expect(passage.displayableGrammarNote == "Passage note.")
    }
}
