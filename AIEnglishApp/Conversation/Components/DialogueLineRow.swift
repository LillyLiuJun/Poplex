import SwiftUI

/// One line in the dialogue flow.
///
/// ⚠️ HARD CONSTRAINT (§4 / Tab2_v2 D-5):
/// This component's initialiser accepts ONLY `text` and `role`.
/// There is NO `issues`, NO `isCorrect`, NO `suggestion` parameter — ever.
/// Correctness data is NOT sent to the client (接口契约 §2.2).
/// If you need to show a correction, you are implementing the wrong feature.
struct DialogueLineRow: View {
    let text: String
    let role: DialogueRole

    var body: some View {
        Group {
            switch role {
            case .ai:
                aiLine
            case .user:
                userLine
            }
        }
    }

    // AI line: full width, normal weight, primary colour, tappable for translation (E1 step 7).
    private var aiLine: some View {
        Text(text)
            .font(AppTheme.Font.englishPrimary)
            .foregroundStyle(AppTheme.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Space.paddingXS)
            .contentShape(Rectangle())
            .accessibilityLabel(text)
    }

    // User transcript: indented, smaller weight, muted colour.
    // Deliberately weaker than AI line so the user's eye stays on the mic, not the text (§3.2).
    private var userLine: some View {
        Text(text)
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, AppTheme.Space.paddingPage * 2)
            .padding(.trailing, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Space.paddingXS)
            .accessibilityLabel(text)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        DialogueLineRow(text: "You've got mornings at the office on your mind. What's been happening there?", role: .ai)
        DialogueLineRow(text: "I set up the room but the projector no work", role: .user)
        DialogueLineRow(text: "So you were troubleshooting before the day even started.", role: .ai)
    }
    .padding(.vertical)
    .background(AppTheme.Color.pageBg)
}
