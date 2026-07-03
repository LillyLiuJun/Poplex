import SwiftUI

struct OnboardingScreen1View: View {
    var onForward: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Learn English\nfrom your own life.")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text("Not textbooks. Not drills. Just what's happening around you, in English you can actually say.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            Spacer()

            Button(action: onForward) {
                Text("Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, 56)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward)
    }
}

#Preview {
    OnboardingScreen1View(onForward: {})
}
