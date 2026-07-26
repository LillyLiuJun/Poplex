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

    /// 首启身份闸门：本地无标记时，只有服务器【明确说没完成】才进引导；
    /// 网络失败 = 不确定身份 → 显示重试页，绝不误把老用户踢回引导。
    private enum Gate {
        case checking          // 正在向服务器确认
        case needsOnboarding   // 服务器明确：未完成引导
        case connectionFailed  // 连不上服务器：身份不明，等重试
    }
    @State private var gate: Gate = .checking

    var body: some View {
        Group {
            if onboardingCompletedAt > 0 {
                ContentView()
            } else {
                switch gate {
                case .checking:
                    // MVP 占位 loading：只放系统转圈、不带文案。
                    // 品牌启动页确定后在此替换（视觉风格 TBD，见 CLAUDE.md）。
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .needsOnboarding:
                    OnboardingView {
                        onboardingCompletedAt = Date().timeIntervalSince1970
                    }
                case .connectionFailed:
                    ConnectionRetryView {
                        gate = .checking
                        await syncOnboardingStateFromRemote()
                    }
                }
            }
        }
        // Race the network sync against a 20-second timeout using a TaskGroup so
        // whichever finishes first automatically cancels the other — avoids the
        // false-positive retry page that appeared when slow-but-successful cold
        // starts (auth Keychain restore + Supabase round-trip) exceeded 10 s.
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await syncOnboardingStateFromRemote() }
                group.addTask {
                    do {
                        try await Task.sleep(for: .seconds(20))
                        if gate == .checking { gate = .connectionFailed }
                    } catch {
                        // Cancelled because sync completed first — nothing to do
                    }
                }
                // Wait for whichever task finishes first, then Swift's structured
                // concurrency cancels the remaining one automatically on scope exit
                await group.next()
            }
        }
    }

    private func syncOnboardingStateFromRemote() async {
        guard onboardingCompletedAt == 0 else { return }
        do {
            // 必须先确保会话存在：RLS 靠 auth.uid() 返回用户自己的行，
            // 未登录时查询会返回 0 行，把「已完成引导的重装用户」误判为需要引导。
            // 重装用户的会话从 Keychain 秒级恢复（无网络）；新用户才走一次匿名注册。
            try await SupabaseManager.ensureSignedIn()
            // 启动关键路径只保留这一次远端查询：识别「同机重装且已完成引导」的用户。
            // 不再做 ensureProfileRow —— 新用户的 profile 行由 DB 触发器建好，
            // 完成引导时 markOnboardingComplete 的 upsert 会兜底建行，无需冷启动多加一次往返。
            switch try await ProfileService.fetchOnboardingState() {
            case .completed(let remoteDate):
                // 走过引导（如同机重装的老用户）→ 回填本地标记，直接进主界面
                onboardingCompletedAt = remoteDate.timeIntervalSince1970
            case .notCompleted:
                gate = .needsOnboarding
            case .missingProfile:
                // 网络成功但查不到行：无法证明完成过引导；新用户必有行（触发器保证），
                // 此为边缘情况，按未完成处理让其走引导（完成时 upsert 会建行）。
                print("[RootView] profile row missing — treating as not completed")
                gate = .needsOnboarding
            }
        } catch {
            // 网络/auth 失败：身份不明，不猜。引导本身需要联网（AI 生成），进引导也走不完。
            print("[RootView] onboarding check failed, showing retry: \(error)")
            gate = .connectionFailed
        }
    }
}
