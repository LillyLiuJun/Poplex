import Foundation

/// 学习语言的单一真源。
///
/// MVP 固定 English-as-target / Chinese-as-native，但 CLAUDE.md 明确要求
/// 「目标语言 / 母语不得硬编码」——提示词与字段名都按 target/native 推理
/// （`native_meaning` 而非 `zh_meaning`），正是为了将来换语言时不必满库找字符串。
/// 展示层同理：这两个词只在这里出现一次。
///
/// 值写英文名（"Chinese" 而非 "中文"）是因为 CLAUDE.md 的另一条硬规则——
/// 产品 UI 文案一律英文，中文只能作为 AI 生成的学习内容出现。
enum LearningLanguages {
    /// 用户正在学的语言。
    static let target = "English"
    /// 用户的母语。
    static let native = "Chinese"
}
