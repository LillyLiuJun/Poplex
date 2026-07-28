-- Slice 1 · 记账 RPC：把一条素材抽出的 learnable_units 原子化入账。
-- 由 generate 的 Stage 3 调用；补账作业（Slice 1b）复用同一函数，保证行为一致。
--
-- 为什么用 DB 函数而不是 Edge 发多个 REST：
--   · 原子性——一条素材的全部单元在一个事务里，失败整体回滚（§5.3.1「不写半条」）。
--   · 无竞态——find-or-create + total_count 累加靠 INSERT ... ON CONFLICT 一步完成。
--   · 防复活——命中 status='excluded' 的词条时，既不累加也不记流水（§6.3.5）。
--
-- 枚举收敛：模型产出的 kind / input_lang / granularity / direction 是概率性的、会飘，
-- 这里统一收敛到合法集合，非法 → NULL，免得一个怪值撞 CHECK 约束把整批记账带崩（§5.1.3）。
-- 归一化（lemma 小写/停用词）在 Edge 侧做好后传入。

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
  p_units              jsonb   -- [{ "lemma": "...", "display_form": "...", "entry_kind": "..." }, ...]
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
  -- 素材级枚举收敛（一次，全单元共用）
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
      -- entry_kind 收敛：合法值直接用；phrasal verb → phrase；其余 → NULL。
      v_kind := lower(trim(coalesce(v_unit->>'entry_kind', '')));
      v_kind := (CASE
        WHEN v_kind IN ('word','phrase','collocation','slang','idiom','pattern') THEN v_kind
        WHEN v_kind IN ('phrasal verb','phrasal-verb')                            THEN 'phrase'
        ELSE NULL
      END);

      -- 找到或新建词条。命中 excluded 时 WHERE 挡下更新、RETURNING 无行 → v_entry_id 保持 NULL。
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

      -- v_entry_id 为 NULL = 命中 excluded（防复活）→ 不记流水。
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

-- 只授给 service_role：记账是服务端动作，客户端永不直接调用。
GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, jsonb
) TO service_role;
