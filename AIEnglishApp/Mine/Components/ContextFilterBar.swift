import SwiftUI

struct ContextFilterBar: View {
    let categories: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Space.paddingS) {
                // "All" 只在有 2 个以上情境时才有意义
                if categories.count > 1 {
                    FilterChip(label: "All", isSelected: selected == nil) {
                        selected = nil
                    }
                }
                ForEach(categories, id: \.self) { cat in
                    FilterChip(label: cat, isSelected: selected == cat || categories.count == 1) {
                        selected = cat
                        Analytics.track("context_tag_tapped", properties: ["scene_category": cat])
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, AppTheme.Space.paddingXS)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingXS)
                .background(isSelected ? AppTheme.Color.brandStrong : AppTheme.Color.cardBg)
                .foregroundStyle(isSelected ? Color.white : AppTheme.Color.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
