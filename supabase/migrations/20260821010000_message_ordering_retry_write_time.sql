-- 方案丙（微信式「写作时刻」语义）：Tab1 重试成功后卡片放回气泡原位。
--
-- 背景：重试请求（复用原 request_id）由 Edge Function 携带
-- original_created_at（气泡的原始发送时刻）落库——user 行按写作时刻
-- 写 created_at，assistant 行按「写作时刻 + 1ms」写 created_at。
-- 这样服务器时间线与客户端原位摆放一致：刷新历史时卡片仍紧跟其气泡，
-- 不跳位置。同时服务端按 (user_id, request_id) 幂等，重试不会生成第二组记录。
--
-- 本迁移只改 assistant 行的 created_at 表达式：
--   · 显式传入时（仅重试路径）用传入值，但 GREATEST 兜底保证恒不早于
--     user 行 + 1ms —— 顺序不变量在 20260821000000 建立，这里不削弱。
--   · 未传入时（正常发送 / 预设卡路径）GREATEST(now(), v_user_created_at
--     + 1ms) 原样保留，行为与 20260821000000 版逐字节一致。
--
-- CREATE OR REPLACE 保持签名与 20260821000000 版一致；幂等分支、advisory
-- lock、onboarding 清理逻辑全部原样保留。
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
