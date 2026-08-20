# Photo Generation Reliable Commit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make onboarding photo generation durable, authenticated, idempotent, and locally recoverable until the server confirms the same request was committed.

**Architecture:** A stable client `request_id` follows one selected photo through onboarding and Tab1 retry. The Edge Function validates Auth before external work, checks for an existing committed request, then calls one Postgres RPC that atomically writes the reconstructable message pair and core material. Client pending data is removed only when the returned success identifies the same request.

**Tech Stack:** Swift 5 / SwiftUI iOS 17 / Swift Testing, Supabase Edge Functions (Deno TypeScript), Postgres 17, pgTAP, Supabase CLI local stack.

**Spec:** `docs/superpowers/specs/2026-08-16-photo-generation-reliable-commit-design.md`

## Global Constraints

- Target iOS 17+ and use `@Observable`; do not introduce `ObservableObject`.
- Product UI copy remains English and existing error visuals are reused.
- The mobile client never receives a service-role key or AI-provider key.
- Auth ownership comes from verified Supabase Auth identity, never from a body `user_id`.
- RLS remains enabled on `messages` and `materials` as defence in depth.
- AI and Storage calls stay outside the database transaction.
- Old clients without `request_id` remain accepted during rollout.
- No production deployment occurs before local database, Edge Function, and iOS tests pass and the owner confirms the written results.

---

### Task 1: Add the atomic and idempotent Postgres commit boundary

**Files:**
- Create with `supabase migration new reliable_photo_generation_commit`: the exact CLI-emitted file under `supabase/migrations/`
- Create: `supabase/tests/reliable_photo_generation_commit_test.sql`

**Interfaces:**
- Consumes: authenticated `auth.uid()`, one UUID request ID, two message JSON objects, and one optional material JSON object.
- Produces: `public.commit_generated_content(p_request_id uuid, p_user_message jsonb, p_assistant_message jsonb, p_material jsonb) returns jsonb`.
- Produces JSON keys: `request_id`, `user_message_id`, `assistant_message_id`, `material_id`, `card_type`, `card_content`, and `already_committed`.

- [ ] **Step 1: Confirm the local tooling and create the migration using the CLI**

Run:

```bash
supabase --version
supabase migration new reliable_photo_generation_commit
```

Expected: the CLI prints one newly created migration path. Use that exact emitted path for every migration edit; do not invent a timestamp.

- [ ] **Step 2: Write the failing pgTAP contract tests**

Create `supabase/tests/reliable_photo_generation_commit_test.sql` with tests that set a request-scoped JWT subject, call the public RPC twice, and assert these observable outcomes:

```sql
select plan(8);

-- unauthenticated call raises insufficient_privilege
-- first authenticated call returns already_committed=false
-- exactly two messages share request_id and the authenticated user_id
-- exactly one material shares request_id and the authenticated user_id
-- second call with the same user/request returns already_committed=true
-- second call does not increase either row count
-- a forced invalid material payload rolls the two message inserts back
-- a second user can use the same request UUID without seeing the first result

select * from finish();
```

Use fixed UUID literals as independent expected values. Do not assert private PL/pgSQL branches.

- [ ] **Step 3: Run the database test and verify RED**

Run:

```bash
supabase start
supabase db reset
supabase test db supabase/tests/reliable_photo_generation_commit_test.sql
```

Expected: FAIL because `commit_generated_content` and `request_id` columns do not exist.

- [ ] **Step 4: Implement the additive migration**

In the CLI-created migration:

```sql
alter table public.messages add column if not exists request_id uuid;
alter table public.materials add column if not exists request_id uuid;

create unique index if not exists messages_user_request_role_key
  on public.messages (user_id, request_id, role)
  where request_id is not null;

create unique index if not exists materials_user_request_key
  on public.materials (user_id, request_id)
  where request_id is not null;
```

Implement `commit_generated_content` as `security invoker`, obtain the owner with `(select auth.uid())`, reject null ownership, lock the idempotency key with `pg_advisory_xact_lock(hashtextextended(uid::text || ':' || request_id::text, 0))`, return an existing complete operation only when both messages and the expected material exist, otherwise insert all required rows and return their durable IDs. Revoke the default public execute grant and grant execute only to `authenticated` and `service_role`.

The RPC must derive every inserted `user_id` and `request_id` internally and whitelist payload fields instead of expanding arbitrary JSON directly into a row.

- [ ] **Step 5: Reset the local database and verify GREEN**

Run:

```bash
supabase db reset
supabase test db supabase/tests/reliable_photo_generation_commit_test.sql
supabase db lint --level warning
```

Expected: all 8 pgTAP assertions pass and lint reports no new security error.

- [ ] **Step 6: Commit the database slice**

```bash
git add supabase/migrations supabase/tests/reliable_photo_generation_commit_test.sql
git commit -m "feat(db): commit generated content atomically"
```

### Task 2: Make the Edge Function success contract truthful

**Files:**
- Create: `supabase/functions/generate/reliableCommit.ts`
- Create: `supabase/functions/generate/reliableCommit_test.ts`
- Modify: `supabase/functions/generate/index.ts`

**Interfaces:**
- Consumes RPC from Task 1.
- Produces `resolveCommittedRequest(...)` and `commitGeneratedContent(...)` adapters whose injected `fetch` makes HTTP status behavior testable.
- `generate` accepts optional JSON `request_id`; success echoes `request_id`, `user_message_id`, `assistant_message_id`, and `material_id` alongside the existing card fields.

- [ ] **Step 1: Write failing adapter tests**

In `reliableCommit_test.ts`, use `Deno.test` and an injected fake `fetch` to verify:

```ts
// 401 auth response => authentication result is absent and no downstream fetch runs
// RPC 500 => commitGeneratedContent throws and cannot be converted to success
// RPC 200 with already_committed=true => stored card and durable IDs are returned
// RPC 200 with a mismatched request_id => adapter rejects the response
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
deno test supabase/functions/generate/reliableCommit_test.ts
```

Expected: FAIL because `reliableCommit.ts` does not exist.

- [ ] **Step 3: Implement the narrow adapters**

`reliableCommit.ts` must expose typed results and check every `Response.ok` before decoding. Authentication uses `/auth/v1/user`; the RPC call uses the caller's Authorization header plus the project publishable/anon API key so `auth.uid()` is available inside the transaction. Do not pass `user_id` in the RPC payload.

- [ ] **Step 4: Run adapter tests and verify GREEN**

Run:

```bash
deno test supabase/functions/generate/reliableCommit_test.ts
```

Expected: PASS.

- [ ] **Step 5: Write the failing handler-level contract harness**

Extract the handler construction just enough to inject Auth, Gemini, Storage, and RPC fetch behavior. Assert:

```ts
// invalid token => HTTP 401, Gemini calls = 0, RPC calls = 0
// committed duplicate => HTTP 200, Gemini calls = 0, returned request_id matches input
// new request + RPC failure => HTTP 502, never HTTP 200
// new request + RPC success => HTTP 200 and all durable IDs are present
```

- [ ] **Step 6: Verify handler contract RED, then replace independent writes**

Run the focused test and confirm it fails against the current handler. Then modify `index.ts` to:

1. parse or generate `request_id`;
2. return 401 immediately when Auth cannot identify the user;
3. short-circuit a complete duplicate before Gemini;
4. keep Gemini/upload outside the transaction;
5. build the existing `raw_content` and call the atomic RPC once;
6. return 502 and retain the uploaded object path for retry/reconciliation when commit fails;
7. return 200 only with the RPC's durable result;
8. leave lexicon accounting non-blocking after commit.

Delete the old `insertMessage` success path and stop calling `saveMaterial` for the core insert. Retain pure classification/accounting helpers only where they operate after the reliable commit.

- [ ] **Step 7: Run all generate tests**

Run:

```bash
deno test supabase/functions/generate
```

Expected: all model-gate, raw-content, reliable-commit, and handler contract tests pass.

- [ ] **Step 8: Commit the Edge Function slice**

```bash
git add supabase/functions/generate
git commit -m "fix(generate): return success only after durable commit"
```

### Task 3: Carry request identity through the iOS service contract

**Files:**
- Modify: `AIEnglishApp/Services/AIService.swift`
- Modify: the file that declares `AIEnvelope` found by `rg -n 'struct AIEnvelope' AIEnglishApp`
- Modify: `AIEnglishAppTests/AIEnglishAppTests.swift`

**Interfaces:**
- Changes `AIServicing.generate` to include `requestId: UUID?` before `source`.
- Adds optional response metadata to `AIEnvelope`: `requestId`, `userMessageId`, `assistantMessageId`, and `materialId`.
- Old server-shaped fixtures without metadata continue decoding for non-onboarding and mock compatibility; reliable onboarding success separately validates matching metadata.

- [ ] **Step 1: Write failing encoding and decoding tests**

Add Swift Testing cases asserting that a fixed UUID becomes JSON key `request_id`, that returned snake-case identifiers decode, and that existing card-only fixtures still decode.

- [ ] **Step 2: Run focused tests and verify RED**

Run the iOS test target filtered to the AI service tests. Expected: compile/test failure because request identity is not represented.

- [ ] **Step 3: Implement the service contract minimally**

Add `requestId` to the protocol and mocks, write `request_id` into the body only when non-nil, and decode the optional durable identifiers using explicit `CodingKeys`. Do not change UI copy or unrelated generation behavior.

- [ ] **Step 4: Run focused tests and verify GREEN**

Expected: request encoding, new response decoding, and legacy fixtures pass.

- [ ] **Step 5: Commit the client API slice**

```bash
git add AIEnglishApp/Services/AIService.swift AIEnglishApp AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "feat(ios): carry generation request identity"
```

### Task 4: Persist every retryable onboarding photo with its request ID

**Files:**
- Modify: `AIEnglishApp/Onboarding/OnboardingViewModel.swift`
- Modify: `AIEnglishApp/Onboarding/OnboardingView.swift`
- Modify: `AIEnglishApp/Services/PendingRetryStore.swift`
- Modify: `AIEnglishAppTests/AIEnglishAppTests.swift`

**Interfaces:**
- `OnboardingViewModel` produces `currentRequestId: UUID?` and `hasUnconfirmedPhotoGeneration: Bool`.
- `PendingRetryRecord` gains optional `requestId: UUID?` for backward-compatible decoding.
- `savePhoto(_ image: UIImage, requestId: UUID)` persists both the JPEG and request identity.

- [ ] **Step 1: Write the failing state tests**

Add tests proving:

```swift
// selecting one image creates one ID; retry keeps it
// selecting a replacement image creates a different ID
// generic failure leaves hasUnconfirmedPhotoGeneration true
// matching durable response clears the unconfirmed state
// mismatched or absent response request ID is treated as failure
// contentBlocked clears the selection and creates no pending eligibility
```

- [ ] **Step 2: Write the failing persistence compatibility tests**

Verify `savePhoto` round-trips the fixed request UUID across a new store instance, and a legacy JSON record without `requestId` still decodes with nil.

- [ ] **Step 3: Run focused onboarding/pending tests and verify RED**

Expected: compile/test failures at the new public state and persistence seams.

- [ ] **Step 4: Implement request lifecycle and generic-failure retention**

Create the request ID in `startWithImage`, reuse it in `retry`, pass it to `service.generate`, and require a matching echoed ID plus durable message IDs before setting `generationResult`. Replace the offline-only completion condition with `hasUnconfirmedPhotoGeneration`, while leaving content-blocked behavior unchanged.

Do not silently discard `savePhoto` errors: keep onboarding open and surface the existing generic persistent error state when the local unique copy cannot be written. Set the local onboarding completion flag only after required pending persistence succeeds.

- [ ] **Step 5: Run focused tests and verify GREEN**

Expected: all new lifecycle and persistence tests pass, plus existing offline/content-blocked tests remain green.

- [ ] **Step 6: Commit the onboarding slice**

```bash
git add AIEnglishApp/Onboarding AIEnglishApp/Services/PendingRetryStore.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "fix(onboarding): retain every unconfirmed photo"
```

### Task 5: Reconcile Tab1 Retry before deleting the local unique copy

**Files:**
- Modify: `AIEnglishApp/Today/TodayViewModel.swift`
- Modify: `AIEnglishAppTests/AIEnglishAppTests.swift`

**Interfaces:**
- Consumes `PendingRetryRecord.requestId` and durable response metadata from Tasks 3–4.
- Removes a pending photo only when response `requestId` equals the pending request and durable user/assistant IDs are present.

- [ ] **Step 1: Write failing Retry reconciliation tests**

Add cases for matching success, mismatched request ID, missing durable IDs, transport failure, and a legacy pending record without a request ID. Only matching confirmed success may remove the record and replace it with the bubble/card pair; all other cases retain the JPEG and pending row.

- [ ] **Step 2: Run focused tests and verify RED**

Expected: the current code incorrectly clears pending on any decoded card success.

- [ ] **Step 3: Implement confirmed-success reconciliation**

Pass the pending request ID into `service.generate`. For legacy records without one, assign and persist a stable ID before the first retry rather than generating a different ID on every attempt. Validate the returned request and durable IDs before calling `pendingRetryStore.remove`.

- [ ] **Step 4: Run focused and full iOS tests**

Run the focused Today tests, then the complete `AIEnglishAppTests` target on the available iOS simulator. Expected: all pass.

- [ ] **Step 5: Commit the Tab1 slice**

```bash
git add AIEnglishApp/Today/TodayViewModel.swift AIEnglishApp/Services/PendingRetryStore.swift AIEnglishAppTests/AIEnglishAppTests.swift
git commit -m "fix(today): clear pending only after confirmed commit"
```

### Task 6: Validate the zero-cost test environment and prepare production rollout

**Files:**
- Modify only if test instructions need correction: `docs/superpowers/specs/2026-08-16-photo-generation-reliable-commit-design.md`
- Create: `docs/testing/2026-08-16-photo-generation-reliable-commit-results.md`

**Interfaces:**
- Consumes all prior slices.
- Produces written evidence for the owner; does not mutate production.

- [ ] **Step 1: Rebuild the local Supabase stack from migrations**

```bash
supabase db reset
supabase test db
deno test supabase/functions/generate
```

Expected: clean migration replay and all database/function tests pass.

- [ ] **Step 2: Run local HTTP fault injection**

Serve `generate` locally and exercise: invalid JWT, RPC rejection, duplicated `request_id`, and a successful authenticated photo fixture. Record only redacted status codes, IDs, row counts, and timings; never record tokens or image payloads.

- [ ] **Step 3: Run the full iOS test target**

Use `xcodebuild test` with the available iPhone simulator and record the exact destination and summary. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Audit cleanup and security**

```bash
rg -n '\[DEBUG-' AIEnglishApp supabase
git diff --check
git status --short
```

Expected: no temporary debug tags, no whitespace errors, and the unrelated `supabase/functions/debug-messages/` remains untouched.

Review that the RPC has no `PUBLIC` execute grant, no payload-controlled owner, no service-role secret in iOS, and no external call inside the transaction.

- [ ] **Step 5: Write and commit the test report**

Document pass/fail results, fault-injection evidence, known limitations, and exact production order. Commit only scoped files:

```bash
git add docs/testing/2026-08-16-photo-generation-reliable-commit-results.md
git commit -m "test: verify reliable photo generation commit"
```

- [ ] **Step 6: Stop for owner confirmation**

Report the local-test evidence and wait. Do not run `supabase db push`, `supabase functions deploy`, distribute an iOS build, or modify production secrets until the owner explicitly approves the production rollout checkpoint.
