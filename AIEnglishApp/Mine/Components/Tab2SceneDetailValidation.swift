import Foundation

/// 活动名（scene_detail）的卡面校验规则（刀 4b 重写，规格 v3「活动级字段」+ §10.5）。
///
/// 四条**全满足**才渲染，任一不满足 → 该活动整条不渲染、且不计入 +N：
/// 1. 非空（trim 后）
/// 2. ≤ 24 字符（trim 后按字符计数）
/// 3. 纯 ASCII 英文：首字符必须是 ASCII 字母，全串仅含字母 / 空白 / `'` / `-`
///    （字符集沿用刀 3 前旧实现，`'` 与 `-` 是短语里合法的连接符，如 "Let's"、"re-do"）
/// 4. 不含 `/`（已由 3 的允许集隐含，单独列出是因为它是「拒绝」的口径而非「允许」的口径——
///    未来若要放宽字符集，`/` 仍需拒绝：它会让文案读成路径）
///
/// 与当前 English-as-target 配置绑定；未来允许更换目标语言时，只需替换这一处脚本校验。
/// Hero 卡与 More 行共用，只有一处真相（两处调用点各自维护一份同名函数会悄悄不一致）。
enum Tab2SceneDetailValidation {

    /// 通过校验 → 返回 trim 后的活动名；否则 nil。
    static func validatedTargetSceneDetail(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 24 else { return nil }
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
