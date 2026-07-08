import SwiftUI

struct CardSceneTrigger: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            DashedDivider()
            Text(text)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.accentBuddy)
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
            .stroke(AppTheme.Color.borderDashed, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}
