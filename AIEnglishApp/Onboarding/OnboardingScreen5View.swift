import SwiftUI

// Slice 2 will replace this stub with full streaming generation + audio playback.
// For now it simply marks onboarding complete so the user can reach Tab1.
struct OnboardingScreen5View: View {
    var onComplete: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: AppTheme.Space.paddingCard) {
                // Placeholder for the generated English content card
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .fill(AppTheme.Color.cardBg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .overlay(
                        Text("Your English expression\nwill appear here.")
                            .font(.body)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    )
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.3), value: appeared)

                Text("That's a moment from your life — now it's yours in English.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.6), value: appeared)
            }

            Spacer()

            Button(action: onComplete) {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, 56)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.9), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    OnboardingScreen5View(onComplete: {})
}
