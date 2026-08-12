-- Slice 1 · 第 1 刀：record_lexicon_material_units 增加 p_intent_source 参数
-- 设计依据：docs/prd/Tab2_Hero卡_数据提取与展示_设计方案_v1.md §10.4.3
--
-- 签名从 11 参数扩为 12 参数；旧版 DROP 后重建，保证 PostgREST 路由唯一。

-- 1. 移除旧版（11 参数）
DROP FUNCTION IF EXISTS record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
);

-- 2. 新版（12 参数，新增 p_intent_source）
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
  v_entry_id     uuid;
  v_recorded     int := 0;
  v_input_lang   text;
  v_gran         text;
  v_dir          text;
  v_intent_src   text;
BEGIN
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

      v_entry_id := NULL;
      INSERT INTO lexicon_entries (
        user_id, lemma, sense_key, display_form, entry_kind, native_meaning,
        origin, total_count, first_seen_at, last_used_at
      ) VALUES (
        p_user_id, v_lemma, 'default',
        nullif(v_unit->>'display_form', ''),
        v_kind,
        v_note,
        'captured', 1, now(), now()
      )
      ON CONFLICT (user_id, lemma, sense_key) DO UPDATE
        SET total_count    = lexicon_entries.total_count + 1,
            last_used_at   = now(),
            native_meaning = COALESCE(lexicon_entries.native_meaning, EXCLUDED.native_meaning)
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

-- 只授给 service_role：记账是服务端动作，客户端永不直接调用。
GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) TO service_role;
