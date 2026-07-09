import Foundation
import Supabase

enum ProfileService {

    private struct ProfileRow: Decodable {
        let onboardingCompletedAt: Date?
        enum CodingKeys: String, CodingKey {
            case onboardingCompletedAt = "onboarding_completed_at"
        }
    }

    /// 远端引导状态的三态结果：把「明确没完成」和「查不到行」区分开，
    /// 网络/auth 失败则直接 throws——三种情况的处理各不相同（见 RootView）。
    enum OnboardingRemoteState: Equatable {
        case completed(Date)   // 有行且有完成时间 → 走过引导
        case notCompleted      // 有行但完成时间为空 → 确实没走过
        case missingProfile    // 查不到行 → 数据缺失，不代表没走过（触发器保证新用户必有行）
    }

    /// 查询当前用户的引导完成状态。RLS 保证最多返回自己那一行。
    /// 不用 .single()：0 行是合法结果（missingProfile），不应作为异常抛出。
    static func fetchOnboardingState() async throws -> OnboardingRemoteState {
        let rows: [ProfileRow] = try await SupabaseManager.client
            .from("profiles")
            .select("onboarding_completed_at")
            .execute()
            .value
        return parseOnboardingState(completedDates: rows.map(\.onboardingCompletedAt))
    }

    /// 纯解析逻辑，独立出来便于单元测试
    static func parseOnboardingState(completedDates: [Date?]) -> OnboardingRemoteState {
        guard let first = completedDates.first else { return .missingProfile }
        if let date = first { return .completed(date) }
        return .notCompleted
    }

    /// 新会话开始时原子自增 session_count。失败不阻塞流程（调用方 fire-and-forget）。
    static func incrementSessionCount() async throws {
        try await SupabaseManager.ensureSignedIn()
        try await SupabaseManager.client
            .rpc("increment_session_count")
            .execute()
    }

    /// 引导完成时写入远端。用 upsert 而非 update，防止行缺失时静默失败
    /// （行缺失是边缘情况；upsert = INSERT…ON CONFLICT，顺带完成 profile 行自愈）。
    /// 失败不阻塞流程（调用方 fire-and-forget）。
    static func markOnboardingComplete() async throws {
        let user = try await SupabaseManager.ensureSignedIn()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = formatter.string(from: Date())
        print("[ProfileService] marking onboarding complete for user \(user.id)")
        try await SupabaseManager.client
            .from("profiles")
            .upsert(["id": user.id.uuidString.lowercased(), "onboarding_completed_at": nowISO, "updated_at": nowISO])
            .execute()
        print("[ProfileService] onboarding_completed_at upserted OK")
    }
}
