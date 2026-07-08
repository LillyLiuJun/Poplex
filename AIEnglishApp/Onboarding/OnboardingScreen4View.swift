import Foundation

struct PresetCard: Identifiable {
    let id: String
    let title: String
    let imageName: String

    static let all: [PresetCard] = [
        PresetCard(id: "1", title: "Morning coffee",  imageName: "card_morning_coffee"),
        PresetCard(id: "2", title: "Packed commute",  imageName: "card_packed_commute"),
        PresetCard(id: "3", title: "Afternoon slump", imageName: "card_afternoon_slump"),
        PresetCard(id: "4", title: "Hangry",          imageName: "card_hangry"),
    ]

    var generationPrompt: String {
        switch id {
        case "1": return "I'm on my second cup of coffee and still not fully awake."
        case "2": return "The subway was so crowded I could barely move this morning."
        case "3": return "It's 3 pm and my brain has completely stopped working."
        case "4": return "I'm so hungry I can't decide what to eat and it's making me irritable."
        default:  return title
        }
    }
}
