import SwiftUI

struct CardTypeChip: View {
    let label: String
    let color: Color
    // 默认白字（配深色实心胶囊）；黄色系（Polish）扛不住白字，由调用方传入深色文字。
    var textColor: Color = AppTheme.Color.textOnChip

    var body: some View {
        Text(label.uppercased())
            .font(AppTheme.Font.pos)
            .fontWeight(.bold)
            .tracking(0.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}
