# Onboarding 错误态按情境拆分 — 设计文档

日期：2026-08-14
状态：已与 PM 逐项确认，待实现

## 一、背景与问题

Onboarding Capture 页（自选照片路径）生成失败时，所有错误显示同一句
"Something went wrong. Want to try again?" + Try again 按钮，不区分原因。

实际上失败原因至少三类，且用户能做的动作不同：
- **断网** — 用户可自助解决（连网后重试可成功）
- **内容被拒** — 服务端安全过滤拦截（422 `content_blocked`）；同一张图重试必再被拒，
  正确动作是换素材
- **其它** — 超时 / 服务器错误 / 解码失败等，用户只能重试

## 二、范围

1. **Onboarding Capture 页**错误态按三档拆分（本次核心）
2. **Tab1 一行文案同步**：`TodayViewModel.swift` 的 contentBlocked 提示句
   改为与 Onboarding 被拒档同一句（一行字符串替换，不做 Tab1 错误分类）

### 明确不做（YAGNI）

- Tab1 不做三档错误分类拆分（sendFailed 重试行保持原样），以后若要做另排切片
- 服务层（`AIService.swift` / `AIServiceError`）不动 —— 分类放 ViewModel 层
- 断网档不做「网络恢复后自动消失/自动重试」监听
- 放弃态（两次重试后）机制与文案保持现状

## 三、三档设计

| 档位 | 判定 | 文案 | 按钮 | retryCount |
|---|---|---|---|---|
| 断网 offline | `URLError` 断网码，或 `NetworkMonitor.shared.isConnected == false` 兜底 | "Network unavailable. Check your network and try again." | "Try again"（照旧，走 `retry()`） | 累加；≥2 进放弃态（照旧） |
| 内容被拒 contentBlocked | `AIServiceError.contentBlocked`（服务端 422） | "This content can't be processed. Try another one." | **"Try another photo"** → 走新方法 `chooseAnother()`：清空已选照片/结果/错误态，返回选择页 | **不累加**（不走重试，自然无放弃态） |
| 其它 generic | 其余一切失败（超时/服务器/解码等） | "Something went wrong. Retry generation." | "Try again"（照旧，走 `retry()`） | 累加；≥2 进放弃态（照旧） |

- 放弃态文案 "No worries — you can explore inside the app." 保持不动。
- 文案遵循 Warm Minimalism 语气：陈述事实、可行动、不指责用户、不甩锅。
- 文案直接写在代码里（与 Tab1 / 现有错误文案的做法一致，不为此新建文案 token 层）。

### Tab1 同步句

`TodayViewModel.swift:211`：
- 旧：`"This moment can't be turned into a lesson. Try another one."`
- 新：`"This content can't be processed. Try another one."`
（与 Onboarding 被拒档同句，两处体验一致。）

## 四、实现要点

### 1. 新增错误档位 enum（`OnboardingViewModel.swift`）

```swift
enum OnboardingErrorKind {
    case offline          // 断网
    case contentBlocked   // 内容被服务端安全过滤拦截
    case generic          // 其它（超时/服务器/解码等）
}
```

### 2. 分类纯函数（static，可脱离网络单测）

```swift
static func classify(_ error: Error, isConnected: Bool) -> OnboardingErrorKind
```

判定顺序（先明确信号、后兜底）：
1. `AIServiceError.contentBlocked` → `.contentBlocked`（服务端明确信号优先）
2. `URLError` 且 code ∈ {`.notConnectedToInternet`, `.networkConnectionLost`,
   `.dataNotAllowed`, `.internationalRoamingOff`} → `.offline`
3. `isConnected == false`（NetworkMonitor 真实网络状态兜底）→ `.offline`
4. 其余 → `.generic`

### 3. ViewModel 状态改动

- `errorMessage: String?` → 替换为 `errorKind: OnboardingErrorKind?`
  （`errorMessage` 唯一消费点在 `OnboardingCaptureView.swift:623`，一并替换）
- `generate()` 的 catch：
  `errorKind = Self.classify(error, isConnected: NetworkMonitor.shared.isConnected)`；
  retryCount 规则：`contentBlocked` 不累加，其余累加
- 新增 `chooseAnother()`：清空 `selectedCard / selectedImage / generationResult /
  errorKind / retryCount` → 视图回到选择页

### 4. CaptureView 渲染改动（`fallbackStage`）

- 按 `viewModel.errorKind ?? .generic` 切换三档文案（文案常量随视图，与现状同风格）
- `contentBlocked` 档：按钮 "Try another photo" → `chooseAnother()`
- 其余两档：按钮 "Try again" → `retry()`（照旧）
- 放弃态 `isFailed`（`retryCount >= 2`）逻辑照旧

### 5. 预设卡路径不受影响

预设样品卡走静态数据（零网络），错误页只可能出现在自选照片路径；本次改动
不触碰预设卡分支。

## 五、测试计划

切片稳定后写单测（遵循项目测试节奏：逻辑确认后再锁行为）：

1. **`classify` 纯函数**：contentBlocked 优先；各断网 URLError 码；`isConnected=false`
   兜底；普通错误 → generic
2. **ViewModel（注入 MockAIService）**：
   - 抛 `contentBlocked` → `errorKind == .contentBlocked` 且 retryCount 不变
   - 抛断网 URLError → `.offline` 且 retryCount +1
   - 抛普通错误 → `.generic` 且 retryCount +1
   - `chooseAnother()` 清空全部状态
3. Tab1 文案替换为纯字符串改动，无需新测试（现有 contentBlocked 路径测试若有，
   跑通即可）

## 六、验收

1. 编译通过
2. 模拟器逐项验证（改前/改后截图给 PM 确认）：
   - 断网生成 → 显示断网文案 + Try again
   - 被拒内容生成 → 显示被拒文案 + Try another photo，点击回选择页
   - 其它失败 → 通用文案 + Try again；重试两次后进放弃态
   - 预设卡路径正常生成（回归）
3. Tab1 被拒提示显示新句
