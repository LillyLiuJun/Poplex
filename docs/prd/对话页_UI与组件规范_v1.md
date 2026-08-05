# 对话页 · UI 与组件规范 v1

> 版本：v1 · 2026-07-31
> **定位**：把 `Tab2设计方案_v2 §七之二` 定下的呈现规则，落成**可直接建文件的组件清单 + token 映射**。
> **上位**：`对话页与成长层_需求设计_v1.md`（做什么）、`对话页_接口契约_v1.md`（数据从哪来）、`Tab2设计方案_v2 §七之二`（呈现决定）。
> **硬约束来源**：`CLAUDE.md` 的「Code & Design Hard Constraints」+「Design Token Rules」。本文不重复条文，只写**这个页面怎么遵守**。

---

## 〇、一条判据，贯穿全文

> **屏幕存在的目的是让人开口，不是让人读。**（`Tab2_v2 §七之二 A`）

每加一个元素问一句：**它降低了开口门槛，还是替代了开口？** 替代的，删掉或收起。

这条在组件设计上有一个具体推论：**这一页的视觉重心必须是麦克风，不是对话流。** 对话流是背景，麦克风是主角。如果做完之后看起来像微信聊天界面，就是做错了——微信的重心在消息，这一页的重心在"该我说了"。

---

## 一、文件结构

```
AIEnglishApp/Conversation/
├── ConversationView.swift              页面容器 + 状态机
├── ConversationViewModel.swift         @Observable，会话状态与网络
├── ConversationSummaryView.swift       总结卡（独立页，见 §5）
└── Components/
    ├── ConversationTopBar.swift        话题名 + 退出
    ├── DialogueLineRow.swift           一行对话（AI / 用户转写）
    ├── MicButton.swift                 麦克风（四态）
    ├── PreparingIndicator.swift        开场生成中的呼吸态
    ├── SuggestionsBar.swift            实时推荐（默认收起）
    ├── NativeFallbackButton.swift      "Say it in Chinese"
    ├── NativeFallbackSheet.swift       译文 + 音标 + 提示
    ├── TranslationSheet.swift          点 AI 那句 → 整句母语译文
    ├── TopicChipsRow.swift             收窄用的兜底 chips
    ├── MicPermissionView.swift         权限未授予 / 被拒
    └── SummaryBlock.swift              总结卡的三个块共用外壳
```

**为什么单独开 `Conversation/` 目录而不是塞进 `Mine/`**：对话页虽然是 Tab2 的子页，但它的组件（麦克风、转写行、音标弹窗）和 Tab2 的组件（分类卡、词条行）零复用。放一起会让 `Mine/Components/` 变成杂物间。

---

## 二、页面状态机

`CLAUDE.md` 要求每屏定义 loading / empty / error（含权限拒绝）。对话页的五态：

| 状态 | 触发 | 显示 |
|---|---|---|
| `permissionNeeded` | 麦克风或语音识别权限未授予 / 被拒 | `MicPermissionView` |
| `preparing` | 已进页，`start` 请求在路上 | 话题名 + `PreparingIndicator` |
| `active` | 开场白已到 | 三区版面（§3） |
| `failed` | 模型/网络失败 | 保留对话流 + toast + 可重试 |
| `ended` | 已收尾 | 跳 `ConversationSummaryView` |

**两条容易做错的：**

1. **`failed` 不是一个空白屏。** 它必须**保留已有的对话流**——用户说过的话不能因为一次网络失败就从屏幕上消失（`接口契约 §5.2`）。错误用 toast 表达，不用整屏。
2. **`empty` 态不存在。** 对话页永远有内容（至少有开场白）。**不要为它设计空态**——那会变成一个没人看得到的分支。

---

## 三、`active` 版面：三区

```
┌─────────────────────────────┐
│  ←   Mornings at the office │  ConversationTopBar（薄，44pt）
├─────────────────────────────┤
│                             │
│  AI 的话（正常字重）           │  DialogueLineRow ×N
│    你的话（小字、灰）           │  ScrollView，自动滚到底
│                             │
├─────────────────────────────┤
│  3 words you could use  ⌄   │  SuggestionsBar（默认收起）
│                             │
│      [ 🎤 ]   Say it in     │  MicButton（主角）
│               Chinese       │  NativeFallbackButton
└─────────────────────────────┘
```

### 3.1 区域配比

| 区 | 高度 | 说明 |
|---|---|---|
| 顶栏 | `AppTheme.Size.barControl`（44） | 只有话题名 + 退出。**别的都不要**——不放设置、不放计时、不放轮次 |
| 对话流 | 剩余空间 | 可滚动，新内容自动滚到底 |
| 底部 | 约 140–160 | **麦克风占据视觉重心** |

> **不显示时长和轮次**（`Tab2_v2 §七之二 F-2` 的待定项，本文拍板：**不显示**）。
> 理由：`PRD §6.2.7` 已定不设最低时长。屏幕上出现任何计时器，用户都会把它读成"我应该聊够多久"——**一个明确说了不考核的东西，不要给它一个仪表盘。**

### 3.2 `DialogueLineRow`：两种角色，视觉必须不对等

| | AI | 用户转写 |
|---|---|---|
| 字体 | `AppTheme.Font.englishPrimary` | `AppTheme.Font.englishBody` |
| 颜色 | `AppTheme.Color.textPrimary` | `AppTheme.Color.textMuted` |
| 对齐 | 左 | 左，**缩进** `AppTheme.Space.paddingPage` |
| 可点 | ✅ → `TranslationSheet` | ❌ |

**不做气泡。** 两边都是纯文本 + 缩进区分。理由：气泡是聊天软件的语言，它暗示"这是一场消息往来"；而这一页是一场**对话**，文字只是它的影子。去掉气泡，屏幕的分量自然落到麦克风上。

**转写为什么要弱化**（`Tab2_v2 D-1`）：转写必须存在——它是 `sample_sentence` 的证据，也让用户确认 ASR 没听岔。但这是口语产品，**用户不该在屏幕上读自己刚说过的话**。弱化是为了让视线离开屏幕。

**逐字上屏**：用户说话时转写实时增长（系统 Speech 框架支持）。**这一行在说话过程中用 `AppTheme.Color.textSecondary`，结束后降到 `textMuted`**——说的时候要看得见（确认被听到），说完就该淡出注意力。

### 3.3 `MicButton`：四态

| 态 | 视觉 | 可点 |
|---|---|---|
| `idle` | 实心圆 `brandStrong` + 白色麦克风图标 | ✅ 点了开始听 |
| `listening` | 外圈脉冲 + 音量响应 | ✅ 点了结束这轮 |
| `aiSpeaking` | 降到 `textFaint`，图标换成波形 | ❌ 但**可点打断** |
| `disabled` | `textFaint`，无动效 | ❌ 网络失败等 |

**`aiSpeaking` 时允许打断**（点一下让 AI 闭嘴、立刻开麦）。这条是给"我已经知道要说什么了"的用户的——**不让他等 AI 把话说完，是尊重他的表达欲**。技术上就是停掉 TTS。

**尺寸：直径 72。** 现有 `AppTheme.Size` 里没有这一档（只有 `barControl` = 44），**需要新增 token**，见 §7。

### 3.4 `SuggestionsBar`：默认收起

收起态一行：`3 words you could use ⌄`，`AppTheme.Font.sectionLabel` + `textMuted`。

展开后每个词一行：词 + 一句极短的提示（`hint`）。**不给释义、不给例句**——那会变成阅读材料。

*为什么默认收起*（`Tab2_v2 D-4`）：**词一直摊在屏幕上，用户会读，不会回忆——而回忆那一下才是学习发生的地方。** 收起态保留"我有后备"的安全感，展开是主动求助。

> **A/B 待做**：`Tab2_v2 D-4` 建议在 Slice 3 测"默认展开 vs 默认收起"，看 `spoken_count` 和 `native_fallback_used` 的差异。**组件要支持默认态由外部传入**，别把 `false` 写死在里面。

### 3.5 `NativeFallbackButton`：常驻，且不带羞耻感

文案 `Say it in Chinese`（**不是** `I don't know` / `Help` / `Stuck?`）。

样式：文字按钮，`AppTheme.Font.buddy` + `AppTheme.Color.textSecondary`。**不做成醒目的求助按钮**，也不藏起来——**它应该像换挡一样自然**。

*为什么这么在意一个按钮的文案*（`Tab2_v2 D-2`）：母语兜底产出 `is_known_gap`，是**全产品最高价值的语料**（高动机 + 高缺口）。把它做成"求助"会让用户回避使用，**等于亲手关掉最好的数据源**。

### 3.6 `NativeFallbackSheet`

三样，然后闭嘴：

```
The projector wasn't working, so we started ten minutes late.
projector  /prəˈdʒektər/
Try saying it.
```

- 译文 `Font.englishPrimary`
- 音标 `Font.phonetic`（等宽，已有 token）
- 提示 `Font.buddy` + `textMuted`

**不比对、不判念得对不对、不给"很好"。** 用户念完、说了变体、甚至说岔了，都推进（`Tab2_v2 D-3`）。

**Sheet 不自动关闭。** 用户可能要念两遍。他自己划走，或者说出目标语言后自动收起。

---

## 四、⚠️ 组件层的硬约束：纠错 UI 不存在

`Tab2_v2 D-5` 要求"屏幕上永远不出现纠错标记"，并且明确说**这必须落成组件层面的硬约束**。落法：

> **本页所有组件的入参里，没有任何一个字段承载"错误 / 建议 / 纠正"。**

- `DialogueLineRow` 只接受 `text` 和 `role`，**没有 `issues`、没有 `isCorrect`、没有 `suggestion`**。
- `correctness` 字段**根本不下发到客户端**（`接口契约 §2.2`）——数据到不了前端，前端就不可能渲染它。

**这两道一起做，才是真的硬。** 只在文档里写"不要显示纠错"是软的——半年后有人为了"帮用户一下"加个小提示，评审时也看不出它违反了什么。**而入参里没有这个字段，他会先撞到编译错误。**

同理，**这一页不出现红色**。`AppTheme.Color.danger` 在本页的正确引用次数是 **0 次**。审代码时可以直接 grep。

---

## 五、总结卡：独立页，方便日后改 sheet

`ConversationSummaryView` **做成一个完全独立的 View**，不嵌在 `ConversationView` 里。

*为什么*（`需求设计 v1 §6.4`）：整页还是 sheet 你要上机体验后再定。**做成独立 View，改形态只是换一层 presentation modifier，不用重写内容。**

### 5.1 三块 + 一块

| 块 | 组件 | 空了 |
|---|---|---|
| 用出了哪些你的词 | `SummaryBlock` + 词条行 | 不渲染 |
| 待提高（≤2 条） | `SummaryBlock` | 不渲染 |
| 进步 | `SummaryBlock` | 不渲染 |
| **新素材确认** | `SummaryBlock` + 勾选行 | 不渲染 |

**"有才出现"必须是组件行为，不是页面逻辑。** `SummaryBlock` 自己判断内容为空就返回 `EmptyView`——这样调用方不需要写四个 `if`，也不会漏写一个导致空标题挂在那里。

### 5.2 文案（`需求设计 v1 §6.2`）

| 块 | 用 | 不用 |
|---|---|---|
| 用出的词 | `You used these today` | ~~`5/12 words used`~~ |
| 待提高 | `You could also say…` | ~~`Mistakes`~~ / ~~`Corrections`~~ |
| 进步 | `First time you've said this out loud` | ~~`+1 progress`~~ |
| 新素材 | `Keep any of these?` | ~~`Save to your library!`~~ |

**新素材默认全不勾。** "素材是用户的"，要他主动认领（`PRD §6.3.4`：按一下确认既是筛选也是确权）。

### 5.3 退出后回 Tab2

`需求设计 v1 §6.6`：**Tab2 首屏必须看得出变化**，否则用户感觉不到刚才十分钟发生过。

实现上两件事：
1. 退出时**强制刷新**，不能走 `Tab2HomeViewModel.loadIfStale()` 的 30 秒判定——那会导致刚练完回去什么都没变。
2. 刚练过的分类卡显示一行 `Talked about this today`。

---

## 六、动效

现有 `AppTheme.Motion` 只有两条（`tabSelection` / `topBarCompact`），对话页需要三条新的，**都要走 token 层，不许在组件里写 `.spring(...)` 字面量**。

| 用途 | 建议 | 说明 |
|---|---|---|
| 卡片展开成对话页 | `matchedGeometryEffect` + 一条新 Motion token | `Tab2_v2 拍板 11c`：让人觉得"这张卡打开了"，不是"跳到了别处" |
| 麦克风 listening 脉冲 | 循环动效 | 幅度要小。它是"我在听"的指示，不是视觉表演 |
| `PreparingIndicator` 呼吸 | 同上 | **不要转圈菊花**——那是技术味的（`需求设计 v1 §4.3`） |

**必须支持"减弱动态"**（`Reduce Motion`）：麦克风脉冲和呼吸在开启该系统设置时降级为静态或极轻的透明度变化。这不是可选项——持续脉冲对前庭敏感的用户是真实困扰。

---

## 七、Token：需要新增的（**待你确认后再动 Theme.swift**）

> `CLAUDE.md` 明确：token 改动要先列出问题和方案，**不许自动编辑**。以下是提案。

| 提案 token | 值 | 为什么现有的不够 |
|---|---|---|
| `Size.micButton` | 72 | 现有只有 `barControl`(44)/`iconBadge`(44)。麦克风是这一页的主角，44 撑不起视觉重心 |
| `Motion.pageExpand` | spring，待调 | 卡片展开转场，现有两条都是别的语义 |
| `Motion.breathing` | 循环 ease-in-out | listening 脉冲 + preparing 呼吸共用 |

**复用现有、不新增的**（`Design Token Rules` 第 2 条：复用优先）：

| 需求 | 用现有 |
|---|---|
| AI 说的话 | `Font.englishPrimary` + `Color.textPrimary` |
| 用户转写 | `Font.englishBody` + `Color.textMuted` |
| 说话中的转写 | `Color.textSecondary` |
| 音标 | `Font.phonetic`（等宽，已有） |
| 麦克风实心底 | `Color.brandStrong` |
| 推荐区标题 | `Font.sectionLabel` + `Color.textMuted` |
| 兜底按钮 | `Font.buddy` + `Color.textSecondary` |
| 页面底 / 卡片底 | `Color.pageBg` / `Color.cardBg` |
| 分割线 | `Color.divider` |

> **注意 `Font` 的现状**：现有 token 全部基于系统 TextStyle（如 `.system(.body, weight: .medium)`），Dynamic Type 是保住的。**新组件继续走这套，不许出现 `.system(size:)` 字面量**（`CLAUDE.md` 硬约束；`Image(systemName:)` 的字号除外）。

---

## 八、无障碍

| 项 | 要求 |
|---|---|
| Dynamic Type | 走 Font token 即自动支持。**但要实测特大字号下三区版面不塌**——底部区域是固定高度，字号放大后容易挤掉对话流 |
| 点击热区 | 麦克风 72 足够；`SuggestionsBar` 收起行、兜底按钮**热区不得小于 44** |
| VoiceOver | 麦克风按钮四态要有不同的 label（"Start speaking" / "Stop" / "AI is speaking, tap to interrupt"）。**转写行要能被读到**——对视障用户它不是可弱化的装饰 |
| Reduce Motion | 见 §6 |

> **这一页的无障碍有个特殊性**：它是语音产品，**目标用户里"看不清"和"不方便看"的比例本来就高**（有人是边走边练的）。所以 VoiceOver 不是合规动作，是真实场景。

---

## 九、实现顺序

| # | 做什么 | 能验证什么 |
|---|---|---|
| 1 | `ConversationView` 骨架 + 五态状态机（内容全用假数据） | 状态切换对不对，不依赖后端 |
| 2 | `MicPermissionView` + 两个权限的请求时机 | 拒绝后能不能引导到设置 |
| 3 | `DialogueLineRow` + 对话流滚动 | 长对话滚动、自动到底 |
| 4 | `MicButton` 四态 + ASR 接入 | 逐字转写、打断 |
| 5 | 接后端（`start` / `turn`） | 端到端第一次真对话 |
| 6 | `NativeFallbackButton` + `Sheet` | 兜底不推进剧情 |
| 7 | `SuggestionsBar` + `TranslationSheet` | — |
| 8 | `ConversationSummaryView` + 退出刷新 Tab2 | 闭环 |

**第 1 步用假数据先把状态机跑通**，是因为这一页有五个状态、三个是错误相关的。**如果等后端好了再一起调，错误态多半会被草草带过**——而 `CLAUDE.md` 明确写了这些状态是核心不是边缘。

---

## 十、待定

| # | 问题 | 建议 |
|---|---|---|
| 1 | `Size.micButton` = 72 是拍的 | 上机看，可能要 64 或 80。**先做出来再调，别在纸上争** |
| 2 | 打断 AI 说话要不要给触觉反馈 | 倾向给一个轻的（`.impact(.light)`）。`CLAUDE.md` 要求可点元素至少有视觉或触觉反馈 |
| 3 | 对话流要不要显示时间戳 | **倾向不要**——同 §3.1 不显示时长的理由 |
| 4 | 总结卡整页 vs sheet | 上机体验后定（`需求设计 v1 §6.4`） |

---

*本文档是对话页 UI 的唯一来源。新增组件必须落在 §1 的目录结构里；新增 token 必须先回到 §7 登记并获确认。*
