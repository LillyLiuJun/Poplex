# Tab1 行内提示 (Inline Notices) 视觉与文案微优化规范 (v1)

> **目标**：基于用户确立的“微优化、保持原有结构与颜色、统一右对齐、单句客观归因”原则，对 Tab1 时间线内及 InputBar 上方的全部行内状态（5 个场景，6 种分支）进行系统性收敛与落地交付。
> 
> **参考实现文件**（已在 Xcode 验证编译通过）：
> - [`AIEnglishApp/DesignLab/Tab1InlineNoticesExplorationPreview.swift`](file://<repo>-style-sandbox/AIEnglishApp/DesignLab/Tab1InlineNoticesExplorationPreview.swift)

---

## 一、 核心设计原则（Core Design Principles）

1. **严格右对齐原则（Strict Right Alignment）**：
   - 除 05（InputBar 居中悬挂 Banner）外，**所有附属于用户发言的提示与状态行，全部严格右对齐（`.trailing`）**；
   - 紧贴用户深色气泡/照片卡片右下角，整页时间线的右缘整齐划一，坚决不与左侧 AI 生成卡片及居中日期混淆。
2. **真实原图保留原则（Preserve Real Photo）**：
   - 用户拍摄/选取照片发送失败时，时间线上展示的**永远是用户的真实生活照片原图（`UIImage`）**，完好无损；
   - 严禁用灰色占位方块替代用户原图；只有在图片被 AI 审查拦截（04-B）时才抹除原图。
3. **颜色与核心组件克制沿用（No Color Drift）**：
   - 发送失败与重试文字/图标颜色**保持现网原版错误色 `AppTheme.Color.danger`**，不乱用品牌橙色；
   - 错误图片占位**100% 沿用线上现网原版 `ImageLoadFailedPlaceholder`**（纯粹 16pt 小三角居中，内部坚决不要文字）。
4. **单句客观归因（Clear & Objective Copy）**：
   - 重试文案必须指出网络问题，给用户明确动作（`Check your connection and try again.`）；
   - 内容被拒只保留客观事实前半句（`This content can't be processed.`），剔除多余的教导式废话；
   - 额度横幅删去冗长动作引导（`Daily limit reached (5/5)`），短促通透，绝不折行截断。

---

## 二、 全部 6 种场景全景矩阵（Matrix）

| # | 场景分类 | 触发时机与位置 | 对齐规则 | 图标 | 定稿文案 (字符数) | 字体/颜色规范 |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | **纯文字发送失败**<br>`SendFailedRow` | 用户发文字后断网或超时；紧跟文字气泡右下 | 👉 严格右对齐<br>`.trailing` | `arrow.clockwise`<br>(11pt semibold) | `Check your connection and try again.`<br>(37 字符) | `AppTheme.Font.chineseFaint`<br>`AppTheme.Color.danger` |
| **02** | **带图发送失败**<br>`SendFailedRow` | 用户发图文后断网或超时；气泡内为**用户真实照片**，提示紧跟文字右下 | 👉 严格右对齐<br>`.trailing` | `arrow.clockwise`<br>(11pt semibold) | `Check your connection and try again.`<br>(37 字符) | `AppTheme.Font.chineseFaint`<br>`AppTheme.Color.danger` |
| **03** | **断网暂存照片待重试**<br>`PendingRetryRow` | Onboarding/历史离线照片冷启动注入时间线；气泡内为**用户照片原图** | 👉 严格右对齐<br>`.trailing` | `arrow.clockwise`<br>(11pt semibold) | `Check your connection and try again.`<br>(37 字符，与 01/02 统一) | `AppTheme.Font.chineseFaint`<br>`AppTheme.Color.danger` |
| **04-A** | **纯文本合规拦截**<br>`UserRejectedRow` | 文本触发安全敏感词拦截；深色文本气泡保留在右侧，说明在气泡下方 | 👉 严格右对齐<br>`.trailing`<br>*(线上原为居中)* | `info.circle`<br>(.small scale) | `This content can't be processed.`<br>(33 字符，仅保留客观前半句) | `AppTheme.Font.chineseFaint`<br>`AppTheme.Color.textMuted` |
| **04-B** | **违规图片合规拦截**<br>`UserRejectedRow` | 上传照片被安全模型拦截；抹去原图为 120x120 浅灰方块，说明在下方 | 👉 严格右对齐<br>`.trailing`<br>*(线上原为居中)* | `info.circle`<br>(.small scale) | `This content can't be processed.`<br>(33 字符，仅保留客观前半句) | 方块内无文字只有 16pt 小三角；下方文字为 `chineseFaint` + `textMuted` |
| **05** | **每日额度用尽横幅**<br>`InputBarLimitBanner` | 当日 5 次额度用尽 (429)；悬挂在锁定状态的 InputBar 顶部 | 🔝 居中悬挂<br>`.center` | `sparkles`<br>(13pt semibold) | 左侧：`Daily limit reached (5/5)`<br>右侧：`Settings >` | 左侧文字 `statusNote` + `textPrimary`<br>右侧 `metaNote` + `textSecondary` |

---

## 三、 生产代码落地指南（Implementation Guide）

本节提供各文件的精确修改位置与代码 Diff，供落地 Agent 直接参考替换。

### 1. `Today/Components/MessageRow.swift`

#### (1) 修改 `SendFailedRow`（统一重试文案与图标）
- **位置**：约 109~125 行
- **修改内容**：
  - 图标由 `exclamationmark.arrow.circlepath` 改为 `arrow.clockwise`；
  - 文案由 `No connection — tap to retry.` 改为 `Check your connection and try again.`；
  - 严格保持 `.foregroundStyle(AppTheme.Color.danger)` 与 `.frame(maxWidth: .infinity, alignment: .trailing)`。

```swift
// MARK: - Send failed (tap to retry)
private struct SendFailedRow: View {
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text("Check your connection and try again.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, AppTheme.Space.paddingXS)
        }
        .buttonStyle(.plain)
    }
}
```

#### (2) 修改 `PendingRetryRow`（与发送失败文案彻底收敛）
- **位置**：约 34~60 行
- **修改内容**：
  - 图标与文案与 `SendFailedRow` 100% 对齐统一，彻底解决之前 57 字符长句（`You were offline, so this wasn't generated. Tap to retry.`）在窄屏上的挤压问题。

```swift
struct PendingRetryRow: View {
    let record: PendingRetryRecord
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingXS) {
            UserBubble(
                text: "Describe this image",
                image: PendingRetryStore.shared.photoImage(for: record),
                imageUrl: nil,
                imageStableKey: nil
            )

            Button(action: onRetry) {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Check your connection and try again.")
                        .font(AppTheme.Font.chineseFaint)
                }
                .foregroundStyle(AppTheme.Color.danger)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, AppTheme.Space.paddingXS)
            }
            .buttonStyle(.plain)
        }
    }
}
```

#### (3) 修改 `UserRejectedRow`（右对齐 + 精简文案 + 错误图片 1:1 复用现网小三角）
- **位置**：约 64~105 行
- **修改内容**：
  - `wasImage` 分支直接复用现网标准组件 `ImageLoadFailedPlaceholder()`，彻底剔除原本在方块内硬塞的 `Content blocked` 文字；
  - 下方轻提示文案截断后半句，仅保留 `This content can't be processed.`；
  - 下方轻提示由 `.center` 改为 `.trailing`（右对齐），紧贴气泡右下角。

```swift
// MARK: - 被拒条目：图片转占位块（不合规图片不上屏），文本原样；下方一行轻提示
private struct UserRejectedRow: View {
    let text: String?
    let wasImage: Bool
    private let imageSize = UIScreen.main.bounds.width * 0.3   // 与 UserBubble 同尺寸，保持时间线节奏

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
            if let text, !text.isEmpty {
                Text(text)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.bubbleUserText)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.bubbleUserBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }

            if wasImage {
                ImageLoadFailedPlaceholder()
                    .frame(width: imageSize, height: imageSize)
            }

            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "info.circle")
                    .imageScale(.small)
                Text("This content can't be processed.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .trailing) // 👈 统一改为右对齐，紧贴气泡
        }
    }
}
```

---

### 2. `Today/Components/InputBar.swift`

#### 修改 `InputBarLimitBanner`（删减额度横幅冗余文案）
- **位置**：约 27~70 行
- **修改内容**：
  - 将原先长达 46 字符的 `Daily limit reached (\(usedCount)/\(dailyLimit)) · Request invite code`，精准删去 ` · Request invite code`；
  - 定稿为：`Daily limit reached (\(usedCount)/\(dailyLimit))`，右侧保留操作入口 `Settings >`。

```swift
/// 达到额度限制时的内联微横幅（温润极简：暖纸卡片底 + 衬线小字 + 品牌点缀）
struct InputBarLimitBanner: View {
    var usedCount: Int = 5
    var dailyLimit: Int = 5
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.brandInk)

                // 精简文案：仅陈述客观状态，避免小屏被挤压折行
                Text("Daily limit reached (\(usedCount)/\(dailyLimit))")
                    .font(AppTheme.Font.statusNote)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: AppTheme.Space.paddingXS) {
                    Text("Settings")
                        .font(AppTheme.Font.metaNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingS)
            .background {
                Capsule()
                    .fill(AppTheme.Color.cardBg)
            }
            .overlay {
                Capsule()
                    .stroke(AppTheme.Color.border, lineWidth: 0.5)
            }
            .shadow(color: AppTheme.Shadow.cardColor, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}
```

---

## 四、 验收检查清单（QA Checklist）

落地 Agent 完成上述代码修改后，必须逐一核对以下验收项：

- [ ] **编译验证**：`xcodebuild -scheme AIEnglishApp ...` 必须通过，无编译警告。
- [ ] **01 / 02 发送失败行**：
  - 文案严格为 `Check your connection and try again.`；
  - 图标为顺时针小箭头 `arrow.clockwise`；
  - 颜色严格为 `AppTheme.Color.danger`；
  - 02 带图发送失败时，气泡中显示的是用户刚拍的**真实原图**，不得为灰色方块。
- [ ] **03 离线照片重试行**：
  - 文案、图标、颜色与 01/02 100% 保持一致；
  - 气泡中显示用户离线拍摄的原图。
- [ ] **04-A / 04-B 合规拦截**：
  - 提示文案严格为 `This content can't be processed.`（无后半句）；
  - 对齐方式严格为**右对齐（`.trailing`）**，紧贴用户文本气泡或方块右下；
  - 04-B 拦截图片方块内部**无任何文字**，仅居中显示一枚 16pt 警告小三角（复用 `ImageLoadFailedPlaceholder`）。
- [ ] **05 额度横幅**：
  - 文案严格为 `Daily limit reached (5/5)` + 右侧 `Settings >`，小屏无省略号。
