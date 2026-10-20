<p align="center">
  <img src="docs/brand/readme-banner.png" alt="Poplex — Build language from your own life. 从你自己的生活里学语言。" width="100%">
</p>

# Poplex

**从你自己的生活里学语言。** Poplex 是一款 AI native 的 iOS 语言学习 App：把身边的瞬间——
一张照片、几个词、一个念头——变成你真的能开口说出来的、带场景的表达。

> **当前阶段：** 目前支持 **中文 → 英语**。

[English](README.md)

> **源码公开（source-available），不是开源。** 代码按
> [PolyForm Noncommercial License 1.0.0](LICENSE) 发布。你可以阅读、学习、运行和修改它，
> 但只限**非商业**用途，**本协议不授予商业使用权**。「Poplex」的名称、Logo 与设计不在授权范围内，
> 详见[协议说明](#协议)与 [NOTICE](NOTICE)。

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

`docs/` 下多数文档为中文，少数文档提到未公开的内部工作文件（例如 `docs/review/`、`docs/testing/`、`docs/design-demos/` 下的内容）。建议从这里读起：

- [`docs/prd/整体架构_两个Tab与对话页_v1.md`](docs/prd/整体架构_两个Tab与对话页_v1.md) —— 产品结构（Tab1 / Tab2）
- [`docs/prd/Agent内容组织与成长系统_PRD_v2.md`](docs/prd/Agent内容组织与成长系统_PRD_v2.md) —— Tab2、词汇账本、成长层
- [`docs/engineering/CI.md`](docs/engineering/CI.md) —— PR 验证
- [`docs/architecture/AI协作手册.md`](docs/architecture/AI协作手册.md) —— 产品负责人与 AI 助手如何分工
- [`docs/brand/README.md`](docs/brand/README.md) —— 品牌资产与规则
- [`docs/design-system/`](docs/design-system/) —— 字体与组件规范（颜色以 `AIEnglishApp/Theme/Theme.swift` 为准）
- [`CLAUDE.md`](CLAUDE.md) —— 设计规则、工作方法、已拍板的取舍、当前进度

## 自己跑起来

本仓库**不指向任何真实后端**。要运行 App，你需要自己的 Supabase 项目和 Gemini API Key。

1. **新建一个 Supabase 项目**，并开启**匿名登录**（Authentication → Sign In / Providers）。
2. **应用迁移。** 把 `supabase/migrations/` 里的 SQL 按文件名顺序在你的项目上执行（可以用 Supabase CLI；先把 `supabase/config.toml.example` 复制为
   `supabase/config.toml`，CLI 才会把这个文件夹当作 Supabase 项目）。
3. **创建一个私有的 Storage 存储桶**，名字叫 `material_images`。
4. **部署 `supabase/functions/` 里的 Edge Functions** 并设置密钥。Supabase 会自动注入
   `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY`；你需要自己设置 `GEMINI_API_KEY`
   （如果使用孤儿图片对账函数，还要设置 `RECONCILE_SECRET`）。
5. **让 App 指向你的项目。** 编辑 `AIEnglishApp/Services/SupabaseConfig.swift`，替换两个占位符：
   `https://YOUR-PROJECT-REF.supabase.co` 和 `YOUR_SUPABASE_PUBLISHABLE_KEY`。
6. **用 Xcode 打开 `AIEnglishApp.xcodeproj`**，设置你自己的 Team 和 Bundle Identifier
   （工程当前是按作者的账号配置的），在 iOS 17+ 的模拟器或真机上运行。

新项目是空的。先在 Today 里添加几条内容；Library 里的话题要攒够 20 个表达才会解锁。

绝对不要把 Gemini 密钥或 service-role 密钥放进 App。

### 测试

```bash
bash scripts/ci/test-ios.sh
bash scripts/ci/test-edge-functions.sh
ALLOW_LOCAL_SUPABASE_RESET=1 bash scripts/ci/test-database.sh   # 会重置本地数据库
```

每个脚本检查什么，见 [`docs/engineering/CI.md`](docs/engineering/CI.md)。

## 协议

- **代码：** [PolyForm Noncommercial License 1.0.0](LICENSE)。个人学习、研究、业余项目，以及教育、
  公益、公共利益组织的使用，属于允许的非商业用途。本协议不授予商业使用权。
- **品牌与设计：** 「Poplex」名称、Logo、字标、App 图标和视觉设计，**保留所有权利**。
- **第三方材料**（字体、Swift 依赖库、照片）各自遵循自己的条款，见 [NOTICE](NOTICE)。

## 贡献与安全

本项目**不接受代码贡献，欢迎提 issue**，见 [CONTRIBUTING.md](CONTRIBUTING.md)。
报告安全漏洞请按 [SECURITY.md](SECURITY.md) 处理，不要公开提 issue。

## 截图

App Store 截图（iPhone，界面为英文）。

<p align="center">
  <img src="docs/screenshots/01-cover.jpg" alt="Poplex: Build your language from work & life" width="19%">
  <img src="docs/screenshots/02-ask.jpg" alt="Ask what you're curious about: word and sentence cards" width="19%">
  <img src="docs/screenshots/03-snap.jpg" alt="Snap it, type it: a photo turned into a bilingual sentence card" width="19%">
  <img src="docs/screenshots/04-words.jpg" alt="Your words, sorted by topic in the Library" width="19%">
  <img src="docs/screenshots/05-scenes.jpg" alt="Your life, sorted into scenes: topic cards in the Library" width="19%">
</p>
