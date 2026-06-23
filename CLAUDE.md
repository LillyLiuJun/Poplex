# CLAUDE.md — AIEnglishApp 项目说明书

> 这份文件是给任何 Claude 实例(网页版、桌面版、Claude Code)看的项目上下文。
> 任何时候打开这个项目工作,请先读完这份文件再动手。

## 项目是什么

一个 AI native 的英语学习 App,定位:从用户的生活场景取材(拍照/语音/文字),AI 生成场景描述,帮用户从听说读写全方位提升英语(尤其口语)。目标平台:iOS,上线 App Store。

产品架构:
- 引导页(核心价值 + 个性化)
- Tab1:内容捕捉与生成(用户输入文字/图片+文字 → AI 生成场景化英语内容)
- Tab2:内容组织与练习(MVP 阶段两者合并在一个 Tab)

## 当前阶段

阶段 1:环境搭建 + 空壳项目跑通。目标是让一个最简单的 App 先跑在开发者自己的 iPhone 上,验证技术链路,再逐步迭代功能。**不要在这个阶段写复杂功能或做视觉打磨。**

## 技术栈(已确定,不要更改)

- **前端**:SwiftUI(原生,不是 UIKit/Storyboard)
- **目标系统版本**:iOS 17+
- **后端/数据库**:Supabase(免费额度覆盖 MVP)
- **AI 内容生成服务商**:待定,正在测试成本,暂不要硬编码绑定某一家
- **AI 调用架构**:手机端绝不直连 AI 服务商。所有 AI 请求必须经过 Supabase Edge Functions(或同类后端中间层)转发。API Key 只能存在于服务器端环境变量里,绝不能出现在客户端代码中。

## 强制代码规范

```
- Target iOS 17+. Always use NavigationStack. Do not use deprecated NavigationView.
- Use the @Observable macro (iOS 17+) for state management.
  Avoid @StateObject/@ObservedObject unless there is a specific reason.
- Use standard system components and default styling.
  Do not hand-write custom visual effects to mimic older iOS appearances —
  this ensures the app automatically inherits the latest system visual language
  (e.g. iOS 26 Liquid Glass) without code changes.
- Separate structure/logic layer from style layer:
  centralize colors, fonts, spacing as design tokens/variables rather than
  hardcoding them inline in each component, so the visual style can be
  swapped later without touching structural code.
- Never embed API keys directly in app code. All AI API calls must be routed
  through the backend (Supabase Edge Functions or equivalent) — the mobile
  client never holds or sends the raw API key.
```

## Design Token Rules

1. Name tokens by PURPOSE, not appearance, using a consistent format
   `category-purpose-level` (e.g. color-text-primary, space-padding-card).
   Never use arbitrary names like color1, myGray, bg2.

2. Reuse before creating. Before introducing a value, check existing tokens
   and reuse if one fits. Never define the same value under multiple names.

3. Define ALL tokens centrally in one theme/tokens file — never inline in
   components or pages. Use two layers: primitive (raw values) and semantic
   (purpose-named, referencing primitives). Components reference only the
   semantic layer. This lets you re-skin by editing primitives and fine-tune
   by editing semantics.

## Token Hygiene
Every 2-3 vertical slices, audit all tokens: check naming format, find
duplicate values under different names, check whether anything should be
merged or split, and find any tokens defined inline instead of centrally.
List issues and propose fixes — do NOT auto-edit tokens without confirmation.

## 开发方法论(必须遵守)

- **Vertical slice 优先**:任何新功能都先做一条最窄的完整链路(前端 + 后端都打通),验证能跑之后才横向扩展,不要先搭整个 UI 框架再填功能。
- **结构层与风格层分离**:颜色、字体、间距等风格信息要集中定义为设计变量(design tokens),不要散落硬编码在各个组件里。
- **测试同步进行**:每写一个功能 slice,同步写基础测试,不要把测试留到最后一次性补。

## 项目负责人背景(供 Claude 调整解释方式时参考)

营销背景的产品经理,代码背景为 0。需要每个技术决策都解释"为什么",不要只给结论。重视:视觉体验、交互体验、内容价值(MVP 阶段从简)、软件测试质量、API 安全。学习目标包括:Claude Code 工作流(CLAUDE.md / MCP / skill / subagent)、AI 辅助前端设计 skill 的实战应用。

## 当前已知风险点(开发时主动规避)

1. API Key 泄露 → 见上方"AI 调用架构"
2. AI 写出过时 SwiftUI 语法(如 NavigationView)→ 见上方"强制代码规范"
3. 前端结构和风格强耦合 → 见上方"结构层与风格层分离"
4. 一次性做完整功能导致代码混乱 → 见上方"Vertical slice 优先"
