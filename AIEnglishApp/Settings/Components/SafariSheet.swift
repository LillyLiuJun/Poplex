import SwiftUI
import SafariServices

/// 应用内 Safari 承载。SettingsView / AboutAIView 都要打开法务链接，
/// 此前两边各存了一份**逐字节相同**的私有拷贝；这里是唯一副本。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

/// `.sheet(item:)` 需要 Identifiable，而 URL 不是。包一层给它一个身份。
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL

    init(_ url: URL) {
        self.url = url
    }
}
