import CoreGraphics
import CoreText
import Foundation
import UIKit

// MARK: - 自定义字体运行时加载器 (Custom Font Loader)
// 在 App 启动或首次访问 AppTheme.Font 时自动注册 Gothic A1 / Geist 等外部字体文件。
// Geist 三档为 Gothic A1 换装过渡期保留（v1.1 §3.6）：包内文件与注册均不删，
// 回滚只需把 AppTheme.Font.SansWeight.postScriptName 的字符串改回 Geist-*。
// 稳定一个版本后单独一刀删除 Geist 文件并从这里移除。
enum FontLoader {
    private static var isRegistered = false

    static func registerCustomFonts() {
        guard !isRegistered else { return }
        isRegistered = true

        let fontFiles = [
            "GothicA1-ExtraLight.ttf", "GothicA1-Light.ttf", "GothicA1-Regular.ttf", "GothicA1-Medium.ttf", "GothicA1-SemiBold.ttf",
            "Geist-Regular.ttf", "Geist-Medium.ttf", "Geist-SemiBold.ttf",
        ]
        for file in fontFiles {
            let possiblePaths = [
                Bundle.main.path(forResource: file, ofType: nil),
                Bundle.main.resourcePath.map { ($0 as NSString).appendingPathComponent(file) },
                URL(fileURLWithPath: #file)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Resources/Fonts/\(file)").path
            ].compactMap { $0 }

            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path),
                   let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   let provider = CGDataProvider(data: data as CFData),
                   let font = CGFont(provider) {
                    var error: Unmanaged<CFError>?
                    CTFontManagerRegisterGraphicsFont(font, &error)
                    break
                }
            }
        }
    }
}
