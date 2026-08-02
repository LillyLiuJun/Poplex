import SwiftUI

/// Shown while the `start` request is in flight (§4.3).
/// Mic icon with a gentle breathing animation + a short status line.
/// Never a spinner — "technical feel" is explicitly ruled out (需求设计 §4.3).
struct PreparingIndicator: View {
    @State private var breathScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingCard) {
            ZStack {
                // Soft halo behind the icon (breathing ring)
                Circle()
                    .fill(AppTheme.Color.brandSubtleBg)
                    .frame(width: 88, height: 88) // TODO(token) AppTheme.Size.micButton + halo
                    .scaleEffect(breathScale)
                    .opacity(breathScale > 1.05 ? 0.0 : 0.6)

                Image(systemName: "mic")
                    .font(AppTheme.Font.wordTitle)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .scaleEffect(breathScale)
            }
            .frame(width: 96, height: 96)

            Text("Getting your topics…")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textFaint)
        }
        .onAppear {
            // TODO(token) AppTheme.Motion.breathing
            withAnimation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            ) {
                breathScale = 1.12
            }
        }
        .accessibilityLabel("Loading your conversation topics")
    }
}

#Preview {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        PreparingIndicator()
    }
}
