-- CI replay privilege contract.
--
-- RLS continues to decide which rows an authenticated caller may access.
-- These GRANTs only make the existing RLS policies and service-only Edge
-- Function paths reachable after a database is rebuilt from migrations.
-- Keep this list aligned with supabase/tests/ci_privilege_contract_test.sql.

-- Authenticated calls made through SECURITY INVOKER commit_generated_content.
GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT DELETE ON TABLE public.materials TO authenticated;
GRANT DELETE ON TABLE public.messages TO authenticated;

-- Edge Functions authenticate the caller themselves, then use service_role
-- for narrowly-scoped server work. service_role bypasses RLS, so every query
-- in those functions includes an explicit user_id or ownership check.
GRANT SELECT, UPDATE, DELETE ON TABLE public.materials TO service_role;
GRANT SELECT, DELETE ON TABLE public.messages TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lexicon_entries TO service_role;
GRANT SELECT, INSERT, DELETE ON TABLE public.lexicon_occurrences TO service_role;
GRANT DELETE ON TABLE public.learning_events TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.dialogue_sessions TO service_role;
GRANT SELECT, INSERT, DELETE ON TABLE public.dialogue_turns TO service_role;

GRANT SELECT, INSERT ON TABLE public.feedback TO service_role;
GRANT INSERT ON TABLE public.analytics_events TO service_role;
