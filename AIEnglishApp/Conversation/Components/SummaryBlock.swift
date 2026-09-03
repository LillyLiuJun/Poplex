import SwiftUI

/// Outer shell used by the three summary card blocks (§5.1).
/// Returns EmptyView when content is empty — "有才出现" is enforced at component level (§5.1).
struct SummaryBlock<Content: View>: View {
    let title: String
    let isEmpty: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                Text(title)
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .textCase(.uppercase)

                content()
            }
            .padding(AppTheme.Space.paddingCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: AppTheme.Radius.medium, fillColor: AppTheme.Color.cardBg)
        }
    }
}

#Preview {
    VStack(spacing: AppTheme.Space.paddingCard) {
        SummaryBlock(title: "You used these today", isEmpty: false) {
            Text("set up · run late")
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
        // Empty block renders nothing
        SummaryBlock(title: "Progress", isEmpty: true) {
            Text("Should not appear")
        }
    }
    .padding(AppTheme.Space.paddingPage)
    .background(AppTheme.Color.pageBg)
}
