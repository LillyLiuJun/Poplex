import Foundation

/// "pops" 是产品统一的可学表达计数单位（一个 pop = 用户捕捉到的一个可学表达）。
/// 进度行胶囊与 Hero 卡共用此格式化，保证复数处理一致。
enum PopsLabel {
    /// 0 → "0 pops"，1 → "1 pop"，N → "N pops"。
    static func format(_ count: Int) -> String {
        count == 1 ? "1 pop" : "\(count) pops"
    }
}
