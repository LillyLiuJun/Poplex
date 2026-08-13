import SwiftUI

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingCard)
        .background(Color.primary.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}
