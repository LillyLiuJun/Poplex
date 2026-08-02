import SwiftUI

/// Post-conversation summary card — independent View so presentation mode (full page vs sheet)
/// can be changed later with zero content rewrite (需求设计 §6.4).
///
/// E1 step 1: shows fake/stub data so the `ended` state has something to display.
/// Full implementation arrives in step 8.
struct ConversationSummaryView: View {
    let sceneCategory: String
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.paddingCard) {
                headerRow

                // Block ①: Words used today
                SummaryBlock(title: "You used these today", isEmpty: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                        Text("set up")
                            .font(AppTheme.Font.englishPrimary)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text("First time you've said this out loud")
                            .font(AppTheme.Font.buddy)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }

                // Block ②: Suggestions (could also say…)
                SummaryBlock(title: "You could also say…", isEmpty: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                        Text("the projector wasn't working")
                            .font(AppTheme.Font.englishPrimary)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text("negation needs a verb")
                            .font(AppTheme.Font.chineseFaint)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                }

                // Block ③: Progress — empty in fake data, so hidden (tests "有才出现")
                SummaryBlock(title: "First time you've said this out loud", isEmpty: true) {
                    EmptyView()
                }

                Spacer(minLength: AppTheme.Space.paddingSection)
            }
            .padding(AppTheme.Space.paddingPage)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(AppTheme.Font.englishPrimary)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
            }
            .padding(.leading, AppTheme.Space.paddingM)
        }
    }

    private var headerRow: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            Spacer().frame(height: AppTheme.Size.barControl)
            Text("You practiced")
                .font(AppTheme.Font.screenTitle)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Text(sceneCategory)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ConversationSummaryView(sceneCategory: "工作与学业", onDismiss: {})
}
