import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case today = 0
    case mine  = 1

    /// 顶部导航显示名。TopTabSelector 与导航 chrome 测试共用，
    /// 改 Tab 文案只改这一处（测试会按新文案重测宽度）。
    var title: String {
        switch self {
        case .today: return "Today"
        case .mine: return "Library"
        }
    }
}
