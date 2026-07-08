import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hex helper (仅供 Primitive 层构造色值使用，不在组件中直接调用)
private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Primitive layer (raw values — never reference these directly in components)
private enum Primitive {
    // 间距
    static let space4: CGFloat  = 4
    static let space8: CGFloat  = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48
    static let space56: CGFloat = 56

    // 圆角
    static let radius8: CGFloat  = 8
    static let radius16: CGFloat = 16
    static let radius20: CGFloat = 20

    // 色值（浅色锁定，固定 hex —— 已退出系统自适应，深色模式留后续版本）
    static let warmWhite    = Color(hex: 0xFAFAF8)  // 暖白页面底
    static let pureWhite    = Color(hex: 0xFFFFFF)  // 卡片底
    static let warmSubtle   = Color(hex: 0xF3F2EF)  // 用户气泡 / 输入框底
    static let nearBlack    = Color(hex: 0x111111)  // 英文主内容 / 控件
    static let graphite     = Color(hex: 0x374151)  // 次要英文
    static let slateGray    = Color(hex: 0x6B7280)  // 音标/词性/语法/中文翻译
    static let ashGray      = Color(hex: 0x9CA3AF)  // 中文原文/日期（最浅）
    static let sage         = Color(hex: 0x2D7D52)  // AI 专属声音
    static let sageBg       = Color(hex: 0xF0FAF5)  // AI 声音轻背景
    static let warmBorder   = Color(hex: 0xE8E5E0)  // 卡片描边
    static let dashGray     = Color(hex: 0xD9D6D0)  // 卡片内虚线
    static let dangerRed    = Color(hex: 0xDC2626)  // 删除
}

// MARK: - Semantic layer (purpose-named tokens — components reference only these)
enum AppTheme {
    enum Space {
        static let paddingXS: CGFloat           = Primitive.space4
        static let paddingS: CGFloat            = Primitive.space8
        static let paddingCard: CGFloat         = Primitive.space16
        static let paddingPage: CGFloat         = Primitive.space20
        static let paddingSection: CGFloat      = Primitive.space32
        static let paddingHero: CGFloat         = Primitive.space48
        static let paddingScreenBottom: CGFloat = Primitive.space56
    }

    enum Color {
        // 背景
        static let pageBg   = Primitive.warmWhite
        static let cardBg   = Primitive.pureWhite
        static let inputBg  = Primitive.warmSubtle

        // 文字（英文由重到轻：primary → secondary → muted；中文只有 faint 一档）
        static let textPrimary   = Primitive.nearBlack
        static let textSecondary = Primitive.graphite
        static let textMuted     = Primitive.slateGray
        static let textFaint     = Primitive.ashGray

        // AI 专属声音（scene trigger / 核心词组）—— 绝不用于交互控件
        static let accentBuddy   = Primitive.sage
        static let accentBuddyBg = Primitive.sageBg

        // 交互控件（发送键 / 选中态 / CTA）—— 中性近黑
        static let interactive   = Primitive.nearBlack

        // 描边 / 分割
        static let border       = Primitive.warmBorder
        static let borderDashed = Primitive.dashGray
        static let divider      = Primitive.warmBorder

        // 语义状态
        static let danger = Primitive.dangerRed

        // 用户气泡（横向铺开阶段再定，暂留）
        static let bubbleUserBg   = Primitive.nearBlack
        static let bubbleUserText = Primitive.pureWhite
        static let bubbleAIBg     = Primitive.pureWhite

        // MARK: 过渡别名（旧组件仍引用，横向迁移后废弃 —— 勿在新代码中使用）
        static let textAccent = Primitive.sage
    }

    enum Font {
        static let englishPrimary = SwiftUI.Font.system(.title2, weight: .semibold)   // 英文主内容 ~22
        static let englishBody    = SwiftUI.Font.system(.body)                        // 英文例句
        static let buddy          = SwiftUI.Font.system(.callout).italic()            // scene trigger（绿斜体）
        static let keyPhrase      = SwiftUI.Font.system(.callout, weight: .medium)    // 核心词组
        static let phonetic       = SwiftUI.Font.system(.footnote, design: .monospaced) // IPA 音标（等宽）
        static let pos            = SwiftUI.Font.system(.caption)                     // 词性
        static let chineseFaint   = SwiftUI.Font.system(.footnote)                    // 中文原文弱化
        static let chineseBody    = SwiftUI.Font.system(.callout)                     // 中文翻译
        static let date           = SwiftUI.Font.system(.caption2, weight: .semibold) // 日期分隔
        static let hero           = SwiftUI.Font.system(.largeTitle, weight: .bold)   // Onboarding 标题
    }

    enum Radius {
        static let small: CGFloat  = Primitive.radius8   // tag / 小元素
        static let medium: CGFloat = Primitive.radius16  // 卡片 / 气泡
        static let large: CGFloat  = Primitive.radius20  // 输入框

        // MARK: 过渡别名（旧组件仍引用，横向迁移后统一到上面三档）
        static let bubble: CGFloat = Primitive.radius16
        static let card: CGFloat   = Primitive.radius16
    }

    enum Shadow {
        static let cardColor: SwiftUI.Color = SwiftUI.Color.black.opacity(0.05)
        static let cardRadius: CGFloat = 4
        static let cardX: CGFloat = 0
        static let cardY: CGFloat = 1
    }
}
