# Topics 进度卡视觉打磨 — 设计规范

日期：2026-08-11 · 分支：`feat/card-visual-polish`

## 目标

打磨 Tab2 "Topics in progress" 进度卡的视觉，让它更贴品牌暖极简气质。共 7 项调整，
经并排渲染逐项定案。**只动视觉，不改数据 / 后端。**

## 范围

- **主要**：Topics 进度卡 —— 锁定态 `MineView.topicsCard`（约 `MineView.swift:237`）
  与解锁态 "Topics in Progress" 列表（约 `MineView.swift:599`），两者共用
  `CategoryProgressRow`（`AIEnglishApp/Mine/Components/CategoryProgressRow.swift`）
  与 `glassCard`。
- **次要**：Hero 卡 `Tab2HeroCard`（`AIEnglishApp/Mine/Components/Tab2HeroCard.swift`）
  —— #3 单位改动（`words` → `pops`）**＋** #4 暖橙薄纱去边框（与 Topics 卡统一）。
  图标不动。

**不在范围**：数据模型、后端、计数逻辑、Tab1、解锁动画。

## 七项定案

| # | 项 | 现状 | 定案 | 落点 |
|---|---|---|---|---|
| 1 | 标题→卡片间距 | 标题 `.padding(.bottom, 12)` | **24pt** | `topicsCard` / 解锁态标题 |
| 2 | 每行垂直留白 | `.padding(.vertical, 16)`（总 32） | **12pt（总 24）** | `CategoryProgressRow.expandToggle` |
| 3 | 计数单位 | 裸数字 / `N words` | **`N pops`**（1 时 `1 pop`） | `countLabel` + Hero 卡 |
| 4 | 卡片背景 | 中性暖白玻璃 + 描边 | **暖橙薄纱 · 去描边** | Topics 列表容器背景 |
| 5 | 类别图标 | 细线 SF Symbol · 32% · 无底 | **实心字形（`.fill`）· ~42% · 无底** | `categoryBadge` |
| 6 | 展开词条缩进 | `.padding(.leading, 48)` | **16pt** | `wordList` |
| 7 | 展开提示 | 尾部弱 chevron | **半轻灰胶囊** `N pops ▾`（展开旋转 180°） | 行尾组件 |

### 视觉细节

- **#4 暖橙薄纱（去边框）**：单层暖纸白底（≈`#FFF9F4`）叠一层品牌橙极淡径向柔光
  （右上角起，`brandStrong` @ ~13% → 0）；**去掉描边**；阴影加深一档托起卡片
  （约 `0 14 34 rgba(120,80,40,.13)` + `0 2 6 ….06`）。做成一个**共享 modifier**
  （如 `warmGlassCard()`），**Topics 列表容器与 Hero 卡共用**。
  **不改全局 `glassCard`**（其余调用点不受影响）。
- **#5 实心图标**：沿用 `SceneCategory.iconName`，加 `.symbolVariant(.fill)`，
  透明度约 42%，暖中性色，无底圈。
- **#7 半轻灰胶囊**：把计数 + chevron 合并成一个胶囊单元，底色为极淡暖灰
  （≈`rgba(120,80,40,.06)`，中性、不引入橙），读作一个整体。
  计数数字保留现有颜色逻辑（最接近解锁的 hot 行 = 品牌橙，其余 = 暖灰 muted）。
  chevron 展开时旋转 180°。整行仍单击原地展开。

### 交互确认（#7 附带）

用户曾提议"双击弹出"，**已否**：双击无可见提示（违反"可交互元素必须有可见反馈"硬约束）、
与 VoiceOver 双击=激活冲突、弹窗会打断多主题横向浏览。保留**单击原地展开**。

## Token 变更（全部走 token 层，禁止内联字面值）

新增 / 复用（最终名称在实现阶段按 `category-purpose-level` 规范定稿）：

- **primitive**：新增 `space24 = 24`（#1 需要，现有阶梯缺 24）。#2 复用 `space12`。
- **semantic 间距**：
  - `space-title-to-content = 24`（区标题→内容，统一散落字面值；解锁态同源）。
  - `space-listrow-vertical = 12`（列表行垂直节奏）。
  - #6 缩进复用 `paddingCard`（16）。
- **semantic 颜色**：
  - `color-surface-topiccard`（暖纸白底 ≈`#FFF9F4`）。
  - 橙柔光复用 `brandStrong`（低透明度）。
  - `color-pill-neutral-bg`（胶囊底 ≈暖灰 6%）。
- **semantic 阴影**：Topics 卡去边框后的加深阴影配方（新增或扩展现有 `Shadow.card`）。
- **字体**：本次触碰到的文本一律改走 `AppTheme.Font.*`（现组件多处直写
  `.font(.system(...))`，属既有欠账；顺手补齐编辑到的行，必要时新增
  `Font.categoryRowTitle` / `Font.popsCount` 等 token）。

## pops 口径

一个 pop = 用户捕捉到的一个可学表达（word / phrase），即当前 `category.wordCount`。
统一到进度行胶囊与 Hero 卡。复数处理：`count == 1 ? "1 pop" : "\(count) pops"`，
抽成一个共享 helper（避免两处重复）。

## 组件封装

- Topics 卡背景做成独立 modifier（如 `topicCardBackground()`），与全局 `glassCard` 分开。
- 半轻灰胶囊做成独立小组件（如 `PopsPill`），承载计数 + chevron + 旋转态。

## 测试

视觉不做 UI 自动化测试。逻辑面只锁一处：**pops 复数 helper** 的单元测试
（0 / 1 / N → `0 pops` / `1 pop` / `N pops`）。其余为纯样式，靠预览人工核对。

## Heads-up（本次不做，记录以便后续决定）

Hero 卡与"已解锁"横向轮播里的 peek 卡 `Tab2CategoryRow` 并排展示。本次 Hero 套了
暖橙薄纱去边框，而 peek 卡仍用旧 `glassCard`，并排会有轻微不一致。本次按既定范围
**不动 peek 卡**；若日后想统一，把 `warmGlassCard()` 一并套到 `Tab2CategoryRow` 即可。
