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
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)   // 已退出系统自适应，MVP 锁定浅色
                .task {
                    // 启动即静默匿名登录（无 UI）。拿到会话后所有请求才带得上用户 JWT。
                    do {
                        let user = try await SupabaseManager.ensureSignedIn()
                        print("[Auth] signed in, user id = \(user.id) (anonymous = \(user.isAnonymous))")
                    } catch {
                        print("[Auth] sign-in failed: \(error)")
                    }
                }
        }
    }
}

struct RootView: View {
    @AppStorage("onboarding_completed_at") private var onboardingCompletedAt: Double = 0
    @State private var isCheckingRemote = false

    var body: some View {
        Group {
            if onboardingCompletedAt > 0 {
                ContentView()
            } else if isCheckingRemote {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                OnboardingView {
                    onboardingCompletedAt = Date().timeIntervalSince1970
                }
            }
        }
        .task { await syncOnboardingStateFromRemote() }
    }

    private func syncOnboardingStateFromRemote() async {
        guard onboardingCompletedAt == 0 else { return }
        isCheckingRemote = true
        defer { isCheckingRemote = false }
        do {
            try await SupabaseManager.ensureSignedIn()
            if let remoteDate = try await ProfileService.fetchOnboardingCompletedAt() {
                onboardingCompletedAt = remoteDate.timeIntervalSince1970
            }
        } catch {
            print("[RootView] remote profile check failed, showing onboarding: \(error)")
        }
    }
}
