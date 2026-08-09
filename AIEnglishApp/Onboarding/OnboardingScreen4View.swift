import Foundation

struct PresetCard: Identifiable {
    let id: String
    let title: String
    let imageName: String
    let staticEnglish: String
    let staticChinese: String

    static let all: [PresetCard] = [
        PresetCard(
            id: "1",
            title: "Scene 1",
            imageName: "card_scene_1",
            staticEnglish: "My dog is sleeping peacefully on the sofa, completely relaxed.",
            staticChinese: "我家狗在沙发上四脚朝天睡着了，格外放松。"
        ),
        PresetCard(
            id: "2",
            title: "Scene 2",
            imageName: "card_scene_2",
            staticEnglish: "Caught in the evening commute, but the golden sunset makes it all worthwhile.",
            staticChinese: "下班路上虽然赶上晚高峰，但落日余晖让一切都值得了。"
        ),
        PresetCard(
            id: "3",
            title: "Scene 3",
            imageName: "card_scene_3",
            staticEnglish: "A cozy morning with a simple breakfast and a cup of warm coffee.",
            staticChinese: "清晨在阳光下享用一份简单的早餐和一杯热咖啡。"
        ),
        PresetCard(
            id: "4",
            title: "Scene 4",
            imageName: "card_scene_4",
            staticEnglish: "Unwinding late at night under the warm glow of the bedside lamp.",
            staticChinese: "深夜在床头暖黄的灯光下翻翻书，卸下一天的疲惫。"
        ),
    ]

    var staticCard: AICard {
        .card(CardContent(
            granularity: "sentence",
            direction: "express",
            targetExpression: staticEnglish,
            nativeMeaning: staticChinese
        ))
    }

    var generationPrompt: String {
        switch id {
        case "1": return "My dog is sleeping on its back on the sofa."
        case "2": return "The evening commute sunset looks beautiful."
        case "3": return "A quiet morning breakfast."
        case "4": return "Late night reading by the lamp."
        default:  return title
        }
    }
}
