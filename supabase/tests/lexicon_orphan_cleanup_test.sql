begin;

select plan(21);

-- Fixtures. profiles.id has a real FK to auth.users(id), and the
-- handle_new_user() trigger auto-creates a bare profiles row on insert, so the
-- profiles writes below are upserts rather than fresh inserts.
insert into auth.users (id) values
  ('a0000000-0000-0000-0000-00000000000a'::uuid),
  ('b0000000-0000-0000-0000-00000000000b'::uuid);

set local role authenticated;

select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('a0000000-0000-0000-0000-00000000000a'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-00000000000b', true);
insert into public.profiles (id, onboarding_completed_at) values
  ('b0000000-0000-0000-0000-00000000000b'::uuid, null)
  on conflict (id) do update set onboarding_completed_at = excluded.onboarding_completed_at;

-- ─────────────────────────────────────────────────────────────
-- 1. A deleted material takes its occurrences with it, and the entry's cached
--    total_count is corrected to match what actually survives.
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);

-- Two materials for user A. "commute" appears in both; "espresso" only in the
-- first, so deleting the first must zero espresso but only decrement commute.
insert into public.materials (id, user_id, material_type, source, raw_content) values
  ('11110000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-00000000000a'::uuid,
   'scene', 'onboarding', '{"user_original":"first"}'::jsonb),
  ('11110000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-00000000000a'::uuid,
   'scene', 'onboarding', '{"user_original":"second"}'::jsonb);

set local role service_role;
select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  '11110000-0000-0000-0000-000000000001'::uuid,
  'commute', null, 'native', 'zh', 'sentence', 'express', null, null, 'first sample',
  '[{"lemma":"commute","entry_kind":"word"},{"lemma":"espresso","entry_kind":"word"}]'::jsonb
);
select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  '11110000-0000-0000-0000-000000000002'::uuid,
  'commute', null, 'native', 'zh', 'sentence', 'express', null, null, 'second sample',
  '[{"lemma":"commute","entry_kind":"word"}]'::jsonb
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'commute'),
  2,
  'baseline: a lemma seen in two materials is counted twice'
);

delete from public.materials where id = '11110000-0000-0000-0000-000000000001'::uuid;

select is(
  (select count(*)::integer from public.lexicon_occurrences
    where source_type = 'material'
      and source_id = '11110000-0000-0000-0000-000000000001'::uuid),
  0,
  'deleting a material removes the occurrences that pointed at it'
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'commute'),
  1,
  'a lemma still evidenced by another material is decremented, not zeroed'
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'espresso'),
  0,
  'a lemma whose only evidence was deleted is zeroed'
);

-- ─────────────────────────────────────────────────────────────
-- 2. A zeroed entry stays usable: status must not be flipped to 'excluded',
--    because record_lexicon_material_units refuses to re-count excluded
--    entries and the word would then be permanently unrecordable.
-- ─────────────────────────────────────────────────────────────
select is(
  (select status from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'espresso'),
  'active',
  'a zeroed entry is left active, not excluded'
);

insert into public.materials (id, user_id, material_type, source, raw_content) values
  ('11110000-0000-0000-0000-000000000003'::uuid, 'a0000000-0000-0000-0000-00000000000a'::uuid,
   'scene', 'tab1', '{"user_original":"third"}'::jsonb);

select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  '11110000-0000-0000-0000-000000000003'::uuid,
  'cafe', null, 'native', 'zh', 'sentence', 'express', null, null, 'third sample',
  '[{"lemma":"espresso","entry_kind":"word"}]'::jsonb
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'espresso'),
  1,
  'a previously zeroed lemma can be counted again when genuinely met again'
);

-- ─────────────────────────────────────────────────────────────
-- 3. Race guard: accounting that lands after the material is gone is a no-op.
-- ─────────────────────────────────────────────────────────────
select is(
  record_lexicon_material_units(
    'a0000000-0000-0000-0000-00000000000a'::uuid,
    '11110000-0000-0000-0000-000000000001'::uuid,   -- deleted in section 1
    'commute', null, 'native', 'zh', 'sentence', 'express', null, null, 'late sample',
    '[{"lemma":"commute","entry_kind":"word"}]'::jsonb
  ),
  0,
  'accounting for an already-deleted material records nothing'
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'commute'),
  1,
  'late accounting for a deleted material does not re-inflate the count'
);

-- A material belonging to someone else must not be accountable either.
select is(
  record_lexicon_material_units(
    'b0000000-0000-0000-0000-00000000000b'::uuid,   -- wrong owner
    '11110000-0000-0000-0000-000000000002'::uuid,   -- user A's material
    'commute', null, 'native', 'zh', 'sentence', 'express', null, null, 'cross-user',
    '[{"lemma":"commute","entry_kind":"word"}]'::jsonb
  ),
  0,
  'accounting cannot attach occurrences to another user''s material'
);

-- ─────────────────────────────────────────────────────────────
-- 4. Cross-user isolation, and materials with no ledger rows at all.
-- ─────────────────────────────────────────────────────────────
insert into public.materials (id, user_id, material_type, source, raw_content) values
  ('22220000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-00000000000b'::uuid,
   'scene', 'onboarding', '{"user_original":"other user"}'::jsonb);

select record_lexicon_material_units(
  'b0000000-0000-0000-0000-00000000000b'::uuid,
  '22220000-0000-0000-0000-000000000001'::uuid,
  'commute', null, 'native', 'zh', 'sentence', 'express', null, null, 'other user sample',
  '[{"lemma":"commute","entry_kind":"word"}]'::jsonb
);

delete from public.materials where id = '11110000-0000-0000-0000-000000000002'::uuid;

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'b0000000-0000-0000-0000-00000000000b'::uuid and lemma = 'commute'),
  1,
  'deleting user A''s material leaves user B''s same-lemma entry untouched'
);

-- A preset card never gets accounted, so deleting one must be a clean no-op.
insert into public.materials (id, user_id, material_type, source, raw_content) values
  ('33330000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-00000000000a'::uuid,
   'scene', 'onboarding', '{"user_original":"never accounted"}'::jsonb);

select lives_ok(
  $$ delete from public.materials where id = '33330000-0000-0000-0000-000000000001'::uuid $$,
  'deleting a material that was never accounted for raises no error'
);

-- ─────────────────────────────────────────────────────────────
-- 5. Integration: the onboarding regenerate cleanup path really does fire the
--    trigger — i.e. the cleanup is wired to the delete event, not bolted onto
--    one call site.
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);

select public.commit_generated_content(
  'dd000000-0000-0000-0000-000000000001'::uuid,
  jsonb_build_object('input_type', 'image', 'user_content', '[photo] attempt one', 'source', 'onboarding'),
  jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'One'), 'source', 'onboarding'),
  jsonb_build_object('material_type', 'scene', 'raw_content', jsonb_build_object('user_original', '[photo] attempt one'), 'source', 'onboarding')
);

set local role service_role;
select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  (select id from public.materials
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid
      and request_id = 'dd000000-0000-0000-0000-000000000001'::uuid),
  'harbour', null, 'native', 'zh', 'sentence', 'express', null, null, 'attempt one sample',
  '[{"lemma":"harbour","entry_kind":"word"}]'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);

-- A second onboarding attempt supersedes the first, deleting its material.
select is(
  (
    public.commit_generated_content(
      'dd000000-0000-0000-0000-000000000002'::uuid,
      jsonb_build_object('input_type', 'image', 'user_content', '[photo] attempt two', 'source', 'onboarding'),
      jsonb_build_object('card_type', 's4', 'card_content', jsonb_build_object('title', 'Two'), 'source', 'onboarding'),
      jsonb_build_object('material_type', 'scene', 'raw_content', jsonb_build_object('user_original', '[photo] attempt two'), 'source', 'onboarding')
    ) ->> 'cleaned_up_materials'
  ),
  '1',
  'commit_generated_content reports how many materials its cleanup removed'
);

select is(
  (select total_count from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'harbour'),
  0,
  'the superseded attempt''s lexicon rows are cleaned up through the real path'
);

-- ─────────────────────────────────────────────────────────────
-- 5b. tier is persisted again (it was silently dropped in 20260730001000 and
--     never restored, leaving lexicon_entries.tier permanently NULL).
-- ─────────────────────────────────────────────────────────────
set local role service_role;

insert into public.materials (id, user_id, material_type, source, raw_content) values
  ('44440000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-00000000000a'::uuid,
   'scene', 'tab1', '{"user_original":"tier check"}'::jsonb);

select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  '44440000-0000-0000-0000-000000000001'::uuid,
  'office', null, 'native', 'zh', 'sentence', 'express', null, null, 'tier sample',
  '[{"lemma":"take","entry_kind":"word","tier":"framework"},
    {"lemma":"invoice","entry_kind":"word","tier":"domain"},
    {"lemma":"garbled","entry_kind":"word","tier":"not-a-tier"}]'::jsonb
);

select is(
  (select tier from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'take'),
  'framework',
  'tier is persisted for a framework word'
);

select is(
  (select tier from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'invoice'),
  'domain',
  'tier is persisted for a domain word'
);

select is(
  (select tier from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'garbled'),
  null,
  'an out-of-enum tier is coerced to null rather than aborting the batch'
);

-- Self-healing: an entry left with a NULL tier by the broken versions must pick
-- one up the next time the word appears — that is why ON CONFLICT uses
-- COALESCE(EXCLUDED.tier, existing) rather than overwriting blindly.
update public.lexicon_entries set tier = null
 where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'take';

select record_lexicon_material_units(
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  '44440000-0000-0000-0000-000000000001'::uuid,
  'office', null, 'native', 'zh', 'sentence', 'express', null, null, 'tier sample again',
  '[{"lemma":"take","entry_kind":"word","tier":"framework"}]'::jsonb
);

select is(
  (select tier from public.lexicon_entries
    where user_id = 'a0000000-0000-0000-0000-00000000000a'::uuid and lemma = 'take'),
  'framework',
  'an entry left with a NULL tier is healed the next time the word appears'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);

-- ─────────────────────────────────────────────────────────────
-- 6. Security: the back-office lexicon RPCs are not client-callable.
--    These were reachable by PUBLIC (so by anon too) despite being documented
--    as service_role-only, and the two SECURITY DEFINER ones bypass RLS —
--    reconcile_lexicon_counts(null) would have returned and rewritten every
--    user's entries.
-- ─────────────────────────────────────────────────────────────
select throws_ok(
  $$ select public.reconcile_lexicon_counts(null) $$,
  '42501',
  null,
  'an authenticated client cannot run reconcile_lexicon_counts'
);

select throws_ok(
  $$ select public.get_unaccounted_material_ids('a0000000-0000-0000-0000-00000000000a'::uuid) $$,
  '42501',
  null,
  'an authenticated client cannot run get_unaccounted_material_ids'
);

select throws_ok(
  $$ select record_lexicon_material_units(
       'a0000000-0000-0000-0000-00000000000a'::uuid, null, null, null, null, null,
       null, null, null, null, null, '[]'::jsonb) $$,
  '42501',
  null,
  'an authenticated client cannot run the accounting RPC directly'
);

set local role anon;
select throws_ok(
  $$ select public.reconcile_lexicon_counts(null) $$,
  '42501',
  null,
  'an unauthenticated caller cannot run reconcile_lexicon_counts either'
);

select * from finish();

rollback;
