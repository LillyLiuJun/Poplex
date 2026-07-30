-- Slice A · 更新 record_lexicon_material_units：新增 p_scene_detail + 词条级 sample_sentence
--
-- 两处变更：
-- 1. p_scene_detail text — 子场景标签（可空）；vocabulary / 判不出时传 null。
-- 2. 词条级 sample_sentence — 缺口 7 修复：passage 素材里每个词的 sample_sentence
--    应指向该词所在的那一行，而不是整篇文章。
--    实现方式：p_units 里每个对象可携带可选的 "sample_sentence" 字段；
--    RPC 优先取词条级别的值，取不到则 fallback 到素材级的 p_sample_sentence。
--    对 sentence 和 vocabulary 素材：不传词条级别字段，行为与旧版完全相同。

CREATE OR REPLACE FUNCTION record_lexicon_material_units(
  p_user_id            uuid,
  p_source_id          uuid,
  p_scene_category     text,
  p_scene_detail       text,   -- 子场景标签（可空）
  p_input_lang         text,
  p_input_lang_code    text,
  p_source_granularity text,
  p_source_direction   text,
  p_intent_text        text,
  p_sample_sentence    text,
  p_units              jsonb
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit       jsonb;
  v_lemma      text;
  v_kind       text;
  v_entry_id   uuid;
  v_recorded   int := 0;
  v_input_lang text;
  v_gran       text;
  v_dir        text;
BEGIN
  v_input_lang := (CASE WHEN lower(p_input_lang)         IN ('native','target','other')     THEN lower(p_input_lang)         ELSE NULL END);
  v_gran       := (CASE WHEN lower(p_source_granularity) IN ('word','sentence','passage')   THEN lower(p_source_granularity) ELSE NULL END);
  v_dir        := (CASE WHEN lower(p_source_direction)   IN ('comprehend','express')        THEN lower(p_source_direction)   ELSE NULL END);

  IF p_units IS NULL OR jsonb_typeof(p_units) <> 'array' THEN
    RETURN 0;
  END IF;

  FOR v_unit IN SELECT * FROM jsonb_array_elements(p_units)
  LOOP
    v_lemma := nullif(trim(v_unit->>'lemma'), '');

    IF v_lemma IS NOT NULL THEN
      v_kind := lower(trim(coalesce(v_unit->>'entry_kind', '')));
      v_kind := (CASE
        WHEN v_kind IN ('word','phrase','collocation','slang','idiom','pattern') THEN v_kind
        WHEN v_kind IN ('phrasal verb','phrasal-verb')                            THEN 'phrase'
        ELSE NULL
      END);

      v_entry_id := NULL;
      INSERT INTO lexicon_entries (
        user_id, lemma, sense_key, display_form, entry_kind,
        origin, total_count, first_seen_at, last_used_at
      ) VALUES (
        p_user_id, v_lemma, 'default',
        nullif(v_unit->>'display_form', ''),
        v_kind,
        'captured', 1, now(), now()
      )
      ON CONFLICT (user_id, lemma, sense_key) DO UPDATE
        SET total_count  = lexicon_entries.total_count + 1,
            last_used_at = now()
        WHERE lexicon_entries.status <> 'excluded'
      RETURNING id INTO v_entry_id;

      IF v_entry_id IS NOT NULL THEN
        INSERT INTO lexicon_occurrences (
          entry_id, user_id, source_type, source_id, scene_category, scene_detail,
          input_lang, input_lang_code, source_granularity, source_direction,
          intent_text, sample_sentence
        ) VALUES (
          v_entry_id, p_user_id, 'material', p_source_id, p_scene_category, p_scene_detail,
          v_input_lang, p_input_lang_code, v_gran, v_dir,
          p_intent_text,
          -- 词条级 sample_sentence 优先（passage 修复）；无则 fallback 到素材级。
          COALESCE(nullif(v_unit->>'sample_sentence', ''), p_sample_sentence)
        );
        v_recorded := v_recorded + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_recorded;
END;
$$;

GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
) TO service_role;
