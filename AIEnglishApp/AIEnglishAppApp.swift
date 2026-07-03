//
//  AIEnglishAppApp.swift
//  AIEnglishApp
//
//  Created by lilyliu on 2026/6/21.
//

import SwiftUI

@main
struct AIEnglishAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
