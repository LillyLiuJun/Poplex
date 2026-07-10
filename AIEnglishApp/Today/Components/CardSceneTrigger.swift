import SwiftUI

struct CardSceneTrigger: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.Font.buddy)
            .foregroundStyle(AppTheme.Color.accentBuddy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background(AppTheme.Color.accentBuddyBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
    }
}
