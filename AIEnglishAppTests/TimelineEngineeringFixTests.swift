import Testing
import Foundation
import UIKit
import SwiftUI
@testable import AIEnglishApp

@MainActor
private final class TimelineGeometryCapture {
    var frame: CGRect = .zero
}

@MainActor
private struct ShortTimelineFixture: View {
    let topMargin: CGFloat
    let markerFrame: TimelineGeometryCapture

    var body: some View {
        InitialBottomScrollView(
            topContentMargin: topMargin,
            bottomContentInset: 100
        ) {
            Color.clear.frame(width: 0, height: 0)
            LazyVStack(spacing: 0) {
                Color.clear
                    .frame(height: 100)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        markerFrame.frame = frame
                    }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 100)
        }
        .contentMargins(.top, topMargin, for: .scrollContent)
    }
}


/// 与 TodayView.historyTimeline 同构的停靠线夹具：InitialBottomScrollView + LazyVStack
/// （仅顶/左右边距）+ 底部 safeAreaInset（输入框高度 + 停靠净空）+ 顶部 contentMargins。
@MainActor
private final class DockingProbe {
    var lastRowFrame: CGRect = .zero
    var proxy: ScrollViewProxy?
}

@MainActor
private struct DockingTimelineFixture: View {
    static let inputBarHeight: CGFloat = 60
    static let topMargin: CGFloat = 80
    let rowHeights: [CGFloat]
    let probe: DockingProbe

    var body: some View {
        ScrollViewReader { proxy in
            InitialBottomScrollView(
                topContentMargin: Self.topMargin,
                bottomContentInset: Self.inputBarHeight + AppTheme.Space.timelineInputClearance
            ) {
                Color.clear.frame(width: 0, height: 0)
                LazyVStack(spacing: 0) {
                    ForEach(rowHeights.indices, id: \.self) { index in
                        Color.gray
                            .frame(height: rowHeights[index])
                            .id(index)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                if index == rowHeights.count - 1 { probe.lastRowFrame = frame }
                            }
                            .padding(.bottom, index == rowHeights.count - 1 ? 0 : 12)
                    }
                }
                .padding([.top, .horizontal], AppTheme.Space.paddingPage)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: Self.inputBarHeight + AppTheme.Space.timelineInputClearance)
            }
            .contentMargins(.top, Self.topMargin, for: .scrollContent)
            .onAppear { probe.proxy = proxy }
        }
    }
}

@MainActor
struct TimelineEngineeringFixTests {
    @Test func hiddenPassageMeasurementDoesNotAddVisibleSpacing() {
        // 3 句 passage：收起态显示前 2 句 + 展开按钮，隐藏测量节点在 background 里
        // 量全文高度。2 句 passage 则没有按钮、也没有隐藏测量节点——两者高度差应
        // 恰好是展开按钮块（caption2 行高 + 12pt 上间距，实测约 25pt）。
        let threeLine = CardContent(
            granularity: "passage",
            direction: "comprehend",
            passageLines: [
                PassageLine(en: "One.", zh: "一。"),
                PassageLine(en: "Two.", zh: "二。"),
                PassageLine(en: "Three.", zh: "三。")
            ]
        )
        let twoLine = CardContent(
            granularity: "passage",
            direction: "comprehend",
            passageLines: [
                PassageLine(en: "One.", zh: "一。"),
                PassageLine(en: "Two.", zh: "二。")
            ]
        )
        let host3 = UIHostingController(
            rootView: AICardBody(content: threeLine)
                .environment(\.sizeCategory, .medium)
        )
        let host2 = UIHostingController(
            rootView: AICardBody(content: twoLine)
                .environment(\.sizeCategory, .medium)
        )

        let size3 = host3.sizeThatFits(
            in: CGSize(width: 358, height: UIView.layoutFittingExpandedSize.height)
        )
        let size2 = host2.sizeThatFits(
            in: CGSize(width: 358, height: UIView.layoutFittingExpandedSize.height)
        )

        // 区间断言两头抓：隐藏测量节点若泄漏进可见布局（多出的整段句对 ≈ 62pt），
        // 差值会远超按钮块；按钮丢失则差值归零。
        let delta = size3.height - size2.height
        #expect(delta >= 20 && delta <= 30)

        // 绝对上限：实测 183.33pt（iOS 18.6 与 iOS 26.5 两个 runtime 数值分毫不差；
        // iOS 26.5 即 CI runner 的 runtime），规格由 #62 时间线间距定义，
        // 留 6pt 余量。精确守卫由上面的差值断言承担，此上限只兜底灾难性泄漏。
        #expect(size3.height <= 190)
    }

    @Test func historyLoadReadsItsInjectedCache() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-vm-cache-target-\(UUID())", isDirectory: true)
        let cache = LocalCache(directory: directory)
        let cachedHistory = Data("""
        [{"id":"11111111-2222-3333-4444-555555555599","role":"user","user_content":"isolated cached entry","created_at":"2026-08-22T09:00:00Z"}]
        """.utf8)
        await cache.save(cachedHistory, key: .messages)

        let viewModel = TodayViewModel(
            historyDataLoader: { throw URLError(.notConnectedToInternet) },
            isConnected: { false },
            isConsentGranted: { true },
            localCache: cache
        )

        await viewModel.loadHistory()

        var containsCachedEntry = false
        for entry in viewModel.entries {
            if case .userBubble(let text, _, _, _) = entry.content,
               text == "isolated cached entry" {
                containsCachedEntry = true
                break
            }
        }
        #expect(containsCachedEntry)
    }

    @Test func passageToggleUsesReducedMotionPolicyWhenRequested() {
        #expect(PassageTimelineLayout.toggleMotion(reduceMotion: true) == .reduced)
        #expect(PassageTimelineLayout.toggleMotion(reduceMotion: false) == .standard)
    }

    // 短时间线使用底部默认锚点时，顶部 content margin 仍必须完整保留。
    @Test func initialBottomScrollViewKeepsShortContentBelowTopMargin() async throws {
        let topMargin: CGFloat = 80
        let markerFrame = TimelineGeometryCapture()
        let host = UIHostingController(
            rootView: ShortTimelineFixture(topMargin: topMargin, markerFrame: markerFrame)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        await Task.yield()
        host.view.layoutIfNeeded()

        let scrollView = try #require(Self.firstScrollView(in: host.view))
        let scrollFrame = scrollView.convert(scrollView.bounds, to: nil)
        #expect(markerFrame.frame.height > 0)
        #expect(markerFrame.frame.minY >= scrollFrame.minY + topMargin + 15)

        window.isHidden = true
    }


    // 停靠线一致性（2026-10-03 冷启动下跳 20pt 回归）：长时间线首次布局停在底部的位置，
    // 必须与之后 scrollTo(最后一条, .bottom) 的位置一致，且都在「输入框上沿 − 52pt」。
    @Test func longTimelineInitialDockMatchesScrollToBottom() async throws {
        let (initial, afterScroll, dockLine) = try await Self.measureDocking(
            rowHeights: Array(repeating: 160, count: 12)
        )
        #expect(abs(initial - afterScroll) < 1, "initial \(initial) vs scrollTo \(afterScroll)")
        #expect(abs(afterScroll - dockLine) < 1, "scrollTo \(afterScroll) vs dock line \(dockLine)")
    }

    private static func measureDocking(rowHeights: [CGFloat]) async throws -> (CGFloat, CGFloat, CGFloat) {
        let probe = DockingProbe()
        let host = UIHostingController(rootView: DockingTimelineFixture(rowHeights: rowHeights, probe: probe))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        for _ in 0..<5 { host.view.layoutIfNeeded(); await Task.yield() }
        try await Task.sleep(nanoseconds: 200_000_000)
        host.view.layoutIfNeeded()
        let initial = probe.lastRowFrame.maxY

        let proxy = try #require(probe.proxy)
        proxy.scrollTo(rowHeights.count - 1, anchor: .bottom)
        for _ in 0..<5 { host.view.layoutIfNeeded(); await Task.yield() }
        try await Task.sleep(nanoseconds: 200_000_000)
        host.view.layoutIfNeeded()
        let afterScroll = probe.lastRowFrame.maxY

        let scrollView = try #require(firstScrollView(in: host.view))
        let scrollFrame = scrollView.convert(scrollView.bounds, to: nil)
        let dockLine = scrollFrame.maxY - window.safeAreaInsets.bottom
            - DockingTimelineFixture.inputBarHeight - AppTheme.Space.timelineInputClearance
        window.isHidden = true
        return (initial, afterScroll, dockLine)
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }
}
