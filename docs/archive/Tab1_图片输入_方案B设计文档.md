# Tab1 图片输入（方案B）设计文档

> 整理于 2026-07-04

---

## 一、方案B 是什么

用户可以通过拍照或相册选图的方式向 Tab1 发送内容。图片发送时，用户可以同时填写文字说明，也可以不填（仅发图片）。AI 同时接收图片和文字（如有），生成对应的英文学习卡片。

---

## 二、现有输入链路（文字输入，已上线）

### 2.1 前端链路

```
用户在 InputBar 打字
  ↓
文字非空 → 发送按钮激活
  ↓
点击发送 → TodayViewModel.send(_ text: String)
  ↓
消息流追加一条用户气泡（文字，右对齐）
  ↓
调用 LiveAIService.generate(text: String)
  → POST /functions/v1/generate  body: { "text": "用户输入" }
  ↓
等待返回 → 消息流追加一条 AI 卡片
```

**涉及文件：**

| 文件 | 职责 |
|------|------|
| `Today/Components/InputBar.swift` | 文字输入框 + 发送按钮 |
| `Today/TodayViewModel.swift` | 消息列表状态管理 + 调用 AIService |
| `Services/AIService.swift` | HTTP 请求封装（目前有两个独立方法：text / image） |
| `Models/Message.swift` | TimelineEntry 数据结构（userBubble / aiCard / aiError） |

### 2.2 AI 生成链路（后端 Edge Function）

```
Edge Function (generate/index.ts) 收到请求
  ↓
解析 body：{ text?, image_base64?, mime_type? }
  ↓
构建发给 Gemini 的内容：
  有 image_base64 → 图片 + 固定描述 prompt（用户文字被忽略）
  只有 text      → 用户原始文字
  ↓
调用 Gemini 2.5 Flash（带 SYSTEM_PROMPT）
  SYSTEM_PROMPT 定义了 5 种卡片分类规则（s1/s2/s3/s4/chat）
  ↓
解析 AI 返回的 JSON → { card_type, card_content, extracted_concept }
  ↓
并行写 DB：
  messages 表写两行（user + assistant）
  saveMaterial() → 提取素材写入 materials 表
  ↓
返回 { card_type, card_content, extracted_concept } 给 App
```

### 2.3 现有 AIService 接口

```swift
// 两个独立方法，互不关联

func generate(text: String) async throws -> AIEnvelope
// → body: { "text": "..." }

func generate(image: UIImage) async throws -> AIEnvelope
// → body: { "image_base64": "...", "mime_type": "image/jpeg" }
// 没有文字参数
```

---

## 三、方案B 涉及的改动范围

### 3.1 后端 Edge Function

**现有问题：** 当请求中包含 `image_base64` 时，`text` 字段被完全忽略，AI 收到的是硬编码的固定 prompt，而不是用户的文字说明。需要修改为：当图片和文字同时存在时，两者都传给 AI。

**需要改动的逻辑：**
- 图片 + 文字同时存在时的 prompt 拼接方式
- `messages` 表 `input_type` 字段：当前只有 `"text"` / `"image"`，混合发送时如何记录

### 3.2 前端 AIService

当前是两个独立方法，需要合并为一个支持混合输入的接口：
```swift
generate(text: String?, image: UIImage?) async throws -> AIEnvelope
```

### 3.3 前端 TodayViewModel

- 新增图片状态（当前 ViewModel 里没有 image 相关状态）
- `send()` 方法需要支持携带图片参数

### 3.4 前端 InputBar

- 新增拍照按钮和相册按钮
- 用户选图后，输入框区域显示图片缩略图 + 删除（×）按钮
- 图片挂载后发送按钮激活（不需要填文字也可发送）

### 3.5 前端 TimelineEntry（用户气泡）

当前用户气泡只支持文字：
```swift
case userBubble(text: String)
```
需要支持图片（以及图片+文字的混合态）。

### 3.6 客户端图片大小校验

图片超过 10MB 时，显示 Toast 提示，不挂载图片。在客户端（选图回调处）处理，不依赖后端。

### 3.7 权限处理

| 权限 | 触发时机 |
|------|---------|
| 相机权限 | 首次点击拍照按钮 |
| 相册权限 | 首次点击相册按钮 |

Onboarding 流程中已有相机权限相关代码（`CameraPickerView.swift`），Tab1 可复用。

---

## 四、待决策事项

### D1：输入栏按钮布局

加入拍照 + 相册两个按钮后，输入栏元素变为：拍照、相册、文字框、发送（后续还有语音按钮待加入）。

- 方式A：所有按钮平铺在输入栏内
- 方式B：用一个「+」按钮收起拍照/相册，点击后展开选择

### D2：用户消息气泡样式

发送图片（含图片+文字）后，聊天流中用户侧如何显示？

- 方式A：图片气泡和文字气泡各自独立，分两行显示
- 方式B：图片和文字合并在同一个气泡内（图上文下）

### D3：仅发送图片时 AI 的卡片行为

用户不填文字、仅发图片时，AI 没有用户的语言意图，只能根据图片内容生成内容。当前逻辑下大概率返回 s4（场景手帐）。

- 是否接受这个默认行为？
- 还是需要为纯图片输入设计专门的 prompt 或卡片类型？

---

*方案C（圈选区域）已记录，决定推迟到 v2*
