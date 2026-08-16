# Onboarding 错误态重设计：Fail-open + Tab1 待重试记录 — 设计文档 v2

日期：2026-08-14
状态：v2 与 PM 逐项确认（含杀 app 不丢、记录带图、Retry 链路），待 PM 最终审阅
基线：main `10e0d6e`（#28 + 错误态三档/Tab1 被拒/后端修复的合并结果）

## 一、背景与问题

合并后 main 的错误体验有两处违背产品原则：

1. **挡用户**：预设卡断网被完全禁用（#28 guard）；自选图失败时整块错误页
   占据内容区，进 App 出口（Continue）要失败 2 次才出现。断网用户被困在 onboarding。
2. **错误提示过重**：错误页 + No worries + Try again 是「页面级」处理，
   不符合 Warm Minimalism——错误应是轻提示。
3. **失败内容无恢复路径**：用户带着「没生成成功的内容」进 App 后，这条内容
   就永远消失了（杀 app 必丢）；Tab1 空白，且没有欢迎页兜底观感。

核心原则：**Fail-open——内容可以失败，用户不能被卡。** 失败的代价 = 一条
「待重试」的记录，而不是内容蒸发 + 用户被困。

## 二、范围

1. Onboarding 错误态：错误页 → toast 轻提示；Continue 在失败后立即可用
2. **待重试记录**：带未成功内容离开 onboarding 时，本地持久化一条记录
   （带图展示），杀 app 不丢；Tab1 显示记录 + 网络错误文案 + Retry
3. 断网规则统一：预设卡与自选图前端体验完全同构（断网 → 不落库/不调 AI + 内容照常显示 + 提示）

### 明确不做

- 不做有网时的自动补发（用户明确要求手动点 Retry 再展示）
- 待重试记录 MVP 无删除按钮（Retry 成功后自然消失；持续失败可忽略，
  后续刀再加删除）
- 不动 Tab1 正常生成链路与 Tab1 被拒体验（独立刀已完成）
- 预设卡有网时的落库、打标补发、seed 兜底（#28）全部保留不动
- onboarding_completed 判定机制**不动**（见 §五说明）

## 三、产品体验

### Onboarding 层

| 场景 | 表现 |
|---|---|
| 生成中 | loading 卡，暂不显示 Continue（2-3s） |
| 自选图成功 | 结果卡 + Continue |
| 自选图失败（任一档） | 图片预览保留 + 底部 toast + Continue 立即可用（fail-open） |
| ─ 断网 | toast 常驻：`Network unavailable. Check your network and try again.`，网络恢复自动消失 |
| ─ 被拒 | toast 4s：`This content can't be processed. Try another one.` |
| ─ 其它 | toast 4s：`Something went wrong. Please try again.` |
| 预设卡 + 有网 | 静态卡 + 落库（#28 原样）+ Continue |
| **预设卡 + 断网** | **与自选图完全同构**：照常选中 → 生成阶段检测断网 → **不落库（不发请求）**、卡片内容照常显示（本地静态内容可见）→ 同一条常驻断网 toast + Continue 可用 |
| **Continue（带未成功内容离开）** | 若本次有**断网导致**的未生成内容（被拦预设卡 / 断网失败照片），写一条**本地待重试记录**再进 App。被拒/其它档失败不写记录——被拒同图重试必再被拒（用户换图是唯一解），其它档（服务器错误）罕见且 Retry 收益不明确，MVP 只覆盖断网场景 |

### Tab1 层（待重试记录）

- 一条带图的记录：**展示图片**（照片存本地文件显示原图；预设卡用内置
  asset 图）+ 网络错误文案 + **Retry 按钮**
- 文案：`You were offline, so this wasn't generated.` + Retry（点击有网时
  重新生成并展示；无网时点 Retry → toast 提示）
- **杀 app 不丢**：记录与图片持久化到本地磁盘，重启后仍在
- Retry 成功 → 记录就地变卡片；Retry 失败 → 记录保留可再试

### 移除项

- 错误页（fallbackStage）、Try again 按钮、No worries 文案、retryCount 与
  2 次门控、chooseAnother、#28 的预设卡断网禁用 guard

## 四、实现要点

### 1. 待重试记录模型（新，`Services/` 或 `Today/` 下）

```swift
/// 持久化的待重试记录：带未成功内容离开 onboarding 时写入，Tab1 展示与 Retry。
enum PendingRetrySource: String, Codable {
    case presetCard    // 断网未落库的预设卡（记 imageName / presetCardId）
    case photo         // 生成失败的照片（图存本地文件，记 fileName）
}

struct PendingRetryRecord: Codable, Identifiable {
    let id: UUID
    let source: PendingRetrySource
    let presetCardId: String?     // source == .presetCard
    let presetImageName: String?  // 内置 asset 图名（展示用）
    let photoFileName: String?    // source == .photo（图片文件在 Documents 下）
    let createdAt: Date
}
```

- 存储：`PendingRetryStore`（单例）——记录 JSON 存 UserDefaults；
  照片 JPEG 写 Documents/；提供 save / load / remove
- 杀 app 语义 = 新进程重新 load（单测用独立 suite/注入 defaults）

### 2. Onboarding 层改动

- `OnboardingViewModel`：
  - 预设卡分支（`generate()`）：生成阶段 `isConnected() == false` → **跳过落库任务**
    （不发请求）、`presetSavedToServer = false`、`errorKind = .offline`、
    `generationResult = card.staticCard` **照常设置**（卡片内容照常显示）——
    与自选图失败态同构（内容保留 + 离线信号）
  - 自选图失败（断网）：现有 catch → `errorKind = .offline`（不变，图片预览保留）
  - 删除 retryCount / chooseAnother
- `OnboardingView.completeOnboarding`：进入前检查——
  - `selectedCard != nil && errorKind == .offline` → 写 presetCard 记录
  - `selectedImage != nil && generationResult == nil && errorKind == .offline` →
    写 photo 记录（UIImage 落盘）
  - 仅断网档写记录（被拒同图重试必再拒、其它档罕见，MVP 只覆盖断网）
- CaptureView：删 fallbackStage；bottomButton 条件 = `(selectedCard != nil || selectedImage != nil) && !isLoading`；toast 挂载（被拒/其它 4s 自动消失；断网常驻由 `errorKind == .offline` + 网络恢复 onChange 清 nil 驱动）；删 #28 两处 guard

### 3. Tab1 层改动

- `TodayViewModel.loadHistory`（或 TodayView）：启动/进入时 `PendingRetryStore.load()`
  → 若存在记录且时间线无对应内容 → 在时间线顶部插入一条 `PendingRetryRow`
- `PendingRetryRow`（新组件，MessageRow 同目录）：
  - 图片（photo → 本地文件 UIImage；presetCard → `UIImage(named:)`）
  - 文案 `You were offline, so this wasn't generated.`
  - Retry 按钮：有网 → 触发生成（photo 走 `service.generate`；presetCard 走
    静态卡 + 落库，成功后 `PendingRetryStore.remove` + 就地变卡片）；无网 → toast
- 成功后复用 Tab1 现有生成链路与卡片渲染；落库复用 #28 PresetCardSaver

### 4. 文案契约（逐字）

- Onboarding 断网 toast（常驻）：`Network unavailable. Check your network and try again.`
- 被拒（4s）：`This content can't be processed. Try another one.`
- 其它（4s）：`Something went wrong. Please try again.`
- Tab1 待重试记录：`You were offline, so this wasn't generated.` + 按钮 `Retry`

### 5. 测试计划

- `PendingRetryStore`：save → 新实例 load（杀 app 语义）→ 数据完整（含照片文件
  往返）；remove
- VM：预设卡断网（注入 `isConnected: { false }`）→ generationResult 照常为静态卡
  （内容显示）、不调 saver（mock 计数断言零调用）、presetSavedToServer == false、
  errorKind == .offline；自选图断网失败 → errorKind == .offline
- completeOnboarding 记账：带失败照片离开 → Store 写入（注入 store）；正常成功 → 不写
- Retry 链路：photo 记录 Retry 成功 → 生成 + 记录移除；presetCard 记录 Retry 成功 →
  静态卡 + 落库 + 记录移除；无网 Retry → 不触发
- 删除 retryCount 相关旧用例；保留落库两用例、errorKind 归类用例、Tab1 被拒用例
- 全量回归：客户端全量 + deno 28 用例

## 五、onboarding_completed 判定（不动，附说明）

现状：本地标记（点 Get Started 即写，无论网络）+ 远端打标 + #28 补发机制
（失败留待办、启动有网自动补）。fail-open 下断网进 App 本地标记已写 →
下次启动直接进主界面，远端由补发追平。**无需修改。**

## 六、验收

1. `xcodebuild test` 全绿
2. 模拟器验证（截图发 PM 确认）：
   - 断网 + 预设卡：卡片照常显示 + 常驻 toast + Continue 可用；进 Tab1 看到带图
     待重试记录（asset 图）+ 文案 + Retry；**杀 app 重启记录仍在**
   - 断网 + 自选图：失败 toast + Continue；进 Tab1 记录带原图；杀 app 重启仍在
   - 有网后点 Retry：预设卡 → 卡片 + 服务端落库（重启后仍在）；照片 → AI 生成卡片
   - 无网点 Retry → toast 提示
   - 被拒/其它失败、正常有网流程：回归一致
3. 后端无改动，无需部署（落库走已有 save-preset-card）
