import SwiftUI

/// Thin top bar: topic name on the left, dismiss button on the right (§3.1).
/// Height = AppTheme.Size.barControl (44). Nothing else goes here —
/// no timer, no turn count, no settings (§3.1 决策：不显示时长和轮次).
struct ConversationTopBar: View {
    let topicName: String
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("End practice and go back")

            Text(topicName)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingM)
        .frame(height: AppTheme.Size.barControl)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview {
    ConversationTopBar(topicName: "Mornings at the office", onDismiss: {})
}
