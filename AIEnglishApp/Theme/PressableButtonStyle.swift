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

// 两档具名预设。此前调用点各写各的字面量（0.92/0.6、0.98/0.82、0.9/0.8、0.97/0.85），
// 同一种「按下去有多少反应」被表达成四组数字，无从判断哪组是标准。
// 收成两档，按**被按的面积**分——这是唯一真正影响观感的变量：
// 小图标缩 8% 才看得出来，整行缩 8% 会像页面在抖。
extension ButtonStyle where Self == PressableButtonStyle {
    /// 图标 / 胶囊 / 独立按钮等小面积控件。
    static var iconControl: PressableButtonStyle {
        PressableButtonStyle()
    }

    /// 整行、整卡等大面积表面（沿用 Tab2LoadErrorView 已确立的取值）。
    static var rowSurface: PressableButtonStyle {
        PressableButtonStyle(pressedScale: 0.98, pressedOpacity: 0.82)
    }
}
