# AIEnglishApp

一款 AI native 的 iOS 英语学习 App，核心理念是 **从用户自己的生活取材来学英语**。

用户通过文字、语音、拍照或相册，把身边的场景或此刻的想法发给 AI；AI 据此生成与这个场景相关的英语内容（轻词典、句子分析、地道翻译、场景手帐等结构化卡片），用户还能就同一场景继续追问、逐步深入。生成的素材会被 AI 自动分类整理，沉淀到用户自己的素材库中，从听、说、读、写各方面（尤其是口语）帮助用户提升英语表达能力。

产品分为两个主 Tab：

- **Tab1 / Today —— 内容捕捉与生成**：负责输入 → AI 生成 → 追问深入。
- **Tab2 / Mine —— 内容组织与练习**：接收 Tab1 生成的素材，按「场景维度 + 语言素材维度（单词/句子/段落）」自动分类，并承载练习功能（Tab2 本身不生成内容）。

## 技术栈

| 层 | 技术 | 说明 |
|----|------|------|
| 前端 | Swift 5.0 + SwiftUI | 原生开发，非 UIKit/Storyboard |
| 平台 | iOS 17+ | 使用 `@Observable`、`NavigationStack` 等特性 |
| 构建 | Xcode 工程（`AIEnglishApp.xcodeproj`） | |
| 后端 | Supabase | 数据库 + Storage + Edge Functions（Deno / TypeScript） |
| AI | Google Gemini（`gemini-2.5-flash`） | 仅在 Edge Function 服务端调用，密钥不下发客户端 |

## 项目结构

```
AIEnglishApp/              # iOS 源码
├── AIEnglishAppApp.swift  #   App 入口
├── ContentView.swift      #   根视图 / Tab 容器
├── Onboarding/            #   引导页（介绍核心价值 + 询问 English Level）
├── Today/                 #   Tab1：内容捕捉与生成
├── Mine/                  #   Tab2：素材库（场景详情、词汇本）与练习
├── Models/                #   数据模型（Material / Message / AIResponse 等）
├── Services/              #   AI 调用、Supabase 客户端、相机/相册、会话上下文、埋点
├── Theme/                 #   设计 token（颜色/字体/间距，集中定义）
└── Assets.xcassets/       #   图片与颜色资源

AIEnglishAppTests/         # 单元测试
AIEnglishAppUITests/       # UI 测试
supabase/                  # 后端：Edge Functions + 数据库 migrations
docs/                      # 项目文档（PRD、架构、笔记、归档）
design-system/             # 设计规范（颜色/字体/组件规则）
assets/                    # 设计/演示素材（示例场景图等）
config/                    # 预留配置目录
CLAUDE.md                  # 面向 AI 协作的开发规范（详见文末）
```

### 后端做了什么（`supabase/`）

**Edge Functions**（`supabase/functions/`）：

- `generate` —— 核心函数。接收输入，服务端携 `GEMINI_API_KEY` 调用 Gemini，产出 5 类结构化卡片（s1/s2/s3/s4/chat），并将可提取的素材两阶段写入 `materials` 表。
- `get-materials` / `get-vocabs` —— 供 Tab2 读取场景素材 / 词汇本（按用户 `user_id` 隔离，图片按需签发临时 Storage 签名 URL）。
- `get-messages` —— 供 Tab1 读取历史消息（按时间排序、前端按日期分组）。
- `delete-material` / `restore-material` —— 素材软删除与恢复。
- `log-event` —— 埋点事件写入 `analytics_events`。

**数据库 migrations**（`supabase/migrations/`）：建立 `materials`、`messages`、`analytics_events` 等表，为 `materials` 开启行级安全（RLS）做用户隔离，并有 `image_url`、软删除等增量变更。

## 如何运行

### 1. 运行 iOS App

```bash
open AIEnglishApp.xcodeproj
```

在 Xcode 中选择模拟器或真机，直接 `Cmd + R` 运行。客户端的 Supabase 连接信息（`projectURL` 与可公开的 `anonKey`）位于 `AIEnglishApp/Services/SupabaseConfig.swift`。

> 该 `anonKey` 是 Supabase 的 publishable key，可公开，由 RLS 保护；**不要**把 Gemini 等敏感密钥写进客户端代码。

### 2. 本地/远程运行 Supabase（可选）

项目已通过 Supabase CLI 关联云端项目。常用命令：

```bash
supabase login                  # 首次登录
supabase functions deploy       # 部署所有 Edge Functions
supabase db push                # 应用 migrations 到关联的数据库
```

Edge Function 依赖的服务端环境变量（**只配在 Supabase 服务端，切勿写入仓库或客户端**）：

- `GEMINI_API_KEY` —— Gemini API 密钥
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

> 在 Supabase 后台 `Edge Functions → Secrets` 或用 `supabase secrets set` 配置这些变量。

> TODO：本地完整跑通 Supabase（`supabase start` 所需的 Docker 环境、种子数据等）尚未在仓库中固化，需要时请补充。

## 文档索引

- 产品总纲：[`docs/prd/IOS App-Language Learning 1.0.md`](docs/prd/IOS%20App-Language%20Learning%201.0.md)
- 引导页 PRD：[`docs/prd/Tab0_onboarding_PRD_v1.md`](docs/prd/Tab0_onboarding_PRD_v1.md)
- Tab1 PRD：[`docs/prd/Tab1_PRD_v1.md`](docs/prd/Tab1_PRD_v1.md) ｜ [多轮对话设计](docs/prd/Tab1_多轮对话设计_v1.md) ｜ [AI 回复卡片需求](docs/prd/Tab1_AI回复卡片需求设计_v1.md) ｜ [图片输入方案 B](docs/prd/Tab1_图片输入_方案B设计文档_v3.md)
- Tab2 PRD：[`docs/prd/Tab2_PRD_v1.md`](docs/prd/Tab2_PRD_v1.md) ｜ [数据逻辑梳理](docs/prd/Tab2_数据逻辑梳理_v1.md)
- 架构：[`docs/architecture/全局数据架构审计报告_v1.md`](docs/architecture/全局数据架构审计报告_v1.md)
- 协作笔记：[`docs/notes/AI协作手册.md`](docs/notes/AI协作手册.md)
- 归档（历史版本）：`docs/archive/`
- 设计规范：[`design-system/aienglishapp/MASTER.md`](design-system/aienglishapp/MASTER.md)

## 开发规范

面向 AI 辅助开发的完整协作规范（技术选型约束、设计 token 规则、垂直切片工作法等）详见 [`CLAUDE.md`](CLAUDE.md)，此处不再重复。
