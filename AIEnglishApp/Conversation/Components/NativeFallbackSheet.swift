import SwiftUI

/// Shows translation + phonetics + "Try saying it." when the user asks for help (§3.6).
/// Implemented in E1 step 6. Stub present to keep the file structure complete (§1).
struct NativeFallbackSheet: View {
    let translation: String
    let keyWords: [(word: String, phonetic: String)]
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(translation)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)

            ForEach(keyWords, id: \.word) { entry in
                HStack(spacing: AppTheme.Space.paddingS) {
                    Text(entry.word)
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(entry.phonetic)
                        .font(AppTheme.Font.phonetic)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }

            Text("Try saying it.")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NativeFallbackSheet(
        translation: "The projector wasn't working, so we started ten minutes late.",
        keyWords: [("projector", "/prəˈdʒektər/")],
        onDismiss: {}
    )
    .background(AppTheme.Color.cardBg)
}
