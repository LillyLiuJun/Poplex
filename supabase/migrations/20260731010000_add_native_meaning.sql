-- N4: 词条行展示目标语言 + 母语两行
--
-- learnable_units 每条的 note 字段（母语释义）原来在 generate/index.ts 被丢弃，
-- 现在传入 RPC 并落库到 lexicon_entries.native_meaning。
-- 注意：已有词条 native_meaning 为 null，新入账才会填入；
--       COALESCE 确保不覆盖已有值（先到先得，避免后续覆盖干扰）。

-- 1. 给词条表加列
ALTER TABLE lexicon_entries
    ADD COLUMN IF NOT EXISTS native_meaning text;

-- 2. 更新记账 RPC：写入 note → native_meaning
DROP FUNCTION IF EXISTS record_lexicon_material_units(
    uuid, uuid, text, text, text, text, text, text, text, jsonb
);

CREATE OR REPLACE FUNCTION record_lexicon_material_units(
  p_user_id            uuid,
  p_source_id          uuid,
  p_scene_category     text,
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
        SET total_count   = lexicon_entries.total_count + 1,
            last_used_at  = now(),
            -- 只在尚无值时填入，不覆盖已有的释义
            native_meaning = COALESCE(lexicon_entries.native_meaning, EXCLUDED.native_meaning)
        WHERE lexicon_entries.status <> 'excluded'
      RETURNING id INTO v_entry_id;

      IF v_entry_id IS NOT NULL THEN
        INSERT INTO lexicon_occurrences (
          entry_id, user_id, source_type, source_id, scene_category,
          input_lang, input_lang_code, source_granularity, source_direction,
          intent_text, sample_sentence
        ) VALUES (
          v_entry_id, p_user_id, 'material', p_source_id, p_scene_category,
          v_input_lang, p_input_lang_code, v_gran, v_dir,
          p_intent_text, p_sample_sentence
        );
        v_recorded := v_recorded + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_recorded;
END;
$$;

GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, jsonb
) TO service_role;

-- 3. 更新 get_category_words：返回 native_meaning
--    （依赖 20260731000000 已执行，该版本已修复图片路径取法）
DROP FUNCTION IF EXISTS get_category_words(uuid, text);

CREATE OR REPLACE FUNCTION get_category_words(
  p_user_id       uuid,
  p_scene_category text
)
RETURNS TABLE(
  lemma           text,
  display_form    text,
  entry_kind      text,
  pos             text,
  granularity     text,
  source_type     text,
  sample_sentence text,
  native_meaning  text,
  source_image_path text
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT DISTINCT ON (le.lemma)
    le.lemma,
    le.display_form,
    le.entry_kind,
    le.pos,
    lo.source_granularity    AS granularity,
    lo.source_type,
    lo.sample_sentence,
    le.native_meaning,
    (
      SELECT m.raw_content->>'source_image_path'
      FROM   materials m
      WHERE  m.id = lo.source_id
        AND  m.raw_content->>'source_image_path' IS NOT NULL
        AND  m.raw_content->>'source_image_path' <> ''
      LIMIT  1
    )                        AS source_image_path
  FROM   lexicon_occurrences lo
  JOIN   lexicon_entries     le ON le.id = lo.entry_id
  WHERE  lo.user_id           = p_user_id
    AND  lo.scene_category    = p_scene_category
    AND  le.status             = 'active'
  ORDER  BY le.lemma, lo.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_category_words(uuid, text) TO service_role;
