# App UI 文案用户显式修改记录

本文档仅记录用户明确指定修改的文案内容，其余现有代码中的文案一律保持原样，不做改动。

---

## 1. Screen 1 (`OnboardingScreen1View.swift`)

* **Title 词汇修改**：
  * **原代码**：`Build your expression / from work & life.`
  * **中间版本**：`Build your language / from work & life.`（仅将 expression 替换为 language）
  * **曾用（2026-10-07，已撤回）**：`Build language from your life.`（写死三行：`Build` / `language` / `from your life.`）
  * **现行文案（2026-10-07 起，以代码为准）**：`Build your language` / `from work & life.`（写死两行，`OnboardingScreen1View.swift`）

---

## 2. Screen 2 (`OnboardingScreen2View.swift`)

* **Text Card（便签卡片文案）修改**：
  * **原代码**：
     ```
    Before diving into details, let's
    align on the core
    ```
  * **修改后**：
 
    ```
    Let's align on the details， 
    before diving into
    ```
* **Subtitle（选择/拍摄态副标题）修改**：
  * **原代码**：`Point at your desk, coffee, or view — no preparation needed.`
  * **修改后**：`Capture whatever inspires you today. No preparation needed.`
  * *（Screen 2 仅修改 Text Card，其余 Title、Subtitle、Photo Card、Voice Card 均保持原样）*

---

## 3. Screen 3 (`OnboardingCaptureView.swift`)

* **Subtitle（选择/拍摄态副标题）修改**：
  * **原代码**：`Point at your desk, coffee, or view — no preparation needed.`
  * **修改后**：`Capture whatever inspires you today. No preparation needed.`

* **Result Subtitle（结果产出态副标题）修改**：

  * **原代码**：`Your photo, now something you can say.`
  * **修改后**：`From what you see, to what you say.`

* **Loading Hint（生成中提示文案）修改**：
  * **原代码**：`Turning your moment into English…`
  * **修改后**：`Transforming what you see into words…`

* *（备注：Screen 3 的 Title、Result Title 均保持原样不变）*

---

## 4. Tab1 主页面 (`TodayView` / `InputBar.swift`)

* **InputBar 输入框提示词（Placeholder）修改**：
  * **原代码**：`Your moment`
  * **修改后**：`Say something...`
  * *（Tab1 仅修改输入框 Placeholder，其余组件及逻辑保持原样）*

---

## 5. 顶层导航栏 (`Navigation/TopTabSelector.swift`)

* **Tab2 标签名称（Label）修改**：
  * **原代码**：`Library`
  * **修改后**：`Speak`
  * *（Tab1 标签保持原代码 `Capture` 不变；Tab2 仅将 `Library` 修改为 `Speak`）*

---

## 6. Settings 反馈页面 (`Settings/FeedbackView.swift`)

* **Feedback 详情输入框提示词（Placeholder）修改**：
  * **原代码**：`Tell us what's on your mind…`
  * **修改后**：`Describe what you experienced, or any feedback…`
  * *（仅修改输入框 Placeholder，其余 Category 与功能逻辑保持原样）*

---

## 7. Settings 设置页面 (`Settings/SettingsView.swift`)

* **Delete Account 确认弹窗详细说明（Alert Message）修改**：
  * **原代码**：`This permanently deletes your account and all your learning data. This can't be undone.`
  * **修改后**：`This will permanently delete your account, expressions, and progress. This action cannot be undone.`
  * *（仅修改弹窗内说明文案，其余 Delete Account 按钮与确认逻辑保持原样）*

---

## 8. Tab2 页面 (`MineView.swift` / `Tab2HeroCard.swift`)

* **未解锁态副提示文案修改**：
  * **原代码**：`Reach 20 pops in any topic to start practicing.`
  * **修改后**：`Reach 20 pops in any topic to start talking.`
  * *（去除了 practicing 的压迫感，统一为 talking）*

* **已解锁态大标题（Main Title）修改**：
  * **原代码**：`Talk about something`
  * **修改后**：`Speak`

* **已解锁态 Hero 卡片分区标题（Section Header）修改**：
  * **原代码**：`Your materials`
  * **修改后**：`Featured scenes`

* **已解锁态副标题（Subtitle）删除**：
  * **原代码**：`Text("Scenarios built from your daily moments.").font(...)`
  * **修改后**：删除该副标题文案（直接隐藏/不显示该组件）。
