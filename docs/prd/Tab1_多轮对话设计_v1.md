# 多轮对话设计文档 v1.1

> 本文档描述 Tab1 文字输入的多轮对话上下文机制，包括 Session 生命周期、消息链结构、iOS 端实现和 Edge Function 注入逻辑。

---

## 一、设计决策

**采用 Session 分界 + 客户端内联上下文方案：**
- App 打开到退到后台算一个 Session，Session 内自动携带上一轮对话内容作为上下文
- 上下文直接由客户端打包在请求里发给 Edge Function，服务端无需查 DB
- Session 结束后（后台超过 30 分钟 / App 被杀死）重置上下文，每次打开是全新开始

**上下文携带方式：标准 messages 数组，raw JSON 直接传**

客户端将上一轮的 user_content 和 card_content 存在内存里，发下一条消息时构造标准 messages 数组：

```
messages = [
  { role: "system",    content: SYSTEM_PROMPT },
  { role: "user",      content: "overtime" },               ← 上一轮用户输入
  { role: "assistant", content: "{...card_content JSON...}" }, ← 上一轮 AI 回复（raw JSON）
  { role: "user",      content: "帮我造个更复杂的句子" }    ← 当前输入
]
```

经测试验证：AI 能直接理解 card_content 的 JSON 结构，无需转为自然语言摘要。Edge Function 不做任何转换，直接把 messages 数组传给 AI API。

**未采用的方案及原因：**
- 跨天自动带上下文：话题不连续，跨天污染比无上下文更差
- 每次显式点按钮追问：破坏 scene_trigger 的自然性
- 服务端通过 trigger_message_id 查询上下文：多一次 DB 查询，且客户端已有数据，无必要
- card_type 分支摘要转换：测试证明不必要，raw JSON 效果等同且代码更简单

---

## 二、Session 生命周期

```
APP LAUNCH           FOREGROUND            BACKGROUND            RE-ACTIVE
App 冷启动     →    用户交互、发消息    →   用户按 Home / 切 App   →  用户返回 App
currentContext       每次 AI 回复后           记录 backgroundedAt       判断超时↓
= null               更新 currentContext      时间戳
```

**返回 App 时的判断逻辑：**

| 后台时长 | 判断 | 行为 |
|----------|------|------|
| < 30 分钟 | 同一 Session | `currentContext` 保留，继续上下文 |
| > 30 分钟 | 新 Session | `currentContext = null`，全新开始 |
| App 被系统杀死 | 内存清空 | 自动全新开始，无需额外处理 |

> **30 分钟阈值来源：** 行业惯例（Google Analytics 默认值），代表"用户去做了别的事情"。可根据上线后埋点数据调整，MVP 先用 30 分钟。

---

## 三、消息链结构

### 3.1 数据库字段

`messages` 表与多轮对话相关的字段只保留一个：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `parent_message_id` | uuid | user 消息专用，记录本条消息追问的是哪条 AI 消息（null = 全新话题）。**仅用于埋点分析**，不用于上下文注入。 |

上下文注入通过请求体中的 `context` 字段传递，Edge Function 无需查 DB。

### 3.2 Session 内消息链走一遍

```
currentContext = null（Session 开始）

① 用户发 "overtime"
   messages 数组：
     [system, { user: "overtime" }]
   AI 回复 → s1 卡片（card_content JSON）
   currentContext = { userContent: "overtime", cardContent: {word:"overtime",...} }

② 用户发 "帮我造个更长的句子"（直接打字，无需任何按钮）
   messages 数组：
     [system,
      { user: "overtime" },
      { assistant: '{"card_type":"s1","word":"overtime",...}' },  ← raw JSON
      { user: "帮我造个更长的句子" }]
   AI 理解上下文是 overtime → 回复 → chat 卡片
   currentContext = { userContent: "帮我造个句", cardContent: {card_type:"chat","text":"..."} }

③ 用户发 "摸鱼"（换话题）
   messages 数组：
     [system,
      { user: "帮我造个句" },
      { assistant: '{"card_type":"chat","text":"..."}' },
      { user: "摸鱼" }]
   AI 自判：摸鱼与造句无关 → 忽略上下文 → s3 卡片
   currentContext = { userContent: "摸鱼", cardContent: {card_type:"s3",...} }
```

**显式追问旧卡片（跨 Session）：**

```
用户点某张历史卡片的追问按钮
→ 客户端从 SwiftUI View 读取该卡片的 card_content
→ 临时覆盖 currentContext = { userContent: 原始输入, cardContent: 该卡片 JSON }
→ 发送时 messages 数组包含这张旧卡片的内容
→ AI 回复后 currentContext 自动更新为新一轮
```

---

## 四、iOS 端实现

### 4.1 数据结构

```swift
struct ContextTurn {
    let userContent: String         // 上一轮用户说了什么
    let cardContent: [String: Any]  // 上一轮卡片的完整数据（直接 JSON 序列化后传给 AI）
}
```

### 4.2 ConversationSession 类

```swift
class ConversationSession: ObservableObject {
    var currentContext: ContextTurn? = nil
    private var backgroundedAt: Date? = nil

    // App 进后台时调用
    func didEnterBackground() {
        backgroundedAt = Date()
    }

    // App 回前台时调用
    func didBecomeActive() {
        guard let t = backgroundedAt else { return }
        if Date().timeIntervalSince(t) > 30 * 60 {
            currentContext = nil  // 超过 30 分钟，新 Session
        }
        backgroundedAt = nil
    }

    // 每次 AI 回复完整返回后调用
    func onAIResponseReceived(userContent: String, cardContent: [String: Any]) {
        currentContext = ContextTurn(
            userContent: userContent,
            cardContent: cardContent
        )
    }

    // 用户点击旧卡片的追问按钮时调用
    func overrideContext(with turn: ContextTurn) {
        currentContext = turn
        // 发送完成后由 onAIResponseReceived 自动覆盖为新的 context
    }
}
```

### 4.3 发送消息时

```swift
func sendMessage(text: String) {
    let request = GenerateContentRequest(
        userContent: text,
        context: session.currentContext  // null = 新话题，有值 = 带上下文
    )
    // 发送请求...
}
```

### 4.4 生命周期注册（SwiftUI）

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    session.didEnterBackground()
}
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
    session.didBecomeActive()
}
```

---

## 五、Edge Function 上下文注入逻辑

请求结构：

```json
{
  "user_content": "帮我造个句",
  "context": {
    "user": "overtime",
    "card_content": { "card_type": "s1", "word": "overtime", "phonetic": "/ˈoʊvərtaɪm/", ... }
  }
}
```

Edge Function 构造标准 messages 数组：

```python
def build_messages(user_content: str, context: dict | None) -> list:
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    if context:
        # 上一轮：user + assistant（raw JSON，无需转换）
        messages.append({"role": "user",      "content": context["user"]})
        messages.append({"role": "assistant", "content": json.dumps(context["card_content"], ensure_ascii=False)})

    # 当前输入
    messages.append({"role": "user", "content": user_content})

    return messages

# 调用 AI
response = openai.chat.completions.create(
    model="gpt-4o",
    messages=build_messages(user_content, context)
)
```

- **context 为 null**：messages 只有 system + 当前 user，按新话题正常分类生成
- **context 有值**：messages 包含完整的上一轮对话，AI 自判是否使用上下文
- **不查 DB，不做摘要转换**，Edge Function 逻辑极简

---

## 六、关键注意点

**AI 必须自判是否使用上下文。**
System Prompt 里明确写：如果当前输入与上下文无关，忽略上下文按新话题处理。这是防止同一 Session 内换话题时出现污染的安全阀。

**currentContext 在 AI 流式返回期间暂不更新。**
等完整 card_content 返回后再调用 `onAIResponseReceived`。输入框在 AI 生成期间禁用，竞态实际上不会触发。

**只带 1 轮历史。**
每次只注入直接上一轮（1 问 + 1 答），不递归追溯。完整多轮历史（3-5 轮）留 v2。

---

## 七、与 PRD 的关系

本文档是 `Page1_PRD_v1.md` 第五章 5.2 节"多轮对话设计"的详细展开。

`messages` 表中 `parent_message_id` 保留（用于埋点），`trigger_message_id` 字段已移除。`Page1_PRD_v1.md` 中对应字段说明需同步更新。

---

*文档版本：v1.2 | 更新日期：2026-07-05 | 主要变更：经测试验证改为标准 messages 数组 + raw JSON 方案，删除 card_type 分支摘要逻辑，ContextTurn 移除 cardType 字段*
