begin;

select plan(36);

select ok(
  not has_function_privilege('anon', 'public.get_category_words(uuid,text)', 'EXECUTE'),
  'anon cannot execute get_category_words'
);
select ok(
  not has_function_privilege('authenticated', 'public.get_category_words(uuid,text)', 'EXECUTE'),
  'authenticated cannot execute get_category_words directly'
);
select ok(
  has_function_privilege('service_role', 'public.get_category_words(uuid,text)', 'EXECUTE'),
  'service_role can execute get_category_words'
);

select ok(
  not has_function_privilege('anon', 'public.get_lexicon_scenes(uuid)', 'EXECUTE'),
  'anon cannot execute get_lexicon_scenes'
);
select ok(
  not has_function_privilege('authenticated', 'public.get_lexicon_scenes(uuid)', 'EXECUTE'),
  'authenticated cannot execute get_lexicon_scenes directly'
);
select ok(
  has_function_privilege('service_role', 'public.get_lexicon_scenes(uuid)', 'EXECUTE'),
  'service_role can execute get_lexicon_scenes'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.record_lexicon_dialogue_units(uuid,uuid,uuid,text,text,boolean,boolean,text,jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute dialogue accounting'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.record_lexicon_dialogue_units(uuid,uuid,uuid,text,text,boolean,boolean,text,jsonb)',
    'EXECUTE'
  ),
  'authenticated cannot execute dialogue accounting directly'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.record_lexicon_dialogue_units(uuid,uuid,uuid,text,text,boolean,boolean,text,jsonb)',
    'EXECUTE'
  ),
  'service_role can execute dialogue accounting'
);

select ok(
  not has_function_privilege('anon', 'public.increment_session_count()', 'EXECUTE'),
  'anon database role cannot execute increment_session_count'
);
select ok(
  has_function_privilege('authenticated', 'public.increment_session_count()', 'EXECUTE'),
  'signed-in app users can execute increment_session_count'
);

select ok(
  not has_function_privilege('anon', 'public.cleanup_lexicon_after_material_delete()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.cleanup_lexicon_after_material_delete()', 'EXECUTE'),
  'cleanup trigger function is not directly callable by API roles'
);
select ok(
  not has_function_privilege('anon', 'public.handle_new_user()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.handle_new_user()', 'EXECUTE'),
  'new-user trigger function is not directly callable by API roles'
);

select ok(
  not has_table_privilege('anon', 'public.feedback', 'SELECT,INSERT')
  and not has_table_privilege('authenticated', 'public.feedback', 'SELECT,INSERT'),
  'feedback is inaccessible to public API roles'
);
select ok(
  has_table_privilege('service_role', 'public.feedback', 'SELECT,INSERT'),
  'submit-feedback service role keeps rate-limit read and insert access'
);
select ok(
  has_table_privilege('service_role', 'public.analytics_events', 'INSERT')
  and not has_table_privilege('service_role', 'public.analytics_events', 'SELECT'),
  'log-event service role has insert-only analytics access'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT')
  and has_table_privilege('authenticated', 'public.profiles', 'SELECT,INSERT,UPDATE')
  and not has_table_privilege('authenticated', 'public.profiles', 'DELETE'),
  'profiles grants match the signed-in app read and upsert contract'
);

select ok(
  has_table_privilege('authenticated', 'public.materials', 'DELETE')
  and has_table_privilege('authenticated', 'public.messages', 'DELETE'),
  'signed-in app users can delete their own materials and messages (commit_generated_content cleanup runs as the user JWT)'
);

select ok(
  has_table_privilege('service_role', 'public.materials', 'SELECT,INSERT,DELETE')
  and has_table_privilege('service_role', 'public.lexicon_entries', 'SELECT,INSERT,UPDATE')
  and has_table_privilege('service_role', 'public.lexicon_occurrences', 'SELECT,INSERT')
  and has_table_privilege('service_role', 'public.dialogue_turns', 'SELECT'),
  'service_role holds the minimum privileges for the server-side accounting path'
);

select ok(
  has_table_privilege('authenticated', 'public.lexicon_entries', 'SELECT,INSERT')
  and has_table_privilege('authenticated', 'public.lexicon_occurrences', 'SELECT,INSERT')
  and has_table_privilege('authenticated', 'public.dialogue_sessions', 'SELECT,INSERT')
  and has_table_privilege('authenticated', 'public.dialogue_turns', 'SELECT,INSERT')
  and not has_table_privilege('authenticated', 'public.lexicon_entries', 'DELETE'),
  'signed-in users hold exactly the ledger/dialogue privileges their RLS policies express'
);

select ok(
  not has_function_privilege('anon', 'public.get_effective_daily_generation_limit(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.get_effective_daily_generation_limit(uuid)', 'EXECUTE'),
  'effective-limit helper is not client-callable'
);
select ok(
  has_function_privilege('service_role', 'public.get_effective_daily_generation_limit(uuid)', 'EXECUTE'),
  'service_role can resolve the effective limit'
);
select ok(
  has_function_privilege('authenticated', 'public.check_generation_quota(date)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.check_generation_quota(date)', 'EXECUTE'),
  'only signed-in users can check their own quota'
);
select ok(
  not has_function_privilege('anon', 'public.check_generation_quota_for_user(uuid,date)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.check_generation_quota_for_user(uuid,date)', 'EXECUTE'),
  'the named-user quota check is not client-callable'
);
select ok(
  has_function_privilege('service_role', 'public.check_generation_quota_for_user(uuid,date)', 'EXECUTE'),
  'service_role can run the named-user quota check'
);
select ok(
  has_table_privilege('authenticated', 'public.generation_usage', 'SELECT')
  and not has_table_privilege('authenticated', 'public.generation_usage', 'INSERT,UPDATE,DELETE'),
  'generation_usage is read-only for signed-in users'
);
select ok(
  has_table_privilege('authenticated', 'public.app_config', 'SELECT')
  and not has_table_privilege('authenticated', 'public.app_config', 'INSERT,UPDATE,DELETE'),
  'app_config is read-only for signed-in users'
);
select ok(
  has_function_privilege('authenticated', 'public.consume_generation_quota(date)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.consume_generation_quota(date)', 'EXECUTE'),
  'quota consume helper runs for signed-in users only and is self-scoped via auth.uid()'
);
select ok(
  has_function_privilege('authenticated', 'public.commit_generated_content(uuid,jsonb,jsonb,jsonb,date,boolean)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.commit_generated_content(uuid,jsonb,jsonb,jsonb,date,boolean)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.commit_generated_content(uuid,jsonb,jsonb,jsonb,date,boolean)', 'EXECUTE'),
  'the quota-aware commit overload keeps the original EXECUTE grants'
);
-- The override column cannot be protected by a column-level REVOKE: PostgreSQL
-- column ACLs only add privileges on top of a table-level grant, never
-- subtract. The CI privilege contract requires the table-level profiles
-- grants, so the column is guarded by a trigger instead (client writes are
-- silently stripped; postgres/service_role pass through).
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_daily_generation_limit_guard'
  ),
  'the quota override column is guarded by a server-side trigger'
);
select ok(
  not has_function_privilege('anon', 'public.guard_daily_generation_limit_override()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.guard_daily_generation_limit_override()', 'EXECUTE')
  and not has_function_privilege('service_role', 'public.guard_daily_generation_limit_override()', 'EXECUTE'),
  'guard trigger function is not directly callable by API roles'
);

insert into auth.users (id)
values ('77777777-7777-7777-7777-777777777777'::uuid);

select ok(
  exists (
    select 1
    from public.profiles
    where id = '77777777-7777-7777-7777-777777777777'::uuid
  ),
  'handle_new_user trigger still creates a profile after EXECUTE is revoked'
);

select ok(
  not has_schema_privilege('anon', 'public', 'CREATE')
  and not has_schema_privilege('authenticated', 'public', 'CREATE'),
  'fixed public search_path is safe from API-role object injection'
);

-- Legacy word-list RPCs were dropped in 20261018000000; nothing may recreate them.
select hasnt_function(
  'public', 'get_lexicon_entries_tab2', array['uuid', 'integer'],
  'legacy get_lexicon_entries_tab2 does not exist'
);
select hasnt_function(
  'public', 'exclude_lexicon_entry', array['uuid', 'uuid'],
  'legacy exclude_lexicon_entry does not exist'
);
select hasnt_function(
  'public', 'restore_lexicon_entry', array['uuid', 'uuid'],
  'legacy restore_lexicon_entry does not exist'
);

select * from finish();
rollback;
