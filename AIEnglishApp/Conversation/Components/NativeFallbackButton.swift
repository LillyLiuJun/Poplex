import SwiftUI

/// Switches ASR to dual-language mode (en-US + zh-CN on the same audio tap).
/// Tapping starts a new listening session. If the user speaks Chinese, the result
/// routes to the fallback flow (translation + phonetics). If they speak English,
/// it processes as a normal turn.
///
/// Deliberately low-key: text-only, secondary colour, buddy font.
/// Minimum hit area = 44 pt (accessibility).
struct NativeFallbackButton: View {
    var isListening: Bool = false
    var isDisabled: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isListening ? "Listening…" : "Say it your way")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(
                    isDisabled
                    ? AppTheme.Color.textFaint
                    : isListening
                        ? AppTheme.Color.brandDefault
                        : AppTheme.Color.textSecondary
                )
                .frame(minWidth: 44, minHeight: AppTheme.Size.barControl)
                .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .accessibilityLabel(
            isListening
            ? "Listening — speak in any language"
            : "Switch to any language to express what you want to say"
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        NativeFallbackButton(isListening: false, isDisabled: false, onTap: {})
        NativeFallbackButton(isListening: true,  isDisabled: false, onTap: {})
        NativeFallbackButton(isListening: false, isDisabled: true,  onTap: {})
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}
