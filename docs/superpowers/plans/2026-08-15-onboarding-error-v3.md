# Onboarding 错误态 v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 断网两条路径完全同构（不生成内容，显示素材图 + 常驻状态条 + Try again）；被拒不展示图片、清选中回空上传区（无 Continue）；toast 与按钮重合问题随状态条替代而消失。

**Architecture:** VM 层：预设卡断网分支不再设置 `generationResult`；新增 `rejectSelection()` 清选中；状态条文案映射做成 `OnboardingErrorKind` 的纯函数扩展。视图层：失败分支 = 素材图 + `FailureStatusBar`（常驻、Try again）；被拒 toast 挂到 body 外层（切回选择页后仍可见）。

**Tech Stack:** SwiftUI / iOS 17+ / @Observable / Swift Testing。后端零改动。

**Spec:** `docs/superpowers/specs/2026-08-15-onboarding-error-v3-design.md`

## Global Constraints

- 文案逐字契约：
  - 断网状态条（常驻）：`Network unavailable. Check your network and try again.`
  - 其它状态条（常驻）：`Something went wrong. Please try again.`
  - 被拒 toast（4s）：`This content can't be processed. Try another one.`
  - 按钮：`Try again`
- 断网两路径同构：不生成内容（generationResult 保持 nil），只显示所选素材图
- 被拒不展示图片；清选中回空上传区；**无 Continue**（fail-open 唯一例外）
- 断网/其它档 Continue 可用（bottomButton 条件不变：有选中且非 loading）
- 待重试记录/seed/打标补发机制不动；后端不动
- 样式走 AppTheme token；不新增 token；SF Symbol 图标字号豁免
- commit 追加 trailer `Co-Authored-By: Claude <noreply@anthropic.com>`

---

### Task 1: Onboarding 错误态 v3（单一切片）

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingViewModel.swift`（预设卡断网分支、`rejectSelection()`、catch、`OnboardingErrorKind` 文案映射扩展）
- Modify: `AIEnglishApp/Onboarding/OnboardingCaptureView.swift`（失败分支 + `FailureStatusBar`、errorToast 收敛、被拒 toast 外移）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`

**Interfaces:**
- Produces: `OnboardingViewModel.rejectSelection()`、`OnboardingErrorKind.failureBarCopy: String?`（Task 后续无依赖；纯本切片）

**背景：** 现状（main `e50c26f`）：预设卡断网时 `generationResult = card.staticCard`（要改）；失败分支 = `resultImage` 预览 + 独立 `errorToast`（断网/其它用 `AppToast`/`AutoDismissingAppToast`，与 Continue 重合）；被拒时图片保留（要改）。

- [ ] **Step 1: 改写/新增测试（先红）**

`AIEnglishAppTests/AIEnglishAppTests.swift`：

a) 改写 `presetCardOfflineSkipsSaveButShowsCard`（约 1362 行）——断网不再生成内容：

```swift
    // 预设卡断网：不生成内容（generationResult 为 nil）、不调 saver、errorKind == .offline、
    // 粘性标记置位。与自选图断网完全同构。
    @Test func presetCardOfflineSkipsSaveAndDoesNotGenerate() async {
        let saver = CountingPresetCardSaver()
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { false }
        )
        await vm.startWithCard(PresetCard.all[0])
        #expect(vm.generationResult == nil)          // 断网不生成内容
        #expect(saver.callCount == 0)                // 断网零请求
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
        #expect(vm.isLoading == false)
    }
```

b) 新增被拒清选中用例（`contentBlockedClassifiedAsBlocked` 之后）：

```swift
    // 被拒：rejectSelection 清空选中（图片不上屏、回空上传区）、errorKind 保留驱动 toast、
    // 粘性标记不受影响
    @Test func contentBlockedRejectsSelectionAndKeepsErrorKind() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock(), isConnected: { true })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
        #expect(vm.selectedImage == nil)
        #expect(vm.selectedCard == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
        #expect(vm.offlineFailureOccurred == false)
    }
```

c) 新增 Try again 链路用例（断网失败 → 恢复 → retry 成功）：

```swift
    // Try again 链路：断网失败 → 网络恢复 → retry() 原素材重新生成成功
    @Test func retryAfterOfflineRecoveryGeneratesCard() async {
        let vm = OnboardingViewModel(service: OfflineMock(), isConnected: { false })
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.generationResult == nil)

        // 模拟网络恢复后的重试：同 VM 不可换 mock——改用「恢复后重新生成」语义：
        // retry() 仍走同一个 OfflineMock 会再失败，因此这里验证 retry 入口存在且再次落 offline。
        await vm.retry()
        #expect(vm.errorKind == .offline)
        #expect(vm.offlineFailureOccurred == true)
    }
```

（注：单 VM 实例无法中途换 mock，全成功链路由既有 `retryAfterFailureSucceeds`（FailOnceMock：首败后成功）覆盖——该用例已锁定「retry 成功 → generationResult != nil、errorKind nil」。本用例补「断网重试仍安全失败、粘性保持」。）

d) 新增状态条文案映射纯函数用例（`OnboardingErrorKindTests` 内）：

```swift
    // 状态条文案映射：断网/其它有文案且常驻；被拒不映射（走 toast）
    @Test func failureBarCopyMapping() {
        #expect(OnboardingErrorKind.offline.failureBarCopy == "Network unavailable. Check your network and try again.")
        #expect(OnboardingErrorKind.generic.failureBarCopy == "Something went wrong. Please try again.")
        #expect(OnboardingErrorKind.contentBlocked.failureBarCopy == nil)
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(error:|Test case.*failed)" | head -5`

Expected: 编译/断言失败 — `'OnboardingErrorKind' has no member 'failureBarCopy'`、`'OnboardingViewModel' has no member 'rejectSelection'`、`presetCardOfflineSkipsSaveAndDoesNotGenerate` 失败（generationResult 当前非 nil）。

- [ ] **Step 3: 实现 ViewModel**

`AIEnglishApp/Onboarding/OnboardingViewModel.swift`：

a) `OnboardingErrorKind` 之后加文案映射扩展：

```swift
extension OnboardingErrorKind {
    /// 失败态状态条文案（常驻）。被拒不映射——走 toast + 回上传页。
    var failureBarCopy: String? {
        switch self {
        case .offline: return "Network unavailable. Check your network and try again."
        case .generic: return "Something went wrong. Please try again."
        case .contentBlocked: return nil
        }
    }
}
```

b) 预设卡断网分支（约 127-131 行）改：

```swift
                } else {
                    presetSavedToServer = false
                    errorKind = .offline
                    offlineFailureOccurred = true
                    // 不设 generationResult：断网不生成内容，失败分支显示所选素材图 + 状态条
                }
```

c) `generate()` catch（约 141-145 行）改：

```swift
        } catch {
            let kind = OnboardingErrorKind.classify(error: error, isConnected: isConnected())
            errorKind = kind
            if kind == .offline {
                offlineFailureOccurred = true
            } else if kind == .contentBlocked {
                // 被拒：清选中回空上传区（图片不上屏）。不允许空手进 App——换新图是唯一前进路径。
                rejectSelection()
            }
        }
```

d) `reset()` 之后加：

```swift
    /// 内容被拒：清空选中回上传页（图片不上屏）。errorKind 保留驱动 toast（4s 自动消失）；
    /// offlineFailureOccurred 不动（被拒不是断网失败）。
    func rejectSelection() {
        selectedCard = nil
        selectedImage = nil
        generationResult = nil
        isLoading = false
        presetSavedToServer = false
    }
```

- [ ] **Step 4: 实现 CaptureView**

`AIEnglishApp/Onboarding/OnboardingCaptureView.swift`：

a) 失败分支（约 545-558 行）改为图 + 状态条：

```swift
                        } else if let image = resultImage {
                            // 失败态（断网/其它）：保留用户所选素材图 + 常驻状态条（fail-open——
                            // 内容在、状态条说明原因、Try again 可重试、Continue 可用）
                            VStack(spacing: 0) {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 195)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                                    .allowsHitTesting(false)

                                if let copy = viewModel.errorKind?.failureBarCopy {
                                    FailureStatusBar(copy: copy) {
                                        Task { await viewModel.retry() }
                                    }
                                }
                            }
                            .transition(.opacity)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer()
                        } else {
                            Spacer()
                        }
```

b) `resultContent` 的 ZStack 里删除 `errorToast` 挂载（约 573-574 行的 `errorToast` 调用）。

c) 删除 `errorToast` 与 `errorToastCopy`（约 679-704 行）；`bottomButton` 不变。

d) body 外层（ZStack 之后）加被拒 toast（挂两个内容区之上）：

```swift
        .overlay(alignment: .bottom) {
            // 被拒 toast：4s 自动消失。挂在 body 外层——被拒后切回选择页（空上传区），
            // toast 必须高于两个内容区才能显示；选择页无 Continue 按钮，无重合。
            if viewModel.errorKind == .contentBlocked {
                AutoDismissingAppToast(
                    message: Binding(
                        get: {
                            viewModel.errorKind == .contentBlocked
                                ? "This content can't be processed. Try another one."
                                : nil
                        },
                        set: { if $0 == nil { viewModel.errorKind = nil } }
                    ),
                    systemImage: "exclamationmark.triangle",
                    lifetime: AppTheme.Motion.toastLifetime
                )
                .padding(.bottom, AppTheme.Space.paddingSection)
            }
        }
```

e) 文件内（`OnboardingUploadActionButton` 旁或文件尾部）加 `FailureStatusBar`：

```swift
/// 断网/其它失败的状态条：嵌在素材图下方、常驻（不自动消失）。
/// 网络恢复由既有 onChange 清 errorKind → 状态条随之消失（图保留）。
private struct FailureStatusBar: View {
    let copy: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            Text(copy)
                .font(AppTheme.Font.chineseFaint)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Space.paddingCard)

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
    }
}
```

（网络恢复 onChange / `networkRecovered()` 逻辑不动。）

- [ ] **Step 5: 运行测试确认通过**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(\*\* TEST|Test case.*failed)" | tail -3`

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 6: Commit**

```bash
git add AIEnglishApp/Onboarding/OnboardingViewModel.swift AIEnglishApp/Onboarding/OnboardingCaptureView.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(onboarding): 错误态 v3——断网不生成内容 + 状态条 + 被拒不展示图片"
```

---

## 验收清单

1. `xcodebuild test -only-testing:AIEnglishAppTests` 全绿
2. 模拟器截图发 PM 确认：
   - 断网 + 预设卡：预设卡图（**无卡片内容**）+ 图下常驻状态条 + Try again + Continue；恢复网络状态条消失、图保留
   - 断网 + 自选图：原图 + 同款状态条 + Try again + Continue
   - 其它失败：图 + "Something went wrong. Please try again." 状态条 + Try again
   - 被拒：toast + 回到空上传区（图片不上屏、无 Continue）；换新图成功生成
   - Try again（有网）重新生成成功；断网离开 Tab1 待重试记录照旧；正常有网流程回归
3. 后端零改动，无需部署
