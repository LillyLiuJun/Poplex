import SwiftUI

/// Fallback topic chips shown in `start` response when the AI lists sub-scene options (接口契约 §2.1).
/// Implemented in E1 step 5. Stub present to keep the file structure complete (§1).
struct TopicChipsRow: View {
    struct Chip: Identifiable {
        var id = UUID()
        let label: String
        let name: String
    }

    let chips: [Chip]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Space.paddingS) {
                ForEach(chips) { chip in
                    Button {
                        onSelect(chip.name)
                    } label: {
                        Text(chip.label)
                            .font(AppTheme.Font.buddy)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .padding(.horizontal, AppTheme.Space.paddingM)
                            .padding(.vertical, AppTheme.Space.paddingS)
                            .background(AppTheme.Color.brandSubtleBg, in: Capsule())
                    }
                    .accessibilityLabel("Talk about \(chip.label)")
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }
}

#Preview {
    TopicChipsRow(chips: [
        .init(label: "Mornings at the office", name: "晨会前"),
        .init(label: "Client calls", name: "客户电话"),
    ], onSelect: { _ in })
    .background(AppTheme.Color.pageBg)
}
