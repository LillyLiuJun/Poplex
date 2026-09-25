# CLAUDE.md — AIEnglishApp Project Brief

> This file is the project context for any Claude instance (web, desktop, Claude Code).
> Read this file in full before doing any work on this project.

## What the Product Is

Draws material from the user's own life to help them organize learning content
around themselves. Users record their environment or thoughts via photo, voice,
or text; AI generates scene-based English descriptions from that input. The
product is built around these materials, helping users improve their English
(especially speaking) across listening, speaking, reading, and writing.

## Document Index — read the authoritative doc before touching a feature

These are the current sources of truth. When a doc conflicts with an older one,
the doc listed higher wins. When a doc conflicts with the code, **the code is
the fact** — fix the doc and say so.

| Doc (under `docs/`) | Authoritative for |
|---|---|
| `prd/整体架构_两个Tab与对话页_v1.md` | **Upper-level framework.** Responsibilities of Tab1 / Tab2 / dialogue page. No feature doc may conflict with it |
| `prd/Agent内容组织与成长系统_PRD_v2.md` | Tab2 (practice & growth), the **lexicon ledger** (3 new tables), dialogue page, growth layer |
| `prd/Tab1_Prompt与输出结构_改造方案_v2.md` | Tab1 prompt + output structure. **Supersedes `输入到成长` §1** |
| `prd/Tab1_Prompt改造_第1刀验收样例_v1.md` | Acceptance criteria for the slice currently in flight |
| `prd/输入到成长_链路现状与待敲定_v1.md` | §二 extraction/tagging rules, §三 recording & summarising — **still open, not yet decided** |
| `prd/Agent系统PRD_逻辑审查_v1.md` | Review record behind the v1→v2 revision (rationale, historical reference) |
| `优化需求全量清单_v1.md` | Unified index of all low-priority / deferred / pending-decision items, trigger-gated (not a schedule) |
| `engineering/CI.md` | Pull-request verification commands, required checks, and database privilege-test maintenance |
| `design-system/*` | Brand colour (`#FF7622`, warm paper-grey neutrals) and typography |
| `design-system/底部暖光规范_v1.md` | Three-tier warm glow spec (A/B/C tier, background vs ellipse vs none) |
| `brand/README.md` | **Brand assets** — logo, app icon, wordmark, splash. Start there for anything visual-identity related. Note: the *source of truth is code* (`PoplexPShape`, `PoplexWordmarkMetrics`, `AppTheme.Motion.Splash`), the SVGs under `brand/assets/` are exports |

**Treat with care — partly outdated:**

- `architecture/全局数据架构审计报告_v1.md` — dated 2026-07-04. Several findings
  are already fixed (user_id isolation, missing migrations). See
  `Agent内容组织与成长系统_PRD_v2.md` §二 for the corrected status.
- `prd/Tab1_PRD_v1.md`, `prd/Tab2_PRD_v1.md`, `prd/Tab1_AI回复卡片需求设计_v1.md` —
  early PRDs. Product *principles* in them still hold (and are cited by the newer
  docs), but specific field/card designs have been superseded. Cross-check before
  relying on them.

## Current State (update this when a slice lands)

- **Tab2 rebuild in flight** (branch `feat/tab2-rebuild`, plan =
  `Agent内容组织与成长系统_PRD_v2.md` §十三). Scope: Tab2 + dialogue + growth only;
  Tab1 frontend untouched, `generate` backend gets the accounting stage.
  - **Slice 0** (`source_message_id` backfill): **skipped** — the 8th-cut unified
    `raw_content` made materials self-contained, no consumer for the link.
  - **Slice 0.5 · DONE + verified** (backend only): split
    `user_original_lang` → `input_lang` (role: native/target/other) +
    `input_lang_code`; added `intent` (normalized native intent phrase, express
    only). Deployed; live-verified — `累死了`/`太累了` both normalize to `很累`,
    日文 → other/ja, `I have a 会议 at 3pm` → native.
  - **Slice 1 (core) · DONE + verified**: created `lexicon_entries` /
    `lexicon_occurrences` (migrations `20260728000000`), added the
    `record_lexicon_material_units` accounting RPC (`20260728010000`) and
    Stage 3 in `generate` (read `learnable_units[]` → normalize lemma →
    stopword backstop → upsert entry + append occurrence, non-blocking).
    The RPC coerces model-drifted enums (kind/input_lang/granularity/direction)
    to valid-or-null so a stray value can't abort the batch. Live-verified:
    "set up" ×2 → one entry `total_count=2`, `entry_kind` coerced
    phrasal-verb→phrase, occurrences carry the inherited signals.
  - **Next · Slice 1b + Slice 2**: 1b = failure/backfill/reconcile jobs +
    backfill history into the ledger. Slice 2 = static word-list `tier` +
    lemmatisation (meetings→meeting) + fuller stopword list.
- **Prompt backlog** (`Prompt改动需求.md` §待优化需求): N1 — pure third-language
  input should be `comprehend` not `express` (prompt direction rule + Slice 1
  accounting must skip `intent_text` when `input_lang='other'`).
- **Tab1 prompt rework** (slices 1–8) already landed on main (see 8th-cut commit).
- Slice order and what blocks what: see `整体架构_两个Tab与对话页_v1.md` §五 and
  `Agent内容组织与成长系统_PRD_v2.md` §十三.

## Overall Structure

**Tab1 exists to generate content from input. Tab2 exists to make the user
practise and grow.** That is a split by *function stage* (Tab1 feeds, Tab2
processes), not by "two views of the same content".

- **Tab1 — input & generation.** User inputs via text/photo (voice and long-form
  content are planned, not built). AI turns it into a learning card. Tab1 does
  NOT categorize, and does NOT host practice.

- **Tab1 → Tab2 handoff is asynchronous.** The user is NOT auto-navigated to
  Tab2; they switch tabs manually to see their material organized.

- **Tab2 — practice & growth.** Three layers, all serving that one purpose:
  - *What to practise* — the **lexicon ledger** (a de-duplicated, cross-input
    aggregation of expressions) is the practice list. Every row must carry its
    practice state (`○ not said yet` / `● said N times`).
  - *How to practise* — the **dialogue page**: a separate, immersive, voice-based
    page launched from Tab2. It is Tab2's practice feature; there is no other
    practice module waiting to be designed.
  - *How it's going* — the **growth layer**: reads the ledger against what the
    user actually said, and states the gaps. States facts only; never scores or
    judges.

- **The dialogue page is a child of Tab2, not a third top-level surface.** It is
  never the default screen.

- **Deciding where a new feature goes**: ask whether it is *creating material* or
  *turning material into ability*. Former → Tab1. Latter → Tab2.

## Decided (do not re-open without a reason)

- **AI persona / tone**: **Warm Minimalism + efficiency first.** Warm but never
  loud; restrained but never cold. Never praise the user's input, never use coach
  voice, never lecture, no emoji, no self-description. Warmth comes from
  describing the user's situation accurately, not from emotional words.
  Full rules + worked examples: `Tab1_Prompt与输出结构_改造方案_v2.md` §4.1.
- **Brand**: primary `#FF7622` (keep the saturation, do not tone it down);
  neutrals are warm paper-grey (H 24–30°). See `design-system/`.
- **Growth layer states current facts only** — no scoring, no anxiety-inducing
  framing, even for negative gaps.
- **Tab2 is word-centred**; scenes appear as a word's source context. Browsing
  scenes end-to-end belongs to Tab1.

## Technology Choices (confirmed — do not change)

- **Frontend**: SwiftUI (native, not UIKit/Storyboard)
- **Target OS version**: iOS 17+
- **Backend/database**: Supabase (free tier covers MVP)
- **AI content generation provider**: the code currently calls **Gemini 3.7 Flash**
  (`supabase/functions/generate/index.ts`, `supabase/functions/dialogue/index.ts`).
  Switched from 2.5 Flash on 2026-09-03: 2.5 Flash returns 404 for new API accounts
  and its free tier was cut to ~20 requests/day. The provider is not final — cost is
  still being compared — so **do not let provider-specific behaviour leak into
  design docs or the data contract**. Swapping providers should only touch the
  Edge Function.
- **AI call architecture**: The mobile client must NEVER connect directly to
  an AI provider. All AI requests must be routed through Supabase Edge
  Functions (or an equivalent backend middle layer). The API key may only
  exist in server-side environment variables — it must never appear in
  client-side code.
- **Target / native language must not be hardcoded.** MVP is English-as-target and
  Chinese-as-native, but prompts and field names reason in terms of "target" and
  "native" (e.g. `native_meaning`, not `zh_meaning`) so neither is baked in.
- **Verified security pattern for new tables** (follow it, don't reinvent):
  Edge Function verifies the JWT via `/auth/v1/user` (never decode the token
  locally), writes `user_id`, returns 401 when there is no uid, filters every read
  by `user_id`, and the table has RLS enabled as defence in depth.

## Code & Design Hard Constraints (mandatory rules for all code)

```
- Target iOS 17+. Always use NavigationStack. Do not use deprecated NavigationView.
- Use the @Observable macro (iOS 17+) for state management.
  Avoid @StateObject/@ObservedObject unless there is a specific reason.
- Use standard system components and default styling as the MVP starting
  point. Do not hand-write custom visual effects to mimic older iOS
  appearances.
- Separate structure/logic layer from style layer:
  centralize colors, fonts, spacing as design tokens/variables rather than
  hardcoding them inline in each component, so the visual style can be
  swapped later without touching structural code.
- Never embed API keys directly in app code. All AI API calls must be routed
  through the backend (Supabase Edge Functions or equivalent) — the mobile
  client never holds or sends the raw API key.
- Every interactive-looking element must respond to taps (visual/haptic
  feedback at minimum). No decorative-only UI that looks clickable but isn't.
- All product UI text and display language defaults to English. This includes
  button labels, empty states, error messages, navigation titles, placeholder
  text, and toast messages. Chinese may only appear as learning content
  generated by the AI (e.g. Chinese translations of English sentences) — never
  as product UI copy.
- Reusable UI units (cards, buttons, inputs, etc.) must be encapsulated as
  standalone components. Do not assemble system controls + style modifiers
  directly inline on a page. This keeps future re-skinning limited to editing
  one component file instead of hunting across every screen.
- Even while using system default styling as the MVP starting point, all
  colors and fonts must be referenced through design tokens — never write
  system literals (e.g. `.primary`, `.system(size: 16)`) directly in a
  component. The token may currently resolve to a system default value, but
  the reference must go through the token layer from day one.
- Every screen must define its loading, empty, and error states (including
  permission-denied, e.g. microphone/camera access refused) — these are not
  optional add-ons to design later. This product depends heavily on
  voice/camera permissions and AI generation, both of which fail often enough
  that these states are core, not edge cases.
- Text must reference fonts through the `AppTheme.Font.*` token layer. Each
  token is defined with a system TextStyle base (e.g. `.system(.title2,
  weight: .semibold)`) so Dynamic Type is preserved while still allowing a
  chosen weight/design. Never write `.system(size:)` fixed point sizes in a
  component. (Icon glyph sizing via `.imageScale`/`.font(.system(size:))` on
  an `Image(systemName:)` is NOT text and is exempt from this rule, but prefer
  a shared icon-size token where practical.)
```

Note: some system chrome (navigation bar, system Alert/Sheet, TabBar) has
limited official customization APIs. If a future visual redesign wants strong
branding on these elements, expect a fuller replacement rather than a token
edit — set this expectation now so it isn't a surprise later.

**Design Token Rules:**

1. Name tokens by PURPOSE, not appearance, using a consistent format
   `category-purpose-level` (e.g. color-text-primary, space-padding-card).
   Never use arbitrary names like color1, myGray, bg2.

2. Reuse before creating. Before introducing a value, check existing tokens
   and reuse if one fits. Never define the same value under multiple names.

3. Define ALL tokens centrally in one theme/tokens file — never inline in
   components or pages. Use two layers: primitive (raw values) and semantic
   (purpose-named, referencing primitives). Components reference only the
   semantic layer. This lets you re-skin by editing primitives and fine-tune
   by editing semantics.

4. **Semantic tokens must reference a primitive — with one narrow exception.**

   A semantic token may hold a raw value directly *only* when the value is
   **component-private**: it serves exactly one component, is not reusable, and
   does not sit on a design scale.

   The test: **"would this value still mean anything on a different component?"**
   - Yes → it belongs in the primitive layer (e.g. `20` page margin: Tab1, Tab2
     and Onboarding all want the same one).
   - No → keep it in the semantic layer (e.g. `progressBarHeight = 2.5`,
     `settingsIconStroke = 1.6`, `emptyStateCardBackRotation = -7` — these were
     tuned for one control and mean nothing anywhere else).

   Why the exception exists: the primitive layer is a **scale** — a clean ruler
   you pick from (4/8/12/16/20/24…, and the primary colour ramp). Promoting
   one-off internal metrics into it turns that ruler into a junk drawer: someone
   choosing a spacing would see `2.5` sitting next to `20` with no way to tell
   which is a real design step. Polluting the scale is worse than leaving the
   value where it is used.

   This is an exception, not a licence. Anything reusable — spacing, radii,
   brand colours, type sizes — still goes through a primitive. When unsure,
   promote it.

   **"Reusable" means consumed by two *independent* components or two distinct
   semantic purposes** — not merely appearing twice. The same value used twice
   inside one component is still component-private; the same value shared by
   Tab1 and Onboarding is not.

5. **The primitive layer is a palette, not a to-do list.** Unconsumed steps in a
   ramp (e.g. `primary300`–`primary900` currently having no consumer) are
   normal and must NOT be deleted: a scale has to stay contiguous so the
   semantic layer can pick from it, and removing a middle step leaves a
   `700 → 900` gap that is harder to maintain than an idle value.

   The "delete tokens nobody references" rule applies to the **semantic layer
   only** — there, one token is one live design decision, so no consumer means
   the decision was retired. Delete those.

   **Scope and legacy debt.** As of 2026-08-27 roughly 16 of ~213 semantic
   tokens have no consumer (`accentBuddy`, `growthStatus`, `keyPhrase`,
   several `onboarding*Glyph`, …). They are **pre-existing debt, not a licence
   to add more**, and they are not a blocker for unrelated work:

   - Applies to tokens **your slice orphaned** — if you removed the last
     consumer, remove the token in the same commit. That is the rule.
   - Pre-existing orphans get cleaned up during token-hygiene passes
     (see Working Method), not opportunistically mid-feature.
   - How to check: grep for `AppTheme.<Namespace>.<name>` across
     `AIEnglishApp/`. Beware false positives — tokens reached through
     aliases or factory functions (e.g. `AppTheme.Font.categoryLabel(isHot:)`)
     will not show up as a direct reference. **Confirm by reading before
     deleting**; a naive grep is a starting point, not a verdict.

## Working Method (how development is paced — mandatory)

- **Vertical slice first**: Every new feature starts as the narrowest possible
  complete chain (frontend + backend both wired up), validated end-to-end
  before expanding horizontally. Do not build out the full UI framework first
  and fill in functionality later.
- **Test cadence and timing**: Tests should follow every feature slice — do
  not defer all testing to a single pass at the end of the project. Every
  completed slice should have corresponding tests; do not let testing debt
  pile up. However, within a single slice, do NOT rush to write tests while
  the feature logic is still being iterated on and hasn't stabilized — tests
  would have to be rewritten every time the logic changes, wasting effort.
  The correct time to write tests is once the slice's behavior is up and
  running and has basically settled (i.e. once you've reached "I believe this
  feature is correct") — at that point, write unit tests to lock in the
  verified behavior so future changes don't accidentally break it. Prefer
  unit tests (validating data parsing logic, state transitions, etc.) as the
  primary layer. UI tests are not skipped: `iOS tests` is a required PR check
  and the existing UI launch test must keep passing; when a slice changes
  navigation, onboarding, or screen structure, add a minimal UI smoke test for
  the affected critical path. What is not required is exhaustive UI automation
  (tap-through of every screen and edge case) — see `docs/engineering/CI.md`
  §Current UI-test scope. After tests are written and passing,
  report the results (pass/fail, specific error messages if any) to the
  project owner in writing, and wait for confirmation that the result is
  acceptable before moving to the next slice — do not repeatedly modify tests
  or code on your own without getting confirmation first.
- **Token hygiene cadence**: Every 2–3 vertical slices, audit all tokens:
  check naming format, find duplicate values under different names, check
  whether anything should be merged or split, and find any tokens defined
  inline instead of centrally in the theme file. List issues and proposed
  fixes — do NOT auto-edit tokens without confirmation first.

## 视觉产物自查（截图 / 录屏 / OCR — 交付前必做）

截图、录屏、OCR 这类产物，**交付前必须自己打开看过，并用文字写出画面里实际
有什么**，再和说明文字逐条对照。描述不出来 = 没验收，不允许只凭「命令跑通、
文件生成了」就下结论。

这条规矩是三次返工换来的（2026-09-15 ~ 09-16，刀 6b 与 toast 排查）：

1. 胶囊溢出四连拍 —— 四张图全是卡片底部的词数行，胶囊组根本没入画
   （`sips` 裁剪锚点语义不可靠），但报告写的是「7/7 通过」。
2. 改用 PIL 显式坐标裁剪并做了像素级校验之后，图是真的了，可 ② 号图用的是
   短名夹具、说明文字写的却是 24 字符长名用例 —— 像素校验只证明「裁得准」，
   不证明「截的是对的场景」。
3. 录屏演示 #3 时整段画面被 onboarding 弹层盖住，演示视图一帧都没出现。

三次的共同点都不是工具不行，是**产物没有被它的作者打开看过一眼**。所以：

- 先描述画面，再下结论。顺序不能反 —— 先写好结论再去找图佐证，必然放过错图。
- 像素/OCR 校验只回答「这张图是否被正确截取」，回答不了「这张图是不是该截的
  那一张」。场景是否正确，只能靠人眼对照夹具与说明文字。
- 多状态连拍时注意：`simctl launch` 的启动参数只在冷启动生效，两次截图之间
  必须 `terminate`，否则后续截图静默复用第一个状态。
- 夹具必须满足线上校验规则（例：`scene_detail` ≤ 24 字符）。用一个线上永不
  可能出现的值去截图，截得再准也是无效验收。

## Debug Probes（DEBUG-only 常备验收探针）

真机曾现「toast 弹出后常驻不消失」（2026-09-15，结论：rebase 前构建的旧包，
当前代码无法复现；探针保留，再现时立即抓日志）。三条 toast（comingSoon /
vm.toastMessage / milestone）共用 AppToast 的自动消失链路，MineView 内置
常备探针验证该链路，全部包在 `#if DEBUG`，不进 Release。

| 环境变量 | 触发 |
|---|---|
| `TOAST_PROBE=1` | 进入 Tab2 后 2s 自动写 comingSoonToast（"Speaking mode will be available soon."） |
| `TOAST_PROBE_BLOCKED=1` | Tab2 load 成功后自动写 vm.toastMessage（"You're offline. Check your connection."） |
| `TAB2_MILESTONE_DEMO=1` | Tab2 刷新时写入里程碑演示数据；切走再切回 Tab2 触发 milestoneToast |

验收标准（三者共用）：日志前缀 `[toast-probe]`，验证的是 **toast 写入 →
自动清空的全链路时序**——每条写入必须后跟一条 nil（3s / 2.2s 附近），
只有写入没有 nil = 自动消失链路坏。注意：设备 console 是管道、stdout
全缓冲，`print()` 不可见，探针必须走 NSLog（os_log 通道）。

## CI & Pull Requests

For any task that changes code, tests, Supabase Functions, migrations, or
GitHub workflows, read `docs/engineering/CI.md` before verification. Run the
relevant documented local checks once the slice is stable, report their results
to the project owner, and require the documented GitHub PR checks to pass
before describing a PR as ready to merge.

### 自动化 PR 交付与生命周期闭环（Ship & Auto-Cleanup）

合并与清理**永远不随「提 PR」自动发生**，分三阶段执行：

1. **阶段一 · 提 PR**：用户指示「提交 PR / 提 PR」时，在当前分支/worktree 下执行
   `bash scripts/ci/ship-pr.sh`。脚本先跑本地守卫（工作区必须完全干净**含未跟踪文件**、
   提交作者必须与当前 git 身份一致），然后推送分支、创建/复用 PR、阻塞等待 GitHub Actions
   并汇报结果；CI 红则自动提取失败日志，现场完整保留。**脚本到此为止，绝不合并。**
2. **阶段二 · 合并**：用户明确指示「合并」后执行 `bash scripts/ci/ship-pr.sh merge`。
   脚本复核 PR 上**至少有一个检查且全部通过**（无检查一律拒绝，如 commit 带 `[skip ci]`），
   Squash Merge（**不删分支**——远端与本地分支统一留给阶段三），切回主仓库
   `--ff-only` 对齐 main（分叉即停止报告，禁止 reset --hard）。**改动涉及
   `supabase/` 或 `.github/` 的 PR 脚本拒绝自动合并，改由用户手动处理。**
3. **阶段三 · 清理**：合并后用户确认已关闭 Xcode，执行
   `bash scripts/ci/ship-pr.sh cleanup <PR号>`（PR 号见阶段二收尾提示；**合并后仓库
   已停在 main，在 main 上执行 cleanup 是预期行为**）。脚本确认 PR 为 MERGED 后：
   删远端分支（若还在）→ **无 `--force`** 移除 worktree（目录含未跟踪/修改文件时
   git 拒绝删除、保留现场）→ 删本地分支。若当前会话正运行在该 worktree 内，
   清理后需立即退出该目录会话。

**触发词纪律**：关键词只进入阶段一；「合并 / 清理」必须是一句独立、明确的用户指令，
禁止因用户消息里出现 "merge" 字样就执行阶段二或阶段三。

### Edge Function 部署纪律

**改动 `supabase/functions/` 的 PR，合并不等于上线。** Edge Function 必须显式
部署才会生效，所以「代码已合并」和「线上在跑」是两件事；中间这段真空里，
线上跑的仍是上一次部署的版本。

2026-09-15 实例：`classifyVocabCategory` 的修复 09-11 提交、09-14 进 main，
而线上 `generate` 停在 09-10 的部署。结果是修复看起来做完了，线上词卡分类
失败率仍是 89%，一路查到日志才对上——**控制台上只有一个「5 days ago」，
不告诉你那是哪个 commit。**

规矩：

1. **涉及 `supabase/functions/` 的 PR，合并后部署是收尾的一部分**，不是另一
   件事。没部署 = 这一刀没做完。
2. **部署后必须记录**：函数名、函数版本号、部署时间、部署所用的 commit SHA。
   写进该刀的验收记录。
3. **部署后必须验证线上行为，而不是验证代码。** 至少一次真实调用 + 一条日志
   证明新代码在跑（找只有新版才有的输出特征），再加一条数据证明结果是对的。
   **两个都要**：只看结果可能是碰巧，只看日志只证明代码在跑、不证明结果对。
   最强的形式是同一输入的前后对照（如 `corn` 部署前 Other、部署后 Food & Drink）。
4. **修复不追溯。** 部署之前写进库的数据仍是旧行为的产物，不会自愈。需要回填
   的，回填是单独一刀。
5. **别从 feature 分支部署。** `functions deploy` 推的是当前工作区的整个
   `supabase/functions/`，会把该分支上所有未经 PR 审核的后端改动一起推上线。

这条与既有的「结果属于谁，必须先证明，再解读」同源：**源码不是证据，
跑着的东西才是。**

## Project Owner Background (for Claude to calibrate explanations)

A product manager with a marketing background; zero coding background. Every
technical decision needs a "why," not just a conclusion. Priorities: interaction
experience, content value (kept minimal at MVP stage), software testing
quality, API security. Learning goals include: the Claude Code workflow
(CLAUDE.md / MCP / skills / subagents) and hands-on use of AI-assisted
frontend design skills.
