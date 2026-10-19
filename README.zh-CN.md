# Poplex（AIEnglishApp）

**从你自己的生活里学语言。** Poplex 是一款 AI native 的 iOS 语言学习 App：把身边的瞬间——
一张照片、几个词、一个念头——变成你真的能开口说出来的、带场景的表达。

> **当前阶段：** 目前支持 **中文 → 英语**。

[English](README.md)

## 产品做什么

Poplex 把你生活里的瞬间，变成属于你的语言：都是你真正用得上的表达，自动帮你整理好——
你记录下的每一刻，都会变成能用上的东西。

### Today（Tab1）—— 捕捉与生成

输入一句话，或拍照 / 选图。AI 生成一张中英对照的学习卡：用中文写，得到你本来想说的英文；
用英文写，得到它的中文意思；发一张照片，得到这个场景的英文表达。同一场景可以继续追问。

### Library（Tab2）—— 你的素材，自动整理好

不用手动归类。你捕捉的所有内容都会被自动整理：

- **自动分类**到生活主题。
- **自动聚合场景**，同一情境下的片段放在一起。
- **拆成表达**——单词、短语、搭配、习语、固定句型——跨所有输入去重，每条表达都记得它来自哪些场景。

一个主题收集满 20 条表达后解锁。

### 默认匿名

无需注册、无邮箱：首次启动自动匿名登录，用户创建的一切只属于该账号。删除账号会一并删除账号及其全部数据。

界面语言为英文；每张卡片都是英文和对应的中文意思并排。

## 架构

```
iOS App（SwiftUI，iOS 17+）
   │  HTTPS，用户 JWT
   ▼
Supabase Edge Functions（Deno / TypeScript）   ← 唯一与 AI 服务商通信的地方
   │                         │
   ▼                         ▼
Postgres（RLS）+ Storage      Google Gemini（gemini-3.7-flash）
```

- **客户端不持有任何 AI 密钥。** 所有 AI 请求都经由 Edge Function，服务商密钥只存在于函数的环境变量。
- **Edge Function 向 Supabase Auth 验证调用者 JWT**，写入 `user_id`，每次读取都按它过滤；
  表另有行级安全（RLS）作为纵深防御。
- 更换 AI 服务商只需改 Edge Function。

| 层 | 技术 |
|---|---|
| App | Swift 5、SwiftUI、`@Observable`、`NavigationStack`，iOS 17+，仅 iPhone |
| 后端 | Supabase：Postgres、Auth（匿名）、Storage、Edge Functions |
| AI | Google Gemini，仅服务端调用 |
| 测试 | Swift Testing + XCTest（UI 启动 / Toast 回归）、Deno 测试、pgTAP |

### Edge Functions（`supabase/functions/`）

| 函数 | 作用 |
|---|---|
| `generate` | 核心流水线：输入 → 学习卡 → 素材，并做词汇账本记账 |
| `get-messages`、`get-materials`、`get-vocabs`、`get-tab2-home`、`get-category-words` | Tab1 / Tab2 读取 |
| `save-preset-card`、`delete-material`、`restore-material` | 素材写入类 |
| `backfill-lexicon`、`reconcile-orphan-images` | 手动维护作业 |
| `delete-account`、`submit-feedback`、`log-event` | 账号、反馈、埋点 |

数据库结构变更在 `supabase/migrations/`（CI 会从零重放）。

## 仓库结构

```
AIEnglishApp/          iOS 源码 —— Today/（Tab1）、Mine/（Tab2）、Onboarding/、Settings/、
                       Services/、Models/、Theme/（设计 token）
AIEnglishAppTests/     单元测试
AIEnglishAppUITests/   UI 启动与 Toast 回归测试
supabase/              Edge Functions、SQL migrations、数据库测试
scripts/ci/            本地与 CI 共用的验证 / PR 脚本
docs/                  PRD、架构、设计规范、品牌、工程笔记
legal/                 隐私政策、条款、支持页
CLAUDE.md, AGENTS.md   面向 AI 编码助手的项目说明
```

`docs/` 下多数文档为中文。建议从这里读起：

- [`docs/prd/整体架构_两个Tab与对话页_v1.md`](docs/prd/整体架构_两个Tab与对话页_v1.md) —— 产品结构（Tab1 / Tab2）
- [`docs/prd/Agent内容组织与成长系统_PRD_v2.md`](docs/prd/Agent内容组织与成长系统_PRD_v2.md) —— Tab2、词汇账本、成长层
- [`docs/engineering/CI.md`](docs/engineering/CI.md) —— PR 验证
- [`docs/architecture/AI协作手册.md`](docs/architecture/AI协作手册.md) —— 产品负责人与 AI 助手如何分工
- [`docs/brand/README.md`](docs/brand/README.md) —— 品牌资产与规则
- [`docs/design-system/`](docs/design-system/) —— 字体与组件规范（颜色以 `AIEnglishApp/Theme/Theme.swift` 为准）
- [`CLAUDE.md`](CLAUDE.md) —— 设计规则、工作方法、已拍板的取舍、当前进度

## 运行与测试

```bash
open AIEnglishApp.xcodeproj      # 选模拟器或真机，Cmd+R
bash scripts/ci/test-ios.sh      # 另有 test-edge-functions.sh、test-database.sh
```

后端地址和 publishable key（可公开，由行级安全保护）在 `AIEnglishApp/Services/SupabaseConfig.swift`。
绝不要把 Gemini 或 service-role 密钥写进 App。PR 必须通过三项 CI 检查；完整流程（含 Edge Function
部署）见 [`docs/engineering/CI.md`](docs/engineering/CI.md) 与 [`CLAUDE.md`](CLAUDE.md)。
