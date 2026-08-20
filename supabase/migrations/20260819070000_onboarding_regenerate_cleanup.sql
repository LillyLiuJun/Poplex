-- Onboarding regenerate-before-complete cleanup, done safely.
--
-- Background: before the reliable-commit rework, `generate` deleted a user's
-- prior onboarding messages/materials BEFORE writing the new attempt. If the
-- new write then failed, the user's previously successful onboarding content
-- was gone with nothing to replace it. That delete-before-write step was
-- removed entirely when the atomic commit RPC was introduced (see
-- 20260816045614), which fixed the data-loss risk but left no cleanup at
-- all: a user who regenerates during onboarding (the capture screen's back
-- button allows reselecting a photo/card even after a successful result)
-- now accumulates one committed row-set per attempt, all visible in Tab1
-- and all counted in the Tab2 lexicon ledger forever.
--
-- This migration restores the "keep only the final onboarding attempt"
-- invariant, but orders it correctly: cleanup only runs AFTER the new
-- attempt's rows are already inserted in the same transaction, so a delete
-- can only ever remove attempts that have been safely superseded — it can
-- never run when the new attempt is what failed.
--
-- Two additional safety properties this migration adds, both found while
-- reviewing why the original 2026-07-09 version was unsafe to simply restore
-- as-is:
--
-- 1. "Already completed" must be checked fresh, server-side, at commit time
--    — never trusted from client state. A device can genuinely re-enter
--    onboarding for a user who already completed it (RootView's local
--    "onboarding done" flag can be stale after a reinstall combined with a
--    failed/timed-out background confirmation check, which does not retry).
--    If that happens and the user regenerates, this RPC still sees the
--    real `profiles.onboarding_completed_at` and skips cleanup, protecting
--    the user's real historical content.
--
-- 2. A profiles row that cannot be found is treated as "unknown, do not
--    delete" — not as "not completed, safe to delete". The original version
--    conflated these (`profiles.length > 0 && ...` treats a missing row the
--    same as "not completed"), which would have wiped a real user's history
--    in the rare case their profile row went missing. A signup trigger
--    guarantees the row normally exists, so this only matters as a fail-safe.
--
-- `messages` never had a DELETE RLS policy (only Edge Functions using the
-- service-role key have ever deleted from it). This RPC is intentionally
-- SECURITY INVOKER, so it needs one — added here, scoped identically to the
-- existing `users_delete_own_materials` policy.
CREATE POLICY "users_delete_own_messages"
  ON public.messages
  FOR DELETE
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.commit_generated_content(
  p_request_id uuid,
  p_user_message jsonb,
  p_assistant_message jsonb,
  p_material jsonb DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_user_message_id uuid;
  v_assistant_message_id uuid;
  v_material_id uuid;
  v_card_type text;
  v_card_content jsonb;
  v_extracted_concept text;
  v_expects_material boolean := p_material IS NOT NULL;
  v_source text := COALESCE(NULLIF(p_user_message ->> 'source', ''), 'tab1');
  v_not_yet_completed boolean;
BEGIN
  v_user_id := (SELECT auth.uid());

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'request_id is required' USING ERRCODE = '22004';
  END IF;

  IF p_user_message IS NULL OR jsonb_typeof(p_user_message) <> 'object' THEN
    RAISE EXCEPTION 'user_message must be a JSON object' USING ERRCODE = '22023';
  END IF;

  IF p_assistant_message IS NULL OR jsonb_typeof(p_assistant_message) <> 'object' THEN
    RAISE EXCEPTION 'assistant_message must be a JSON object' USING ERRCODE = '22023';
  END IF;

  IF v_expects_material AND jsonb_typeof(p_material) <> 'object' THEN
    RAISE EXCEPTION 'material must be a JSON object' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_request_id::text, 0)
  );

  -- Only onboarding commits ever delete another request's rows below, so only
  -- they need to be serialized against each other per-user (Tab1's hot path
  -- pays nothing extra). Without this, two concurrent onboarding commits for
  -- the same user (double-tap, two devices) could each insert their own row
  -- and then race to delete the other's, leaving a nondeterministic result.
  -- Serializing them makes the outcome deterministic: whichever transaction
  -- runs second sees the first one's row already committed and cleans it up.
  IF v_source = 'onboarding' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_user_id::text || ':onboarding-regenerate', 0)
    );
  END IF;

  SELECT id
    INTO v_user_message_id
    FROM public.messages
   WHERE user_id = v_user_id
     AND request_id = p_request_id
     AND role = 'user';

  SELECT id, card_type, card_content, extracted_concept
    INTO v_assistant_message_id, v_card_type, v_card_content, v_extracted_concept
    FROM public.messages
   WHERE user_id = v_user_id
     AND request_id = p_request_id
     AND role = 'assistant';

  SELECT id
    INTO v_material_id
    FROM public.materials
   WHERE user_id = v_user_id
     AND request_id = p_request_id;

  IF v_user_message_id IS NOT NULL
     AND v_assistant_message_id IS NOT NULL
     AND (NOT v_expects_material OR v_material_id IS NOT NULL) THEN
    RETURN jsonb_build_object(
      'request_id', p_request_id,
      'user_message_id', v_user_message_id,
      'assistant_message_id', v_assistant_message_id,
      'material_id', v_material_id,
      'card_type', v_card_type,
      'card_content', v_card_content,
      'extracted_concept', v_extracted_concept,
      'already_committed', true
    );
  END IF;

  -- The payload keys below are intentionally enumerated. Ownership, request ID,
  -- role, and the material-to-message link are always derived inside this RPC.
  INSERT INTO public.messages (
    user_id, request_id, role, input_type, user_content, preset_card_id,
    status, source, image_url, created_at
  ) VALUES (
    v_user_id,
    p_request_id,
    'user',
    NULLIF(p_user_message ->> 'input_type', ''),
    p_user_message ->> 'user_content',
    NULLIF(p_user_message ->> 'preset_card_id', ''),
    COALESCE(NULLIF(p_user_message ->> 'status', ''), 'delivered'),
    v_source,
    NULLIF(p_user_message ->> 'image_url', ''),
    COALESCE(NULLIF(p_user_message ->> 'created_at', '')::timestamptz, now())
  ) RETURNING id INTO v_user_message_id;

  INSERT INTO public.messages (
    user_id, request_id, role, card_type, card_content, extracted_concept, status, source
  ) VALUES (
    v_user_id,
    p_request_id,
    'assistant',
    NULLIF(p_assistant_message ->> 'card_type', ''),
    p_assistant_message -> 'card_content',
    NULLIF(p_assistant_message ->> 'extracted_concept', ''),
    COALESCE(NULLIF(p_assistant_message ->> 'status', ''), 'delivered'),
    COALESCE(NULLIF(p_assistant_message ->> 'source', ''), 'tab1')
  ) RETURNING id, card_type, card_content, extracted_concept
    INTO v_assistant_message_id, v_card_type, v_card_content, v_extracted_concept;

  IF v_expects_material THEN
    INSERT INTO public.materials (
      user_id, request_id, source_message_id, material_type, status,
      scene_category, raw_content, source
    ) VALUES (
      v_user_id,
      p_request_id,
      v_user_message_id,
      p_material ->> 'material_type',
      COALESCE(NULLIF(p_material ->> 'status', ''), 'pending'),
      NULLIF(p_material ->> 'scene_category', ''),
      p_material -> 'raw_content',
      COALESCE(NULLIF(p_material ->> 'source', ''), 'tab1')
    ) RETURNING id INTO v_material_id;
  END IF;

  -- Cleanup runs only now, after this attempt's rows are durably inserted in
  -- this same transaction — never before. A commit that fails never reaches
  -- this point, so a failed regeneration can never delete a prior success.
  IF v_source = 'onboarding' THEN
    SELECT (onboarding_completed_at IS NULL)
      INTO v_not_yet_completed
      FROM public.profiles
     WHERE id = v_user_id;

    -- FOUND is false when the profiles row itself is missing. Treat that as
    -- "cannot confirm the user hasn't finished onboarding" and skip cleanup
    -- rather than assuming it's safe — see the design note above.
    IF FOUND AND v_not_yet_completed THEN
      DELETE FROM public.materials
       WHERE user_id = v_user_id
         AND source = 'onboarding'
         AND request_id IS DISTINCT FROM p_request_id;

      DELETE FROM public.messages
       WHERE user_id = v_user_id
         AND source = 'onboarding'
         AND request_id IS DISTINCT FROM p_request_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'request_id', p_request_id,
    'user_message_id', v_user_message_id,
    'assistant_message_id', v_assistant_message_id,
    'material_id', v_material_id,
    'card_type', v_card_type,
    'card_content', v_card_content,
    'extracted_concept', v_extracted_concept,
    'already_committed', false
  );
END;
$$;
