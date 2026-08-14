import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case screen1, screen2, screen4
}

struct OnboardingView: View {
    @State private var step: OnboardingStep = .screen1
    @State private var viewModel = OnboardingViewModel()
    var onComplete: () -> Void

    private var index: Int { step.rawValue }  // screen1=0, screen2=1, screen4=2

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingAuraBackground()
            
            // Offset-based paging: all pages sit side by side in one HStack and
            // we slide the whole strip left/right. No insert/remove transitions,
            // so direction is always correct and pages never overlap or ghost.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    OnboardingScreen1View(isActive: step == .screen1, onForward: advance)
                        .frame(width: geo.size.width, height: geo.size.height)

                    OnboardingScreen2View(isActive: step == .screen2, onBack: back, onForward: advance)
                        .frame(width: geo.size.width, height: geo.size.height)

                    OnboardingCaptureView(
                        viewModel: viewModel,
                        isActive: step == .screen4,
                        onBack: back,
                        onComplete: completeOnboarding
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .offset(x: -CGFloat(index) * geo.size.width)
                .animation(.easeInOut(duration: 0.35), value: step)
            }
            .clipped()

            progressDots
                .padding(.bottom, 20)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == step ? AppTheme.Color.brandStrong : AppTheme.Color.neutralFaint)
                    .frame(width: s == step ? 20 : 6, height: 6)
                    .animation(.spring(duration: 0.25), value: step)
            }
        }
    }

    private func advance() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx + 1 < cases.count else { return }
        step = cases[idx + 1]
    }

    private func back() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx > 0 else { return }
        step = cases[idx - 1]
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "onboarding_completed_at")
        // Preset card: build [userBubble(asset image) + aiCard] so Tab1 shows image + description.
        // Own photo: server already has the record; leave seed empty, loadHistory() handles it.
        if let card = viewModel.selectedCard, let result = viewModel.generationResult {
            let image = UIImage(named: card.imageName)
            OnboardingSeedStore.shared.entries = [
                .userBubble(text: "Describe this image", image: image, imageStableKey: card.imageName),
                .aiCard(result)
            ]
        }
        Task {
            do { try await ProfileService.markOnboardingComplete() }
            catch { print("[Onboarding] ERROR remote sync failed: \(error)") }
        }
        onComplete()
    }
}

// MARK: - Horizontal swipe helper

extension View {
    /// Detects horizontal swipes. `onLeft` = swipe finger left (advance),
    /// `onRight` = swipe finger right (back). Uses simultaneousGesture so it
    /// coexists with buttons (taps don't move) and ScrollViews (vertical drags
    /// are ignored via the horizontal guard).
    func onHorizontalSwipe(
        threshold: CGFloat = 60,
        onLeft: @escaping () -> Void = {},
        onRight: @escaping () -> Void = {}
    ) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let w = value.translation.width
                    let h = value.translation.height
                    guard abs(w) > abs(h) else { return }
                    if w <= -threshold { onLeft() }
                    else if w >= threshold { onRight() }
                }
        )
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
