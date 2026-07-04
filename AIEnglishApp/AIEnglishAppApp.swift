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

    var body: some View {
        if onboardingCompletedAt > 0 {
            ContentView()
        } else {
            OnboardingView {
                onboardingCompletedAt = Date().timeIntervalSince1970
            }
        }
    }
}
