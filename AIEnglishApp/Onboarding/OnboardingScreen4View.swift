import Foundation

struct PresetCard: Identifiable {
    let id: String
    let title: String
    let imageName: String

    static let all: [PresetCard] = [
        PresetCard(id: "morning_coffee",  title: "Morning coffee",  imageName: "card_morning_coffee"),
        PresetCard(id: "packed_commute",  title: "Packed commute",  imageName: "card_packed_commute"),
        PresetCard(id: "afternoon_slump", title: "Afternoon slump", imageName: "card_afternoon_slump"),
        PresetCard(id: "hangry",          title: "Hangry",          imageName: "card_hangry"),
    ]

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
