# Tab1 图片被拒体验重设计 — 设计文档

日期：2026-08-14
状态：已与 PM 逐项确认，待实现
依赖：`feat/onboarding-error-states` 分支（后端 422 content_blocked 已部署；
Tab1 被拒文案 f95e127；客户端宽容解码 723e2fe）

## 一、背景与问题

Tab1 发送不合规图片/文本时（后端 422 content_blocked），当前体验有两处问题：

1. **不合规图片留在屏幕上**：被拒后只移除「生成中」条目，用户气泡里的原图
   原样留在时间线里。
2. **提示过重**：系统 Alert（"Can't create a lesson" + OK）打断阅读，
   PM 要求更轻的提示。

另有一个后端隐患：图片在请求时已并行上传到 Storage，被拒后无人删除——
不合规内容以孤儿文件形式长期留在云存储（合规风险 + 空间浪费）。

## 二、范围

1. Tab1 被拒呈现重设计（图片占位块 + inline 轻提示行 + Alert 退役）
2. 后端存储清理（422 早退时删除已上传图片）

### 明确不做

- Onboarding 被拒体验不动（上一刀已定：文案 + Try another photo 按钮）
- 被拒条目不加重试按钮（同输入重试必再被拒；用户继续发新消息即可）
- 不做「重发时自动换图」等任何自动引导
- 服务端已返回 422 不落库（上一刀已实现），本次不涉及消息持久化改动

## 三、产品体验

| 场景 | 时间线呈现 |
|---|---|
| 图片被拒 | 用户气泡就地转换：图片 → 浅灰占位块（图标 + "Content blocked"）+ 下方 inline 轻提示行 "This content can't be processed. Try another one."（小字、弱图标、无按钮） |
| 文本被拒 | 文本气泡原样保留 + 下方同一条轻提示行（整句） |
| 图文混合被拒 | 文本气泡原样 + 图片变占位块 + 轻提示行（两条规则自然合并，无特判） |
| 弹窗 | TodayView 唯一的 `.alert`（"Can't create a lesson"）整个移除；被拒场景不再有任何弹窗 |

- 轻提示行文案与 Onboarding 被拒档、后端语义同句，三处一致。
- 占位块文案 "Content blocked" 只作形态标签，原因说明集中在轻提示行整句。

## 四、实现要点

### 1. 时间线新状态（`Models/Message.swift`）

```swift
case userRejected(text: String?, wasImage: Bool)
// 被安全拦截的请求：只保留形态信息（文本原样展示、图片转占位块）。
// 不带原图数据：不渲染、不重试，无需保留像素。
```

### 2. ViewModel 转换（`Today/TodayViewModel.swift`）

- `send()` 里记录本次请求对应的 userBubble entry id（pending 状态，
  仿照 sendFailed 的关联方式；若无关联 entry 则兜底新建一条 userRejected）
- `catch AIServiceError.contentBlocked`：
  - 对应的 userBubble entry → 就地 `replace` 为 `.userRejected(text: 原文, wasImage: 是否有图)`
  - 移除 loading entry
  - 不再设置 `contentBlockedMessage`
- `contentBlockedMessage` 字段退役（连同 TodayView 的 `.alert` 与 Binding）

### 3. 渲染器（`Today/Components/MessageRow.swift`）

`TimelineRow` 增加 `.userRejected` 分支 → 新组件 `UserRejectedRow`：
- `text != nil` → 复用现有文本气泡样式原样渲染
- `wasImage` → 占位块：`AppTheme.Color.imagePlaceholderBg` 底、SF Symbol
  描边图标、小字 "Content blocked"（`AppTheme.Font.statusNote` + `textMuted`）
- 底部轻提示行：整句文案，小字弱图标（延续 ErrorBanner 的轻行样式，
  但用 `textMuted` 而非 danger 色——被拒不是系统故障）
- 全部走 token 层，无新 token、无写死字号/颜色

### 4. 后端存储清理（`supabase/functions/generate/index.ts`）

- 新增 `deleteImage(path: string): Promise<void>`（Storage 删除 helper；
  失败仅 `console.error`，不阻塞主响应）
- 模型 error 卡 422 早退块中：若 `sourceImagePath` 非空 → `await deleteImage(sourceImagePath)`
  （在 `return json(..., 422)` 之前）

## 五、测试计划

逻辑稳定后写单测：

1. **ViewModel**（注入 MockAIService，抛 `contentBlocked`）：
   - 图片被拒：userBubble(有图) → userRejected(text: nil, wasImage: true)；
     loading 移除；`contentBlockedMessage` 恒 nil（改写现有
     `contentBlockedSetsMessageAndRemovesLoading` 用例）
   - 文本被拒：userBubble(文本) → userRejected(text 原样, wasImage: false)
   - 混合被拒：text 原样 + wasImage: true
2. **后端**：`isModelErrorCard` 已有 3 用例覆盖判定；`deleteImage` 为纯 Storage
   调用（deno 无 mock 基建），不写网络级测试，失败路径有 log 兜底
3. 全量回归：现有 165 用例中仅 contentBlocked 相关 1-2 个需改写，其余不动

## 六、验收

1. `xcodebuild test` 全绿；`deno test` 全绿
2. 模拟器验证（截图发 PM 确认）：
   - Tab1 发不合规图片 → 气泡变占位块（"Content blocked"）+ 轻提示行；
     无 Alert；原图不出现
   - Tab1 发不合规文本 → 文本气泡原样 + 轻提示行；无 Alert
   - 正常图片/文本 → 时间线行为与改前一致（回归）
3. 后端部署后：重放不合规图片 → 422；Storage 中原图被删除（在 Supabase
   Dashboard Storage 中确认无新孤儿文件）
