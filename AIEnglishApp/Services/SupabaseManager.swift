import Foundation
import Supabase
import Auth   // Session.accessToken / .user、currentSession、signInAnonymously 等成员定义在 Auth 模块

/// 全局唯一的 Supabase 客户端 + 匿名会话管理。
///
/// 设计要点：
/// - App 启动即静默匿名登录（Page0 PRD 10.1「匿名优先」），用户无感、不出现登录页。
/// - SDK 自动把 refresh token 存进 iOS Keychain（落实 PRD 10.2 的「重装可能不丢数据」），
///   并在 access token 过期时自动刷新。
/// - 所有对 Edge Function 的请求，Authorization 头改带【用户 JWT】（而非 publishable key），
///   后端才能从 JWT 解析出 auth.uid()，为后续 user_id 数据隔离（切片 B/C）打底。
enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.anonKey
    )

    private static let gate = SignInGate()

    /// App 启动时调用一次：确保存在一个会话（老用户从 Keychain 恢复，新用户静默匿名注册）。
    @discardableResult
    static func ensureSignedIn() async throws -> User {
        try await gate.ensureSession(client: client).user
    }

    /// 当前会话的 access token（JWT）。若尚无会话会先静默匿名登录，token 过期时 SDK 自动刷新。
    static func accessToken() async throws -> String {
        _ = try await gate.ensureSession(client: client)
        return try await client.auth.session.accessToken
    }

    /// 给请求装上鉴权头：Authorization = 用户 JWT，apikey = publishable key。
    /// 6 处网络调用点统一走这里，避免重复拼头（对应审计报告「删除/请求逻辑重复」的收敛方向）。
    static func setAuthHeaders(on request: inout URLRequest) async throws {
        let token = try await accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    }
}

/// 单飞闸门：并发的首次调用只触发一次匿名登录，避免创建出多个匿名账号
/// （多个 user_id 会直接破坏我们正在建立的数据隔离）。
private actor SignInGate {
    private var inFlight: Task<Session, Error>?

    func ensureSession(client: SupabaseClient) async throws -> Session {
        // 已有会话（含从 Keychain 恢复的老用户）直接复用。
        if let existing = client.auth.currentSession {
            return existing
        }
        // 首次登录单飞：并发调用复用同一个 Task，不会各自注册一个新匿名账号。
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await client.auth.signInAnonymously() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
