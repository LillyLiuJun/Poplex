-- Harden legacy database entry points discovered by the Supabase security
-- advisor. PostgreSQL grants EXECUTE to PUBLIC for new functions unless it is
-- explicitly revoked, so an explicit GRANT to service_role alone is not an
-- access boundary.

-- These RPCs are called only by Edge Functions using the service-role key.
REVOKE EXECUTE ON FUNCTION public.get_category_words(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_lexicon_scenes(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_lexicon_dialogue_units(
  uuid, uuid, uuid, text, text, boolean, boolean, text, jsonb
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_category_words(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_lexicon_scenes(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_lexicon_dialogue_units(
  uuid, uuid, uuid, text, text, boolean, boolean, text, jsonb
) TO service_role;

-- These three functions survive on the production database from pre-migration
-- development, but a clean database no longer creates them. Harden them when
-- present without making a fresh migration replay depend on legacy drift.
DO $$
DECLARE
  v_signature text;
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.get_lexicon_entries_tab2(uuid,integer)',
    'public.exclude_lexicon_entry(uuid,uuid)',
    'public.restore_lexicon_entry(uuid,uuid)'
  ]
  LOOP
    IF pg_catalog.to_regprocedure(v_signature) IS NOT NULL THEN
      EXECUTE pg_catalog.format(
        'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
        v_signature
      );
      EXECUTE pg_catalog.format(
        'GRANT EXECUTE ON FUNCTION %s TO service_role',
        v_signature
      );
      EXECUTE pg_catalog.format(
        'ALTER FUNCTION %s SET search_path = public',
        v_signature
      );
    END IF;
  END LOOP;
END;
$$;

-- Trigger functions are invoked by PostgreSQL, never through PostgREST. Their
-- owners retain execution; no API role needs a direct EXECUTE grant.
REVOKE EXECUTE ON FUNCTION public.cleanup_lexicon_after_material_delete()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated, service_role;

-- increment_session_count is the one intentional client RPC. Keep the signed-
-- in caller, but remove the unintended PUBLIC/anon path. Anonymous app users
-- still use the authenticated database role after Supabase Auth signs them in.
REVOKE EXECUTE ON FUNCTION public.increment_session_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_session_count() TO authenticated;

-- Pin function name resolution. The public schema is not CREATE-able by anon
-- or authenticated in this project, so a fixed public search_path prevents
-- caller-controlled resolution without rewriting these stable function bodies.
ALTER FUNCTION public.increment_session_count() SET search_path = public;
ALTER FUNCTION public.reconcile_lexicon_counts(uuid) SET search_path = public;
ALTER FUNCTION public.get_unaccounted_material_ids(uuid) SET search_path = public;
ALTER FUNCTION public.get_lexicon_scenes(uuid) SET search_path = public;
ALTER FUNCTION public.get_category_words(uuid, text) SET search_path = public;
ALTER FUNCTION public.record_lexicon_dialogue_units(
  uuid, uuid, uuid, text, text, boolean, boolean, text, jsonb
) SET search_path = public;
ALTER FUNCTION public.record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) SET search_path = public;

-- The app reads and upserts only its own profile under RLS. Production had
-- broad implicit table grants while a clean migration replay had none; encode
-- the intended minimum explicitly so both environments behave the same.
REVOKE ALL ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;

-- commit_generated_content is SECURITY INVOKER: it runs as the signed-in user
-- and deletes the user's own cleanup materials and messages. The hosted
-- platform grants all table privileges to the API roles by default and relies
-- on RLS for row security, while the local Docker image ships without DELETE —
-- encode the platform's existing reality so both environments behave the same.
GRANT DELETE ON TABLE public.materials TO authenticated;
GRANT DELETE ON TABLE public.messages TO authenticated;

-- The accounting RPCs (record_lexicon_material_units / record_lexicon_dialogue_units)
-- are SECURITY INVOKER and are called by Edge Functions as service_role: they
-- verify the existence of the source material/dialogue turn and upsert the
-- ledger. The hosted platform grants service_role all table privileges by
-- default while the local Docker image grants none — encode the minimum the
-- server-side accounting path needs so both environments behave the same.
-- Row security remains RLS; service_role bypasses RLS by platform default.
GRANT SELECT, INSERT, DELETE ON TABLE public.materials TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.lexicon_entries TO service_role;
GRANT SELECT, INSERT ON TABLE public.lexicon_occurrences TO service_role;
GRANT SELECT ON TABLE public.dialogue_turns TO service_role;

-- The ledger and dialogue tables carry RLS policies that express the signed-in
-- user's direct access (users_select_own_* / users_insert_own_*). The hosted
-- platform's default grants back those policies, while a clean local replay
-- leaves the tables without any data privileges — align the two by granting
-- exactly what the policies express, so RLS stays the row-security boundary.
GRANT SELECT, INSERT ON TABLE public.lexicon_entries TO authenticated;
GRANT SELECT, INSERT ON TABLE public.lexicon_occurrences TO authenticated;
GRANT SELECT, INSERT ON TABLE public.dialogue_sessions TO authenticated;
GRANT SELECT, INSERT ON TABLE public.dialogue_turns TO authenticated;

-- feedback is deliberately server-only: submit-feedback validates the user JWT
-- and performs both the rate-limit SELECT and INSERT with service_role.
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.feedback FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT ON TABLE public.feedback TO service_role;

-- analytics_events is also server-only and log-event only inserts rows.
REVOKE ALL ON TABLE public.analytics_events FROM service_role;
GRANT INSERT ON TABLE public.analytics_events TO service_role;
