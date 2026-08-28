import Foundation

/// 法务页地址的单一真源。
///
/// 此前 SettingsView 与 AboutAIView 各自声明了一份同样的两个 URL。
/// 两份字面量意味着改版时可能只改一处，而「隐私政策打开的是旧地址」
/// 这类错误不会有任何东西报警——App Review 5.1.2 又恰好查这两个链接。
enum LegalLinks {
    static let privacy = URL(string: "https://poplex-legal.vercel.app/privacy.html")!
    static let terms   = URL(string: "https://poplex-legal.vercel.app/terms.html")!
}
