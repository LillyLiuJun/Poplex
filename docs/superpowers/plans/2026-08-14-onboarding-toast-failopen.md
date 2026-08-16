# Onboarding Fail-open + Tab1 待重试记录 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 断网时 onboarding 不挡用户：内容照常显示/保留 + 常驻 toast + Continue 可用；带未成功内容离开时本地持久化一条待重试记录（杀 app 不丢），Tab1 展示记录并可 Retry。

**Architecture:** 三层：`PendingRetryStore`（持久化：记录 JSON 进 UserDefaults、照片 JPEG 进 Documents）→ Onboarding 层（断网跳过落库/不调 AI + errorKind 驱动 toast + completeOnboarding 记账）→ Tab1 层（时间线注入 PendingRetryRow + Retry 复用现有生成链路）。

**Tech Stack:** SwiftUI / iOS 17+ / @Observable / Swift Testing / 无后端改动（落库复用 save-preset-card）。

**Spec:** `docs/superpowers/specs/2026-08-14-onboarding-toast-failopen-design.md`

## Global Constraints

- 文案逐字契约：
  - Onboarding 断网 toast（常驻）：`Network unavailable. Check your network and try again.`
  - 被拒（4s）：`This content can't be processed. Try another one.`
  - 其它（4s）：`Something went wrong. Please try again.`
  - Tab1 待重试记录：`You were offline, so this wasn't generated.` + 按钮 `Retry`
- 预设卡与自选图前端体验完全同构；断网时不发任何请求（预设卡不落库、自选图不调 AI）
- 仅断网档写待重试记录（被拒/其它不写）
- 移除：fallbackStage、Try again 按钮、No worries、retryCount/2 次门控、chooseAnother、#28 两处断网 guard
- #28 的有网落库、打标补发、seed 兜底机制保留不动；onboarding_completed 判定不动
- 全部样式走 AppTheme token；不新增 token；SF Symbol 图标字号豁免
- commit 追加 trailer `Co-Authored-By: Claude <noreply@anthropic.com>`
- 工作目录：<repo>-onboarding-polish（main）

---

### Task 1: PendingRetryStore 持久化层

**Files:**
- Create: `AIEnglishApp/Services/PendingRetryStore.swift`
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（新增 `PendingRetryStoreTests` suite，放在 `ImageCacheTests` 之前）

**Interfaces:**
- Produces（Task 2/3 依赖）：
  - `enum PendingRetrySource: String, Codable { case presetCard, photo }`
  - `struct PendingRetryRecord: Codable, Identifiable { let id: UUID; let source: PendingRetrySource; let presetCardId: String?; let presetImageName: String?; let photoFileName: String?; let createdAt: Date }`
  - `final class PendingRetryStore`（单例 `shared`）：`func savePreset(cardId: String, imageName: String)`、`func savePhoto(_ image: UIImage) throws`、`func load() -> [PendingRetryRecord]`、`func remove(id: UUID)`、`func photoImage(for record: PendingRetryRecord) -> UIImage?`
  - 测试注入点：`init(defaults: UserDefaults, documentsDir: URL)`（非单例路径，便于隔离 suite）

- [ ] **Step 1: 写失败测试**

在 `AIEnglishAppTests/AIEnglishAppTests.swift` 的 `// MARK: - ImageCache tests` 之前插入：

```swift
// MARK: - PendingRetryStore tests

struct PendingRetryStoreTests {

    private func makeStore(suite: String) -> (PendingRetryStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-retry-tests-\(suite)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (PendingRetryStore(defaults: defaults, documentsDir: dir), dir, defaults)
    }

    // 预设卡记录：写入 → 新实例读取（杀 app 语义）→ 字段完整
    @Test func presetRecordSurvivesReload() {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-preset")
        store.savePreset(cardId: "2", imageName: "card_scene_2")

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .presetCard)
        #expect(records[0].presetCardId == "2")
        #expect(records[0].presetImageName == "card_scene_2")
    }

    // 照片记录：照片落盘 → 新实例读取 → 图片往返一致
    @Test func photoRecordSurvivesReloadWithImage() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-photo")
        let image = UIImage(systemName: "photo")!
        try store.savePhoto(image)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        let records = reloaded.load()
        #expect(records.count == 1)
        #expect(records[0].source == .photo)
        let restored = reloaded.photoImage(for: records[0])
        #expect(restored != nil)
        #expect(restored?.size == image.size)
    }

    // remove：删除后 load 为空，且照片文件被清理
    @Test func removeClearsRecordAndFile() throws {
        let (store, dir, defaults) = makeStore(suite: "pending-retry-remove")
        let image = UIImage(systemName: "photo")!
        try store.savePhoto(image)
        let record = store.load()[0]

        store.remove(id: record.id)

        let reloaded = PendingRetryStore(defaults: defaults, documentsDir: dir)
        #expect(reloaded.load().isEmpty)
        #expect(reloaded.photoImage(for: record) == nil)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/PendingRetryStoreTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `cannot find 'PendingRetryStore' in scope`。

- [ ] **Step 3: 实现 PendingRetryStore**

创建 `AIEnglishApp/Services/PendingRetryStore.swift`：

```swift
import Foundation
import UIKit

/// 待重试记录的来源：断网未落库的预设卡 / 断网生成失败的照片。
enum PendingRetrySource: String, Codable {
    case presetCard
    case photo
}

/// 带未成功内容离开 onboarding 时持久化的待重试记录（杀 app 不丢）。
struct PendingRetryRecord: Codable, Identifiable {
    let id: UUID
    let source: PendingRetrySource
    let presetCardId: String?     // source == .presetCard
    let presetImageName: String?  // 内置 asset 图名（展示用）
    let photoFileName: String?    // source == .photo（图片文件在 Documents 下）
    let createdAt: Date
}

/// 待重试记录存储：记录 JSON 存 UserDefaults，照片 JPEG 写 Documents。
/// 单例供 App 使用；init(defaults:documentsDir:) 供单测隔离。
final class PendingRetryStore {
    static let shared = PendingRetryStore(
        defaults: .standard,
        documentsDir: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    )

    private static let recordsKey = "pending_retry_records"

    private let defaults: UserDefaults
    private let documentsDir: URL

    init(defaults: UserDefaults, documentsDir: URL) {
        self.defaults = defaults
        self.documentsDir = documentsDir
    }

    // MARK: - Save

    /// 预设卡：只记元数据，图片用内置 asset（无需落盘）。
    func savePreset(cardId: String, imageName: String) {
        var records = load()
        records.removeAll { $0.source == .presetCard && $0.presetCardId == cardId }  // 幂等
        records.append(PendingRetryRecord(
            id: UUID(), source: .presetCard,
            presetCardId: cardId, presetImageName: imageName,
            photoFileName: nil, createdAt: .now
        ))
        persist(records)
    }

    /// 照片：JPEG 落盘 + 记元数据。失败抛错（调用方决定是否提示）。
    func savePhoto(_ image: UIImage) throws {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "PendingRetryStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "image encode failed"])
        }
        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: documentsDir.appendingPathComponent(fileName))
        var records = load()
        records.append(PendingRetryRecord(
            id: UUID(), source: .photo,
            presetCardId: nil, presetImageName: nil,
            photoFileName: fileName, createdAt: .now
        ))
        persist(records)
    }

    // MARK: - Load / Remove

    func load() -> [PendingRetryRecord] {
        guard let data = defaults.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([PendingRetryRecord].self, from: data)
        else { return [] }
        return records
    }

    func remove(id: UUID) {
        var records = load()
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        if let fileName = records[idx].photoFileName {
            try? FileManager.default.removeItem(
                at: documentsDir.appendingPathComponent(fileName)
            )
        }
        records.remove(at: idx)
        persist(records)
    }

    /// 照片记录的本地图片；预设卡记录返回 asset 图（两者都供 UI 展示）。
    func photoImage(for record: PendingRetryRecord) -> UIImage? {
        if record.source == .presetCard, let name = record.presetImageName {
            return UIImage(named: name)
        }
        if let fileName = record.photoFileName {
            return UIImage(contentsOfFile: documentsDir.appendingPathComponent(fileName).path)
        }
        return nil
    }

    private func persist(_ records: [PendingRetryRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.recordsKey)
        }
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/PendingRetryStoreTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 3 个用例全部 passed。

- [ ] **Step 5: Commit**

```bash
git add AIEnglishApp/Services/PendingRetryStore.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(today): PendingRetryStore 持久化待重试记录（杀 app 不丢）+ 单测"
```

---

### Task 2: Onboarding 层改造（VM + CaptureView + completeOnboarding 记账）

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingViewModel.swift`（isConnected 注入、预设卡断网跳过落库、删 retryCount/chooseAnother）
- Modify: `AIEnglishApp/Onboarding/OnboardingCaptureView.swift`（删 fallbackStage、删两处 guard、bottomButton 条件、错误 toast 挂载）
- Modify: `AIEnglishApp/Onboarding/OnboardingView.swift`（completeOnboarding 写待重试记录）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（OnboardingViewModel 相关 suite 改写）

**Interfaces:**
- Consumes: Task 1 的 `PendingRetryStore` / `PendingRetryRecord` / `PendingRetrySource`
- Produces（Task 3 依赖）：`OnboardingViewModel.errorKind`（语义不变）、`OnboardingErrorKind`（不变）

**背景：** `PresetCard` 字段：`id: String / title / imageName / staticEnglish / staticChinese`（`OnboardingScreen4View.swift`）。预设卡成功态卡片显示由 `resultContent` → `resultCard(result)` 承担；实现前先确认 `resultCard` 对预设卡路径（selectedImage == nil 时）如何取图显示（`resultImage` getter 需覆盖预设卡 asset 图——若当前预设卡成功态已能显示卡片则不动该逻辑，断网路径复用同一显示链）。

- [ ] **Step 1: 改写测试（先红）**

`AIEnglishAppTests/AIEnglishAppTests.swift` 中 OnboardingViewModel 相关用例：
a) 删除：`repeatedFailuresAccumulateRetryCount`、`contentBlockedDoesNotIncrementRetry`、`chooseAnotherClearsAllState`（这三个语义随 retryCount/chooseAnother 一起退役）
b) 改写 `generateFailureSetsErrorAndIncrementsRetry` → 去掉 retryCount 断言：

```swift
    // generate 失败（服务器错误类）：errorKind == .generic、generationResult 为 nil、loading 回 false
    @Test func generateFailureSetsErrorKind() async {
        let vm = OnboardingViewModel(service: FailingMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .generic)
        #expect(vm.generationResult == nil)
        #expect(vm.isLoading == false)
    }
```

c) 改写 `retryAfterFailureSucceeds` → 去掉 retryCount 断言：

```swift
    // retry 成功（第一次断网失败后 retry）：generationResult 有值、errorKind 清空
    @Test func retryAfterFailureSucceeds() async {
        let vm = OnboardingViewModel(service: FailOnceMock())
        await vm.startWithImage(UIImage(systemName: "photo")!)
        #expect(vm.errorKind == .offline)
        await vm.retry()
        #expect(vm.generationResult != nil)
        #expect(vm.errorKind == nil)
        #expect(vm.isLoading == false)
    }
```

d) 改写 `offlineFailureClassifiedAsOffline` → 去掉 retryCount 断言。

e) 其它用例中 `#expect(vm.retryCount == 0)` 出现处（`initialStateIsEmpty`、`resetClearsAllState`、`startWithCardSuccessSetsResult`）删除该行。

f) 新增预设卡断网用例（用带计数的 saver mock，插入 `PresetCardSavingMock` 旁）：

```swift
/// 计数 saver：记录被调用次数，可配置成败——供断网跳过落库断言用。
private final class CountingPresetCardSaver: PresetCardSaving, @unchecked Sendable {
    private(set) var callCount = 0
    private let succeeds: Bool
    init(succeeds: Bool = true) { self.succeeds = succeeds }
    func save(card: PresetCard) async -> Bool {
        callCount += 1
        return succeeds
    }
}
```

```swift
    // 预设卡断网：卡片照常显示（generationResult 为静态卡）、不调 saver、errorKind == .offline
    @Test func presetCardOfflineSkipsSaveButShowsCard() async {
        let saver = CountingPresetCardSaver()
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { false }
        )
        await vm.startWithCard(PresetCard.all[0])
        #expect(vm.generationResult != nil)          // 卡片内容照常显示
        #expect(saver.callCount == 0)                // 断网零请求
        #expect(vm.presetSavedToServer == false)
        #expect(vm.errorKind == .offline)
        #expect(vm.isLoading == false)
    }

    // 预设卡有网：落库照常（回归 #28 语义）
    @Test func presetCardOnlineStillSaves() async {
        let saver = CountingPresetCardSaver(succeeds: true)
        let vm = OnboardingViewModel(
            service: SuccessMock(),
            presetCardSaver: saver,
            isConnected: { true }
        )
        await vm.startWithCard(PresetCard.all[0])
        #expect(saver.callCount == 1)
        #expect(vm.presetSavedToServer == true)
        #expect(vm.errorKind == nil)
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `argument 'isConnected' must precede argument...`（init 尚无该参数）或计数 saver 相关编译错误。

- [ ] **Step 3: 实现 OnboardingViewModel**

a) init 增加注入（与 `isConsentGranted` 同模式）：

```swift
    private let isConnected: @Sendable () -> Bool

    init(
        service: AIServicing = LiveAIService(),
        presetCardSaver: PresetCardSaving = LivePresetCardSaver(),
        isConnected: @escaping @Sendable () -> Bool = { NetworkMonitor.shared.isConnected }
    ) {
        self.service = service
        self.presetCardSaver = presetCardSaver
        self.isConnected = isConnected
    }
```

b) 删除字段 `var retryCount = 0`；`reset()` 与 `generate()` 中相关行删除；删除 `chooseAnother()` 与 `retry()` 中无关逻辑（`retry()` 保留——测试与 Tab1 语义仍在用）。

c) `generate()` 预设卡分支改造：

```swift
            if let card = selectedCard {
                // 预设卡静态样本，零 AI 消耗。有网时并行做两件事：
                // ① 预热登录 ② 轻量落库（失败 seed 兜底）。
                // 断网时不发任何请求：跳过落库，卡片内容照常显示（本地静态），
                // errorKind = .offline 驱动常驻 toast；离开时写待重试记录。
                async let warmUp: Void = { _ = try? await SupabaseManager.ensureSignedIn() }()
                let saveTask: Task<Bool, Never>?
                if isConnected() {
                    saveTask = Task { await presetCardSaver.save(card: card) }
                } else {
                    saveTask = nil
                }
                try await Task.sleep(for: .milliseconds(3000))
                _ = await warmUp
                if let saveTask {
                    // 写库带 1.5s 上限竞速：正常网络早已完成；超时按失败处理。
                    let saved = await withTaskGroup(of: Bool?.self) { group in
                        group.addTask { await saveTask.value }
                        group.addTask {
                            try? await Task.sleep(for: .milliseconds(1500))
                            return nil
                        }
                        let first = await group.next()
                        group.cancelAll()
                        return first ?? nil
                    }
                    presetSavedToServer = saved == true
                } else {
                    presetSavedToServer = false
                    errorKind = .offline
                }
                generationResult = card.staticCard
            } else if let image = selectedImage {
```

d) catch 块去掉 retryCount 递增：

```swift
        } catch {
            errorKind = OnboardingErrorKind.classify(error: error, isConnected: isConnected())
        }
```

- [ ] **Step 4: 实现 OnboardingCaptureView**

a) 删除 `fallbackStage(isFailed:)` 调用（约 558-565 行）与整个 `fallbackStage` / `fallbackCopy` 定义（约 674-718 行）——三档文案移入新 toast 组件。

b) 删除两处断网 guard：`presetCarousel` 点卡回调（约 482-485 行）与 `performSelection()` 预设卡分支（约 523-528 行）——预设卡断网照常选中生成（VM 层跳过落库）。

c) `resultContent` 失败分支（原 fallbackStage 调用处）改为失败预览：else 分支渲染用户已选的照片（无骨架、不可点），不让内容区空白：

```swift
                        } else if let image = resultImage {
                            // 生成失败：保留用户已选的图（fail-open——内容在、toast 提示、Continue 可用）
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 195)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer()
                        } else {
                            Spacer()
                        }
```

（预设卡断网时 `generationResult != nil` 已走结果卡分支；此 else 只覆盖自选图失败。）

d) `bottomButton` 条件改为：

```swift
    private var bottomButton: some View {
        if (viewModel.selectedCard != nil || viewModel.selectedImage != nil) && !viewModel.isLoading {
            OnboardingPrimaryButton(
                title: "Continue",
                action: continueAction
            )
        }
    }
```

（`continueAction` 即原按钮 action——确认选取/完成流程不变。）

e) toast 挂载：在结果区 ZStack 底部（bottomButton 上方）加错误 toast，替换原 photoValidationMessage 之外的新通道：

```swift
    // 错误 toast：断网档常驻（网络恢复消失），其余档 4s 自动消失
    @ViewBuilder
    private var errorToast: some View {
        if viewModel.errorKind == .offline {
            AppToast(message: "Network unavailable. Check your network and try again.", systemImage: "wifi.slash")
        } else if let kind = viewModel.errorKind {
            AutoDismissingAppToast(
                message: Binding(
                    get: { errorToastCopy(for: kind) },
                    set: { if $0 == nil { viewModel.errorKind = nil } }
                ),
                systemImage: "exclamationmark.triangle",
                lifetime: AppTheme.Motion.toastLifetime
            )
        }
    }

    private func errorToastCopy(for kind: OnboardingErrorKind) -> String {
        switch kind {
        case .contentBlocked: return "This content can't be processed. Try another one."
        case .generic:        return "Something went wrong. Please try again."
        case .offline:        return "Network unavailable. Check your network and try again."
        }
    }
```

并在 `resultContent` 的 ZStack 中挂载 `errorToast`（`.padding(.bottom, AppTheme.Space.paddingHero)`），加：

```swift
        .onChange(of: NetworkMonitor.shared.isConnected) { _, connected in
            if connected, viewModel.errorKind == .offline { viewModel.errorKind = nil }
        }
```

- [ ] **Step 5: 实现 completeOnboarding 记账**

`AIEnglishApp/Onboarding/OnboardingView.swift` 的 `completeOnboarding()` 开头（本地标记写入之后）加：

```swift
        // 断网离开：写待重试记录（预设卡未落库 / 照片未生成），Tab1 展示并可 Retry。
        if viewModel.errorKind == .offline {
            if let card = viewModel.selectedCard {
                PendingRetryStore.shared.savePreset(cardId: card.id, imageName: card.imageName)
            } else if let image = viewModel.selectedImage, viewModel.generationResult == nil {
                try? PendingRetryStore.shared.savePhoto(image)
            }
        }
```

- [ ] **Step 6: 全量回归**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(\*\* TEST|error:)"`

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 7: Commit**

```bash
git add AIEnglishApp/Onboarding/OnboardingViewModel.swift AIEnglishApp/Onboarding/OnboardingCaptureView.swift AIEnglishApp/Onboarding/OnboardingView.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(onboarding): fail-open 错误 toast 化 + 预设卡断网零请求 + 离开写待重试记录"
```

---

### Task 3: Tab1 待重试记录展示与 Retry 链路

**Files:**
- Modify: `AIEnglishApp/Models/Message.swift`（TimelineEntry 新状态）
- Modify: `AIEnglishApp/Today/Components/MessageRow.swift`（TimelineRow 分支 + `PendingRetryRow`）
- Modify: `AIEnglishApp/Today/TodayViewModel.swift`（loadHistory 注入记录条目；`retryPending`）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（TodayViewModel 相关 suite 新增）

**Interfaces:**
- Consumes: Task 1 的 `PendingRetryStore.load() / remove(id:) / photoImage(for:)`、`PendingRetryRecord`；Task 2 的 `OnboardingErrorKind` 无关。
- Produces: `TimelineEntry.Content.pendingRetry(PendingRetryRecord)` + `TodayViewModel.retryPending(record:)`。

- [ ] **Step 1: 写失败测试**

`AIEnglishAppTests/AIEnglishAppTests.swift` 的 `TodayViewModelTests`（约 477 行）新增：

```swift
    // 待重试记录注入：loadHistory 完成后时间线顶部有 pendingRetry 条目
    @Test func pendingRetryRecordInjectedOnLoad() async {
        let suite = "today-pending-retry"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-dir", isDirectory: true)
        let store = PendingRetryStore(defaults: defaults, documentsDir: dir)
        store.savePreset(cardId: "1", imageName: "card_scene_1")

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        await vm.loadHistory()

        #expect(vm.entries.contains { if case .pendingRetry = $0.content { return true }; return false })
    }

    // retryPending（photo）：成功后生成卡片、记录被移除
    @Test func retryPendingPhotoGeneratesAndClearsRecord() async throws {
        let suite = "today-pending-retry-photo"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("today-pending-retry-photo-dir", isDirectory: true)
        let store = PendingRetryStore(defaults: defaults, documentsDir: dir)
        try store.savePhoto(UIImage(systemName: "photo")!)
        let record = store.load()[0]

        let vm = TodayViewModel(service: SuccessMock(), isConsentGranted: { true })
        vm.pendingRetryStore = store
        vm.entries = [TimelineEntry.pendingRetry(record)]

        await vm.retryPending(record: record)

        #expect(store.load().isEmpty)
        #expect(vm.entries.contains { if case .aiCard = $0.content { return true }; return false })
    }
```

（`TodayViewModel` 需新增可注入属性 `var pendingRetryStore = PendingRetryStore.shared`。）

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/TodayViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `type 'TimelineEntry.Content' has no member 'pendingRetry'`。

- [ ] **Step 3: 实现模型与渲染**

a) `AIEnglishApp/Models/Message.swift` Content enum 加：

```swift
        case pendingRetry(PendingRetryRecord)   // 断网待重试记录：带图 + 文案 + Retry（不参与服务端历史）
```

工厂：

```swift
    static func pendingRetry(_ record: PendingRetryRecord) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .pendingRetry(record))
    }
```

b) `AIEnglishApp/Today/Components/MessageRow.swift`：`TimelineRow` switch 加：

```swift
        case .pendingRetry(let record):
            PendingRetryRow(record: record, onRetry: { onRetry?(nil, nil, entry.id) })
```

并在 `SendFailedRow` 之前新增组件：

```swift
// MARK: - 断网待重试记录：带图 + 网络错误文案 + Retry（杀 app 不丢，有网可恢复）
struct PendingRetryRow: View {
    let record: PendingRetryRecord
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            if let image = PendingRetryStore.shared.photoImage(for: record) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }

            Text("You were offline, so this wasn't generated.")
                .font(AppTheme.Font.chineseFaint)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetry) {
                Text("Retry")
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.brandWash, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(AppTheme.Color.border.opacity(0.6), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 4: 实现 TodayViewModel 注入与 Retry**

a) 属性：`var pendingRetryStore = PendingRetryStore.shared`（`TodayViewModel` 顶部）。

b) `loadHistory()` 末尾（defer 之后、返回前）注入记录条目（仅当时间线还没有对应记录）：

```swift
        // 断网待重试记录：本地持久化的「未生成内容」始终展示（杀 app 不丢），
        // 有网后用户手动 Retry。避免与已生成卡片重复：检查现有 pendingRetry 条目。
        let pending = pendingRetryStore.load()
        for record in pending where !entries.contains(where: {
            if case .pendingRetry(let r) = $0.content { return r.id == record.id }
            return false
        }) {
            entries.insert(TimelineEntry.pendingRetry(record), at: 0)
        }
```

c) Retry 方法（`retrySend` 之后）：

```swift
    /// 待重试记录 Retry：photo 走 AI 生成；presetCard 走静态卡 + 落库。
    /// 成功后移除记录、替换为卡片；失败保留记录（断网时 toast 由视图层处理）。
    func retryPending(record: PendingRetryRecord) async {
        switch record.source {
        case .photo:
            guard let image = pendingRetryStore.photoImage(for: record) else { return }
            await runGeneration(text: nil, image: image, userBubbleEntryId: nil)
            if entries.contains(where: { if case .aiCard = $0.content { return true }; return false }) {
                pendingRetryStore.remove(id: record.id)
                entries.removeAll { if case .pendingRetry(let r) = $0.content { r.id == record.id } else { false } }
            }
        case .presetCard:
            guard let card = PresetCard.all.first(where: { $0.id == record.presetCardId }) else { return }
            let saver = LivePresetCardSaver()
            let saved = await saver.save(card: card)
            if saved {
                pendingRetryStore.remove(id: record.id)
                entries.removeAll { if case .pendingRetry(let r) = $0.content { r.id == record.id } else { false } }
                entries.append(.aiCard(card.staticCard))
            }
        }
    }
```

（注意：photo 分支 `runGeneration` 的 catch 里 contentBlocked/generic 已有处理；`userBubbleEntryId` 参数为 Task 上上刀引入的签名——以当前代码实际签名为准。）

- [ ] **Step 5: 全量回归**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(\*\* TEST|error:)"`

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 6: Commit**

```bash
git add AIEnglishApp/Models/Message.swift AIEnglishApp/Today/Components/MessageRow.swift AIEnglishApp/Today/TodayViewModel.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(today): Tab1 待重试记录展示 + Retry 恢复链路"
```

---

## 验收清单（全部任务完成后）

1. `xcodebuild test -only-testing:AIEnglishAppTests` 全绿
2. 模拟器截图发 PM 确认：
   - 断网 + 预设卡：卡片照常显示 + 常驻 toast + Continue 可用；进 Tab1 带图待重试记录；**杀 app 重启记录仍在**
   - 断网 + 自选图：图片保留 + 常驻 toast + Continue；进 Tab1 记录带原图；杀 app 重启仍在
   - 有网点 Retry：预设卡 → 卡片 + 落库（重启后仍在）；照片 → AI 生成卡片
   - 被拒/其它失败、正常有网流程：回归一致
3. 后端无改动
