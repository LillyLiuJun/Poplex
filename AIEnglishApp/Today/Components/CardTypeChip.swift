import SwiftUI

struct CardTypeChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(AppTheme.Font.pos)
            .fontWeight(.bold)
            .tracking(0.5)
            .foregroundStyle(AppTheme.Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}
