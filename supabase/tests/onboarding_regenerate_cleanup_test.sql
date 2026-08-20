begin;

select plan(12);

-- Fixture: profiles.id has a real FK to auth.users(id), so every test user
-- that gets a profiles row below needs a minimal auth.users row first. User D
-- deliberately gets neither — it simulates the profiles-row-missing edge case.
insert into auth.users (id) values
  ('55555555-5555-5555-5555-555555555555'::uuid),
  ('bbbbbbbb-6666-6666-6666-666666666666'::uuid),
  ('55555555-5555-5555-5555-555555555e01'::uuid),
  ('55555555-5555-5555-5555-555555555f01'::uuid),
  ('66666666-6666-6666-6666-666666666601'::uuid),
  ('66666666-6666-6666-6666-666666666602'::uuid);

-- Set each test user's profiles row to the state this suite needs, before
-- switching acting identity per test. The auth.users insert above already
-- triggered handle_new_user() to auto-create a bare row for each of them
-- (onboarding_completed_at defaults to null), so this is an upsert, not a
-- fresh insert. UPDATE is allowed under "update_own_profile" as long as the
-- JWT claim matches the row being written.
set local role authenticated;

-- User A: mid-onboarding, not yet completed — cleanup should fire.
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('55555555-5555-5555-5555-555555555555'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- User B: already completed onboarding — cleanup must never touch their data,
-- even if a client bug re-enters onboarding for them (see design note in the
-- migration: the local "done" flag can go stale after a reinstall combined
-- with a failed background confirmation check).
select set_config('request.jwt.claim.sub', 'bbbbbbbb-6666-6666-6666-666666666666', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('bbbbbbbb-6666-6666-6666-666666666666'::uuid, now())
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- User E: not yet completed, used for the tab1-must-not-cleanup case.
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555e01', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('55555555-5555-5555-5555-555555555e01'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- User F: not yet completed, used for the cross-path (preset-card -> photo) case.
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555f01', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('55555555-5555-5555-5555-555555555f01'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- User H and User I: not yet completed, used for the cross-user isolation case.
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666601', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('66666666-6666-6666-6666-666666666601'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666602', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('66666666-6666-6666-6666-666666666602'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- User D deliberately gets no profiles row at all — simulates the row-missing
-- edge case (a signup trigger guarantees this doesn't normally happen).

-- ─────────────────────────────────────────────────────────────
-- 1. Cleanup fires: a second successful onboarding attempt removes the first.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);

select public.commit_generated_content(
  'd0000001-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] first attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'First attempt'), 'source', 'onboarding'),
  jsonb_build_object('material_type', 'scene', 'raw_content', jsonb_build_object('user_original', '[photo] first attempt'), 'source', 'onboarding')
);

select public.commit_generated_content(
  'd0000001-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] second attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Second attempt'), 'source', 'onboarding'),
  jsonb_build_object('material_type', 'scene', 'raw_content', jsonb_build_object('user_original', '[photo] second attempt'), 'source', 'onboarding')
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '55555555-5555-5555-5555-555555555555'::uuid
      and request_id = 'd0000001-0000-0000-0000-000000000001'::uuid),
  0,
  'the first onboarding attempt''s messages are removed once the second succeeds'
);

select is(
  (select count(*)::integer from public.materials
    where user_id = '55555555-5555-5555-5555-555555555555'::uuid
      and request_id = 'd0000001-0000-0000-0000-000000000001'::uuid),
  0,
  'the first onboarding attempt''s material is removed once the second succeeds'
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '55555555-5555-5555-5555-555555555555'::uuid
      and request_id = 'd0000001-0000-0000-0000-000000000002'::uuid),
  2,
  'the second (surviving) onboarding attempt keeps both messages'
);

-- ─────────────────────────────────────────────────────────────
-- 2. Already-completed users are never touched by cleanup.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', 'bbbbbbbb-6666-6666-6666-666666666666', true);

select public.commit_generated_content(
  'd0000002-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] stray onboarding retry', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Stray retry'), 'source', 'onboarding'),
  null
);

select public.commit_generated_content(
  'd0000002-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] another stray retry', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Another stray retry'), 'source', 'onboarding'),
  null
);

select is(
  (select count(*)::integer from public.messages
    where user_id = 'bbbbbbbb-6666-6666-6666-666666666666'::uuid
      and request_id = 'd0000002-0000-0000-0000-000000000001'::uuid),
  2,
  'an already-completed user''s prior onboarding-sourced commit survives a later one'
);

-- ─────────────────────────────────────────────────────────────
-- 3. A missing profiles row is treated as "unknown" and cleanup is skipped.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888888', true);

select public.commit_generated_content(
  'd0000003-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] first', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'First'), 'source', 'onboarding'),
  null
);

select public.commit_generated_content(
  'd0000003-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] second', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Second'), 'source', 'onboarding'),
  null
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '88888888-8888-8888-8888-888888888888'::uuid
      and request_id = 'd0000003-0000-0000-0000-000000000001'::uuid),
  2,
  'a user with no profiles row at all is not cleaned up (cannot confirm not-yet-completed)'
);

-- ─────────────────────────────────────────────────────────────
-- 4. A tab1-sourced commit must never sweep a user's onboarding rows.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555e01', true);

select public.commit_generated_content(
  'd0000004-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] onboarding attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Onboarding attempt'), 'source', 'onboarding'),
  null
);

select public.commit_generated_content(
  'd0000004-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'text', 'user_content', 'normal tab1 message', 'source', 'tab1'),
  jsonb_build_object('card_type', 's1', 'card_content', jsonb_build_object('title', 'Tab1 card'), 'source', 'tab1'),
  null
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '55555555-5555-5555-5555-555555555e01'::uuid
      and request_id = 'd0000004-0000-0000-0000-000000000001'::uuid),
  2,
  'a later tab1-sourced commit does not delete the user''s onboarding-sourced commit'
);

-- ─────────────────────────────────────────────────────────────
-- 5. Cross-path: a photo attempt cleans up an earlier preset-card attempt,
--    proving the predicate is by source, not by which function produced it.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555f01', true);

select public.commit_generated_content(
  'd0000005-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'preset_card', 'user_content', 'Describe this image', 'preset_card_id', 'sample-card-1', 'source', 'onboarding'),
  jsonb_build_object('card_type', 'card', 'card_content', jsonb_build_object('target_expression', 'Preset card attempt'), 'source', 'onboarding'),
  null
);

select public.commit_generated_content(
  'd0000005-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] replaces the preset card', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Photo attempt'), 'source', 'onboarding'),
  jsonb_build_object('material_type', 'scene', 'raw_content', jsonb_build_object('user_original', '[photo] replaces the preset card'), 'source', 'onboarding')
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '55555555-5555-5555-5555-555555555f01'::uuid
      and request_id = 'd0000005-0000-0000-0000-000000000001'::uuid),
  0,
  'a later photo attempt cleans up an earlier preset-card attempt for the same user'
);

select is(
  (select count(*)::integer from public.messages
    where user_id = '55555555-5555-5555-5555-555555555f01'::uuid
      and request_id = 'd0000005-0000-0000-0000-000000000002'::uuid),
  2,
  'the surviving photo attempt keeps both messages'
);

select is(
  (select count(*)::integer from public.materials
    where user_id = '55555555-5555-5555-5555-555555555f01'::uuid
      and request_id = 'd0000005-0000-0000-0000-000000000002'::uuid),
  1,
  'the surviving photo attempt keeps its material'
);

-- ─────────────────────────────────────────────────────────────
-- 6. Cross-user isolation: cleanup never touches another user's rows.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666602', true);
select public.commit_generated_content(
  'd0000006-0000-0000-0000-000000000009'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] user I attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'User I attempt'), 'source', 'onboarding'),
  null
);

select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666601', true);
select public.commit_generated_content(
  'd0000006-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] user H first attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'User H first attempt'), 'source', 'onboarding'),
  null
);
select public.commit_generated_content(
  'd0000006-0000-0000-0000-000000000002'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] user H second attempt', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'User H second attempt'), 'source', 'onboarding'),
  null
);

-- RLS's own SELECT policy scopes reads to auth.uid() = user_id, so checking
-- user I's rows requires re-authenticating as user I first — otherwise the
-- count would read 0 regardless of what's actually in the table, which would
-- be a false signal of data loss rather than a real one.
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666602', true);
select is(
  (select count(*)::integer from public.messages
    where user_id = '66666666-6666-6666-6666-666666666602'::uuid
      and request_id = 'd0000006-0000-0000-0000-000000000009'::uuid),
  2,
  'user H''s cleanup does not remove user I''s onboarding attempt'
);

select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666601', true);
select is(
  (select count(*)::integer from public.messages
    where user_id = '66666666-6666-6666-6666-666666666601'::uuid
      and request_id = 'd0000006-0000-0000-0000-000000000001'::uuid),
  0,
  'user H''s own first attempt is still cleaned up by their second'
);

-- ─────────────────────────────────────────────────────────────
-- 7. The new DELETE policy is scoped to own rows: a different user cannot
--    delete someone else's message directly through the table.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555e01', true);
delete from public.messages
 where user_id = '66666666-6666-6666-6666-666666666602'::uuid
   and request_id = 'd0000006-0000-0000-0000-000000000009'::uuid;

-- Verifying the delete was blocked requires reading as the row's own owner
-- (user I) — same RLS-visibility reasoning as the assertions above.
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666602', true);
select is(
  (select count(*)::integer from public.messages
    where user_id = '66666666-6666-6666-6666-666666666602'::uuid
      and request_id = 'd0000006-0000-0000-0000-000000000009'::uuid),
  2,
  'a user cannot delete another user''s message row directly (RLS scopes DELETE to own rows)'
);

select * from finish();

rollback;
