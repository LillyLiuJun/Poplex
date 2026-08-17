-- A stable request ID lets the generation path safely retry one user action.
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.materials ADD COLUMN IF NOT EXISTS request_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS messages_user_request_role_key
  ON public.messages (user_id, request_id, role)
  WHERE request_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS materials_user_request_key
  ON public.materials (user_id, request_id)
  WHERE request_id IS NOT NULL;

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
    user_id, request_id, role, input_type, user_content, status, source, image_url, created_at
  ) VALUES (
    v_user_id,
    p_request_id,
    'user',
    NULLIF(p_user_message ->> 'input_type', ''),
    p_user_message ->> 'user_content',
    COALESCE(NULLIF(p_user_message ->> 'status', ''), 'delivered'),
    COALESCE(NULLIF(p_user_message ->> 'source', ''), 'tab1'),
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

REVOKE ALL ON FUNCTION public.commit_generated_content(uuid, jsonb, jsonb, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.commit_generated_content(uuid, jsonb, jsonb, jsonb)
  TO authenticated, service_role;

-- SECURITY INVOKER keeps RLS effective. These are the only table privileges the
-- caller needs for the function's own owned-row reads and inserts.
GRANT SELECT, INSERT ON TABLE public.messages TO authenticated;
GRANT SELECT, INSERT ON TABLE public.materials TO authenticated;
