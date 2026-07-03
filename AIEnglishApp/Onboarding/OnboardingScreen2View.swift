import SwiftUI

struct OnboardingScreen2View: View {
    var onBack: () -> Void
    var onForward: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .padding(AppTheme.Space.paddingS)
                    .contentShape(Rectangle())
            }
            .padding(.leading, AppTheme.Space.paddingCard)
            .padding(.top, AppTheme.Space.paddingCard)

            Spacer()

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Snap a photo, say what's on your mind, or type a few words.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("We'll turn it into natural English you can actually say.")
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
        .onHorizontalSwipe(onLeft: onForward, onRight: onBack)
    }
}

#Preview {
    OnboardingScreen2View(onBack: {}, onForward: {})
}
