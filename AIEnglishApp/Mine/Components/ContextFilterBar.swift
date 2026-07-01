import SwiftUI

struct ContextFilterBar: View {
    let categories: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Space.paddingS) {
                FilterChip(label: "全部", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(categories, id: \.self) { cat in
                    FilterChip(label: cat, isSelected: selected == cat) {
                        selected = cat
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
                .background(isSelected ? AppTheme.Color.textAccent : AppTheme.Color.cardBg)
                .foregroundStyle(isSelected ? Color.white : AppTheme.Color.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
