begin;

select plan(22);

-- Fixtures: auth.users rows for A and B — handle_new_user creates a bare
-- profiles row for each, so B starts onboarding-incomplete (onboarding
-- completed_at IS NULL) and A is a normal user.
insert into auth.users (id) values
  ('aaaaaaaa-0000-0000-0000-00000000000a'::uuid),
  ('bbbbbbbb-0000-0000-0000-00000000000b'::uuid);

-- Payload shapes mirror what the Edge Functions send. v_source is taken from
-- the USER message's source field.
-- ─────────────────────────────────────────────────────────────
-- 1. A first commit with a usage date consumes one generation.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d1'::uuid,
       '{"input_type":"text","user_content":"hello","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"x"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'false',
  'a first commit lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  1,
  'a successful commit consumes one generation'
);

-- ─────────────────────────────────────────────────────────────
-- 2. The idempotent path never reaches the deduction.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d1'::uuid,
       '{"input_type":"text","user_content":"hello","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"x"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'true',
  'a retried request reports already_committed'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  1,
  'an idempotent retry consumes nothing'
);

-- ─────────────────────────────────────────────────────────────
-- 3. A second distinct commit increments the same bucket.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d2'::uuid,
       '{"input_type":"text","user_content":"again","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"y"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'false',
  'a second distinct commit lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  2,
  'each successful commit advances the counter'
);

-- ─────────────────────────────────────────────────────────────
-- 4. Bucketing follows the caller-supplied date, never now().
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d3'::uuid,
       '{"input_type":"text","user_content":"tomorrow","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"z"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-03'::date,
       true
     ), 'already_committed')),
  'false',
  'a commit dated for another day lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  2,
  'the original day''s bucket is untouched by a later-dated commit'
);
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-03'::date), 0),
  1,
  'the caller-supplied date starts its own bucket'
);

-- ─────────────────────────────────────────────────────────────
-- 5. p_count_usage = false skips the deduction entirely.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d4'::uuid,
       '{"input_type":"text","user_content":"free","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"w"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       false
     ), 'already_committed')),
  'false',
  'a commit with counting disabled still lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  2,
  'p_count_usage=false consumes nothing'
);

-- ─────────────────────────────────────────────────────────────
-- 6. A NULL usage date (old callers) consumes nothing.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d5'::uuid,
       '{"input_type":"text","user_content":"legacy","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"v"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       NULL::date,
       true
     ), 'already_committed')),
  'false',
  'a legacy-shaped commit still lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'::uuid
      and usage_date = '2026-09-02'::date), 0),
  2,
  'a caller that never sends a usage date consumes nothing'
);

-- ─────────────────────────────────────────────────────────────
-- 7. Onboarding-incomplete commits are exempt, judged server-side.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d6'::uuid,
       '{"input_type":"preset_card","user_content":"hi","source":"onboarding","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{},"source":"onboarding","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'false',
  'an onboarding commit lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'::uuid
      and usage_date = '2026-09-02'::date), 0),
  0,
  'a user who has not completed onboarding is exempt even when counting is requested'
);

-- ─────────────────────────────────────────────────────────────
-- 8. Only onboarding-sourced commits are exempt: a normal source
--    counts even mid-onboarding.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d7'::uuid,
       '{"input_type":"text","user_content":"sneak","source":"tab1","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{"target_expression":"u"},"source":"tab1","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'false',
  'a non-onboarding commit lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'::uuid
      and usage_date = '2026-09-02'::date), 0),
  1,
  'a tab1-source commit consumes even before onboarding completes'
);

-- ─────────────────────────────────────────────────────────────
-- 9. Completing onboarding closes the exemption: a forged
--    source='onboarding' can no longer dodge the counter.
-- ─────────────────────────────────────────────────────────────
reset role;
update public.profiles
   set onboarding_completed_at = now()
 where id = 'bbbbbbbb-0000-0000-0000-00000000000b'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', true);

select is(
  (select jsonb_extract_path_text(
     public.commit_generated_content(
       'dddddddd-0000-0000-0000-0000000000d8'::uuid,
       '{"input_type":"preset_card","user_content":"hi","source":"onboarding","status":"delivered"}'::jsonb,
       '{"card_type":"s4","card_content":{},"source":"onboarding","status":"delivered"}'::jsonb,
       NULL::jsonb,
       '2026-09-02'::date,
       true
     ), 'already_committed')),
  'false',
  'a forged onboarding commit after completion still lands as new content'
);

reset role;
select is(
  COALESCE((select used_count from public.generation_usage
    where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'::uuid
      and usage_date = '2026-09-02'::date), 0),
  2,
  'after onboarding completes, even an onboarding-sourced commit counts'
);

-- ─────────────────────────────────────────────────────────────
-- 10. The client-facing quota read reflects the consumed counts.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);

select is(
  (select used_count from public.check_generation_quota('2026-09-02'::date)),
  2,
  'check_generation_quota reports exactly the consumed count for the day'
);

-- ─────────────────────────────────────────────────────────────
-- 11. Anonymous callers can neither consume nor commit.
-- ─────────────────────────────────────────────────────────────
reset role;
set local role anon;

-- pgTAP's throws_ok(sql, '42501', description) overload treats the third
-- argument as the EXPECTED ERROR MESSAGE, not a description — use the
-- 4-argument (sql, errcode::char(5), errmsg, description) form to match the
-- SQLSTATE exactly and leave the message unchecked.
select throws_ok(
  $$select public.consume_generation_quota('2026-09-02'::date)$$,
  '42501'::char(5),
  null,
  'anonymous callers cannot invoke the quota consume helper'
);
select throws_ok(
  $$select public.commit_generated_content(
    'dddddddd-0000-0000-0000-0000000000d9'::uuid,
    '{"input_type":"text","user_content":"x","source":"tab1","status":"delivered"}'::jsonb,
    '{"card_type":"s4","card_content":{},"source":"tab1","status":"delivered"}'::jsonb,
    NULL::jsonb,
    '2026-09-02'::date,
    true
  )$$,
  '42501'::char(5),
  null,
  'anonymous callers cannot execute the quota-aware commit RPC'
);

select * from finish();

rollback;
