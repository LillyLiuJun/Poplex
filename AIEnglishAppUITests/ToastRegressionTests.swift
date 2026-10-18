//
//  ToastRegressionTests.swift
//  AIEnglishAppUITests
//
//  Toast 回归验证 + 真机证伪点击矩阵（2026-09-16 刀「toast 动画收敛」）。
//  验证三条 toast（comingSoon / vm.toastMessage / milestone）均能出现并自动
//  消失，并按原始 bug 方式（连点、滚动中点、Hero 与 More 行、里程碑同屏）
//  点击 10+ 次证伪复现。
//
//  环境依赖说明：
//  - 全部用例通过 `launchApp` 统一注入 `UITEST_SKIP_ONBOARDING=1`（DEBUG-only，
//    见 `AIEnglishAppApp.swift`），绕过 onboarding 直达真实 ContentView →
//    RootTabContainer → MineView——`xcodebuild test` 每次全新安装，不绕过的话
//    app 会停在 onboarding，MineView 从不挂载，探针的 `.task` 从不调度
//    （2026-09-23 排查：`[toast-probe]` 日志一行都没有，见调查记录）。
//  - testComingSoonProbe：到达 Tab2 后任何数据状态都能跑（探针不依赖数据）。
//  - testBlockedToastProbe：需要 load 成功（无网络环境自动 XCTSkip，不误报失败）。
//  - testMilestone* / testTapMatrix*：需要 Tab2 有真实数据（Hero / More 行
//    存在），即真机或已有数据的模拟器；空数据/锁态环境自动 XCTSkip。
//    探针环境变量语义见 CLAUDE.md「Debug Probes」。
//

import XCTest

final class ToastRegressionTests: XCTestCase {

    private let comingSoonText = "Speaking mode will be available soon."
    private let blockedText = "You're offline. Check your connection."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - helpers

    @MainActor
    private func launchApp(env: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        // UITEST_SKIP_ONBOARDING：DEBUG-only 路由绕过（AIEnglishAppApp.swift），
        // 让 app 实例落到真实 ContentView → RootTabContainer → MineView，而不是
        // 停在 onboarding（xcodebuild test 每次全新安装，onboarding_completed_at
        // 必为 0）。不写 UserDefaults，不污染模拟器持久状态。
        var launchEnv = ["START_TAB": "mine", "UITEST_SKIP_ONBOARDING": "1"]
        env.forEach { launchEnv[$0] = $1 }
        app.launchEnvironment = launchEnv
        app.launch()
        return app
    }

    @MainActor
    private func toast(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts[text]
    }

    @MainActor
    private func requireToastAppears(
        _ element: XCUIElement,
        timeout: TimeInterval = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "toast 未在 \(timeout)s 内出现",
            file: file, line: line
        )
    }

    @MainActor
    private func requireToastDisappears(
        _ element: XCUIElement,
        timeout: TimeInterval = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter().wait(for: [gone], timeout: timeout)
        XCTAssertEqual(
            result, .completed,
            "toast 未在 \(timeout)s 内自动消失（常驻 bug 复现）",
            file: file, line: line
        )
    }

    /// 探针前置条件：必须真正到达 Tab2（`RootTabContainer` 已挂载），而不是停在
    /// onboarding。`Library` 顶栏 Tab 按钮与 Tab2 数据状态无关（锁态/空态/正常
    /// 态都会渲染），比 `heroCard` 更早也更通用地确认路由到位。到不了就 XCTSkip
    /// 而不是 XCTFail——把"环境没到位"和"toast 功能坏了"两种失败区分开。
    @MainActor
    private func requireReachedMine(in app: XCUIApplication) throws {
        guard app.buttons["Library"].waitForExistence(timeout: 8) else {
            throw XCTSkip("未到达 Tab2（onboarding 绕过未生效或路由异常）——环境问题，非探针问题")
        }
    }

    /// 真机矩阵前置条件：Hero 卡必须存在（空数据/锁态环境自动跳过）。
    @MainActor
    private func heroCard(in app: XCUIApplication) throws -> XCUIElement {
        let hero = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Start talking")
        ).firstMatch
        guard hero.waitForExistence(timeout: 8) else {
            throw XCTSkip("无 Hero 卡（空数据/锁态环境）——矩阵与里程碑场景仅真机有效")
        }
        return hero
    }

    @MainActor
    private func moreRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "words")
        ).firstMatch
    }

    @MainActor
    private func milestoneToast(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "reached 20 words")
        ).firstMatch
    }

    // MARK: - 探针链路

    @MainActor
    func testComingSoonProbeFullChain() throws {
        let app = launchApp(env: ["TOAST_PROBE": "1"])
        try requireReachedMine(in: app)
        let t = toast(comingSoonText, in: app)
        requireToastAppears(t, timeout: 6)   // 探针 2s 后触发，留足余量
        requireToastDisappears(t)
    }

    @MainActor
    func testBlockedToastProbeFullChain() throws {
        let app = launchApp(env: ["TOAST_PROBE_BLOCKED": "1"])
        try requireReachedMine(in: app)
        let t = toast(blockedText, in: app)
        // load 成功才触发。load 失败时 Tab2 显示整页错误态（Tab2LoadErrorView，文案
        // "Something went wrong."；旧文案 "Failed to load" 只是 view model 内部的
        // errorMessage，已不再渲染成文字）。无真实后端（开源仓库的占位符配置）或无网络
        // 都会走到这里，此时没有触发条件，XCTSkip 而不是 XCTFail。
        //
        // 不能只等固定 12 秒再判断：load 失败要先等匿名登录（最长约 10s）再等 Tab2 加载
        // 超时（8s），整页错误态最迟约 18s 才出现，所以这里轮询「toast 出现」与「错误态
        // 出现」二者之一，总预算 30s。
        let errorPage = app.staticTexts["Something went wrong."]
        let legacyError = app.staticTexts["Failed to load"]
        var appeared = false
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if t.waitForExistence(timeout: 1) { appeared = true; break }
            if errorPage.exists || legacyError.exists {
                throw XCTSkip("load 未成功（无网络或未配置后端），blocked 探针无触发条件")
            }
        }
        guard appeared else {
            XCTFail("blocked 探针 toast 30s 未出现，且 Tab2 也没有进入错误态")
            return
        }
        requireToastDisappears(t)
    }

    // MARK: - milestone（仅真实数据环境）

    @MainActor
    func testMilestoneToastAppearsAndDisappears() throws {
        let app = launchApp(env: ["TAB2_MILESTONE_DEMO": "1"])
        _ = try heroCard(in: app)
        // 里程碑仅在切回 Tab2 时触发：Today → Library
        app.buttons["Today"].tap()
        app.buttons["Library"].tap()
        let milestone = milestoneToast(in: app)
        requireToastAppears(milestone, timeout: 10)  // 切回后 load 需要时间
        requireToastDisappears(milestone, timeout: 8) // 2.2s + 余量
    }

    // MARK: - 真机证伪矩阵（原始 bug 点击方式，10+ 次）

    @MainActor
    func testTapMatrixHeroAndMore() throws {
        let app = launchApp(env: [:])
        let hero = try heroCard(in: app)
        let t = toast(comingSoonText, in: app)

        // ① Hero 单点 ×3
        for _ in 0..<3 {
            hero.tap()
            requireToastAppears(t)
            requireToastDisappears(t)
        }
        // ② Hero 连点两下（原始 bug 姿势之一）
        hero.doubleTap()
        requireToastAppears(t)
        requireToastDisappears(t)
        // ③ More 行 ×2
        let row = moreRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 4), "More 行未找到")
        for _ in 0..<2 {
            row.tap()
            requireToastAppears(t)
            requireToastDisappears(t)
        }
        // ④ 滚动中点：swipe 后立刻点当前可见的 More 行 ×2
        for _ in 0..<2 {
            app.swipeUp()
            let visibleRow = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "words")
            ).allElementsBoundByIndex.first(where: \.isHittable)
            guard let row = visibleRow else {
                throw XCTSkip("滚动后无可见 More 行，跳过滚动中点")
            }
            row.tap()
            requireToastAppears(t)
            requireToastDisappears(t)
        }
    }

    @MainActor
    func testMilestoneSameScreenTap() throws {
        let app = launchApp(env: ["TAB2_MILESTONE_DEMO": "1"])
        let hero = try heroCard(in: app)
        // 先制造里程碑 toast，再在其同屏时点 Hero（原始 bug 姿势之一）
        app.buttons["Today"].tap()
        app.buttons["Library"].tap()
        let milestone = milestoneToast(in: app)
        requireToastAppears(milestone, timeout: 10)
        let t = toast(comingSoonText, in: app)
        hero.tap()
        requireToastAppears(t)
        // 两条各自自动消失
        requireToastDisappears(milestone, timeout: 8)
        requireToastDisappears(t)
        // 里程碑消失后再点一次 Hero（计入矩阵次数）
        hero.tap()
        requireToastAppears(t)
        requireToastDisappears(t)
    }
}
