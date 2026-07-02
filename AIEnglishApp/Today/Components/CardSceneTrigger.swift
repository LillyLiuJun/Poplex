import SwiftUI

struct CardSceneTrigger: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            DashedDivider()
            Text(text)
                .font(.callout)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .italic()
        }
    }
}

struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(AppTheme.Color.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}
