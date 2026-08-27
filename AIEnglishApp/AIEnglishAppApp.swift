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

    /// 开屏动画是否播完。
    @State private var splashAnimationDone = false
    /// 删号后的一次性提示（需活过根路由切换，故不放在 Settings 里）。
    private let deletionNotice = AccountDeletionNotice.shared
    /// 后台「是否已完成引导」的确认是否已出结果（或已封顶放行）。
    @State private var startupResolved = false

    /// 首启路由的核心原则：**首屏不等网络当闸门**。
    ///
    /// 过去把「登录 + 查 profiles」这次网络往返放在关键路径上，任何慢/失败都变成
    /// 空白转圈或 "Can't connect" 墙——反复补超时都没根治。现在：本地无完成标记时
    /// 默认就是 onboarding，那次远端检查只用来把【重装的已完成用户】快进到主界面，
    /// 任何失败/超时都放行到 onboarding，绝不阻塞首屏。
    ///
    /// 开屏何时收起（本地无标记时用品牌开屏盖住这段确认窗，避免空白转圈）：
    /// 动画播完后——已知老用户(本地标记>0)立即收；否则等后台检查出结果或 3s 封顶。
    private var showSplash: Bool {
        if !splashAnimationDone { return true }
        if onboardingCompletedAt > 0 { return false }
        return !startupResolved
    }

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView { splashAnimationDone = true }
            } else if onboardingCompletedAt > 0 {
                ContentView()
            } else {
                OnboardingView {
                    onboardingCompletedAt = Date().timeIntervalSince1970
                }
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

    /// 把「确认身份」这次网络检查移出首屏关键路径。
    /// - 本地已有完成标记 → 无需检查，老用户直接进主界面。
    /// - 否则后台查远端：只有明确「已完成」才回填标记（快进主界面）；
    ///   其余（未完成 / 查不到 / 网络或鉴权失败 / 超时）一律停在 onboarding（默认态）。
    ///
    /// 用品牌开屏盖住检查，最多 3s 封顶——检查一出结果就收开屏，网络慢也不拖过 3s。
    /// 检查任务故意不随封顶取消：网络很慢时若稍后才确认「已完成」，仍会把重装老用户
    /// 从 onboarding 快进到主界面（少数慢网重装场景的兜底）。
    private func resolveStartup() async {
        guard onboardingCompletedAt == 0 else { startupResolved = true; return }

        let check = Task { await fastForwardIfCompleted() }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await check.value }                       // 检查出结果就放行
            group.addTask { try? await Task.sleep(for: .seconds(3)) } // 3s 封顶
            await group.next()
            group.cancelAll()   // 只结束「等待」，不取消上面的 check 任务本体
        }
        startupResolved = true
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
