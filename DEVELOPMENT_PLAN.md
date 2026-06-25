# Tab1 搭建规划：从前端骨架到 AI 对话打通

> **进度状态（更新于 2026-06-25）**：Slice 1 的端到端链路已打通 ✅
> （App 文字输入 → Supabase Edge Function `generate` → Gemini 2.5 Flash → 返回结构化 JSON 显示）。
> Supabase 项目已建、`generate` 函数已部署上线、`GEMINI_API_KEY` 已配置，实测调用返回正常。
> 待办：在模拟器中确认真机交互体验 → 补单元测试 → commit。

## Context / 背景

当前项目原本只有纯前端骨架（`ContentView` 的双 Tab + `TodayView`/`MineView` 占位页 + 只含间距的
`Theme.swift`），没有任何后端、数据层或 AI 代码。PRD 已把 Tab1 的三层布局、三种用户状态变体、
素材流转规则写得很详细。负责人是零代码背景的产品经理，需要每个技术决策都有"为什么"。

本规划的目标：按"vertical slice 优先"的方法论，把 Tab1 最核心、风险最高的一条链路
（**用户输入文字 → 安全后端 → AI 生成英文 → 界面显示**）端到端打通，再逐步横向扩展到完整 Tab1。

## 本次讨论已锁定的关键决策

1. **AI 架构 = 单次调用（方案一）**：一次 AI 调用同时完成「意图识别 + 生成英文 + 输出 Tab2 分类标签」。
   理由：成本最低、速度最快、识别与生成上下文一致不易跑偏；将来用量大了要拆成两步，只改 Edge Function，
   App 和数据库不动。意图识别要覆盖的维度：语言（中/英/其他）、是否合规、是否有意义、是否有明确场景、
   （后续）图片识别。
2. **起步模型 = Google Gemini 2.5 Flash**（输入 $0.30 / 输出 $2.50 每百万 token，看图强、英文顶级）。
   被 Edge Function 抽象，将来换模型/对比只改一行服务器配置。
3. **第一刀范围 = 纯文字 + 真实后端**：不做语音/拍照、不做三种变体、不做 Tab2、不做登录。
4. **Tab2** 后续会对生成素材按场景重新分类——所以数据结构现在就预留 `scene_tag` 等字段。

## 整体架构（一张图）

```
┌─────────────┐   POST 文字    ┌──────────────────────┐   带 Key 调用   ┌────────────┐
│  iOS App     │ ────────────→ │ Supabase Edge Function │ ────────────→ │ Gemini API │
│ (SwiftUI)    │ ←──────────── │  generate (Deno/TS)    │ ←──────────── │            │
└─────────────┘  结构化 JSON   └──────────────────────┘   英文+标签     └────────────┘
                                  ▲ Gemini Key 只存在这里的环境变量
```

## 安全红线（CLAUDE.md 强制要求）

- **Gemini API Key 只存在 Edge Function 的环境变量里**，绝不出现在 App 代码或仓库中。
- App 里只放 **Supabase 项目 URL + publishable key**——这个 key 是专门设计给客户端用的、可公开，
  由行级安全（RLS）保护，和 Gemini Key 性质完全不同。
- ⚠️ 待办：Gemini Key 曾在聊天中明文出现过，建议在 Google AI Studio 作废重新生成一个，
  并在 Supabase 后台更新 `GEMINI_API_KEY`。

---

## 第一刀（Slice 1）详细方案

### A. 后端（Supabase Edge Function）— ✅ 已完成

- Supabase 项目：`AIEnglishApp`（ref `YOUR-PROJECT-REF`，区域 eu-west-1）。
- Edge Function `generate`，目录 `supabase/functions/generate/index.ts`：
  - 接收请求体 `{ "text": "用户输入的中文或英文" }`。
  - 内置 **system prompt**（意图识别 + 生成 + 打标签的指令），要求 Gemini 返回结构化 JSON：
    ```json
    {
      "reply": "给用户看的英文表达 + 简短教学",
      "intent": { "language": "zh", "is_meaningful": true, "is_compliant": true, "has_clear_scene": true },
      "material": { "scene_tag": "work", "level": "sentence", "english": "..." }
    }
    ```
    （Slice 1 界面只用 `reply`；`intent`/`material` 字段现在就定好形状，供后续 slice 落库与 Tab2 使用，避免返工。）
  - 用环境变量 `GEMINI_API_KEY` 调 Gemini，解析其输出，原样把上面的 JSON 返回给 App。

### B. 前端（SwiftUI，沿用现有 feature 文件夹风格）— ✅ 已完成

- **数据模型** `AIEnglishApp/Models/`：`Message.swift`、`AIResponse.swift`（`Codable` 解析）。
- **网络服务** `AIEnglishApp/Services/`：`SupabaseConfig.swift`（URL + publishable key）、
  `AIService.swift`（`AIServicing` 协议 + `LiveAIService` 真后端 + `MockAIService` 假数据）。
- **状态层** `AIEnglishApp/Today/TodayViewModel.swift`：`@Observable`，持有 `messages`、`isLoading`、
  `errorMessage`；`send(text:)` 追加用户消息→调 service→追加 AI 回复 / 设置错误。
- **界面** `AIEnglishApp/Today/TodayView.swift` 三层结构：顶部标题栏 / 中部滚动时间线（自动滚到底）/
  底部输入栏；组件拆到 `Today/Components/`（`MessageRow.swift`、`InputBar.swift`）。

### C. 设计 token — ✅ 已完成

- `Theme.swift` 在原有间距 token 基础上新增颜色 token（映射系统语义色，自动适配深浅色），
  primitive + semantic 两层、按用途命名，组件只引用 semantic 层。

### D. 测试（按 CLAUDE.md：行为稳定后再补，优先单元测试）— ⬜ 待办

- 在 `AIEnglishAppTests/` 补：
  - **解析测试**：给定一段 Gemini 返回的 JSON，`AIResponse` 能正确 decode。
  - **状态机测试**：`TodayViewModel.send` 成功/失败两种情况下 `messages`、`isLoading`、`errorMessage`
    变化符合预期（注入 `MockAIService`）。
- 测试通过后把结果书面汇报给负责人，确认 OK 再进下一刀。

---

## 后续 slice 路线图（概要，先不展开实现）

- **Slice 2 — 落库 + Tab2 可见**：接 Supabase 数据库 + 匿名登录，实现"素材生成后立即在 Tab2 可见（待整理）"。
- **Slice 3 — 三种用户状态变体 A/B/C + 凌晨 4:00 日界**：日期分栏线、欢迎语、破冰气泡、状态机。
- **Slice 4 — 追问（多轮对话）**：把对话历史一起发给 Edge Function，支持"先给答案再追问"。
- **Slice 5 — 语音输入**。
- **Slice 6 — 拍照/相册（多模态）+ 引导页预存卡片**：用上 Gemini 的看图能力。

## 常用命令备忘（需开启 Clash 代理）

```bash
# 所有连 Supabase 的命令前都要带代理前缀：
export HTTPS_PROXY=http://127.0.0.1:7897 ALL_PROXY=socks5://127.0.0.1:7897

# 重新部署 generate 函数（改了 index.ts 或 prompt 后）：
supabase functions deploy generate --project-ref YOUR-PROJECT-REF

# 查看已部署函数 / secrets：
supabase functions list --project-ref YOUR-PROJECT-REF
supabase secrets list --project-ref YOUR-PROJECT-REF
```
