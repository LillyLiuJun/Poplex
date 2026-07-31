-- 修正 N4：native_meaning 实际上没有写入
--
-- 20260731010000 改的是 10 参数版本的 RPC，但 generate 调用的是
-- 11 参数版本（含 p_scene_detail，来自 20260730001000）。
-- 11 参数版本从未被改动，note→native_meaning 一直没有写入。
-- 本迁移修正 11 参数版本，同时清理掉 20260731010000 产生的无用 10 参数版本。

-- 1. 清理 20260731010000 产生的无用 10 参数版本
DROP FUNCTION IF EXISTS record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, jsonb
);

-- 2. 修正 11 参数版本（generate 实际调用的那个）：写入 native_meaning
DROP FUNCTION IF EXISTS record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
);

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
  p_sample_sentence    text,
  p_units              jsonb
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit       jsonb;
  v_lemma      text;
  v_kind       text;
  v_note       text;
  v_entry_id   uuid;
  v_recorded   int := 0;
  v_input_lang text;
  v_gran       text;
  v_dir        text;
BEGIN
  v_input_lang := (CASE WHEN lower(p_input_lang)         IN ('native','target','other')   THEN lower(p_input_lang)         ELSE NULL END);
  v_gran       := (CASE WHEN lower(p_source_granularity) IN ('word','sentence','passage') THEN lower(p_source_granularity) ELSE NULL END);
  v_dir        := (CASE WHEN lower(p_source_direction)   IN ('comprehend','express')      THEN lower(p_source_direction)   ELSE NULL END);

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
          intent_text, sample_sentence
        ) VALUES (
          v_entry_id, p_user_id, 'material', p_source_id, p_scene_category, p_scene_detail,
          v_input_lang, p_input_lang_code, v_gran, v_dir,
          p_intent_text,
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
