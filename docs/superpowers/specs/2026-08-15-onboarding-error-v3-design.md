# Onboarding 错误态 v3：状态条 + 被拒不展示图片 — 设计文档

日期：2026-08-15
状态：与 PM 逐项确认，待实现
基线：main `e50c26f`（v2：fail-open + toast + 待重试记录）

## 一、背景与问题

v2 落地后 PM 验收反馈三点：

1. **预设卡断网与自选图不同构**：预设卡断网时仍照常显示卡片内容（静态卡），
   而自选图断网是失败态——两条路径前端体验不一致。要求：断网时**都不生成内容**，
   只显示所选素材图。
2. **独立 toast 的问题**：断网/其它失败的 toast 文案较长、悬浮在底部，与
   Continue 按钮**视觉重合**；且文案脱离内容区，观感「空」。
3. **被拒图片仍上屏**：被拒档当前保留用户图片——不合规图片不该展示。

## 二、产品体验

| 场景 | 呈现 | 出口 |
|---|---|---|
| 生成中 / 成功 | 不变（loading 卡 / 结果卡 + Get Started） | — |
| **断网**（两路径完全同构） | 显示所选素材图（自选图原图 / 预设卡 asset 图，**不生成内容**）+ 图下方**常驻状态条**：`Network unavailable. Check your network and try again.` + **Try again**（原素材重新生成）；网络恢复 → 状态条消失、图保留 | Try again / Continue / 返回 |
| **其它失败** | 同构：图 + 常驻状态条 `Something went wrong. Please try again.` + Try again | Try again / Continue / 返回 |
| **被拒** | toast（4s）`This content can't be processed. Try another one.`；内容区**回到空上传区**（图片不上屏、选中清空、**无 Continue**——不允许空手进 App，首页无欢迎页） | **换新图 / 返回** |
| 断网离开 → Tab1 待重试记录 | 不变（带图记录 + Retry） | — |

### 原则

- **Fail-open 保留**：断网/其它档 Continue 永可用。
- **被拒是 fail-open 的唯一例外**：内容被拒后必须换素材才能前进（空手进 App 会落到无欢迎页的空白首页，不可接受）。
- 两条路径前端完全同构：选中什么显示什么，断网只是「不生成」。

## 三、范围

1. 预设卡断网不生成内容（VM 分支改造）
2. 断网/其它失败：图片 + 常驻状态条 + Try again（新组件，替代独立 toast）
3. 被拒：不展示图片 + 回空上传区 + 无 Continue
4. 被拒 toast 保留（4s）；toast 与按钮重合问题随断网/其它档改状态条而消失

### 明确不做

- 断网自动重试队列；被拒自动换图；首页欢迎页
- 待重试记录、seed 兜底、打标补发、Tab1 Retry 机制全部保留不动

## 四、实现要点

### 1. ViewModel（`OnboardingViewModel.swift`）

a) 预设卡断网分支：**不再设置 `generationResult`**（保持 nil），与自选图同落
失败分支；`errorKind = .offline` + `offlineFailureOccurred = true` 不变：

```swift
                } else {
                    presetSavedToServer = false
                    errorKind = .offline
                    offlineFailureOccurred = true
                    // 不设 generationResult：断网不生成内容，失败分支显示所选素材图 + 状态条
                }
```

b) 被拒清选中（新方法；`errorKind` 保留供 toast，`offlineFailureOccurred` 不动）：

```swift
    /// 内容被拒：清空选中回上传页（图片不上屏）。不允许空手进 App——
    /// 换新图是唯一前进路径；errorKind 保留驱动 toast，4s 自动消失。
    func rejectSelection() {
        selectedCard = nil
        selectedImage = nil
        generationResult = nil
        isLoading = false
        presetSavedToServer = false
    }
```

c) `generate()` 的 catch：`kind == .contentBlocked` 时调用 `rejectSelection()`
（在设 `errorKind = kind` 之后；`offlineFailureOccurred` 只在 offline 置位，不变）。

d) `retry()` 已有（Try again 用：原素材重新生成）。

### 2. CaptureView（`OnboardingCaptureView.swift`）

a) 失败分支（`generationResult == nil && !isLoading && resultImage != nil`）：
素材图 + 新组件 `FailureStatusBar`：

```swift
/// 断网/其它失败的状态条：嵌入图片下方常驻（不自动消失），
/// 网络恢复由既有 onChange 清 errorKind → 状态条消失。
struct FailureStatusBar: View {
    let copy: String          // 由 errorKind 映射（见 c）
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            Text(copy)
                .font(AppTheme.Font.chineseFaint)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button(action: onRetry) {
                Text("Try again")
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.brandWash, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.vertical, AppTheme.Space.paddingCard)
    }
}
```

b) 失败分支布局：图（现有失败预览，195 高）+ 其下 `FailureStatusBar`
（文案映射：`.offline → "Network unavailable. Check your network and try again."`、
`.generic → "Something went wrong. Please try again."`；`.contentBlocked` 不进
状态条——被拒走 toast + 空上传区）。

c) 删除现有 `errorToast` 的断网/其它两档（`AutoDismissingAppToast` 分支）；
被拒档 toast 保留（4s）。**挂载位置从 resultContent 内部移到 body 外层 ZStack**
（被拒后切回 selectionContent，toast 必须挂在两个内容区之上才能显示）；
被拒时无 Continue 按钮、页面为空上传区，无重合问题。`errorToastCopy` 相应收敛。

d) `bottomButton` 条件**不变**（有选中且非 loading）——被拒清选中后自然无
Continue。

e) 网络恢复 onChange（`networkRecovered()`）不变。

### 3. 文案契约（逐字）

- 断网状态条（常驻）：`Network unavailable. Check your network and try again.`
- 其它状态条（常驻）：`Something went wrong. Please try again.`
- 被拒 toast（4s）：`This content can't be processed. Try another one.`
- 按钮：`Try again`

### 4. 测试计划

- 改写 `presetCardOfflineSkipsSaveButShowsCard`：`generationResult == nil`
  （不生成内容）、saver 零调用、`errorKind == .offline`、
  `offlineFailureOccurred == true`、`isLoading == false`
- 新增：被拒 → `rejectSelection` 清选中（selectedCard/Image nil）、
  `errorKind == .contentBlocked`、`offlineFailureOccurred == false`
- 新增：断网 → `networkRecovered()` → `retry()` 成功（有网 mock）→
  `generationResult != nil`、`errorKind == nil`（Try again 链路）
- 状态条文案映射纯函数单测（errorKind → copy，被拒不映射）
- 全量回归

## 五、验收

1. `xcodebuild test` 全绿
2. 模拟器截图发 PM 确认：
   - 断网 + 预设卡：显示预设卡图（**无卡片内容**）+ 图下常驻状态条 + Try again + Continue；恢复网络状态条消失、图保留
   - 断网 + 自选图：原图 + 同款状态条 + Try again + Continue
   - 其它失败：图 + "Something went wrong" 状态条 + Try again
   - 被拒：toast + 回到空上传区（**图片不上屏**、无 Continue）；换新图成功生成
   - Try again（有网）：重新生成成功
   - 断网离开：Tab1 待重试记录照旧；正常有网流程回归
