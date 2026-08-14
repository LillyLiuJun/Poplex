# Onboarding 错误态三档拆分 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Onboarding Capture 页生成失败的错误态按三档拆分（断网 / 内容被拒 / 其它），各配专属文案与按钮行为；Tab1 的 contentBlocked 提示句同步为新文案。

**Architecture:** 分类逻辑做成纯函数放 Onboarding 层（服务层 `AIService.swift` 不动）；ViewModel 用 `errorKind` enum 取代 `errorMessage` 字符串；视图按档位切换文案与按钮。

**Tech Stack:** SwiftUI / iOS 17+ / @Observable / Swift Testing（`@Test` + `#expect`）/ XCTest target `AIEnglishAppTests`（单文件 `AIEnglishAppTests.swift`）。

**Spec:** `docs/superpowers/specs/2026-08-14-onboarding-error-states-design.md`

## Global Constraints

- 文案（逐字，不得改写）：
  - 断网：`Network unavailable. Check your network and try again.`
  - 内容被拒：`This content can't be processed. Try another one.`
  - 其它：`Something went wrong. Retry generation.`
  - Tab1 同步句（`TodayViewModel.swift:211`）：旧 `This moment can't be turned into a lesson. Try another one.` → 新 `This content can't be processed. Try another one.`
- 服务层 `Services/AIService.swift`（含 `AIServiceError`）一行不动。
- 预设卡路径（`startWithCard` 静态样本分支）一行不动——错误页只可能出自选照片路径。
- 放弃态文案与机制（`retryCount >= 2` → "No worries — you can explore inside the app."）不动。
- Tab1 的 `SendFailedRow`（"No connection — tap to retry."）不动。
- 按钮样式沿用现有 token（`AppTheme.Font.buddy` / `brandStrong` / `brandWash`），不新增任何 token、不写死字号/颜色。
- 所有新增产品文案为英文（UI copy 规则）。

---

### Task 1: OnboardingErrorKind enum + classify 纯函数

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingViewModel.swift`（文件头部、imports 之后新增 enum；`OnboardingViewModel` 类定义不动）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（在 `// MARK: - OnboardingViewModel tests` 之前新增 `OnboardingErrorKindTests` struct）

**Interfaces:**
- Produces: `enum OnboardingErrorKind { case offline, contentBlocked, generic }`、`static func classify(error: Error, isConnected: Bool) -> OnboardingErrorKind`（enum 的 static 方法）。Task 2/3 依赖这两个符号。

- [ ] **Step 1: 写失败的测试**

在 `AIEnglishAppTests/AIEnglishAppTests.swift` 中，`// MARK: - OnboardingViewModel tests`（约 899 行）之前插入：

```swift
// MARK: - OnboardingErrorKind classify tests

struct OnboardingErrorKindTests {

    // contentBlocked 优先于一切：即使网络正常也判被拒
    @Test func contentBlockedWinsEvenWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.contentBlocked, isConnected: true) == .contentBlocked)
    }

    // 断网类 URLError 码逐个归 offline
    @Test func offlineURLErrorCodesMapToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.notConnectedToInternet), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.networkConnectionLost), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.dataNotAllowed), isConnected: true) == .offline)
        #expect(OnboardingErrorKind.classify(error: URLError(.internationalRoamingOff), isConnected: true) == .offline)
    }

    // NetworkMonitor 兜底：非断网码但设备无网 → offline
    @Test func disconnectedFallbackMapsToOffline() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: false) == .offline)
    }

    // 有网时的超时 / 服务器错误 → generic
    @Test func serverAndTimeoutMapToGenericWhenConnected() {
        #expect(OnboardingErrorKind.classify(error: URLError(.timedOut), isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: URLError(.badServerResponse), isConnected: true) == .generic)
    }

    // 服务层其它错误与未知错误 → generic
    @Test func otherErrorsMapToGeneric() {
        #expect(OnboardingErrorKind.classify(error: AIServiceError.decodingFailed, isConnected: true) == .generic)
        #expect(OnboardingErrorKind.classify(error: NSError(domain: "test", code: 1), isConnected: true) == .generic)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/OnboardingErrorKindTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `cannot find 'OnboardingErrorKind' in scope`（对应 5 个用例报错）。

- [ ] **Step 3: 实现 enum + classify**

在 `AIEnglishApp/Onboarding/OnboardingViewModel.swift` 的 `import UIKit` 之后、`@Observable` 类之前插入：

```swift
/// Onboarding 生成失败的三种情境，按「用户能做的动作」区分：
/// 断网可自助恢复（连网重试）、内容被拒需换素材、其余只能重试。
enum OnboardingErrorKind {
    case offline          // 断网
    case contentBlocked   // 内容被服务端安全过滤拦截
    case generic          // 其它（超时/服务器/解码等）

    /// 把一次生成失败翻译成档位。纯函数：不碰网络/单例，便于单测。
    /// 判定顺序：服务端明确信号（contentBlocked）优先；URLError 断网码次之；
    /// NetworkMonitor 真实网络状态兜底；其余归 generic。
    static func classify(error: Error, isConnected: Bool) -> OnboardingErrorKind {
        if case AIServiceError.contentBlocked = error { return .contentBlocked }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return .offline
            default:
                break
            }
        }
        if !isConnected { return .offline }
        return .generic
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/OnboardingErrorKindTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 5 个用例全部 `passed`。

- [ ] **Step 5: Commit**

```bash
git add AIEnglishApp/Onboarding/OnboardingViewModel.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(onboarding): OnboardingErrorKind 三档分类纯函数 + 单测"
```

---

### Task 2: ViewModel 改造（errorKind / retryCount 规则 / chooseAnother）

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingViewModel.swift`（`errorMessage` 字段、`generate()` catch、`reset()`；新增 `chooseAnother()`）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（更新 `OnboardingViewModelTests`，约 1022–1121 行；Mocks 区约 397–428 行新增 `OfflineMock`）

**Interfaces:**
- Consumes: `OnboardingErrorKind.classify(error:isConnected:)`（Task 1）
- Produces: `OnboardingViewModel.errorKind: OnboardingErrorKind?`（`errorMessage` 删除）、`func chooseAnother()`。Task 3 依赖。

**背景（为什么改既有测试）：** `OnboardingViewModelTests` 里 3 个失败路径用例当前在 main 上就是红的（预设卡改静态数据后 `startWithCard` 永不失败，`generateFailureSetsErrorAndIncrementsRetry` / `repeatedFailuresAccumulateRetryCount` / `retryAfterFailureSucceeds` 断言不再成立）。本任务把它们改写为 `startWithImage` 走真实 service 路径，顺手修掉这批存量红。

- [ ] **Step 1: 先改测试（含存量红的改写与新用例）**

`AIEnglishAppTests/AIEnglishAppTests.swift` 的 Mocks 区（`FailOnceMock` 之后，约 428 行）新增：

```swift
/// 总是抛断网错误的 mock。
private struct OfflineMock: AIServicing {
    func generate(text: String?, image: UIImage?, context: ContextTurn?,
                  presetCardId: String?, source: String?) async throws -> AIEnvelope {
        throw URLError(.notConnectedToInternet)
    }
}
```

`OnboardingViewModelTests`（1022–1121 行）按下面逐项改：

a) 全部 `#expect(vm.errorMessage == nil)` → `#expect(vm.errorKind == nil)`，`#expect(vm.errorMessage != nil)` → `#expect(vm.errorKind != nil)`（涉及 `initialStateIsEmpty` / `startWithCardSuccessSetsResult` / `retryAfterFailureSucceeds` / `resetClearsAllState` / `generateWithNoSelectionExitsEarly`）。

b) `generateFailureSetsErrorAndIncrementsRetry` 改写为（走图片路径 + FailingMock 的 `.badServerResponse` → generic）：

```swift
    // generate 失败（服务器错误类）：errorKind == .generic、retryCount 为 1、generationResult 为 nil、loading 回 false
    @Test func generateFailureSetsErrorAndIncrementsRetry() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .generic)
        #expect(vm.retryCount == 1)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
    }
```

c) `repeatedFailuresAccumulateRetryCount` 改写为：

```swift
    // 连续失败两次：retryCount 累加到 2
    @Test func repeatedFailuresAccumulateRetryCount() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        await vm.retry()
        #expect(vm.retryCount == 2)
    }
```

d) `retryAfterFailureSucceeds` 改写为（FailOnceMock 先抛 `.notConnectedToInternet` → offline 档，重试成功清空）：

```swift
    // retry 成功（第一次断网失败后 retry）：retryCount 归零、generationResult 有值、errorKind 清空
    @Test func retryAfterFailureSucceeds() async {
        let vm = OnboardingViewModel(service: FailOnceMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.retryCount == 1)
        #expect(vm.errorKind == .offline)
        await vm.retry()
        #expect(vm.generationResult != nil)
        #expect(vm.retryCount == 0)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }
```

e) 新增三个用例（插在 `resetClearsAllState` 之前）：

```swift
    // 断网：errorKind == .offline、retryCount 累加
    @Test func offlineFailureClassifiedAsOffline() async {
        let vm = OnboardingViewModel(service: OfflineMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        #expect(vm.retryCount == 1)
    }

    // 内容被拒：errorKind == .contentBlocked、不占重试次数
    @Test func contentBlockedDoesNotIncrementRetry() async {
        let vm = OnboardingViewModel(service: ContentBlockedMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .contentBlocked)
        #expect(vm.retryCount == 0)
    }

    // chooseAnother：清空全部状态，回到选择页条件（selectedCard/Image 均 nil）
    @Test func chooseAnotherClearsAllState() async {
        let vm = OnboardingViewModel(service: OfflineMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        vm.chooseAnother()
        #expect(vm.selectedCard == nil)
        #expect(vm.selectedImage == nil)
        #expect(vm.generationResult == nil)
        #expect(vm.errorKind == nil)
        #expect(vm.retryCount == 0)
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/OnboardingViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `'OnboardingViewModel' has no member 'errorKind'`、`cannot find 'chooseAnother'`。

- [ ] **Step 3: 实现 ViewModel 改动**

`AIEnglishApp/Onboarding/OnboardingViewModel.swift`：

a) 字段替换（第 10 行）：

```swift
    var errorKind: OnboardingErrorKind?
```

b) `reset()`（37–44 行）里 `errorMessage = nil` → `errorKind = nil`：

```swift
    func reset() {
        selectedCard = nil
        selectedImage = nil
        generationResult = nil
        isLoading = false
        errorKind = nil
        retryCount = 0
    }
```

c) `generate()` 开头（47–49 行）`errorMessage = nil` → `errorKind = nil`。

d) `generate()` 的 catch（69–72 行）：

```swift
        } catch {
            let kind = OnboardingErrorKind.classify(error: error, isConnected: NetworkMonitor.shared.isConnected)
            if kind != .contentBlocked { retryCount += 1 }   // 被拒不占重试次数：同图重试必再被拒
            errorKind = kind
        }
```

e) `reset()` 之后新增：

```swift
    /// 内容被拒时的动作：清空已选照片与结果，回到选择页（`isSelecting` 重新成立）。
    func chooseAnother() {
        reset()
    }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/OnboardingViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: `OnboardingViewModelTests` 全部 passed（含本次修红的 3 个存量用例）。

- [ ] **Step 5: Commit**

```bash
git add AIEnglishApp/Onboarding/OnboardingViewModel.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(onboarding): ViewModel 错误态改 errorKind 三档 + chooseAnother + 修存量红"
```

---

### Task 3: CaptureView 三档渲染（文案 + 按钮行为）

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingCaptureView.swift`（`fallbackStage`，约 614–644 行）

**Interfaces:**
- Consumes: `viewModel.errorKind: OnboardingErrorKind?`（Task 2）、`viewModel.chooseAnother()`

**测试策略：** 本项目约定优先单测、不做复杂 UI 自动化。本任务无新增单测，验证靠编译 + 模拟器人工截图（见 Step 4）。

- [ ] **Step 1: 改 `fallbackStage`**

把 `OnboardingCaptureView.swift` 614–644 行的 `fallbackStage` 整体替换为：

```swift
    // MARK: 兜底态：纸雕插画 + 文案(+按钮)，在内容区剩余空间整体居中
    // isFailed = 重试两次后放弃（引导进 App）；否则为按情境分档的可重试出错态。
    private func fallbackStage(isFailed: Bool) -> some View {
        let kind = viewModel.errorKind ?? .generic
        VStack(spacing: AppTheme.Space.paddingSection) {
            OnboardingFallbackIllustration(kind: isFailed ? .explore : .retry)

            VStack(spacing: AppTheme.Space.paddingCard) {
                Text(isFailed
                     ? "No worries — you can explore inside the app."
                     : fallbackCopy(for: kind))
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)

                if !isFailed {
                    Button(action: {
                        if kind == .contentBlocked {
                            viewModel.chooseAnother()          // 换素材：回选择页，不重试
                        } else {
                            Task { await viewModel.retry() }
                        }
                    }) {
                        Text(kind == .contentBlocked ? "Try another photo" : "Try again")
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
        .frame(maxWidth: .infinity)
    }

    /// 三档文案（Warm Minimalism：陈述事实 + 可行动）。被拒档与 Tab1 同步句一致。
    private func fallbackCopy(for kind: OnboardingErrorKind) -> String {
        switch kind {
        case .offline:        return "Network unavailable. Check your network and try again."
        case .contentBlocked: return "This content can't be processed. Try another one."
        case .generic:        return "Something went wrong. Retry generation."
        }
    }
```

- [ ] **Step 2: 编译确认**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 模拟器截图验收三档**

安装到模拟器（iOS 18.6 的 iPhone 16），逐档触发并截图（断网：关模拟器 Wi-Fi 或开飞行模式；被拒：需能命中 422 的内容；其它：断后端/弱网模拟）。截图发 PM 确认后再合。

- [ ] **Step 4: Commit**

```bash
git add AIEnglishApp/Onboarding/OnboardingCaptureView.swift
git commit -m "feat(onboarding): 错误态三档文案与按钮行为（断网/被拒/其它）"
```

---

### Task 4: Tab1 contentBlocked 文案同步一句

**Files:**
- Modify: `AIEnglishApp/Today/TodayViewModel.swift:211`

**Interfaces:**
- Consumes: 无（纯字符串替换）。现有测试只断言 `contentBlockedMessage != nil`（`AIEnglishAppTests.swift:590`），不锁文案原文，不会红。

- [ ] **Step 1: 替换文案**

`AIEnglishApp/Today/TodayViewModel.swift:211`：

```swift
            contentBlockedMessage = "This content can't be processed. Try another one."
```

- [ ] **Step 2: 跑既有 contentBlocked 用例回归**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/TodayViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: `TodayViewModelTests` 全部 passed。

- [ ] **Step 3: Commit**

```bash
git add AIEnglishApp/Today/TodayViewModel.swift
git commit -m "style(today): contentBlocked 提示句与 Onboarding 被拒档统一"
```

---

## 验收清单（全部任务完成后）

1. `xcodebuild build` 通过。
2. 三档各自触发时显示对应文案与按钮（截改前/改后图发 PM）：
   - 断网 → `Network unavailable. Check your network and try again.` + Try again
   - 被拒 → `This content can't be processed. Try another one.` + Try another photo（点击回选择页）
   - 其它 → `Something went wrong. Retry generation.` + Try again；重试两次后进放弃态（文案不变）
3. 预设卡路径正常生成（回归，不该被本次改动影响）。
4. Tab1 被拒提示显示新句。
