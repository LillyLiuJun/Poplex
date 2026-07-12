import SwiftUI

// Shared press feedback so every tappable icon/button reacts instantly
// (opacity + slight shrink on touch-down). Avoids "dead tap" feel.
// Reused by InputBar icon buttons and the camera controls.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92
    var pressedOpacity: CGFloat = 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
