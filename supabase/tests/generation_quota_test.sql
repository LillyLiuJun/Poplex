begin;

select plan(30);

-- Fixtures: auth.users rows for A and B — the handle_new_user trigger creates
-- a bare profiles row for each. User C (cccccccc-...) deliberately gets no
-- auth.users row and no profiles row: it simulates the profile-row-missing
-- edge case for the effective-limit fallback.
insert into auth.users (id) values
  ('aaaaaaaa-0000-0000-0000-00000000000a'::uuid),
  ('bbbbbbbb-0000-0000-0000-00000000000b'::uuid);

-- ─────────────────────────────────────────────────────────────
-- 1. Fresh user reads the global default: (0, 5, allowed).
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select used_count from public.check_generation_quota('2026-09-02'::date)),
  0,
  'a fresh user has used 0 generations today'
);
select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  5,
  'the effective limit defaults to the global app_config value'
);
select ok(
  (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'a fresh user is allowed to generate'
);

-- ─────────────────────────────────────────────────────────────
-- 2. Seed usage rows (server-side write, as postgres).
-- ─────────────────────────────────────────────────────────────
reset role;

insert into public.generation_usage (user_id, usage_date, used_count, updated_at) values
  ('aaaaaaaa-0000-0000-0000-00000000000a'::uuid, '2026-09-02'::date, 5, now()),
  ('bbbbbbbb-0000-0000-0000-00000000000b'::uuid, '2026-09-02'::date, 2, now());

-- ─────────────────────────────────────────────────────────────
-- 3. A user at the limit: (5, 5, blocked).
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select used_count from public.check_generation_quota('2026-09-02'::date)),
  5,
  'used_count reflects the committed generations'
);
select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  5,
  'the limit is unchanged at the global default'
);
select ok(
  not (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'a user at the limit is blocked'
);

-- ─────────────────────────────────────────────────────────────
-- 4. Cross-user isolation: A cannot see B's usage rows.
-- ─────────────────────────────────────────────────────────────
select is(
  (select count(*)::integer from public.generation_usage),
  1,
  'A''s RLS policy scopes table reads to their own row only'
);
select is(
  (select count(*)::integer from public.generation_usage
    where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'::uuid),
  0,
  'A cannot read B''s usage rows'
);

-- ─────────────────────────────────────────────────────────────
-- 5. The global config row is readable by signed-in users.
-- ─────────────────────────────────────────────────────────────
select is(
  (select value::integer from public.app_config
    where key = 'daily_generation_limit'),
  5,
  'a signed-in user can read the global limit'
);

-- ─────────────────────────────────────────────────────────────
-- 6. B under the limit: (2, 5, allowed).
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', true);

select is(
  (select used_count from public.check_generation_quota('2026-09-02'::date)),
  2,
  'B sees their own used count'
);
select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  5,
  'B inherits the global limit'
);
select ok(
  (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'B is allowed while under the limit'
);

-- ─────────────────────────────────────────────────────────────
-- 7. A per-user override wins over the global value.
-- ─────────────────────────────────────────────────────────────
reset role;
update public.profiles
   set daily_generation_limit = 20
 where id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  20,
  'an individual override wins over the global value'
);
select ok(
  (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'an overridden user is allowed at 5/20'
);

-- ─────────────────────────────────────────────────────────────
-- 8. Setting the override back to NULL returns to the global value.
-- ─────────────────────────────────────────────────────────────
reset role;
update public.profiles
   set daily_generation_limit = null
 where id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  5,
  'a NULL override falls back to the global value'
);
select ok(
  not (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'revoking an override restores the global limit immediately'
);

-- ─────────────────────────────────────────────────────────────
-- 9. A user with no profiles row still resolves the global value.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-00000000000c', true);

select is(
  (select used_count from public.check_generation_quota('2026-09-02'::date)),
  0,
  'a user with no profiles row reads as 0 used'
);
select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  5,
  'a missing profiles row still falls back to the global limit'
);
select ok(
  (select allowed from public.check_generation_quota('2026-09-02'::date)),
  'a user with no profiles row is allowed at the global limit'
);

-- ─────────────────────────────────────────────────────────────
-- 10. The Edge Function entry reads any named user, service_role only.
-- ─────────────────────────────────────────────────────────────
reset role;
set local role service_role;

select is(
  (select used_count from public.check_generation_quota_for_user(
    'bbbbbbbb-0000-0000-0000-00000000000b'::uuid, '2026-09-02'::date)),
  2,
  'service_role reads the named user''s used count'
);
select is(
  (select "limit" from public.check_generation_quota_for_user(
    'bbbbbbbb-0000-0000-0000-00000000000b'::uuid, '2026-09-02'::date)),
  5,
  'service_role reads the named user''s effective limit'
);
select ok(
  (select allowed from public.check_generation_quota_for_user(
    'bbbbbbbb-0000-0000-0000-00000000000b'::uuid, '2026-09-02'::date)),
  'service_role reads the named user''s allowed flag'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

-- pgTAP's throws_ok(sql, '42501', description) overload treats the third
-- argument as the EXPECTED ERROR MESSAGE, not a description — use the
-- 4-argument (sql, errcode::char(5), errmsg, description) form to match the
-- SQLSTATE exactly and leave the message unchecked.
select throws_ok(
  $$select * from public.check_generation_quota_for_user(
    'bbbbbbbb-0000-0000-0000-00000000000b'::uuid, '2026-09-02'::date)$$,
  '42501'::char(5),
  null,
  'a signed-in user cannot query another user''s quota'
);

-- ─────────────────────────────────────────────────────────────
-- 11. Direct client writes are blocked everywhere.
-- ─────────────────────────────────────────────────────────────
select throws_ok(
  $$insert into public.generation_usage (user_id, usage_date, used_count)
    values ('aaaaaaaa-0000-0000-0000-00000000000a'::uuid, '2026-09-02'::date, 9)$$,
  '42501'::char(5),
  null,
  'a signed-in user cannot insert usage rows'
);
select throws_ok(
  $$update public.generation_usage set used_count = 99
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid$$,
  '42501'::char(5),
  null,
  'a signed-in user cannot update usage rows'
);
select throws_ok(
  $$insert into public.app_config (key, value) values ('hacked', '1')$$,
  '42501'::char(5),
  null,
  'a signed-in user cannot insert config rows'
);
select throws_ok(
  $$update public.app_config set value = '999' where key = 'daily_generation_limit'$$,
  '42501'::char(5),
  null,
  'a signed-in user cannot update the global limit'
);

-- ─────────────────────────────────────────────────────────────
-- 12. The override column is server-managed: the guard trigger strips
--     client writes silently instead of raising, so a client payload
--     can never change it and the self-healing upsert keeps working.
-- ─────────────────────────────────────────────────────────────
reset role;
update public.profiles
   set daily_generation_limit = 20
 where id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid;

-- User C gets an auth.users row now (profiles.id references auth.users);
-- handle_new_user creates the profile, which is removed so the plain
-- INSERT below really exercises the trigger's INSERT branch.
insert into auth.users (id)
values ('cccccccc-0000-0000-0000-00000000000c'::uuid);
delete from public.profiles
 where id = 'cccccccc-0000-0000-0000-00000000000c'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

update public.profiles
   set daily_generation_limit = 999
 where id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid;

select is(
  (select daily_generation_limit from public.profiles
    where id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid),
  20,
  'a signed-in user cannot raise their own override (the write is stripped)'
);

select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-00000000000c', true);

insert into public.profiles (id, daily_generation_limit)
values ('cccccccc-0000-0000-0000-00000000000c'::uuid, 999);

select is(
  (select daily_generation_limit from public.profiles
    where id = 'cccccccc-0000-0000-0000-00000000000c'::uuid),
  null,
  'the insert path strips a client-supplied override to NULL'
);

-- ─────────────────────────────────────────────────────────────
-- 13. Changing the global value applies immediately to everyone
--     without an override.
-- ─────────────────────────────────────────────────────────────
reset role;
update public.app_config set value = '8' where key = 'daily_generation_limit';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', true);

select is(
  (select "limit" from public.check_generation_quota('2026-09-02'::date)),
  8,
  'a global config change applies immediately to non-overridden users'
);

-- Restore the global value for any later tests in this transaction.
reset role;
update public.app_config set value = '5' where key = 'daily_generation_limit';

select * from finish();

rollback;
