import SwiftUI

/// "Say it in Chinese" — the mother-tongue fallback trigger (§3.5).
///
/// Deliberately low-key: text-only, secondary colour, buddy font.
/// It should feel like changing gear, not asking for help.
/// Minimum hit area = 44 pt (§八 accessibility).
struct NativeFallbackButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("Say it in Chinese")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(minWidth: 44, minHeight: AppTheme.Size.barControl)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Switch to Chinese to express what you want to say")
    }
}

#Preview {
    NativeFallbackButton(onTap: {})
        .padding()
        .background(AppTheme.Color.pageBg)
}
