import SwiftUI

struct AccountMenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let action: () -> Void
}

struct AccountMenuView: View {
    let items: [AccountMenuItem]
    let appVersion: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    item.action()
                    onDismiss()
                } label: {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                        Text(item.title)
                            .font(AppTheme.Font.englishBody)
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingCard)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuItemButtonStyle())

                Divider()
                    .padding(.horizontal, AppTheme.Space.paddingCard)
            }

            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "number")
                    .frame(width: 20)
                Text("Version \(appVersion)")
                    .font(AppTheme.Font.phonetic)
            }
            .foregroundStyle(AppTheme.Color.textMuted)
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingCard)
        }
        .frame(width: 200)
        .glassContainer()
    }
}

private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
