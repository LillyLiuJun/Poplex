import Foundation

// Supabase 连接信息。
// projectURL 和 anonKey 在 Supabase 后台 Project Settings → API 里获取。
// 注意：anon key 是专门给客户端用的、可以公开，由行级安全（RLS）保护——
// 它和 Gemini API Key 性质完全不同，Gemini Key 绝不能放这里，只能存在 Edge Function 的环境变量里。
// 纯配置常量，不碰任何主线程状态——显式 nonisolated，好让后台网络请求代码
// （比如 TodayViewModel 里标了 nonisolated 的 fetchMessageData）能直接读，
// 不必因为模块默认主线程隔离而被拦下来。
nonisolated enum SupabaseConfig {
    // anonKey 这里用的是 Supabase 新版 publishable key（sb_publishable_...），可公开、由 RLS 保护。
    static let projectURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"

    static var generateFunctionURL: URL {
        projectURL.appending(path: "functions/v1/generate")
    }

    static var getMaterialsFunctionURL: URL {
        projectURL.appending(path: "functions/v1/get-materials")
    }

    static var deleteMaterialFunctionURL: URL {
        projectURL.appending(path: "functions/v1/delete-material")
    }

    static var restoreMaterialFunctionURL: URL {
        projectURL.appending(path: "functions/v1/restore-material")
    }

    static var logEventFunctionURL: URL {
        projectURL.appending(path: "functions/v1/log-event")
    }

    static var messagesFunctionURL: URL {
        projectURL.appending(path: "functions/v1/get-messages")
    }

    // MARK: - Onboarding 预设卡轻量落库
    static var savePresetCardFunctionURL: URL {
        projectURL.appending(path: "functions/v1/save-preset-card")
    }

    // MARK: - Tab2 首页（Slice B）
    static var getTab2HomeFunctionURL: URL {
        projectURL.appending(path: "functions/v1/get-tab2-home")
    }

    static var getCategoryWordsFunctionURL: URL {
        projectURL.appending(path: "functions/v1/get-category-words")
    }

    // MARK: - 对话页（E1）
    static var dialogueFunctionURL: URL {
        projectURL.appending(path: "functions/v1/dialogue")
    }

    // MARK: - 合规
    static var deleteAccountFunctionURL: URL {
        projectURL.appending(path: "functions/v1/delete-account")
    }

    static var submitFeedbackFunctionURL: URL {
        projectURL.appending(path: "functions/v1/submit-feedback")
    }
}
