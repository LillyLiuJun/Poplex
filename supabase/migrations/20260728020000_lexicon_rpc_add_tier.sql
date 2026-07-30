-- Slice 2 · 在记账 RPC 里加 tier 写入。
-- Edge 侧已通过静态词表（FRAMEWORK_LEMMAS）判好 tier，作为 unit 的一个字段传入。
-- RPC 只负责原子持久化：新建 entry 时写入 tier；ON CONFLICT 时也更新 tier，
-- 以便 Slice 2 部署后旧 NULL 条目在下次出现时自动修正。
--
-- 验收：insert "make" → tier='framework'；insert "invoice" → tier='domain'；
--       同一词两次调用 total_count=2，tier 不变。

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
  p_units              jsonb   -- [{ "lemma","display_form","entry_kind","tier" }, ...]
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit       jsonb;
  v_lemma      text;
  v_kind       text;
  v_tier       text;
  v_entry_id   uuid;
  v_recorded   int := 0;
  v_input_lang text;
  v_gran       text;
  v_dir        text;
BEGIN
  -- 素材级枚举收敛（一次，全单元共用）
  v_input_lang := (CASE WHEN lower(p_input_lang)         IN ('native','target','other')   THEN lower(p_input_lang)         ELSE NULL END);
  v_gran       := (CASE WHEN lower(p_source_granularity) IN ('word','sentence','passage') THEN lower(p_source_granularity) ELSE NULL END);
  v_dir        := (CASE WHEN lower(p_source_direction)   IN ('comprehend','express')      THEN lower(p_source_direction)   ELSE NULL END);

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

      -- tier 收敛：Edge 已判好；非法值 → NULL（让 NULL 比写脏值更安全）。
      v_tier := lower(trim(coalesce(v_unit->>'tier', '')));
      v_tier := (CASE WHEN v_tier IN ('framework','domain') THEN v_tier ELSE NULL END);

      -- 找到或新建词条。命中 excluded 时 WHERE 挡下更新、RETURNING 无行 → v_entry_id 保持 NULL。
      v_entry_id := NULL;
      INSERT INTO lexicon_entries (
        user_id, lemma, sense_key, display_form, entry_kind, tier,
        origin, total_count, first_seen_at, last_used_at
      ) VALUES (
        p_user_id, v_lemma, 'default',
        nullif(v_unit->>'display_form', ''),
        v_kind, v_tier,
        'captured', 1, now(), now()
      )
      ON CONFLICT (user_id, lemma, sense_key) DO UPDATE
        SET total_count  = lexicon_entries.total_count + 1,
            last_used_at = now(),
            -- tier: 用 COALESCE 实现"有新值就更新，否则保留原值"——
            -- 这样 Slice 2 部署后旧 NULL tier 在下次出现时自动被修正。
            tier         = COALESCE(EXCLUDED.tier, lexicon_entries.tier)
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

-- 权限不变：只授给 service_role。
GRANT EXECUTE ON FUNCTION record_lexicon_material_units(
  uuid, uuid, text, text, text, text, text, text, text, jsonb
) TO service_role;

-- PostgREST 函数签名未变（参数列表/返回类型一样），通常无需 reload。
-- 若部署后 rpc 调用报 404，手动执行：SELECT pg_notify('pgrst','reload schema');
