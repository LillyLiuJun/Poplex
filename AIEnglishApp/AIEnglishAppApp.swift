//
//  AIEnglishAppApp.swift
//  AIEnglishApp
//
//  Created by lilyliu on 2026/6/21.
//

import SwiftUI
import Auth   // 访问 User 的 id / isAnonymous 属性需显式 import 定义模块

@main
struct AIEnglishAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?

    init() {
        // 字号封顶要在第一个视图渲染之前生效（见 AppDynamicTypeLimit.activate）。
        AppDynamicTypeLimit.activate()
        // 后台预热 Supabase：把 SDK 首次初始化 + Keychain 读会话赶出主线程，
        // detached 确保它不继承主线程执行器，避免冷启动首屏被这段同步工作卡住。
        // 用 .utility 而非 .high：预热不急，断网时它会挂在网络等待上，不该和
        // 冷启动首屏渲染抢 CPU。
        Task.detached(priority: .utility) {
            await SupabaseManager.warmUp()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appDynamicTypeCap()            // 字号封顶在「超大」，不支持无障碍那 5 档（见 AppDynamicTypeCap）
                .onAppear { AppDynamicTypeCapInstaller.install() }
                .preferredColorScheme(.light)   // 已退出系统自适应，MVP 锁定浅色
                .task {
                    do {
                        let user = try await SupabaseManager.ensureSignedIn()
                        print("[Auth] signed in, user id = \(user.id) (anonymous = \(user.isAnonymous))")
                    } catch {
                        print("[Auth] sign-in failed: \(error)")
                    }
                    // 冷启动 = 第 1 次新会话
                    Task {
                        do { try await ProfileService.incrementSessionCount() }
                        catch { print("[Session] cold start count failed: \(error)") }
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                backgroundedAt = Date()
            case .active:
                guard let t = backgroundedAt else { return }
                backgroundedAt = nil
                guard Date().timeIntervalSince(t) > 30 * 60 else { return }
                // 退后台超 30 分钟回来 = 新会话
                Task {
                    do { try await ProfileService.incrementSessionCount() }
                    catch { print("[Session] re-entry count failed: \(error)") }
                }
            default:
                break
            }
        }
    }
}

struct RootView: View {
    @AppStorage("onboarding_completed_at") private var onboardingCompletedAt: Double = 0

    /// 删号后的一次性提示（需活过根路由切换，故不放在 Settings 里）。
    private let deletionNotice = AccountDeletionNotice.shared

    /// 开屏动画盖在路由上方（见 LaunchSplashView）：本地无完成标记 = 首次打开，嫩芽长出 →
    /// 字标擦出 → 停在居中组合等这次检查（最多 3s 封顶）→ 组合原地淡出，露出 onboarding
    /// （新用户）或主界面（重装的已完成用户）。本地已有标记 = 日常打开，1.2s 柔和开屏后
    /// 进主界面，不等任何东西。
    @State private var splash: LaunchSplashController?

    var body: some View {
        Group {
            if previewMode {
                // 刀 6 验收用：`simctl launch <udid> <bundle> -tab2Preview` 直达
                // Tab2 视觉全形态页（DEBUG-only，不进 Release，不影响首屏路由）。
                // 预览页类型只在 DEBUG 下存在，引用也必须包在 #if DEBUG 里，否则 Release 编译失败。
                #if DEBUG
                Tab2Knife6PreviewView()
                #endif
            } else if onboardingCompletedAt > 0 || skipOnboardingForUITests {
                ContentView()
            } else {
                OnboardingView(screen1Ready: splash?.screen1Ready ?? true) {
                    onboardingCompletedAt = Date().timeIntervalSince1970
                }
            }
        }
        .modifier(OnboardingRouteFade(isHome: onboardingCompletedAt > 0 || skipOnboardingForUITests))
        // 日常打开：主界面在开屏底下先缩在 98%，开屏退场时放大到位（「浮上来」接住视线）
        .scaleEffect(splash?.contentSettled == false ? AppTheme.Motion.Launch.dailyContentFromScale : 1)
        .animation(AppTheme.Motion.Launch.dailyContentSettle, value: splash?.contentSettled)
        // 缩放层外垫一层页面底：主界面缩在 98% 时四周让出的约 4pt 露的是这层暖纸，
        // 而不是系统窗口的白底（2026-10-08 录屏实测：退场约 0.25s 内屏幕四周闪一圈白边）。
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .overlay {
            if let splash, !splash.isFinished {
                LaunchSplashView(controller: splash)
            }
        }
        // 删号后的「有残留」提示挂在**根一级**：删号会把上面的分支从 ContentView
        // 切到 OnboardingView，挂在 Settings 上的 alert 会随子树一起销毁、显示不出来。
        // RootView 是路由本身，不会被这次切换销毁。
        .alert("Account deleted", isPresented: accountNoticePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionNotice.message ?? "")
        }
        .task {
            await resolveStartup()
            retryPendingOnboardingSyncIfNeeded()
        }
    }

    /// 开屏只在冷启动建一次。放在 init 而不是 onAppear：第一帧就得是开屏画面，
    /// 否则会先闪一下底下的页面。
    init() {
        let completed = UserDefaults.standard.double(forKey: "onboarding_completed_at") > 0
        #if DEBUG
        // Tab2 预览模式与 UI 测试的 onboarding 绕过都不播开屏：开屏期间覆盖层会吞掉点击，
        // 自动化测试的点击时序不该依赖开屏时长。
        let skipSplash = ProcessInfo.processInfo.arguments.contains("-tab2Preview")
            || ProcessInfo.processInfo.environment["UITEST_SKIP_ONBOARDING"] == "1"
        #else
        let skipSplash = false
        #endif
        guard !skipSplash else { return }
        _splash = State(initialValue: LaunchSplashController(
            kind: completed ? .daily : .firstLaunch,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        ))
    }

    /// 刀 6 视觉验收预览模式（DEBUG-only）。Release 恒 false。
    #if DEBUG
    private var previewMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-tab2Preview")
    }
    #else
    private var previewMode: Bool { false }
    #endif

    /// UI 测试专用 onboarding 绕过（DEBUG-only，Release 恒 false）。只改路由判断，
    /// 不写 `onboardingCompletedAt`——避免污染模拟器持久状态，让后续测试的起始
    /// 条件不可预测。`xcodebuild test` 每次全新安装，`onboardingCompletedAt` 必为
    /// 0，此前测试里挂在 `MineView`（真实 `ContentView → RootTabContainer` 子树）
    /// 上的探针因此从未被挂载过；这个开关让走 `ContentView` 分支的判断额外接受
    /// 这一个环境变量，不影响 App Store 构建。
    #if DEBUG
    private var skipOnboardingForUITests: Bool {
        ProcessInfo.processInfo.environment["UITEST_SKIP_ONBOARDING"] == "1"
    }
    #else
    private var skipOnboardingForUITests: Bool { false }
    #endif

    private var accountNoticePresented: Binding<Bool> {
        Binding(
            get: { deletionNotice.message != nil },
            set: { if !$0 { deletionNotice.message = nil } }
        )
    }

    /// 断网走完 onboarding 的用户：启动时补发打标（机制见 ProfileService 待办注释）。
    /// 不阻塞首屏；失败保留待办，下次启动再试。
    private func retryPendingOnboardingSyncIfNeeded() {
        guard onboardingCompletedAt > 0,
              ProfileService.hasPendingOnboardingSync() else { return }
        Task {
            do { try await ProfileService.markOnboardingComplete() }
            catch { print("[ProfileService] pending sync retry failed: \(error)") }
        }
    }

    /// 首启路由的核心原则：**首屏不等网络当闸门**。
    ///
    /// 过去把「登录 + 查 profiles」这次网络往返放在关键路径上，任何慢/失败都变成
    /// 空白转圈或 "Can't connect" 墙——反复补超时都没根治。现在：本地无完成标记时
    /// 默认就是 onboarding，那次远端检查只用来把【重装的已完成用户】快进到主界面，
    /// 任何失败/超时都放行到 onboarding，绝不阻塞首屏。
    ///
    /// 把「确认身份」这次网络检查移出首屏关键路径。
    /// - 本地已有完成标记 → 无需检查，老用户直接进主界面。
    /// - 否则后台查远端：只有明确「已完成」才回填标记（快进主界面）；
    ///   其余（未完成 / 查不到 / 网络或鉴权失败 / 超时）一律停在 onboarding（默认态）。
    ///
    /// 用品牌开屏盖住检查，最多 3s 封顶——检查一出结果就收开屏，网络慢也不拖过 3s。
    /// 检查任务故意不随封顶取消：网络很慢时若稍后才确认「已完成」，仍会把重装老用户
    /// 从 onboarding 快进到主界面（少数慢网重装场景的兜底）。
    private func resolveStartup() async {
        // 已有完成标记：开屏在 init 时已按日常打开建好、自带去向，这里的 resolve 会被忽略。
        // 仍然调用一次，让「开屏一定会收到去向」不依赖 init 与这里两处判断恰好一致。
        guard onboardingCompletedAt == 0 else { splash?.resolve(.home); return }
        defer {
            // 检查出结果（或封顶）→ 开屏从居中组合继续、原地淡出：已确认完成 = 露出主界面，否则露出 onboarding。
            splash?.resolve(onboardingCompletedAt > 0 || skipOnboardingForUITests ? .home : .onboarding)
        }

        let check = Task { await fastForwardIfCompleted() }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await check.value }                       // 检查出结果就放行
            group.addTask { try? await Task.sleep(for: .seconds(3)) } // 3s 封顶
            await group.next()
            group.cancelAll()   // 只结束「等待」，不取消上面的 check 任务本体
        }
    }

    /// 只在【服务器明确说已完成】时把本地标记回填，从而跳过 onboarding 直达主界面。
    /// 其它任何情况都不动状态——默认停在 onboarding，首屏永不因此报错或转圈。
    private func fastForwardIfCompleted() async {
        do {
            try await SupabaseManager.ensureSignedIn()
            if case .completed(let remoteDate) = try await ProfileService.fetchOnboardingState() {
                // 重装的已完成用户 → 回填本地标记，直接进主界面。
                onboardingCompletedAt = remoteDate.timeIntervalSince1970
                // 完成过引导 = 同意过 AI；重装 / 清数据后本地标记丢失须同步恢复，
                // 否则 TodayViewModel 会误弹同意页。
                if UserDefaults.standard.double(forKey: "ai_consent_accepted_at") == 0 {
                    UserDefaults.standard.set(remoteDate.timeIntervalSince1970, forKey: "ai_consent_accepted_at")
                }
            }
            // .notCompleted / .missingProfile → 不动，默认停在 onboarding。
        } catch {
            // 网络 / 鉴权失败 / 超时 → 不动，默认停在 onboarding（首屏不再因此报错或转圈）。
            print("[RootView] background onboarding check skipped (defaulting to onboarding): \(error)")
        }
    }
}

/// 引导页 ↔ 首页的路由切换：交叉淡入淡出，替代瞬间硬切（2026-10-03）。
///
/// 必须挂在路由容器上、跟着「是否在首页」这个值走，而不能在完成回调里 withAnimation：
/// 完成协调器会**先**直接写 UserDefaults 的完成标记，@AppStorage 随之立即切走分支，
/// 回调里的 withAnimation 执行时切换早已发生（实测此前淡入从未生效）。挂在值上则不论
/// 标记由谁、何时写入，切换都带动画。删号回到引导页同样淡入淡出。
struct OnboardingRouteFade: ViewModifier {
    let isHome: Bool

    func body(content: Content) -> some View {
        // 必须包一层真实容器：直接挂在 Group 上，动画会被分发到各分支视图自身，
        // 分支的插入/移除不在动画作用域内，仍是硬切（探针实测）。
        ZStack { content }
            .animation(AppTheme.Motion.onboardingExitFade, value: isHome)
    }
}
