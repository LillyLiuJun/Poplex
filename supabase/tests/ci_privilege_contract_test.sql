begin;

select plan(37);

-- This is a table-level ACL contract, deliberately independent of PostgREST.
-- It catches the class of bug where a fresh migration replay has RLS policies
-- but is missing the PostgreSQL GRANT that lets an existing code path reach
-- them. Endpoint ownership is covered by Edge Function unit tests.

select ok(has_table_privilege('authenticated', 'public.profiles', 'SELECT'), 'authenticated can select its RLS-protected profile');
select ok(has_table_privilege('authenticated', 'public.profiles', 'INSERT'), 'authenticated can insert its RLS-protected profile');
select ok(has_table_privilege('authenticated', 'public.profiles', 'UPDATE'), 'authenticated can update its RLS-protected profile');
select ok(has_table_privilege('authenticated', 'public.materials', 'DELETE'), 'authenticated can run onboarding material cleanup');
select ok(has_table_privilege('authenticated', 'public.messages', 'DELETE'), 'authenticated can run onboarding message cleanup');

select ok(has_table_privilege('service_role', 'public.profiles', 'SELECT'), 'service role can read profiles for the onboarding exemption check');

select ok(has_table_privilege('service_role', 'public.materials', 'SELECT'), 'service role can read materials for Tab2, backfill, and reconciliation');
select ok(has_table_privilege('service_role', 'public.materials', 'UPDATE'), 'service role can enrich, delete, and restore an owned material');
select ok(has_table_privilege('service_role', 'public.materials', 'DELETE'), 'service role can delete account materials');
select ok(has_table_privilege('service_role', 'public.messages', 'SELECT'), 'service role can load history and reconcile image references');
select ok(has_table_privilege('service_role', 'public.messages', 'DELETE'), 'service role can delete account messages');

select ok(has_table_privilege('service_role', 'public.lexicon_entries', 'SELECT'), 'service role can reconcile lexicon entries');
select ok(has_table_privilege('service_role', 'public.lexicon_entries', 'INSERT'), 'service role can record new lexicon entries');
select ok(has_table_privilege('service_role', 'public.lexicon_entries', 'UPDATE'), 'service role can update lexicon aggregates');
select ok(has_table_privilege('service_role', 'public.lexicon_entries', 'DELETE'), 'service role can delete account lexicon entries');
select ok(has_table_privilege('service_role', 'public.lexicon_occurrences', 'SELECT'), 'service role can reconcile lexicon occurrences');
select ok(has_table_privilege('service_role', 'public.lexicon_occurrences', 'INSERT'), 'service role can record lexicon occurrences');
select ok(has_table_privilege('service_role', 'public.lexicon_occurrences', 'DELETE'), 'service role can delete account lexicon occurrences');
select ok(has_table_privilege('service_role', 'public.learning_events', 'DELETE'), 'service role can delete account learning events');

select ok(has_table_privilege('service_role', 'public.dialogue_sessions', 'SELECT'), 'service role can read dialogue sessions');
select ok(has_table_privilege('service_role', 'public.dialogue_sessions', 'INSERT'), 'service role can create dialogue sessions');
select ok(has_table_privilege('service_role', 'public.dialogue_sessions', 'UPDATE'), 'service role can update dialogue sessions');
select ok(has_table_privilege('service_role', 'public.dialogue_sessions', 'DELETE'), 'service role can delete account dialogue sessions');
select ok(has_table_privilege('service_role', 'public.dialogue_turns', 'SELECT'), 'service role can read dialogue turns');
select ok(has_table_privilege('service_role', 'public.dialogue_turns', 'INSERT'), 'service role can create dialogue turns');
select ok(has_table_privilege('service_role', 'public.dialogue_turns', 'DELETE'), 'service role can delete account dialogue turns');

select ok(has_table_privilege('service_role', 'public.feedback', 'SELECT'), 'service role can enforce feedback rate limiting');
select ok(has_table_privilege('service_role', 'public.feedback', 'INSERT'), 'service role can write feedback');
select ok(has_table_privilege('service_role', 'public.analytics_events', 'INSERT'), 'service role can write analytics events');

select ok(has_table_privilege('authenticated', 'public.generation_usage', 'SELECT'), 'authenticated can read its RLS-protected generation usage');
select ok(not has_table_privilege('authenticated', 'public.generation_usage', 'INSERT,UPDATE,DELETE'), 'generation_usage writes are server-only (no API-role write grants)');
select ok(not has_table_privilege('service_role', 'public.generation_usage', 'INSERT,UPDATE,DELETE'), 'generation_usage advances only through SECURITY DEFINER RPCs');
select ok(has_table_privilege('authenticated', 'public.app_config', 'SELECT'), 'authenticated can read the global app config');
select ok(not has_table_privilege('authenticated', 'public.app_config', 'INSERT,UPDATE,DELETE'), 'app_config writes are ops-only');
select ok(not has_table_privilege('service_role', 'public.app_config', 'INSERT,UPDATE,DELETE'), 'app_config writes are ops-only even for service_role');
select ok(has_function_privilege('authenticated', 'public.consume_generation_quota(date)', 'EXECUTE'), 'authenticated can advance its own quota via the SECURITY DEFINER consume helper');
select ok(not has_function_privilege('anon', 'public.consume_generation_quota(date)', 'EXECUTE'), 'anonymous callers cannot invoke the quota consume helper');

select * from finish();

rollback;
