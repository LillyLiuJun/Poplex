import SwiftUI

/// Shows a full sentence translation when the user taps an AI line (§3.2).
/// Implemented in E1 step 7. Stub present to keep the file structure complete (§1).
struct TranslationSheet: View {
    let originalText: String
    let translation: String
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(originalText)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Divider()
                .background(AppTheme.Color.divider)

            Text(translation)
                .font(AppTheme.Font.chineseBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TranslationSheet(
        originalText: "So you were troubleshooting before the day even started.",
        translation: "所以你在这一天甚至还没开始的时候就已经在排除故障了。",
        onDismiss: {}
    )
    .background(AppTheme.Color.cardBg)
}
