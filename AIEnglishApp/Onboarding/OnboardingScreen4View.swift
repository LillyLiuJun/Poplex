import SwiftUI

struct PresetCard: Identifiable {
    let id: String
    let title: String

    static let all: [PresetCard] = [
        PresetCard(id: "morning_coffee",  title: "Morning coffee"),
        PresetCard(id: "packed_commute",  title: "Packed commute"),
        PresetCard(id: "afternoon_slump", title: "Afternoon slump"),
        PresetCard(id: "hangry",          title: "Hangry"),
    ]

    // Pre-written prompt sent to generate-content instead of image parsing (Slice 2+).
    var generationPrompt: String {
        switch id {
        case "morning_coffee":  return "I'm on my second cup of coffee and still not fully awake."
        case "packed_commute":  return "The subway was so crowded I could barely move this morning."
        case "afternoon_slump": return "It's 3 pm and my brain has completely stopped working."
        case "hangry":          return "I'm so hungry I can't decide what to eat and it's making me irritable."
        default:                return title
        }
    }
}

struct OnboardingScreen4View: View {
    var onContinue: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("What's happening\naround you right now?")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Space.paddingSection)
                    .padding(.bottom, AppTheme.Space.paddingCard)

                // Camera + Album capture buttons
                HStack(spacing: AppTheme.Space.paddingS) {
                    CaptureButton(icon: "camera", label: "Take a photo", action: onContinue)
                    CaptureButton(icon: "photo.on.rectangle", label: "Choose photo", action: onContinue)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                Text("Nothing in mind? Try one of these.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Space.paddingSection)
                    .padding(.bottom, AppTheme.Space.paddingCard)

                LazyVGrid(columns: columns, spacing: AppTheme.Space.paddingCard) {
                    ForEach(PresetCard.all) { card in
                        PresetCardTile(card: card, onSelect: onContinue)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, 72) // clear progress dots
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct CaptureButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        }
        .foregroundStyle(AppTheme.Color.textPrimary)
    }
}

private struct PresetCardTile: View {
    let card: PresetCard
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading) {
                Spacer()
                Text(card.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(AppTheme.Space.paddingCard)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        }
        .frame(height: 140)
    }
}

#Preview {
    OnboardingScreen4View(onContinue: {})
}
