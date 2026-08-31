-- 20260821010000 rewrote this RPC for message ordering and accidentally
-- dropped the cleanup counts introduced by 20260820000000. Preserve the
-- latest ordering behaviour while restoring the stable response contract.
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

  SELECT id INTO v_user_message_id
    FROM public.messages
   WHERE user_id = v_user_id AND request_id = p_request_id AND role = 'user';
  SELECT id, card_type, card_content, extracted_concept
    INTO v_assistant_message_id, v_card_type, v_card_content, v_extracted_concept
    FROM public.messages
   WHERE user_id = v_user_id AND request_id = p_request_id AND role = 'assistant';
  SELECT id INTO v_material_id
    FROM public.materials
   WHERE user_id = v_user_id AND request_id = p_request_id;

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
    v_user_id, p_request_id, 'user',
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
    v_user_id, p_request_id, 'assistant',
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
      v_user_id, p_request_id, v_user_message_id,
      p_material ->> 'material_type',
      COALESCE(NULLIF(p_material ->> 'status', ''), 'pending'),
      NULLIF(p_material ->> 'scene_category', ''),
      p_material -> 'raw_content',
      COALESCE(NULLIF(p_material ->> 'source', ''), 'tab1')
    ) RETURNING id INTO v_material_id;
  END IF;

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
