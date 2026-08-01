import SwiftUI

/// Inline translation card shown after Chinese speech is detected.
/// Appears between the dialogue scroll and the bottom controls — not a modal sheet.
/// Shows: target-language translation + phonetics for hard words + "Try saying it." dismiss.
struct NativeFallbackSheet: View {
    let translation: String
    let keyWords: [(word: String, phonetic: String)]
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(translation)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !keyWords.isEmpty {
                HStack(alignment: .top, spacing: AppTheme.Space.paddingCard) {
                    ForEach(keyWords, id: \.word) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.word)
                                .font(AppTheme.Font.sectionLabel)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Text(entry.phonetic)
                                .font(AppTheme.Font.phonetic)
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                    }
                }
            }

            Button(action: onDismiss) {
                Text("Try saying it.")
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.brandDefault)
                    .frame(minWidth: 44, minHeight: AppTheme.Size.barControl)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss translation and try saying it in English")
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.bottom, AppTheme.Space.paddingS)
    }
}

#Preview {
    NativeFallbackSheet(
        translation: "The projector wasn't working, so we started ten minutes late.",
        keyWords: [("projector", "/prəˈdʒektər/"), ("started", "/ˈstɑːrtɪd/")],
        onDismiss: {}
    )
    .padding(.vertical)
    .background(AppTheme.Color.pageBg)
}
