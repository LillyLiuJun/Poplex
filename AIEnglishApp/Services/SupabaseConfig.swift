import Foundation

// Supabase 连接信息。
// projectURL 和 anonKey 在 Supabase 后台 Project Settings → API 里获取。
// 注意：anon key 是专门给客户端用的、可以公开，由行级安全（RLS）保护——
// 它和 Gemini API Key 性质完全不同，Gemini Key 绝不能放这里，只能存在 Edge Function 的环境变量里。
enum SupabaseConfig {
    // anonKey 这里用的是 Supabase 新版 publishable key（sb_publishable_...），可公开、由 RLS 保护。
    static let projectURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"

    static var generateFunctionURL: URL {
        projectURL.appending(path: "functions/v1/generate")
    }
}
