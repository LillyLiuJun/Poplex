import SwiftUI

/// Real-time vocabulary suggestions, collapsed by default (§3.4 / Tab2_v2 D-4).
/// Collapsed: one line "N words you could use ⌄"
/// Expanded: each suggestion as a lemma + short hint
///
/// The default expansion state is passed in from outside so future A/B testing
/// can control it without touching the component (§3.4 note).
struct SuggestionsBar: View {
    let suggestions: [DialogueSuggestion]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Divider separating suggestions from the page background
            Divider()
                .background(AppTheme.Color.divider)

            // Collapsed header (always visible)
            Button {
                withAnimation(AppTheme.Motion.tabSelection) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(collapsedLabel)
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textMuted)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .frame(minHeight: AppTheme.Size.barControl)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(isExpanded ? "Collapse word suggestions" : "Expand word suggestions")
            .accessibilityHint(collapsedLabel)

            // Expanded suggestions list
            if isExpanded && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                    ForEach(suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.paddingM)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Color.pageBg)
    }

    private var collapsedLabel: String {
        let count = suggestions.count
        return "\(count) word\(count == 1 ? "" : "s") you could use"
    }

    private func suggestionRow(_ suggestion: DialogueSuggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
            Text(suggestion.lemma)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.brandStrong)
            Text(suggestion.hint)
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textMuted)
            Spacer()
        }
        .frame(minHeight: AppTheme.Size.barControl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(suggestion.lemma) — \(suggestion.hint)")
    }
}

#Preview {
    @Previewable @State var expanded = false
    let suggestions = [
        DialogueSuggestion(lemma: "run late",    hint: "if things ran behind"),
        DialogueSuggestion(lemma: "set up",      hint: "when preparing the room"),
        DialogueSuggestion(lemma: "sort it out", hint: "to fix the problem"),
    ]
    VStack {
        Spacer()
        SuggestionsBar(suggestions: suggestions, isExpanded: $expanded)
    }
    .background(AppTheme.Color.pageBg)
}
