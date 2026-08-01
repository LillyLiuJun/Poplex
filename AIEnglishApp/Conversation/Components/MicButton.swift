import SwiftUI

/// The visual centrepiece of the conversation page.
/// Four states map to the four phases of a voice turn (§3.3).
///
/// Size = 72 pt.
/// TODO(token) AppTheme.Size.micButton — needs to be added to Theme.swift once approved (§7).
struct MicButton: View {
    // TODO(token) AppTheme.Size.micButton = 72
    private let buttonDiameter: CGFloat = 72

    let state: MicState
    var onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Pulse ring for .listening state
                if state == .listening {
                    Circle()
                        .stroke(AppTheme.Color.brandStrong.opacity(0.25), lineWidth: 8)
                        .frame(width: buttonDiameter + 20, height: buttonDiameter + 20)
                        .scaleEffect(pulseScale)
                }

                // Main circle
                Circle()
                    .fill(circleColor)
                    .frame(width: buttonDiameter, height: buttonDiameter)
                    .shadow(
                        color: AppTheme.Color.brandStrong.opacity(state == .idle ? 0.18 : 0),
                        radius: 16, x: 0, y: 6
                    )

                // Icon
                Image(systemName: iconName)
                    .font(AppTheme.Font.screenTitle)
                    .foregroundStyle(iconColor)
            }
        }
        .disabled(!isTappable)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: state) { _, newState in
            updateAnimation(for: newState)
        }
        .onAppear { updateAnimation(for: state) }
    }

    // MARK: - State-dependent values

    private var circleColor: Color {
        switch state {
        case .idle:        return AppTheme.Color.brandStrong
        case .listening:   return AppTheme.Color.brandStrong
        case .aiSpeaking:  return AppTheme.Color.textFaint
        case .disabled:    return AppTheme.Color.textFaint
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle, .listening: return AppTheme.Color.cardBg
        case .aiSpeaking, .disabled: return AppTheme.Color.textMuted
        }
    }

    private var iconName: String {
        switch state {
        case .idle:       return "mic.fill"
        case .listening:  return "mic.fill"
        case .aiSpeaking: return "waveform"
        case .disabled:   return "mic.slash.fill"
        }
    }

    // aiSpeaking IS tappable — user can interrupt (§3.3)
    private var isTappable: Bool {
        state != .disabled
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:       return "Start speaking"
        case .listening:  return "Stop — tap to end this turn"
        case .aiSpeaking: return "AI is speaking — tap to interrupt"
        case .disabled:   return "Microphone unavailable"
        }
    }

    // MARK: - Animation

    private func handleTap() {
        if state == .aiSpeaking {
            // Interrupt TTS — light haptic feedback (§十 待定 2)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        onTap()
    }

    private func updateAnimation(for newState: MicState) {
        if newState == .listening {
            // TODO(token) AppTheme.Motion.breathing
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseScale = 1.18
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                pulseScale = 1.0
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            MicButton(state: .idle,       onTap: {})
            MicButton(state: .listening,  onTap: {})
        }
        HStack(spacing: 24) {
            MicButton(state: .aiSpeaking, onTap: {})
            MicButton(state: .disabled,   onTap: {})
        }
    }
    .padding()
    .background(AppTheme.Color.pageBg)
}
