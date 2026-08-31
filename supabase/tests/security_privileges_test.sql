begin;

select plan(22);

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

select * from finish();
rollback;
