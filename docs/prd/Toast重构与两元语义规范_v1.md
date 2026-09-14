# AppToast 视觉重构与系统收敛 PRD (v1)

> **目标**：彻底淘汰老旧沉重的“黑底大胶囊”和刺眼的“红色警报感叹号”，将全 App 的浮层 Toast 统一收敛为 **Warm Editorial 微圆角（R8）藏书票/便签风格**，落实**纯粹两元语义**，规范单行文案，并清理历史死代码与冗余通道。

---

## 一、 核心设计规范（Visual & Motion Spec）

### 1. 几何形态：微圆角藏书票（R8）
* **容器形状**：`RoundedRectangle(cornerRadius: 8, style: .continuous)`（R8 微圆角矩形）。
* **设计隐喻**：像一枚盖着墨印的手作藏书票（Ex Libris）或便签纸条。四角柔韧微收，与 Tab1/相机的底部大胶囊控件形成“方圆互补”的层次对比，彻底抛弃老旧的大药丸胶囊（Capsule）。
* **尺寸与间距**：
  * **底框固定宽度**：统一固定为 `328pt`（黄金宽度，在 375pt 小屏 SE 上留出 23.5pt 边距，在大屏机上稳重不跳动，消除伸缩漂浮感）。
  * 垂直内边距：`8pt`，整体高度约 `34~36pt`。内容组合 `[Icon + Text]` 在固定底框内**水平居中对称呈现**。
  * 间距：图标与文字间距 `8pt`（`AppTheme.Space.paddingS`）。

### 2. 纯粹两元色彩体系（Pure Dual-Semantic System）
全 App 浮层 Toast **只有两个语义**，坚决不使用任何红色报警色：

| 语义层级 | 底色 (Background) | 边框 (Border) | 图标 (Icon) | 文字 (Text) | 微投影 (Shadow) | 心理感受 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **积极确认 (Positive)** | `AppTheme.Color.brandWash`<br>（暖橙晨曦洗印底 10~12%） | `AppTheme.Color.brandInk.opacity(0.18)` | `#FF7622`<br>（`brandStrong` 亮暖橙高光） | `#C2410C`<br>（`brandInk` 品牌焦墨橙，AAA 对比度） | `brandStrong.opacity(0.06)`<br>微暖晕 | 温暖、被回应、达成 |
| **动作受阻 (Blocked)** | `AppTheme.Color.pillNeutralBg`<br>（`#EFECE6` 沉静暖纸灰） | `AppTheme.Color.border`<br>（`#E2DDD4` 浅纸边缘线 0.6pt） | `#7C7773`<br>（`textSecondary` 中性素铅灰） | `#211811`<br>（`textPrimary` 炭黑墨水） | `AppTheme.Shadow.cardColor.opacity(0.55)`<br>（0, 3, 8pt） | 客观事实陈述、零焦虑、无惊扰 |

### 3. 排版与动效原则
* **排版**：`AppTheme.Font.statusNote`（13pt Medium），**强制单行不折行**：
  ```swift
  Text(message)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
  ```
* **动效**：轻弹浮入 `.spring(response: 0.35, dampingFraction: 0.8)`，悬停 **3.0 秒**后平滑淡出退场。
* **无障碍**：弹出时通过 `UIAccessibility.post(notification: .announcement, argument: message)` 播报 VoiceOver，保证视障用户感知。

---

## 二、 全 App 真实文案矩阵（文案严格不超一行）

清理所有带有技术术语（如 `sync`）及多余废话（如 `and try again`）的过长文案，确保在 iPhone mini/SE 等窄屏设备上**绝不折行**：

| # | 触发场景 | 业务来源文件 | 语义 | 图标 | 新版统一文案 (字符数) | 相比原版的改动说明 |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **意见反馈提交成功** | `SettingsView.swift`<br>`RootTabContainer.swift`<br>`FeedbackView.swift` | 🟠 积极 | `paperplane.fill` (-10°仰角) | `Thank you for your feedback.` (28c) | 去除“很快联系你”等过度承诺，真诚、克制、体面 |
| **2** | **离线/下拉刷新受阻** | `TodayViewModel.swift`<br>`Tab2HomeViewModel.swift` | ⚪️ 受阻 | `wifi` (正向轴对称) | `You're offline. Check your connection.` (38c) | 严密双句陈述，圆润正向居中 |
| **3** | **服务端未对齐/拉取受阻** | `TodayViewModel.swift`<br>`Tab2HomeViewModel.swift` | ⚪️ 受阻 | `arrow.clockwise` | `Couldn't refresh. Try again in a moment.` (40c) | 与 Tab2 首载失败错误页共用一条（df137ba/c944731，PM 拍板）：错误页点 Retry、无下拉，「Pull to try again」在那里是错误指引——统一优先，放弃 Pull 动作指引换一条文案覆盖两种语义 |
| **4** | **相机拍照异常** | `CameraCaptureView.swift` | ⚪️ 受阻 | `camera.badge.ellipsis` | `Camera unavailable. Please try again.` (38c) | 剔除口语化的 "that photo"，改用温和系统级陈述 |
| **5** | **相机拍照超时** | `CameraCaptureView.swift` | ⚪️ 受阻 | `timer` | `Capture timed out. Please try again.` (37c) | 剔除带负面情绪的 "took too long"，客观描述事实 |
| **6a** | **Onboarding 选图比例过高** | `OnboardingCaptureView.swift` | ⚪️ 受阻 | `photo` | `Photo is too tall. Try another.` (30c) | 剔除生硬数学比例，恢复精准高度归因与行动指引 |
| **6b** | **Onboarding 选图比例过宽** | `OnboardingCaptureView.swift` | ⚪️ 受阻 | `photo` | `Photo is too wide. Try another.` (30c) | 剔除生硬数学比例，恢复精准宽度归因与行动指引 |
| **6c** | **Onboarding 图片读取失败** | `OnboardingCaptureView.swift` | ⚪️ 受阻 | `photo` | `Couldn't read this photo. Try another.` (37c) | 统一动词为 Try another，保持全站一致 |
| **7** | **Tab2 对话里程碑解锁** | `MineView.swift`<br>`Tab2HomeViewModel.swift` | 🟠 积极 | `sparkles` (原生双微星芒) | `'[Category]' reached 20 pops.` (26c) | 分类名使用单引号包裹界定，避免词性混淆；无感叹号事实呈现 |
| **8** | **功能未就绪占位** | `MineView.swift` | ⚪️ 受阻 | `clock` | `Speaking mode will be available soon.` (37c) | 彻底去除轻浮俏皮的 Hang tight，严肃克制、展现正规排期体面感 |

> **边界澄清**：
> 1. AI 拦截内容提示（`This content can't be processed. Try another one.`）是时间线**行内卡片形态**，坚决不属于 Toast，不混入此表。
> 2. 剪贴板复制、生词收藏由于无业务代码支撑，全部排除。

---

## 三、 代码清理与重构范围（Cleanup Scope）

### 1. 彻底删除 / 重构的代码：
1. **重写 `AIEnglishApp/Components/AppToast.swift`**：
   * ❌ 删除黑底：`AppTheme.Color.textPrimary.opacity(0.82)`；
   * ❌ 删除药丸：`Capsule()`；
   * ❌ 删除黑底白字反差色：`AppTheme.Color.textOnChip`；
   * ❌ 修复 warning：去除非隔离上下文访问 `@MainActor` 属性 `toastLifetime` 的警告；
   * ✅ 升级为统一的 `AppToast(message:systemImage:semantic:)`，支持 `.positive` 和 `.blocked`。
2. **收拢调用通道（消除双轨制）**：
   * 当前同时存在 `NotificationCenter.default.post(.showAppToast)`、`AutoDismissingAppToast`、`.toast()` 三套机制；
   * 统一为：统一的 ViewModifier `.appToast(message:semantic:systemImage:)`，并保持对已有 `@Binding var message: String?` 的顺畅兼容。
