import Foundation
import Supabase

enum ProfileService {

    private struct ProfileRow: Decodable {
        let onboardingCompletedAt: Date?
        enum CodingKeys: String, CodingKey {
            case onboardingCompletedAt = "onboarding_completed_at"
        }
    }

    /// 查询当前用户的 onboarding_completed_at。RLS 保证只返回自己那一行。
    /// 返回 nil 表示远端也未完成引导；抛出异常表示网络或 auth 失败。
    static func fetchOnboardingCompletedAt() async throws -> Date? {
        let row: ProfileRow = try await SupabaseManager.client
            .from("profiles")
            .select("onboarding_completed_at")
            .single()
            .execute()
            .value
        return row.onboardingCompletedAt
    }

    /// 新会话开始时原子自增 session_count。失败不阻塞流程（调用方 fire-and-forget）。
    static func incrementSessionCount() async throws {
        try await SupabaseManager.ensureSignedIn()
        try await SupabaseManager.client
            .rpc("increment_session_count")
            .execute()
    }

    /// 引导完成时写入远端。失败不阻塞流程（调用方 fire-and-forget）。
    static func markOnboardingComplete() async throws {
        let user = try await SupabaseManager.ensureSignedIn()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = formatter.string(from: Date())
        print("[ProfileService] marking onboarding complete for user \(user.id)")
        try await SupabaseManager.client
            .from("profiles")
            .update(["onboarding_completed_at": nowISO, "updated_at": nowISO])
            .eq("id", value: user.id.uuidString.lowercased())
            .execute()
        print("[ProfileService] onboarding_completed_at updated OK")
    }
}
