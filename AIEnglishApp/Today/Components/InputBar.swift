import SwiftUI

// Layer 3：底部固定输入栏。文字输入 + 发送按钮。
struct InputBar: View {
    @Binding var text: String
    var isLoading: Bool
    var onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            TextField("Describe your moment in Chinese or English...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(AppTheme.Space.paddingS)
                .background(AppTheme.Color.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle")
                    .font(.title)
            }
            .disabled(!canSend)
        }
        .padding(AppTheme.Space.paddingCard)
    }
}
