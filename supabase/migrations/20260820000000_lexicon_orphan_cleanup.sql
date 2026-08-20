-- Lexicon ledger orphan cleanup + accounting race guard + reconcile privilege fix.
--
-- Background: 20260819070000 made onboarding regeneration clean up superseded
-- messages/materials, but deliberately left one gap open — the deleted
-- material's rows in the lexicon ledger (lexicon_entries / lexicon_occurrences,
-- the data behind Tab2's practice list) were not cleaned up with it. Because
-- lexicon_occurrences.source_id has no foreign key, that DELETE succeeds
-- silently and leaves dangling occurrences plus a permanently inflated
-- lexicon_entries.total_count.
--
-- This migration closes that gap and two problems found while reviewing it.

-- ─────────────────────────────────────────────────────────────
-- 1. Index for the cleanup lookup
-- ─────────────────────────────────────────────────────────────
-- lexicon_occurrences had indexes on (user_id, created_at) and (entry_id) only.
-- The cleanup below looks rows up by (source_type, source_id), which would
-- otherwise be a sequential scan on every material delete.
CREATE INDEX IF NOT EXISTS idx_lexicon_occurrences_source
  ON public.lexicon_occurrences (source_type, source_id);

-- ─────────────────────────────────────────────────────────────
-- 2. Security fix: the lexicon back-office RPCs must not be client-callable
-- ─────────────────────────────────────────────────────────────
-- 20260728030000 declares these as service_role-only, and 20260812010000 says
-- the same for the accounting RPC ("只授给 service_role"). That was never true:
-- Postgres grants EXECUTE to PUBLIC by default, and none of these migrations
-- revoked it, so the explicit GRANTs only ever added redundancy. Verified on a
-- freshly migrated database — proacl for all three carried a bare `=X/postgres`
-- entry, i.e. PUBLIC (which includes both `authenticated` and the
-- unauthenticated `anon` role) could execute them.
--
-- Why that matters, in severity order:
--
--   * reconcile_lexicon_counts and get_unaccounted_material_ids are
--     SECURITY DEFINER, so they run as the owner and bypass RLS entirely.
--     Neither validates that p_user_id belongs to the caller, and
--     reconcile_lexicon_counts documents p_user_id => NULL as "process every
--     user (admin view)". Any caller could therefore read every user's entry
--     ids, lemmas and counts — and, in reconcile's case, write to their rows.
--   * record_lexicon_material_units is SECURITY INVOKER, so RLS still contains
--     it; the exposure is that its stated access model was simply not enforced.
--
-- Nothing calls any of them from a client (no Swift caller, no Edge Function
-- caller except the accounting RPC, which uses the service-role key). So the
-- fix is to remove the unintended access rather than to add defensive
-- auth.uid() checks to entry points that should not be reachable at all.
-- service_role keeps its explicit grants — that is the intended path.
-- (record_lexicon_material_units is revoked in section 4, right after the
-- CREATE OR REPLACE that rewrites it, so its grants stay in one place.)
REVOKE EXECUTE ON FUNCTION public.reconcile_lexicon_counts(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_unaccounted_material_ids(uuid) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Cleanup trigger: lexicon follows the material it came from
-- ─────────────────────────────────────────────────────────────
-- Attached to the DELETE event on materials rather than wired into
-- commit_generated_content, so that every hard-delete path — the onboarding
-- regenerate cleanup today, and anything added later — is covered without
-- having to remember to call it. Statement-level (not row-level) so deleting
-- N materials recomputes the affected counts once instead of N times.
--
-- SECURITY DEFINER is required: lexicon_entries/lexicon_occurrences have RLS
-- enabled with SELECT/INSERT policies only, so no client role can DELETE from
-- them. Rather than widening those tables with a general DELETE policy (which
-- would sit awkwardly against the ledger's deliberate "evidence is not erased"
-- design — see the ON DELETE RESTRICT on lexicon_occurrences.entry_id), the
-- privilege stays confined to this one function, which only ever touches rows
-- belonging to materials that were just deleted.
CREATE OR REPLACE FUNCTION public.cleanup_lexicon_after_material_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_affected_entry_ids uuid[];
BEGIN
  -- Non-blocking by design: a trigger exception would abort the caller's whole
  -- transaction, which would let a lexicon bookkeeping problem block the user
  -- from generating content at all. This mirrors the existing Stage 3 policy in
  -- generate/index.ts (accounting failures are logged, never surfaced). The
  -- worst case on failure is that the ledger stays as stale as it is today.
  BEGIN
    WITH removed AS (
      DELETE FROM public.lexicon_occurrences lo
       USING deleted_materials dm
       WHERE lo.source_type = 'material'
         AND lo.source_id = dm.id
      RETURNING lo.entry_id
    )
    SELECT pg_catalog.array_agg(DISTINCT entry_id)
      INTO v_affected_entry_ids
      FROM removed;

    IF v_affected_entry_ids IS NULL THEN
      RETURN NULL;   -- nothing was accounted for these materials
    END IF;

    -- Recompute total_count from the occurrences that actually survive, for the
    -- affected entries only. Same definition as reconcile_lexicon_counts (the
    -- column is a cache whose source of truth is the occurrences table), but
    -- deliberately NOT copying that function's `last_used_at = now()` write:
    -- a cleanup is not a use, and stamping it as one would misreport when the
    -- user last touched the word.
    --
    -- status is intentionally left alone. record_lexicon_material_units refuses
    -- to re-count an entry whose status is 'excluded' (an anti-resurrection
    -- guard), so marking a zeroed entry excluded here would permanently stop
    -- the ledger from counting that word if the user genuinely meets it again.
    -- A zeroed entry disappears from Tab2 on its own: those queries INNER JOIN
    -- lexicon_occurrences, so an entry with no occurrences cannot appear.
    UPDATE public.lexicon_entries le
       SET total_count = t.cnt
      FROM (
        SELECT e.id,
               (
                 SELECT pg_catalog.count(*)::int
                   FROM public.lexicon_occurrences lo
                  WHERE lo.entry_id = e.id
               ) AS cnt
          FROM public.lexicon_entries e
         WHERE e.id = ANY (v_affected_entry_ids)
      ) t
     WHERE le.id = t.id
       AND le.total_count IS DISTINCT FROM t.cnt;

  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'cleanup_lexicon_after_material_delete failed (non-blocking): % (%)',
      SQLERRM, SQLSTATE;
  END;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_cleanup_lexicon_after_material_delete ON public.materials;

CREATE TRIGGER trg_cleanup_lexicon_after_material_delete
  AFTER DELETE ON public.materials
  REFERENCING OLD TABLE AS deleted_materials
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.cleanup_lexicon_after_material_delete();

-- ─────────────────────────────────────────────────────────────
-- 4. Race guard on the accounting side
-- ─────────────────────────────────────────────────────────────
-- The trigger above only covers the ordering "material deleted, then nothing
-- more is written". The opposite ordering is reachable and, in the onboarding
-- flow, likely:
--
--   Photo A commits -> HTTP response returned -> Stage 3 accounting for A is
--   scheduled via EdgeRuntime.waitUntil, and before it writes anything it first
--   makes a Gemini classification call (seconds) -> meanwhile the user dislikes
--   the result, goes back and picks photo B -> B's commit deletes A's material
--   and the trigger sweeps A's occurrences (there are none yet) -> A's
--   accounting finally completes and inserts occurrences pointing at a material
--   that no longer exists, re-inflating total_count.
--
-- Guarding here closes that direction: if the material is gone by the time
-- accounting runs, the whole call becomes a no-op. Together with the trigger,
-- neither ordering can leave an orphan behind.
CREATE OR REPLACE FUNCTION record_lexicon_material_units(
  p_user_id            uuid,
  p_source_id          uuid,
  p_scene_category     text,
  p_scene_detail       text,
  p_input_lang         text,
  p_input_lang_code    text,
  p_source_granularity text,
  p_source_direction   text,
  p_intent_text        text,
  p_intent_source      text,   -- 'stated' | 'inferred' | null
  p_sample_sentence    text,
  p_units              jsonb
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit         jsonb;
  v_lemma        text;
  v_kind         text;
  v_note         text;
  v_tier         text;
  v_entry_id     uuid;
  v_recorded     int := 0;
  v_input_lang   text;
  v_gran         text;
  v_dir          text;
  v_intent_src   text;
BEGIN
  -- Race guard (see the note above this function). Ownership is part of the
  -- check so a stale call can never attach occurrences to another user's row.
  -- deleted_at is deliberately NOT considered: a soft-deleted material still
  -- exists and keeps its ledger history, which is the current, separate
  -- product behaviour recorded in docs/prd/Tbc/.
  IF p_source_id IS NULL
     OR NOT EXISTS (
          SELECT 1
            FROM materials
           WHERE id = p_source_id
             AND user_id = p_user_id
        ) THEN
    RETURN 0;
  END IF;

  -- 素材级枚举收敛
  v_input_lang  := (CASE WHEN lower(p_input_lang)         IN ('native','target','other')   THEN lower(p_input_lang)         ELSE NULL END);
  v_gran        := (CASE WHEN lower(p_source_granularity) IN ('word','sentence','passage') THEN lower(p_source_granularity) ELSE NULL END);
  v_dir         := (CASE WHEN lower(p_source_direction)   IN ('comprehend','express')      THEN lower(p_source_direction)   ELSE NULL END);
  v_intent_src  := (CASE WHEN lower(p_intent_source)      IN ('stated','inferred')         THEN lower(p_intent_source)      ELSE NULL END);

  IF p_units IS NULL OR jsonb_typeof(p_units) <> 'array' THEN
    RETURN 0;
  END IF;

  FOR v_unit IN SELECT * FROM jsonb_array_elements(p_units)
  LOOP
    v_lemma := nullif(trim(v_unit->>'lemma'), '');
    v_note  := nullif(trim(v_unit->>'note'),  '');

    IF v_lemma IS NOT NULL THEN
      v_kind := lower(trim(coalesce(v_unit->>'entry_kind', '')));
      v_kind := (CASE
        WHEN v_kind IN ('word','phrase','collocation','slang','idiom','pattern') THEN v_kind
        WHEN v_kind IN ('phrasal verb','phrasal-verb')                            THEN 'phrase'
        ELSE NULL
      END);

      -- tier 收敛：Edge 侧已用静态词表（FRAMEWORK_LEMMAS）判好并随 unit 传入；
      -- 非法值 → NULL（写 NULL 比写脏值安全）。
      --
      -- 这段是 20260728020000 引入的，但在 20260730001000 那次「加 p_scene_detail
      -- 参数」的重写中被整体漏掉，此后 v2（20260812010000）也没恢复 —— 于是
      -- generate/index.ts:759 一直在计算并发送 tier，而 RPC 从不写它，
      -- lexicon_entries.tier 恒为 NULL（连专为它建的
      -- idx_lexicon_entries_user_tier_count 索引也一直空转）。此处恢复。
      v_tier := lower(trim(coalesce(v_unit->>'tier', '')));
      v_tier := (CASE WHEN v_tier IN ('framework','domain') THEN v_tier ELSE NULL END);

      v_entry_id := NULL;
      INSERT INTO lexicon_entries (
        user_id, lemma, sense_key, display_form, entry_kind, native_meaning, tier,
        origin, total_count, first_seen_at, last_used_at
      ) VALUES (
        p_user_id, v_lemma, 'default',
        nullif(v_unit->>'display_form', ''),
        v_kind,
        v_note,
        v_tier,
        'captured', 1, now(), now()
      )
      ON CONFLICT (user_id, lemma, sense_key) DO UPDATE
        SET total_count    = lexicon_entries.total_count + 1,
            last_used_at   = now(),
            native_meaning = COALESCE(lexicon_entries.native_meaning, EXCLUDED.native_meaning),
            -- 「有新值就更新，否则保留原值」——这正是 20260728020000 的原始设计意图：
            -- 部署后，此前写成 NULL 的旧词条会在下次出现时自动被补上 tier，
            -- 无需单独回补历史数据。
            tier           = COALESCE(EXCLUDED.tier, lexicon_entries.tier)
        WHERE lexicon_entries.status <> 'excluded'
      RETURNING id INTO v_entry_id;

      IF v_entry_id IS NOT NULL THEN
        INSERT INTO lexicon_occurrences (
          entry_id, user_id, source_type, source_id, scene_category, scene_detail,
          input_lang, input_lang_code, source_granularity, source_direction,
          intent_text, intent_source, sample_sentence
        ) VALUES (
          v_entry_id, p_user_id, 'material', p_source_id, p_scene_category, p_scene_detail,
          v_input_lang, p_input_lang_code, v_gran, v_dir,
          p_intent_text,
          v_intent_src,
          COALESCE(nullif(v_unit->>'sample_sentence', ''), p_sample_sentence)
        );
        v_recorded := v_recorded + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_recorded;
END;
$$;

-- Accounting is a server-side action; clients must never call it directly.
-- The REVOKE is the part that actually enforces that (see section 2) — the
-- GRANT alone never did, because PUBLIC holds EXECUTE by default.
REVOKE EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 5. Report what the onboarding cleanup actually deleted
-- ─────────────────────────────────────────────────────────────
-- Identical to the 20260819070000 version except that the two cleanup DELETEs
-- now report their row counts, which are returned to the caller so the Edge
-- Function can log them. A destructive step that leaves no trace is impossible
-- to investigate after the fact — and during the current pre-launch testing
-- phase it is also the only way to confirm the cleanup ran at all without
-- querying the database by hand.
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
  v_cleaned_materials int := 0;
  v_cleaned_messages int := 0;
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
      'already_committed', true,
      -- A replayed request performs no cleanup; reported as 0 so the response
      -- shape stays stable for the caller.
      'cleaned_up_messages', 0,
      'cleaned_up_materials', 0
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
  -- Deleting the materials also fires trg_cleanup_lexicon_after_material_delete,
  -- which removes those materials' lexicon occurrences and corrects the
  -- affected entries' cached counts.
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
      GET DIAGNOSTICS v_cleaned_materials = ROW_COUNT;

      DELETE FROM public.messages
       WHERE user_id = v_user_id
         AND source = 'onboarding'
         AND request_id IS DISTINCT FROM p_request_id;
      GET DIAGNOSTICS v_cleaned_messages = ROW_COUNT;
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
    'already_committed', false,
    'cleaned_up_messages', v_cleaned_messages,
    'cleaned_up_materials', v_cleaned_materials
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 6. Correct the source_id column comment
-- ─────────────────────────────────────────────────────────────
-- 20260728000000 documented this column as "materials.id 或 messages.id".
-- The messages half was never true. That comment was written on 2026-07-28,
-- before the dialogue feature existed; when dialogue was actually built four
-- days later (20260801000000) it got its own dialogue_sessions/dialogue_turns
-- tables, and record_lexicon_dialogue_units (20260801020000) writes
-- dialogue_turns.id — its own parameter comment says so, and explains why
-- (turn-level idempotency). The dialogue Edge Function never writes to
-- messages at all, so a dialogue occurrence pointing at messages.id could not
-- exist even in principle.
--
-- Because the column has no foreign key, nothing in the database records or
-- enforces what it actually points at — the comment is the only documentation,
-- so a wrong one sends the next reader to JOIN the wrong table and get empty
-- results with no explanation. Corrected here rather than by editing the
-- original migration, which has already been applied and must stay immutable.
COMMENT ON COLUMN public.lexicon_occurrences.source_id IS
  '来源行 id。source_type=''material'' → materials.id；source_type=''dialogue'' → dialogue_turns.id。'
  '无外键约束（多态列），故数据库不保证也不记录真实指向 —— 改动前务必同步本注释。';
