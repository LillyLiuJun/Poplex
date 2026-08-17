# Photo Generation Reliable Commit Design

## Goal

Guarantee that an onboarding photo cannot be lost after the UI reports success, and that the local unique copy remains recoverable until the server has durably committed the corresponding history.

This is the first P0 vertical slice. It covers the photo-generation path only. Preset-card atomicity, replacement of previously successful onboarding content, and atomic storage internals are separate follow-up slices.

## Product invariant

1. If the UI reports generation success, the authenticated user's user message, assistant card, and core material must already be durably committed and queryable.
2. Until that server success is confirmed, the client must retain the local photo and pending-retry metadata.
3. Retrying the same user action must not create duplicate history.

## User experience

The normal success interaction does not change: the user sees the generated card and can continue to Tab1.

If authentication, transport, decoding, AI generation, or durable persistence fails, the result screen keeps the selected photo, displays the existing persistent error treatment, and allows Try again or Continue. Continue persists the photo as a Tab1 pending retry regardless of whether the failure was classified as offline or generic.

If the session is invalid, the client retains the pending item. A later retry may refresh authentication through the existing session mechanism; the item is not discarded merely because the request returned 401.

## Request identity and idempotency

Each new photo selection creates one UUID `request_id`. Every retry of that same selection reuses it. Selecting a different photo creates a new ID.

The client sends `request_id` to `generate`. The database enforces uniqueness on `(user_id, request_id)` for the committed operation. A repeated request returns the already committed result and does not invoke a second durable write.

For rollout compatibility, `request_id` remains optional for old clients. The Edge Function generates an ID when it is absent. Only new clients receive reliable cross-request idempotency.

## Backend flow

`generate` performs these stages in order:

1. Validate the bearer token through Supabase Auth `/auth/v1/user`.
2. Return 401 immediately if no user ID can be established.
3. Resolve `request_id` and check for an already committed result owned by that user.
4. If committed, return the stored assistant card and identifiers without invoking the AI provider.
5. Upload/process the image and call the AI provider outside any database transaction.
6. Call one Postgres RPC that atomically writes the user message, assistant message, and core material under `(user_id, request_id)`.
7. Return 200 only after that RPC commits and returns the durable record identifiers.

The transaction covers only the minimum history needed to reconstruct Tab1. External AI calls and Storage operations must never run inside the database transaction.

## Transaction model

The migration adds request identity to the records required for reconstruction and provides one narrowly scoped RPC. The RPC:

- derives ownership from the authenticated caller rather than trusting a payload `user_id`;
- rejects unauthenticated callers;
- inserts the user message, assistant message, and core material in one transaction;
- treats `(user_id, request_id)` as the idempotency key;
- returns the identifiers and stored assistant card for both a first commit and a duplicate retry;
- cannot expose another user's committed result;
- keeps RLS enabled as defence in depth.

Any optional downstream accounting remains non-blocking and outside the reliable-commit transaction. It must not turn a committed user-visible result back into failure.

## Client pending lifecycle

The onboarding view model owns the current `request_id` alongside the selected image.

- A new image creates a new request ID.
- Try again reuses it.
- Back/reset or choosing a replacement image discards that in-memory operation and creates a new ID for the replacement.
- Every non-success outcome that still permits Continue is eligible for pending persistence.
- Pending metadata stores `request_id` so Tab1 Retry reuses it across app restarts.
- Retry failure retains metadata and the JPEG.
- Retry success removes the pending item only after the server response confirms the same `request_id` was durably committed.

Content-blocked input remains unchanged: the selected image is cleared, Continue is unavailable, and no pending retry is created.

## Public test seams

### Database RPC

Database tests verify:

- unauthenticated calls are rejected;
- all three core records commit together;
- an injected failure leaves none of the three records;
- repeating `(user_id, request_id)` returns the original operation without duplicates;
- one user cannot read or collide with another user's request.

### `generate` HTTP contract

Edge Function contract tests verify:

- invalid authentication returns 401 before AI or persistence;
- persistence failure cannot return 200;
- a committed duplicate returns the stored result;
- success contains the echoed `request_id` and durable server identifiers.

### iOS state boundary

iOS unit tests verify:

- offline and generic failures both become pending when the user continues;
- the same photo retry preserves `request_id`;
- retry failure preserves the local JPEG and metadata;
- a response for a different request cannot clear the pending item;
- confirmed success for the same request clears it.

## Deployment and rollback

The first validation environment is the local Supabase stack, which costs nothing and does not touch production data.

Production rollout is backward-compatible and ordered:

1. Deploy the additive database migration and RPC.
2. Deploy the compatible `generate` Edge Function, still accepting old clients without `request_id`.
3. Smoke-test old and new request shapes.
4. Release the iOS client that supplies stable request IDs and persists all retryable failures.

Rollback is performed in reverse at the application layer: revert the iOS client/Edge Function while leaving additive nullable columns and the unused RPC in place. Destructive schema rollback is not required during an incident.

## Performance expectations

AI generation and image processing duration do not increase. Replacing multiple database REST writes with one RPC reduces network round trips. The transaction begins only after AI generation completes, so it does not hold a database connection during the slow external call.

## Explicitly out of scope

- Preset-card user/assistant atomic write and its 60-second deduplication defect.
- Making JPEG-file and UserDefaults metadata writes internally atomic.
- Changing the onboarding policy that deletes or replaces older successful server content.
- Guaranteeing image upload and database commit in one distributed transaction.
- Building a durable server-side AI job state machine to avoid repeated provider cost after AI success but pre-commit failure.

These remain P0 follow-up slices. This slice establishes the reliable commit contract they will reuse.
