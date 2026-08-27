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
| `design-system/*` | Brand colour (`#FF7622`, warm paper-grey neutrals) and typography |
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
- **AI content generation provider**: the code currently calls **Gemini 2.5 Flash**
  (`supabase/functions/generate/index.ts`). The provider is not final — cost is
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
  unit tests (validating data parsing logic, state transitions, etc.); do not
  require complex UI automation tests. After tests are written and passing,
  report the results (pass/fail, specific error messages if any) to the
  project owner in writing, and wait for confirmation that the result is
  acceptable before moving to the next slice — do not repeatedly modify tests
  or code on your own without getting confirmation first.
- **Token hygiene cadence**: Every 2–3 vertical slices, audit all tokens:
  check naming format, find duplicate values under different names, check
  whether anything should be merged or split, and find any tokens defined
  inline instead of centrally in the theme file. List issues and proposed
  fixes — do NOT auto-edit tokens without confirmation first.

## Project Owner Background (for Claude to calibrate explanations)

A product manager with a marketing background; zero coding background. Every
technical decision needs a "why," not just a conclusion. Priorities: interaction
experience, content value (kept minimal at MVP stage), software testing
quality, API security. Learning goals include: the Claude Code workflow
(CLAUDE.md / MCP / skills / subagents) and hands-on use of AI-assisted
frontend design skills.
