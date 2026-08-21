-- 修复:onboarding 预设卡(save-preset-card)落库时 user 行与 assistant 行
-- created_at 打平,get-messages 按 created_at.asc, id.asc 排序时靠随机 UUID
-- 决胜,导致 AI 卡片约 50% 概率排在用户消息之前(时间线反序)。
--
-- 根因:同一事务内 Postgres now() 为常量(transaction_timestamp)。此前
-- save-preset-card 不传 created_at,user 行退化成 now(),assistant 行吃表
-- 默认 now(),两行时间戳逐字节相同。
--
-- 修法:user 行时间戳经 RETURNING 取回(v_user_created_at),assistant 行
-- 显式写 GREATEST(now(), v_user_created_at + 1ms):
--   · 预设卡路径:user 行来自 Edge Function 时钟,无论与数据库时钟谁快谁慢,
--     assistant 恒严格晚于 user —— 顺序恒正确。
--   · generate 照片路径:时钟正常时 now() > userCreatedAt + 1ms 恒成立
--     (userCreatedAt 锁定在 Gemini 调用之前),assistant 仍等于落库时刻,
--     行为零变化;仅两边时钟极端漂移时兜底到 user+1ms(顺序仍正确)。
--   · 旧客户端不传 created_at:user 行 = now(),assistant = now()+1ms,
--     顺序同样修复 —— 本迁移单独上线即可生效,不依赖 Edge Function 新版。
--
-- CREATE OR REPLACE 保持签名与 20260819070000 版一致;幂等分支、advisory
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
    GREATEST(now(), v_user_created_at + interval '1 millisecond')
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
