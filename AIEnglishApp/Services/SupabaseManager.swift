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

    /// App 启动时在后台线程预热：强制在 detached Task 里首次触碰 client，
    /// 让 SupabaseClient 的初始化（建 auth/realtime/storage 子系统、读 Keychain 恢复
    /// 会话）全部发生在后台，绝不在主线程同步执行——这是冷启动首屏卡顿的根因。
    static func warmUp() async {
        _ = try? await ensureSignedIn()
    }

    /// App 启动时调用一次：确保存在一个会话（老用户从 Keychain 恢复，新用户静默匿名注册）。
    @discardableResult
    static func ensureSignedIn() async throws -> User {
        try await gate.ensureSession(client: client).user
    }

    /// 当前会话的 access token（JWT）。会话不存在会静默匿名登录，已过期会自动续期。
    /// 统一走 ensureSession：那里用 withTimeout 包住刷新/登录，断网时抛错而非挂死。
    static func accessToken() async throws -> String {
        let session = try await gate.ensureSession(client: client)
        return session.accessToken
    }

    /// 当前登录用户的 UUID 字符串（用于反馈邮件、日志等纯展示场景）。
    static var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }

    /// 注销当前会话（用于删除账号后回到首启态）。
    static func signOut() async throws {
        try await client.auth.signOut()
    }

    /// 给请求装上鉴权头：Authorization = 用户 JWT，apikey = publishable key。
    /// 6 处网络调用点统一走这里，避免重复拼头（对应审计报告「删除/请求逻辑重复」的收敛方向）。
    static func setAuthHeaders(on request: inout URLRequest) async throws {
        let token = try await accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    }
}

/// 带超时的 async 执行：超时后抛 CancellationError，避免断网时无限挂起。
private func withTimeout<T: Sendable>(seconds: Double, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// 取会话时该走哪条路。抽成独立类型只为一件事：**让它可测**。
///
/// 这个三选一原本内联在 `ensureSession` 的两个 if 里，其中「已有会话」那条
/// 漏判了过期，导致过期 JWT 被发出去、全链路静默 401（删账号即此因）。
/// 内联的分支写错了没有任何东西会失败；抽出来就能用单测把它钉死。
/// `nonisolated`：项目设了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，
/// 不标注的类型会被隐式 MainActor 化。而这个判定是从 `SignInGate`（actor）里
/// 调用的纯函数，隐式隔离会产生「Swift 6 模式下将成为错误」的警告。
/// 它不碰任何可变状态，本就不需要隔离。
nonisolated enum SessionAction: Equatable {
    /// 本地会话仍然有效，直接用。
    case reuse
    /// 有会话但已过期 → 用 refresh token 续期。
    case refresh
    /// 完全没有会话（新装 / Keychain 被清）→ 静默匿名注册。
    case signIn

    static func decide(hasSession: Bool, isExpired: Bool) -> SessionAction {
        guard hasSession else { return .signIn }
        return isExpired ? .refresh : .reuse
    }
}

/// 单飞闸门：并发的首次调用只触发一次匿名登录，避免创建出多个匿名账号
/// （多个 user_id 会直接破坏我们正在建立的数据隔离）。
private actor SignInGate {
    private var inFlight: Task<Session, Error>?

    func ensureSession(client: SupabaseClient) async throws -> Session {
        // 已有**且未过期**的会话（含从 Keychain 恢复的老用户）直接复用。
        //
        // `currentSession` 只读本地存储、不做任何校验，SDK 注释原文：
        //   "The session returned by this property may be expired.
        //    Use `session` for a session that is guaranteed to be valid."
        // 早先这里漏了 isExpired 判断，于是过期 JWT 会被原样发出去，
        // Edge Function 拿它验签失败返回 401，而调用方多数把非 2xx 静默吞掉——
        // 表现就是「转圈一下，什么都没发生」，且无从排查（删账号即此因）。
        // 匿名 token 默认 1 小时到期，App 后台挂久了再操作必然命中。
        let existing = client.auth.currentSession
        let action = SessionAction.decide(
            hasSession: existing != nil,
            isExpired: existing?.isExpired ?? false
        )
        if action == .reuse, let existing {
            return existing
        }
        // 单飞：并发调用复用同一个 Task。
        // 既防止「首次登录注册出多个匿名账号」（多 user_id 会破坏数据隔离），
        // 也防止「过期后 N 个并发请求各自发起一次刷新」。
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task {
            // 全程包在 withTimeout 里：这是原实现绕开 `client.auth.session` 的初衷——
            // 断网时刷新会无限挂起。正确解法是「刷新 + 超时」，而不是「不刷新」。
            try await withTimeout(seconds: 10) {
                switch action {
                case .refresh:
                    // `client.auth.session` 才是会自动刷新的入口（区别于 currentSession）。
                    return try await client.auth.session
                case .signIn, .reuse:
                    // .reuse 走不到这里（上面已 return）；并入 signIn 只为穷尽 switch。
                    return try await client.auth.signInAnonymously()
                }
            }
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
