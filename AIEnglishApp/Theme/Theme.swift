import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Primitive layer (raw values — never reference these directly in components)
private enum Primitive {
    static let space4: CGFloat  = 4
    static let space8: CGFloat  = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
}

// MARK: - Semantic layer (purpose-named tokens — components reference only these)
enum AppTheme {
    enum Space {
        static let paddingXS: CGFloat      = Primitive.space4
        static let paddingS: CGFloat       = Primitive.space8
        static let paddingCard: CGFloat    = Primitive.space16
        static let paddingPage: CGFloat    = Primitive.space20
        static let paddingSection: CGFloat = Primitive.space32
        static let paddingHero: CGFloat    = Primitive.space48
    }

    // 颜色：直接映射系统语义色，自动继承浅/深色模式与最新系统视觉语言（如 Liquid Glass）
    enum Color {
        static let textPrimary    = SwiftUI.Color.primary
        static let textSecondary  = SwiftUI.Color.secondary
        static let textAccent     = SwiftUI.Color.accentColor
        static let pageBg         = SwiftUI.Color(uiColor: .systemBackground)
        static let bubbleAIBg     = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let bubbleUserBg   = SwiftUI.Color.accentColor
        static let bubbleUserText = SwiftUI.Color.white
        static let inputBg        = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let divider        = SwiftUI.Color(uiColor: .separator)
        static let cardBg         = SwiftUI.Color(uiColor: .secondarySystemBackground)
    }

    enum Radius {
        static let bubble: CGFloat = 16
        static let card: CGFloat   = 16
    }
}
