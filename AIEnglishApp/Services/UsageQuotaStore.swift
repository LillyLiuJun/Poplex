import Foundation
import Supabase

/// 生成次数额度的共享展示状态（单一事实来源）。
///
/// 三个入口，都只写「服务器说的话」：
/// - `refresh()`：调 `check_generation_quota` RPC（用户由 auth.uid() 决定，
///   不接受 user_id 参数），拿到服务器数字与裁决——Sheet 打开时刷新；
/// - `apply(usage:)`：生成成功响应携带的最新用量（含本次生成），免一次网络往返；
/// - `applyServerVerdict(used:limit:allowed:)`：429 时服务端的明确裁决（不允许）。
///
/// 前端不做任何拦截判断：`isAllowed` 只来自服务器；`nil` = 未知，输入栏不锁。
/// 这样永不完成 onboarding 的豁免用户（服务端永远放行）绝不会被前端误锁。
@Observable
@MainActor
final class UsageQuotaStore {
    static let shared = UsageQuotaStore()

    /// check_generation_quota 的单行返回（used_count / limit / allowed）。
    struct QuotaRow: Decodable, Equatable {
        let usedCount: Int
        let limit: Int
        let allowed: Bool

        enum CodingKeys: String, CodingKey {
            case usedCount = "used_count"
            case limit
            case allowed
        }
    }

    /// 服务器报告的今日已用次数与有效上限；nil = 尚未取得。
    private(set) var usedCount: Int?
    private(set) var dailyLimit: Int?
    /// 服务器最近一次「今天还能不能生成」的裁决；nil = 未知（输入栏不锁）。
    private(set) var isAllowed: Bool?
    /// 最近一次 refresh 是否失败：Sheet 首次加载即失败时给真实反馈，而不是显示假 0。
    private(set) var refreshFailed = false

    /// 可注入的数据源（默认走 check_generation_quota RPC），便于单元测试。
    var fetchQuota: (() async throws -> QuotaRow)?

    /// 设备当地日期（"yyyy-MM-dd"）：与 generate 请求携带的 utc_offset_minutes
    /// 同一套「设备的今天」口径，服务端按它分桶。
    static func localDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - 写入世代守卫

    // 三个入口可能交错：例如 Sheet 里的 refresh 还在途，用户已发消息并收到
    // 429 裁决——迟到的 refresh 结果（更旧的数字）不得把裁决倒退回旧态。
    // 同步入口天然是最新世代；只有「先出发、后完成」的异步入口需要它兜底。
    private var nextWriteGeneration = 0
    private var lastCommittedGeneration = 0

    /// 认领一个写入世代（调用即取号，先取号者世代更旧）。
    private func claimGeneration() -> Int {
        nextWriteGeneration += 1
        return nextWriteGeneration
    }

    /// 只有不早于已落地世代的写入才有权生效——晚完成的旧请求被静默丢弃。
    private func commit(_ generation: Int, _ update: () -> Void) {
        guard generation >= lastCommittedGeneration else { return }
        lastCommittedGeneration = generation
        update()
    }

    func refresh() async {
        let generation = claimGeneration()
        do {
            let row: QuotaRow
            if let fetchQuota {
                row = try await fetchQuota()
            } else {
                try await SupabaseManager.ensureSignedIn()
                // .single() 带 Accept: application/vnd.pgrst.object+json——
                // check_generation_quota 恒返回一行，按单对象取，避免
                // 「RETURNS TABLE → 数组」形状事故（2026-09-02）在客户端重演。
                row = try await SupabaseManager.client
                    .rpc("check_generation_quota", params: ["p_usage_date": Self.localDateString()])
                    .single()
                    .execute()
                    .value
            }
            commit(generation) {
                usedCount = row.usedCount
                dailyLimit = row.limit
                isAllowed = row.allowed
                refreshFailed = false
            }
        } catch {
            // 保留旧值（若有），只标记本次刷新失败；迟到的失败同样不能
            // 覆盖更近的写入（如 429 裁决已把 refreshFailed 置回 false）。
            commit(generation) { refreshFailed = true }
        }
    }

    /// 生成成功响应携带的最新用量（含本次生成）：直接覆盖，免一次网络往返。
    /// 服务器刚放行过一次生成，旧的「不可生成」裁决随之过期，回到未知态。
    func apply(usage: UsageInfo) {
        commit(claimGeneration()) {
            usedCount = usage.used
            dailyLimit = usage.limit
            isAllowed = nil
        }
    }

    /// 429 时服务端的明确裁决：更新数字 + 锁输入栏（banner + 达标态）。
    func applyServerVerdict(used: Int, limit: Int, allowed: Bool) {
        commit(claimGeneration()) {
            usedCount = used
            dailyLimit = limit
            isAllowed = allowed
            refreshFailed = false
        }
    }
}
