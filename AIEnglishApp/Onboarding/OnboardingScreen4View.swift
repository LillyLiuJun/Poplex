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
            staticEnglish: "A Boston Terrier wearing a red plaid harness is running on a grassy field with a blue toy in its mouth.",
            staticChinese: "一只穿着红色格子背带的波士顿梗犬嘴里叼着蓝色玩具，正在草地上奔跑。"
        ),
        PresetCard(
            id: "2",
            title: "Scene 2",
            imageName: "card_scene_2",
            staticEnglish: "The image shows a spread of healthy breakfast items, including bowls of yogurt, fresh oranges, honey, and mintleaves, on a gray textured surface.",
            staticChinese: "这张图片展示了一系列健康的早餐食品，包括几碗酸奶、新鲜橙子、蜂蜜和薄荷叶，摆放在一个灰色纹理的台面上。"
        ),
        PresetCard(
            id: "3",
            title: "Scene 3",
            imageName: "card_scene_3",
            staticEnglish: "The picture shows a beautiful tropical beach with white sand, turquoise ocean water, and many straw umbrellas lined up along the shore.",
            staticChinese: "这张照片展示了一个美丽的白色沙滩热带海滩，有碧绿的海水，许多草编的遮阳伞沿着海岸线排列。"
        ),
        PresetCard(
            id: "4",
            title: "Scene 4",
            imageName: "card_scene_4",
            staticEnglish: "A hand is holding a smartphone that displays a stock market app, showing the Dow Jones Industrial Average chart and a financial news article.",
            staticChinese: "一只手正拿着一部智能手机，手机屏幕上显示着一个股票市场应用，其中包含道琼斯工业平均指数图表和一篇金融新闻文章。"
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
