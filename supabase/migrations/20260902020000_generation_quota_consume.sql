-- Generation quota consume step (生成次数限制 · 第 2 刀).
--
-- Advances generation_usage inside commit_generated_content's transaction, so
-- a rolled-back commit rolls the count back too — "only success consumes".
--
-- Two layers because commit_generated_content is SECURITY INVOKER (it must
-- keep running as the signed-in user for its RLS-scoped reads, inserts, and
-- onboarding deletes) while generation_usage grants no API role any write:
--
--   1. consume_generation_quota(date) — SECURITY DEFINER, resolves the user
--      from auth.uid() inside, so a client calling it directly can only ever
--      advance their own row (self-scoped by construction; no user_id
--      parameter exists to abuse).
--   2. A new 6-argument overload of commit_generated_content carries the two
--      new parameters and calls the helper inside its transaction.
--
-- Defaults (all callers were surveyed before choosing them):
--   p_usage_date   DEFAULT NULL  — old callers that don't send a date simply
--     don't count. Bucketing is caller-computed by design: the RPC must never
--     use now(), or a pre-check at 23:59:59 and a commit at 00:00:02 would
--     land in two different buckets and hand the user a free day.
--   p_count_usage  DEFAULT true  — normal commits count.
--
-- Onboarding exemption is judged from a server-side fact, never from the
-- client-controlled source string alone: a commit is exempt iff
-- source = 'onboarding' AND profiles.onboarding_completed_at IS NULL.
-- A client forging source='onboarding' after completing onboarding is still
-- counted, so the exemption window cannot be extended forever by a lying
-- payload. (A user who never completes onboarding stays exempt by design —
-- accepted trade-off, the onboarding flow itself gates real usage.)
--
-- The 4-argument version is DROPPED, not kept alongside: two overloads make
-- every 4-positional-argument call "not unique" (PostgreSQL considers the
-- 6-arg defaulted signature a candidate too), and PostgREST's overload pick
-- for save-preset-card's 4 named parameters would become non-deterministic.
-- With only the 6-arg function left, legacy callers resolve through its
-- defaults and neither counts (NULL usage date).

CREATE OR REPLACE FUNCTION public.consume_generation_quota(
  p_usage_date date
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.generation_usage (user_id, usage_date, used_count)
  VALUES (auth.uid(), p_usage_date, 1)
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET used_count = public.generation_usage.used_count + 1,
                updated_at = now();
$$;

-- authenticated needs EXECUTE because the INVOKER commit RPC runs as the
-- signed-in user; the write privilege itself is the owner's (SECURITY
-- DEFINER). The worst a direct client call can do is advance the caller's own
-- counter — generation_usage stays unwritable by any API role.
REVOKE ALL ON FUNCTION public.consume_generation_quota(date)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_generation_quota(date)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.commit_generated_content(
  p_request_id uuid,
  p_user_message jsonb,
  p_assistant_message jsonb,
  p_material jsonb DEFAULT NULL,
  p_usage_date date DEFAULT NULL,
  p_count_usage boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_user_created_at timestamptz;
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
      'cleaned_up_messages', 0,
      'cleaned_up_materials', 0
    );
  END IF;

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
  ) RETURNING id, created_at INTO v_user_message_id, v_user_created_at;

  INSERT INTO public.messages (
    user_id, request_id, role, card_type, card_content, extracted_concept,
    status, source, created_at
  ) VALUES (
    v_user_id,
    p_request_id,
    'assistant',
    NULLIF(p_assistant_message ->> 'card_type', ''),
    p_assistant_message -> 'card_content',
    NULLIF(p_assistant_message ->> 'extracted_concept', ''),
    COALESCE(NULLIF(p_assistant_message ->> 'status', ''), 'delivered'),
    COALESCE(NULLIF(p_assistant_message ->> 'source', ''), 'tab1'),
    GREATEST(
      COALESCE(NULLIF(p_assistant_message ->> 'created_at', '')::timestamptz, now()),
      v_user_created_at + interval '1 millisecond'
    )
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

  -- Cleanup happens only after the replacement attempt is safely inserted.
  -- Deleting materials also fires trg_cleanup_lexicon_after_material_delete.
  IF v_source = 'onboarding' THEN
    SELECT (onboarding_completed_at IS NULL)
      INTO v_not_yet_completed
      FROM public.profiles
     WHERE id = v_user_id;

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

  -- 生成次数扣减（第 2 刀）：与上面的落库在同一个事务里，回滚则计数一并回滚。
  -- 幂等路径（already_committed）已在函数早期返回，能走到这里的必然是新落库。
  -- 豁免判定用服务端事实：source 由客户端提供、可伪造，只有
  -- onboarding_completed_at 能证明「还在 onboarding」。p_usage_date 为 NULL
  -- （旧调用方未传）→ 不计入。
  IF COALESCE(p_count_usage, true)
     AND p_usage_date IS NOT NULL
     AND NOT (v_source = 'onboarding' AND COALESCE(v_not_yet_completed, false)) THEN
    PERFORM public.consume_generation_quota(p_usage_date);
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

-- The 6-arg function is a distinct object: CREATE OR REPLACE did not carry
-- the 4-argument version's ACLs over, and a fresh object defaults to PUBLIC
-- EXECUTE. Re-encode the original minimum explicitly.
REVOKE ALL ON FUNCTION public.commit_generated_content(uuid, jsonb, jsonb, jsonb, date, boolean)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.commit_generated_content(uuid, jsonb, jsonb, jsonb, date, boolean)
  TO authenticated, service_role;

-- Dropping the old signature is what makes legacy 4-argument calls resolve
-- unambiguously through the new defaults (see the note at the top).
DROP FUNCTION public.commit_generated_content(uuid, jsonb, jsonb, jsonb);
