import Foundation

/// hero 卡（`Tab2HeroCard`）与 More 列表行（`Tab2MomentRow`）共用的 scene_detail 校验规则：
/// 首字符必须是 ASCII 字母，全串仅含字母/空白/'/-；不满足则判定为非目标语言内容，不显示。
/// 与当前 English-as-target 配置绑定；未来允许更换目标语言时，只需替换这一处脚本校验。
///
/// 两处调用点曾各自维护一份同名私有函数，规则一旦改动容易漏改一处、两个组件悄悄不一致——
/// 收在这里保证只有一处真相。
enum Tab2SceneDetailValidation {
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
