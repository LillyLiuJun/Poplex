import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case screen1, screen2, screen4, screen5
}

struct OnboardingView: View {
    @State private var step: OnboardingStep = .screen1
    @State private var goingBack = false
    var onComplete: () -> Void

    private var stepTransition: AnyTransition {
        goingBack
            ? .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
              )
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
              )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch step {
                case .screen1:
                    OnboardingScreen1View(onContinue: advance)
                case .screen2:
                    OnboardingScreen2View(onBack: back, onContinue: advance)
                case .screen4:
                    OnboardingScreen4View(onContinue: advance)
                case .screen5:
                    OnboardingScreen5View(onComplete: completeOnboarding)
                }
            }
            .id(step)
            .transition(stepTransition)

            progressDots
                .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == step ? Color.primary : Color.secondary.opacity(0.25))
                    .frame(width: s == step ? 20 : 6, height: 6)
                    .animation(.spring(duration: 0.25), value: step)
            }
        }
    }

    private func advance() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx + 1 < cases.count else { return }
        goingBack = false
        step = cases[idx + 1]
    }

    private func back() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx > 0 else { return }
        goingBack = true
        step = cases[idx - 1]
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "onboarding_completed_at")
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
