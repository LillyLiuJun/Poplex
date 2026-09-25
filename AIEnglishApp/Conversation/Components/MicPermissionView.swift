import SwiftUI

/// Shown when microphone or speech recognition permission is denied (§4.4).
/// Explains purpose without demanding compliance; gives a clear path to Settings.
struct MicPermissionView: View {
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingSection) {
            Spacer()

            Image(systemName: "mic.slash")
                .font(.system(size: 56))  // permission icon — intentionally large, exempt from token rule
                .foregroundStyle(AppTheme.Color.textMuted)

            VStack(spacing: AppTheme.Space.paddingS) {
                Text("Voice access needed")
                    .font(AppTheme.Font.screenTitle)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                Text("Practice happens out loud. Allow microphone and speech recognition so you can speak and be heard.")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Space.paddingSection)
            }

            Button(action: onOpenSettings) {
                Text("Open Settings")
                    .font(AppTheme.Font.ctaLabel)
                    .foregroundStyle(AppTheme.Color.cardBg)
                    .padding(.horizontal, AppTheme.Space.paddingSection)
                    .padding(.vertical, AppTheme.Space.paddingCard)
                    .background(AppTheme.Color.brandStrong, in: Capsule())
            }
            .accessibilityLabel("Open Settings to allow microphone access")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }
}

#Preview {
    MicPermissionView(onOpenSettings: {})
}
