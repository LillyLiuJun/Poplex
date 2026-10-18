# CLAUDE.md — AIEnglishApp Project Brief

> Project context for any Claude instance (web, desktop, Claude Code).
> Read this file in full before doing any work on this project.
> Long-form detail lives under `docs/` and is linked below — read it when the task touches that area.

## What the Product Is

Draws material from the user's own life to help them organize learning content
around themselves. Users record their environment or thoughts via photo, voice,
or text; AI generates scene-based English descriptions from that input. The
product is built around these materials, helping users improve their English
(especially speaking) across listening, speaking, reading, and writing.

## Docs

`docs/` is organised as `prd/` (product), `design-system/`, `engineering/`, `brand/`,
`architecture/` and `archive/`. **Most documents age quickly — the code is the fact.**
Before touching a feature, find the newest document for it (check the last-modified date
in git) and verify it against the code; if they conflict, fix the document and say so.

Stable references:

- `prd/整体架构_两个Tab与对话页_v1.md` — **upper-level framework (v3, 2026-10-18)**: what Tab1 / Tab2 / the dialogue page are responsible for and what shipped in 1.0.0
- `engineering/CI.md` — PR verification commands, required checks, database privilege tests
- `engineering/交付与部署纪律.md` — full ship / merge / cleanup flow and Edge Function deploy discipline
- `engineering/视觉产物自查.md`, `engineering/debug-probes.md` — evidence rules and DEBUG probes
- `design-system/信息层级与布局原则.md` — **read before any UI work** (see "Before You Change Anything")
- `design-system/token-rules.md` — full design-token rules. **Colour values are NOT in design-system docs**: every colour comes from `AIEnglishApp/Theme/Theme.swift`, brand colours from `brand/README.md`
- `brand/README.md` — brand assets; the authoritative assets are the SVGs under `docs/brand/assets/`
- `优化需求全量清单_v1.md` — index of deferred / low-priority / pending-decision items (trigger-gated, not a schedule)

## Current State (update this when a slice lands)

*Last reviewed 2026-10-17, against `main`.*

- **Shipped build: 1.0.0 (build 2)**, submitted to App Store review. iPhone only, portrait.
- **Lexicon ledger backend: done** (Slices 0.5 / 1 / 1b / 2, PR #12): ledger tables,
  accounting RPC, Stage 3 in `generate`, `backfill-lexicon`, normalisation in
  `supabase/functions/_shared/lexicon.ts`.
- **Tab2 as shipped in 1.0.0**: a Hero card plus a "More to talk about" list, topics
  that unlock at 20 expressions. The slice plan in `prd/Agent内容组织与成长系统_PRD_v2.md` (§十三) is the *design* sequence;
  **do not assume its slices 3–9 match what shipped** — check the code and the Tab2
  design docs under `docs/prd/` before building on them.
- **Dialogue page: in development, switched off in 1.0.0**
  (`FeatureFlags.conversationEnabled = false`). Read the warning in `FeatureFlags.swift`
  before turning it on (usage-description strings, App Review Guideline 5.1.1).
- **Prompt backlog** (`Prompt改动需求.md`): N1 — pure third-language input should be
  `comprehend` not `express` (prompt direction rule + ledger accounting must skip
  `intent_text` when `input_lang='other'`).

## Overall Structure

**Tab1 exists to generate content from input. Tab2 exists to make the user practise
and grow.** A split by *function stage* (Tab1 feeds, Tab2 processes), not two views of
the same content.

- **Tab1 — input & generation.** Text / photo input (voice and long-form are planned,
  not built). Turns input into a learning card. Does NOT categorize and does NOT host
  practice. The handoff to Tab2 is asynchronous; the user is never auto-navigated.
- **Tab2 — practice & growth.** The first screen is the entry to speaking: topic cards by
  category (Hero, "More to talk about", locked "Topics in progress"). The **dialogue page**
  is a separate immersive voice page launched from a card; the **growth layer** states facts
  only — never scores or judges. The **lexicon ledger** records and remembers behind the
  scenes. Full picture and what shipped: `prd/整体架构_两个Tab与对话页_v1.md` (v3).
- **The dialogue page is a child of Tab2**, never a third top-level surface or default screen.
- **Where does a new feature go?** Ask whether it is *creating material* (Tab1) or
  *turning material into ability* (Tab2).

## Decided (do not re-open without a reason)

- **AI persona / tone**: **Warm Minimalism + efficiency first.** Warm but never loud;
  restrained but never cold. Never praise the user's input, no coach voice, no
  lecturing, no emoji, no self-description. Warmth comes from describing the user's
  situation accurately. Rules + examples: `Tab1_Prompt与输出结构_改造方案_v2.md` §4.1.
- **Brand**: primary `#FF7622` (keep the saturation); neutrals are warm paper-grey
  (H 24–30°); page background = brand paper `#FBF8F5`. Values live in `Theme.swift`.
- **Dynamic Type cap (2026-10-06)**: the whole app is capped at `xxxLarge`; the five
  accessibility sizes (AX1–AX5) are not supported. Implemented in
  `Theme/AppDynamicTypeCap.swift`, switched on in `AIEnglishAppApp`.
- **Growth layer states current facts only** — no scoring, no anxiety-inducing framing.
- **Tab2 is the entry to speaking, organised by topic category** (owner decision, Tab2 design
  v2 #5/#8): the practice entry is the big category, sub-scenes are only card descriptions,
  and the word list (`Your words`) is deferred. The lexicon ledger stays as the
  record-and-memory layer behind it. Browsing a scene end-to-end belongs to Tab1.

## Technology Choices (confirmed — do not change)

- **Frontend**: SwiftUI (native, not UIKit/Storyboard). **Target iOS 17+.**
- **Backend/database**: Supabase.
- **AI provider**: the code currently calls **Gemini 3.7 Flash** (`generate`, `dialogue`
  Edge Functions). The provider is not final — **do not let provider-specific behaviour
  leak into design docs or the data contract**; swapping providers should only touch
  the Edge Function.
- **AI call architecture**: the mobile client NEVER connects to an AI provider or holds
  an API key. All AI requests go through Supabase Edge Functions; keys exist only in
  server-side environment variables.
- **Target / native language must not be hardcoded.** MVP is English-as-target and
  Chinese-as-native, but prompts and field names reason in "target" and "native"
  (e.g. `native_meaning`, not `zh_meaning`).
- **Verified security pattern for new tables** (follow it, don't reinvent): the Edge
  Function verifies the JWT via `/auth/v1/user` (never decode the token locally),
  writes `user_id`, returns 401 when there is no uid, filters every read by `user_id`,
  and the table has RLS enabled as defence in depth.

## Before You Change Anything

1. **Understand the data first.** Before changing a screen or feature, write down its
   data contract and get it confirmed: where each piece of data comes from, how it
   changes, when it changes, and where it flows. Do not optimise a flow whose data
   path you have not traced. (AI features have two request layers — our backend and
   the AI API — plus the conversation flow; user isolation, AI timeline ordering, AI
   return handling and display are the places that break. Template: "数据三问" in
   `architecture/AI协作手册.md`.)
2. **List the design tokens first.** Before building, list which tokens the feature
   touches — reused, new, modified — and confirm, so nothing is missed.
3. **For any UI/layout work**, read `design-system/信息层级与布局原则.md`. In short:
   - Diagnose first: *hierarchy* (granularity not aligned — never mix micro-grain with
     meso-grain in one block) or *layout* (alignment, repetition, proximity, contrast).
   - Describe problems in physical terms (tight/loose, big/small, light/heavy,
     thick/thin), not taste words.
   - **Control variables**: build the draft from production so it matches the live app
     exactly, change only the spot with the problem, keep everything else fixed — that
     is the only way to tell whether a change really helped.
   - **Then check the whole**: the same semantic must look the same everywhere. A
     locally harmonious fix is not necessarily a globally harmonious one.

## Code & Design Hard Constraints (mandatory rules for all code)

```
- Always use NavigationStack (never NavigationView). Use the @Observable macro for
  state; avoid @StateObject/@ObservedObject unless there is a specific reason.
- Use standard system components and default styling as the MVP starting point. Do
  not hand-write custom visual effects to mimic older iOS appearances.
- Separate structure/logic from style. All colors, fonts and spacing go through
  design tokens from day one — never write system literals (`.primary`,
  `.system(size: 16)`) in a component, even if a token currently resolves to one.
- Text must use the `AppTheme.Font.*` tokens. Each token is built on a system
  TextStyle (e.g. `.system(.title2, weight: .semibold)`) so Dynamic Type is kept.
  Never write `.system(size:)` in a component. (Icon glyph sizing on an
  `Image(systemName:)` is not text and is exempt.)
- Reusable UI units (cards, buttons, inputs, ...) are standalone components; do not
  assemble system controls + modifiers inline on a page.
- Every interactive-looking element must respond to taps (visual/haptic feedback at
  minimum). No decorative-only UI that looks clickable.
- All product UI text defaults to English (buttons, empty states, errors, titles,
  placeholders, toasts). Chinese may appear only as AI-generated learning content.
- Every screen defines its loading, empty and error states, including
  permission-denied (microphone/camera). They are core, not edge cases.
- Never embed API keys in app code (see Technology Choices).
```

**Design Token Rules** (full text with rationale: `design-system/token-rules.md`):

1. Name by PURPOSE, not appearance, as `category-purpose-level`
   (`color-text-primary`, `space-padding-card`). Never `color1`, `myGray`.
2. Reuse before creating. Check existing tokens first; never define one value under two names.
3. Define ALL tokens centrally in the theme file, in two layers: primitive (raw values)
   and semantic (purpose-named, referencing primitives). Components use only semantic.
4. A semantic token may hold a raw value directly **only if it is component-private**
   (serves one component, not on a design scale). Test: "would this value still mean
   anything on a different component?" Yes → promote it to a primitive. When unsure, promote.
5. Unconsumed primitive-ramp steps are normal — never delete them. Delete **semantic**
   tokens that have no consumer, and remove any token **your slice** orphaned in the same
   commit. Pre-existing orphans are cleaned in token-hygiene passes, not mid-feature.
   Confirm by reading before deleting; a naive grep misses alias and factory references.

Note: system chrome (navigation bar, Alert/Sheet, TabBar) has limited customization
APIs — a strong visual re-brand there means a fuller replacement, not a token edit.

## Working Method (how development is paced — mandatory)

- **Vertical slice first**: every feature starts as the narrowest complete chain
  (frontend + backend), validated end-to-end before expanding. Never build the full UI
  framework first and fill in functionality later.
- **Tests follow every slice, once behaviour has settled.** While the logic is still
  being iterated, do not write tests (they would be rewritten each time); once you
  believe the feature is correct, write unit tests to lock it in. Unit tests are the
  primary layer. `iOS tests` is a required PR check and the UI launch test must keep
  passing; when a slice changes navigation, onboarding or screen structure, add a minimal
  UI smoke test (`docs/engineering/CI.md` §Current UI-test scope). After tests pass,
  report the results in writing to the project owner (pass/fail, specific errors) and
  **wait for confirmation** before the next slice — do not keep modifying tests or code
  on your own.
- **Token hygiene**: every 2–3 slices, audit all tokens (naming, duplicates, merge/split,
  inline definitions). List issues and proposed fixes — do NOT auto-edit tokens without
  confirmation.

## Visual artifact self-check (视觉产物自查)

Before delivering a screenshot, recording or OCR result, **open it yourself and write down
in words what is actually in the frame**, then compare it line by line with your
description. If you cannot describe it, it has not been verified — "the command ran and
a file was produced" is not evidence. Why, and the three rework incidents behind this:
`docs/engineering/视觉产物自查.md`.

- Describe first, conclude second — never the other way round.
- Pixel / OCR checks only prove the image was *cropped correctly*, not that it is the
  *right scene*. Scene correctness is checked by eye against the fixture and the claim.
- Multi-state captures: `simctl launch` arguments only apply on a cold start, so
  `terminate` between shots or later shots silently reuse the first state.
- Fixtures must satisfy live validation rules (e.g. `scene_detail` ≤ 24 characters).
  A value that can never occur in production makes the check worthless.

## Debug Probes (DEBUG-only standing acceptance probes)

Toast end-to-end probes (`TOAST_PROBE`, `TOAST_PROBE_BLOCKED`, `TAB2_MILESTONE_DEMO`), all
inside `#if DEBUG`, never in Release. Environment variables, the `[toast-probe]` log format
and the acceptance criteria are in `docs/engineering/debug-probes.md`.

## CI & Pull Requests

For any task that changes code, tests, Supabase Functions, migrations, or GitHub
workflows, read `docs/engineering/CI.md` before verification. Run the documented local
checks once the slice is stable, report the results to the project owner, and require
the documented GitHub PR checks to pass before calling a PR ready to merge.

### Ship & Auto-Cleanup (自动化 PR 交付与生命周期闭环)

Three separate stages. **Merging and cleanup never happen automatically as part of "open a
PR".** Full version: `docs/engineering/交付与部署纪律.md`.

- **"提 PR" / open a PR → run only `bash scripts/ci/ship-pr.sh`.** Local guards (working
  tree clean *including untracked files*; commit author matches the current git identity),
  then push, create or reuse the PR, wait for CI. The script stops there and never merges.
- **"合并" / merge → `bash scripts/ci/ship-pr.sh merge`.** Requires a standalone, explicit
  instruction from the user. It re-checks that the PR has at least one check and all pass,
  squash-merges, does not delete the branch, and fast-forwards main with `--ff-only`
  (never `reset --hard`). The script refuses a PR with no checks (e.g. a `[skip ci]` commit).
  **PRs touching `supabase/` or `.github/` are refused by the script — the user merges
  those by hand.**
- **"清理" / cleanup → `bash scripts/ci/ship-pr.sh cleanup <PR number>`.** Also needs its
  own instruction, and the user must have confirmed Xcode is closed. Removes the worktree
  without `--force`, then deletes the local branch. If your own session is running inside
  that worktree, leave the directory right after cleanup.
- Trigger-word discipline: the word "merge" appearing in a message is not a merge command.

### Edge Function deploy discipline (Edge Function 部署纪律)

**For a PR that changes `supabase/functions/`, merging is not shipping** — an Edge Function
only takes effect once explicitly deployed. (Example: a fix was merged to main while the
live `generate` still ran the previous deployment, so the category-failure rate stayed at 89%.)

1. Deploying is part of finishing the slice; not deployed = not done.
2. After deploying, record the function name, version, deploy time and the commit SHA
   deployed, in the slice's acceptance record.
3. **Verify live behaviour, not code**: one real call plus a log line that only the new
   version can produce, **and** data showing the result is correct. Both are required; the
   strongest form is a before/after on the same input.
4. Fixes are not retroactive: data written before the deploy is a product of the old
   behaviour. Backfilling is a separate slice.
5. Never deploy from a feature branch: `functions deploy` pushes the whole workspace's
   `supabase/functions/`, including every un-reviewed backend change on that branch.

> The source is not evidence; the running system is.

## Project Owner Background (for Claude to calibrate explanations)

A product manager with a marketing background; zero coding background. Every
technical decision needs a "why," not just a conclusion. Priorities: interaction
experience, content value (kept minimal at MVP stage), software testing quality,
API security. Learning goals include: the Claude Code workflow (CLAUDE.md / MCP /
skills / subagents) and hands-on use of AI-assisted frontend design skills.
