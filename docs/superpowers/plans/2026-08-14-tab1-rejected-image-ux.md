# Tab1 被拒图片体验重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tab1 内容被拒时：不合规图片不上屏（占位块替代）+ Alert 弹窗退役（inline 轻提示行）+ 后端清理被拒图片（Storage 不残留）。

**Architecture:** 时间线新增 `userRejected` 状态承载「被拒」形态（文本原样 / 图片占位块 / 轻提示行），ViewModel 在 `catch contentBlocked` 时把最近的 userBubble 就地转换；后端在全部 422 早退点删除已上传的 Storage 图片。

**Tech Stack:** SwiftUI / iOS 17+ / @Observable / Swift Testing（`@Test` + `#expect`）/ Deno Edge Function。

**Spec:** `docs/superpowers/specs/2026-08-14-tab1-rejected-image-ux-design.md`

## Global Constraints

- 文案逐字契约：占位块标签 **`Content blocked`**；轻提示行整句 **`This content can't be processed. Try another one.`**
- 被拒条目**无重试按钮**；原图数据不进 `userRejected`（只留形态信息）
- 系统 Alert 整个移除；`contentBlockedMessage` 字段退役
- 文本被拒时气泡原样保留；图片被拒时占位块替代图片
- 全部样式走 `AppTheme` token 层；不新增 token；不写死字号/颜色（SF Symbol 图标字号豁免）
- 后端：所有 422 content_blocked 早退点（Gemini API 层两处 + 模型 error 卡一处）都删除已上传图片；删除失败仅 log 不阻塞响应
- 所有产品文案英文；commit 追加 trailer `Co-Authored-By: Claude <noreply@anthropic.com>`

---

### Task 1: 客户端被拒呈现（模型 + ViewModel 转换 + 渲染器 + Alert 退役）

**Files:**
- Modify: `AIEnglishApp/Models/Message.swift`（Content enum + 工厂方法）
- Modify: `AIEnglishApp/Today/TodayViewModel.swift`（catch 转换逻辑；删 `contentBlockedMessage` 字段）
- Modify: `AIEnglishApp/Today/Components/MessageRow.swift`（TimelineRow 新分支 + `UserRejectedRow`）
- Modify: `AIEnglishApp/Today/TodayView.swift`（删 `.alert` 块）
- Test: `AIEnglishAppTests/AIEnglishAppTests.swift`（TodayViewModelTests 内改写 1 个旧用例、新增 3 个）

**Interfaces:**
- Produces: `TimelineEntry.Content.userRejected(text: String?, wasImage: Bool)` + `TimelineEntry.userRejected(text:wasImage:)` 工厂。Task 2 不依赖本任务。

**背景：** 现有链路（`TodayViewModel.runGeneration`，约 208-211 行）：contentBlocked 时只删 loading、设 `contentBlockedMessage` → TodayView `.alert`（41-48 行）弹窗；用户气泡（含不合规原图）留在时间线。本次改为气泡就地转 `.userRejected`、弹窗退役。

- [ ] **Step 1: 改写/新增测试（先红）**

`AIEnglishAppTests/AIEnglishAppTests.swift` 的 `TodayViewModelTests`（约 471 行起）：
a) 在 `hasLoading` helper（约 584 行）旁新增：

```swift
    private func rejectedEntry(_ vm: TodayViewModel) -> (text: String?, wasImage: Bool)? {
        for e in vm.entries {
            if case .userRejected(let t, let w) = e.content { return (t, w) }
        }
        return nil
    }
```

b) 删除旧用例 `contentBlockedSetsMessageAndRemovesLoading`（约 620-628 行），替换为：

```swift
    // 图片被拒：userBubble 就地转 userRejected(wasImage: true)、loading 移除、不再有弹窗字段
    @Test func contentBlockedImageConvertsBubbleToRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == true)
        #expect(r?.text == "Describe this image")
        #expect(hasBubble(vm) == false)     // 原气泡已转换，时间线不再有 userBubble
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 文本被拒：气泡文本原样保留、wasImage == false
    @Test func contentBlockedTextKeepsBubbleTextAsRejected() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        await vm.send("something the filter rejects")

        let r = rejectedEntry(vm)
        #expect(r != nil)
        #expect(r?.wasImage == false)
        #expect(r?.text == "something the filter rejects")
        #expect(hasLoading(vm) == false)
        #expect(vm.isLoading == false)
    }

    // 图文混合被拒：文本原样 + wasImage == true
    @Test func contentBlockedMixedKeepsTextAndMarksImage() async {
        let vm = TodayViewModel(service: ContentBlockedMock(), isConsentGranted: { true })
        vm.pendingImage = UIImage(systemName: "photo")!
        await vm.send("check this photo")

        let r = rejectedEntry(vm)
        #expect(r?.wasImage == true)
        #expect(r?.text == "check this photo")
        #expect(hasLoading(vm) == false)
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/TodayViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: 编译失败 — `type 'TimelineEntry.Content' has no member 'userRejected'`。

- [ ] **Step 3: 实现四处改动**

a) `AIEnglishApp/Models/Message.swift` — Content enum（第 9-16 行）加一个 case：

```swift
        case userRejected(text: String?, wasImage: Bool)   // 安全拦截：文本原样展示、图片转占位块；不带原图数据（不渲染、不重试）
```

工厂方法区（`aiError` 工厂之后）加：

```swift
    static func userRejected(text: String?, wasImage: Bool) -> TimelineEntry {
        TimelineEntry(id: UUID(), createdAt: .now, content: .userRejected(text: text, wasImage: wasImage))
    }
```

b) `AIEnglishApp/Today/TodayViewModel.swift`：
- 删除字段（约 10 行）：`var contentBlockedMessage: String?`
- `catch AIServiceError.contentBlocked` 块（约 208-211 行）替换为：

```swift
        } catch AIServiceError.contentBlocked {
            // 内容被安全过滤拦截：移除 loading，用户气泡就地转为「被拒」形态
            // （图片 → 占位块；文本 → 原样），不再弹窗、不保留原图。
            entries.removeAll { $0.id == loadingEntry.id }
            if let idx = entries.lastIndex(where: {
                if case .userBubble = $0.content { return true }
                return false
            }),
               case .userBubble(let bubbleText, let bubbleImage, let bubbleImageUrl, _) = entries[idx].content {
                entries[idx] = TimelineEntry(
                    id: entries[idx].id,
                    createdAt: entries[idx].createdAt,
                    content: .userRejected(
                        text: bubbleText,
                        wasImage: bubbleImage != nil || bubbleImageUrl != nil
                    )
                )
            } else {
                // 兜底：时间线里找不到 userBubble（异常路径）时补一条被拒条目
                entries.append(TimelineEntry.userRejected(text: text, wasImage: image != nil))
            }
        }
```

c) `AIEnglishApp/Today/Components/MessageRow.swift`：
- `TimelineRow` 的 switch（约 10-24 行）加分支（放在 `.sendFailed` 之后）：

```swift
        case .userRejected(let text, let wasImage):
            UserRejectedRow(text: text, wasImage: wasImage)
```

- 文件内 `SendFailedRow` 之前新增组件：

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
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.imagePlaceholderBg)
                    .frame(width: imageSize, height: imageSize)
                    .overlay(
                        VStack(spacing: AppTheme.Space.paddingS) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(AppTheme.Color.textMuted)
                            Text("Content blocked")
                                .font(AppTheme.Font.statusNote)
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                    )
            }

            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "info.circle")
                    .imageScale(.small)
                Text("This content can't be processed. Try another one.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
```

d) `AIEnglishApp/Today/TodayView.swift`：删除 `.alert(...)` 整块（约 41-48 行，从 `.alert("Can't create a lesson", isPresented:` 到对应右括号 `)`）。

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests/TodayViewModelTests 2>&1 | grep -E "(Test case|error:)"`

Expected: `TodayViewModelTests` 全部 passed（3 个新用例 + 既有用例）。

- [ ] **Step 5: 全量回归**

Run: `xcodebuild -scheme AIEnglishApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test -only-testing:AIEnglishAppTests 2>&1 | grep -E "(TEST|error:)"`

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 6: Commit**

```bash
git add AIEnglishApp/Models/Message.swift AIEnglishApp/Today/TodayViewModel.swift AIEnglishApp/Today/Components/MessageRow.swift AIEnglishApp/Today/TodayView.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(today): 被拒条目占位块替代原图 + inline 轻提示替代 Alert"
```

---

### Task 2: 后端被拒图片清理（Storage 删除）

**Files:**
- Modify: `supabase/functions/generate/index.ts`（`uploadImage` 之后新增 `deleteImage`；三处 422 早退点调用）

**Interfaces:**
- Consumes: 无（独立于 Task 1）。
- Produces: `deleteImage(path: string | null): Promise<void>`（内部函数，不外引）。

**测试策略（spec 已定）：** `deleteImage` 是纯 Storage HTTP 调用，deno 无 mock 基建，不写网络级单测；失败路径有 log 兜底。本任务回归 = 现有 deno 测试全绿 + 部署后人工验证（见验收清单）。

- [ ] **Step 1: 新增 `deleteImage` helper**

在 `uploadImage` 函数结束之后（约 512 行，`// 从请求的 Authorization 头解析出登录用户 id` 注释之前）插入：

```ts
// 删除已上传图片：被拒内容不入库，也不应留在 Storage（孤儿文件 + 合规风险）。
// 失败仅记录，不阻塞 422 响应。
async function deleteImage(path: string | null): Promise<void> {
  if (!path) return;
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) return;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/storage/v1/object/${STORAGE_BUCKET}/${path}`,
      {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
          "apikey": SUPABASE_SVC_KEY,
        },
      }
    );
    if (!res.ok) {
      console.error("[deleteImage] failed:", res.status, await res.text());
      return;
    }
    console.log(`[deleteImage] ok path=${path}`);
  } catch (e) {
    console.error("[deleteImage] error:", e);
  }
}
```

- [ ] **Step 2: 三处 422 早退点调用删除**

a) Gemini 输入端拦截（约 1027-1029 行）：

```ts
    if (data?.promptFeedback?.blockReason) {
      await deleteImage(sourceImagePath);
      return json({ error: "content_blocked", blockReason: data.promptFeedback.blockReason }, 422);
    }
```

b) Gemini 输出端拦截（约 1030-1032 行）：

```ts
    if (data?.candidates?.[0]?.finishReason === "SAFETY") {
      await deleteImage(sourceImagePath);
      return json({ error: "content_blocked", blockReason: "OUTPUT_SAFETY" }, 422);
    }
```

c) 模型 error 卡（约 1040-1047 行）：

```ts
    if (isModelErrorCard(parsed)) {
      await deleteImage(sourceImagePath);   // 被拒图片不留在 Storage
      return json(
        { error: "content_blocked", blockReason: parsed.card_content?.error_type ?? "MODEL_GATE" },
        422,
      );
    }
```

（spec §二.2 写的是「422 早退时删除已上传图片」，覆盖全部三处 422 点；`sourceImagePath` 在前方 `Promise.all` 解构中已在作用域内，为 null 时 deleteImage 直接返回。）

- [ ] **Step 3: deno 回归**

Run: `npx --yes deno test supabase/functions/generate/modelGate_test.ts supabase/functions/generate/rawContent_test.ts 2>&1 | tail -4`

Expected: 两个文件全部 passed（modelGate 3 用例 + rawContent 25 用例）。

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/generate/index.ts
git commit -m "fix(generate): 被拒图片删除 Storage 残留（三处 422 早退点清理）"
```

---

## 验收清单（全部任务完成后）

1. `xcodebuild test -only-testing:AIEnglishAppTests` 全绿；deno 测试全绿
2. 模拟器截图发 PM 确认：
   - Tab1 发不合规图片 → 气泡变占位块（"Content blocked"）+ 轻提示行；无 Alert；原图不出现
   - Tab1 发不合规文本 → 文本气泡原样 + 轻提示行；无 Alert
   - 正常图片/文本 → 行为与改前一致（回归）
3. 后端部署（PM 确认后）→ 重放不合规图片 → 422；Supabase Dashboard Storage 中确认无新孤儿文件
