import Foundation

/// hero 卡（`Tab2HeroCard`）与 More 列表行（`Tab2MomentRow`）共用的 scene_detail 校验规则：
/// 首字符必须是 ASCII 字母，全串仅含字母/空白/'/-；不满足则判定为非目标语言内容，不显示。
/// 与当前 English-as-target 配置绑定；未来允许更换目标语言时，只需替换这一处脚本校验。
///
/// 两处调用点曾各自维护一份同名私有函数，规则一旦改动容易漏改一处、两个组件悄悄不一致——
/// 收在这里保证只有一处真相。
/// 纯字符校验逻辑，不碰任何主线程状态——显式 nonisolated，不继承项目
/// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor 的默认隔离，调用方（含非隔离上下文，
/// 如把 isValidScalar 当作 allSatisfy 的闭包参数传入）才不用为一次纯计算做线程跳转。
nonisolated enum Tab2SceneDetailValidation {
    static func validatedTargetSceneDetail(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.unicodeScalars.first,
              isASCIILetter(first),
              trimmed.unicodeScalars.allSatisfy(isValidScalar)
        else {
            return nil
        }
        return trimmed
    }

    private static func isValidScalar(_ scalar: UnicodeScalar) -> Bool {
        isASCIILetter(scalar)
            || scalar.properties.isWhitespace
            || scalar == "'"
            || scalar == "-"
    }

    private static func isASCIILetter(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
}
