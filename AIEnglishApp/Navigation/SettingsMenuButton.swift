import SwiftUI

/// 主界面左上角的 Settings 入口。外层保留 44pt 触控区与既有轻量浮层，
/// 图标只承担低视觉重量的菜单提示。
struct SettingsMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DoubleLineMenuIcon()
                .foregroundStyle(AppTheme.Color.textPrimary)
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .surfaceFloating(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.iconControl)
        .accessibilityLabel("Open Settings")
    }
}

/// 两根圆头细横线组成的轻量菜单图标；不复用实心图标，避免与内容竞争注意力。
struct DoubleLineMenuIcon: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let rect = proxy.frame(in: .local)
                let longStart = rect.width * 0.08
                let longEnd = rect.width * 0.92
                let shortEnd = rect.width * 0.72

                path.move(to: CGPoint(x: longStart, y: rect.height * 0.33))
                path.addLine(to: CGPoint(x: longEnd, y: rect.height * 0.33))
                path.move(to: CGPoint(x: longStart, y: rect.height * 0.67))
                path.addLine(to: CGPoint(x: shortEnd, y: rect.height * 0.67))
            }
            .stroke(
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.topBarMenuIconStroke,
                    lineCap: .round
                )
            )
        }
        .frame(
            width: AppTheme.Size.topBarMenuIconGlyph,
            height: AppTheme.Size.topBarMenuIconGlyph
        )
        .accessibilityHidden(true)
    }
}
