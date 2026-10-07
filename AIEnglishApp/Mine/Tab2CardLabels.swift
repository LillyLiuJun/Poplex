import Foundation

/// 刀 4b：Tab2 卡面时间与文案的纯格式化（§10.3 档位表 + §10.4 理由行 + §12 拍板文案集）。
///
/// 全部为纯函数：now 与 calendar 可注入，单测锁定。日差口径：
/// **本地自然日之差**——`calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b))`，
/// 绝不用时间戳相减除以 86400（夏令时切换日会差 1 天，且跨日边界 23:59 → 次日 00:01
/// 用秒数除出来是 0）。这是 4b 最容易写错的一处，`naturalDayDifference` 是唯一实现点。
enum Tab2CardLabels {

    /// 刀 6b 空态：无 activity 时的说明行文案，Hero 与 More 空态共用同一句
    /// （B2 拍板：同一个状态在两处说同一句话）。`reasonLine` / `reasonPillState`
    /// 的 lastMaterialAt == nil 分支与此同源——三处引用一个常量，不新写一句。
    static let onlyWordsSoFar = "Only words so far"

    /// 本地自然日差（from 到 to 经过了多少个自然日）。
    /// - Returns: nil 当 from 为 nil；负值（时钟偏差导致 from 在未来）夹为 0。
    static func naturalDayDifference(
        from: Date?,
        to: Date,
        calendar: Calendar
    ) -> Int? {
        guard let from else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
        return max(0, days)
    }

    /// More 行时间行（§10.3 档位表）。lastMaterialAt 为 nil → 返回 nil，整行不渲染。
    /// 档位：d=0 Added today；d=1 Added yesterday；2–6 Added {d} days ago；
    /// 7–13 Added last week；14–29 Added {w} weeks ago（w = floor(d/7)）；
    /// ≥30 Nothing new in a month。
    static func timeLine(
        lastMaterialAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let d = naturalDayDifference(from: lastMaterialAt, to: now, calendar: calendar) else {
            return nil
        }
        switch d {
        case 0:      return "Added today"
        case 1:      return "Added yesterday"
        case 2...6:  return "Added \(d) days ago"
        case 7...13: return "Added last week"
        case 14...29: return "Added \(d / 7) weeks ago"
        default:     return "Nothing new in a month"
        }
    }

    /// Hero 理由行（§10.4 + §12 文案集）。刀 6 起只被测试消费——卡面改用
    /// `reasonPillState`（§二② 理由胶囊），本函数保留为共用文案底子。
    /// 刀 6b 文案同步 v12：today 分支改「Added N times today / Added something
    /// today」（视觉稿图上 opill 渲染，次数是「记了几次」不是「几条新词」）。
    /// - lastMaterialAt 为 nil → "Only words so far"
    /// - newMaterialCount ≥ 1 且 d == 0 → "Added something today"（1 条）/
    ///   "Added {n} times today"（≥2 条）
    /// - 其余（count == 0，或防御命中）→ 久未分支：d=1 Nothing new since yesterday；
    ///   2–6 Nothing new in {d} days；7–13 Nothing new in the last week；
    ///   14–29 Nothing new in {w} weeks；≥30 Nothing new in a month。
    ///
    /// §12 防御规则：跨午夜后渲染缓存旧响应时会出现 count ≥ 1 但 d ≥ 1——
    /// 此时**以 d 为准**走久未分支。宁可少报一次「今天有新东西」，
    /// 也不要在第二天早上还对用户说「你今天加了 3 条」。
    /// d == 0 且 count == 0 按服务端口径不可达（count 与 lastMaterialAt 同日界、
    /// 同表同扫，见 §10.6），兜底落入久未 default。
    static func reasonLine(
        lastMaterialAt: Date?,
        newMaterialCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let d = naturalDayDifference(from: lastMaterialAt, to: now, calendar: calendar) else {
            return onlyWordsSoFar
        }

        if newMaterialCount >= 1, d == 0 {
            return newMaterialCount == 1
                ? "Added something today"
                : "Added \(newMaterialCount) times today"
        }

        switch d {
        case 1:       return "Nothing new since yesterday"
        case 2...6:   return "Nothing new in \(d) days"
        case 7...13:  return "Nothing new in the last week"
        case 14...29: return "Nothing new in \(d / 7) weeks"
        default:      return "Nothing new in a month"
        }
    }

    /// 刀 6b：Hero 理由胶囊文案 + 两态判定（§二② + v12 .opill，图上）。
    /// - isHot = newMaterialCount ≥ 1 且 d == 0（今天有新东西）
    /// - quiet = 其余一切（count == 0 / 防御命中 / lastMaterialAt 为 nil）
    /// 视觉上两态已不再变色（2026-09-22 起）：封面理由是同一套白字 + 阴影，文案本身已经说完状态，
    /// isHot 只给需要区分「今天有没有新东西」的调用方用。lastMaterialAt 为 nil 时返回
    /// onlyWordsSoFar，Hero 封面不显示这一句（卡身空态说明行已经说过，见 Tab2HeroCard.coverReasonText）。
    /// 防御规则与 `reasonLine` 同源（§12）：跨午夜后 count ≥ 1 但 d ≥ 1 时以 d 为准，
    /// 落 quiet 态，绝不把「今天」说错。
    static func reasonPillState(
        lastMaterialAt: Date?,
        newMaterialCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (text: String, isHot: Bool) {
        guard let d = naturalDayDifference(from: lastMaterialAt, to: now, calendar: calendar) else {
            return (onlyWordsSoFar, false)
        }
        if newMaterialCount >= 1, d == 0 {
            return (
                newMaterialCount == 1
                    ? "Added something today"
                    : "Added \(newMaterialCount) times today",
                true
            )
        }
        return (
            reasonLine(
                lastMaterialAt: lastMaterialAt,
                newMaterialCount: newMaterialCount,
                now: now,
                calendar: calendar
            ),
            false
        )
    }

    /// Hero 副状态 / More 徽章的词数文案（§9.4：POPS 文案已判定删除）。
    /// 已解锁类恒 ≥20（unlocked = word_count ≥ 20），单数仅为文案完备性。
    static func words(_ count: Int) -> String {
        count == 1 ? "1 word" : "\(count) words"
    }
}
