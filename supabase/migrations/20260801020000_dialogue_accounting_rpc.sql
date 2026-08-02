-- E0 · 对话侧记账 RPC
-- 新建 record_lexicon_dialogue_units，平行于已上线的 record_lexicon_material_units。
-- 不改现有素材 RPC——它已上线验证，动它是没必要的风险（需求设计 §5.2）。
--
-- 比素材版多做四件事（需求设计 §5.2）：
--   1. source_type = 'dialogue'；origin = 'spoken'（账本里没有的词，直接用说出来定性）。
--   2. spoken_count += 1；首次由 0 变 1 → 写 first_spoken_at + 插 breakthrough 事件（北极星指标，100% 可靠）。
--   3. 接受 p_used_correctly (bool?) 和 p_is_known_gap (bool)，写进 occurrence。
--   4. 只有 source_type='dialogue' 的记账才动 spoken_count（接口契约 §7.3 硬规则）。
--
-- 继承素材版两个既有行为：
--   · 枚举容错：模型漂移的 entry_kind 收敛到合法集合，非法 → NULL，防止一条脏数据撞崩整批。
--   · 防复活：命中 status='excluded' 的词条直接跳过，不重建（PRD §6.3.5）。
--
-- breakthrough 的判定：RETURNING spoken_count = 1 意味着此轮是第一次说出（无论新词还是已有词首说）。
-- 这是确定性数据事实，不依赖任何模型判断。

CREATE OR REPLACE FUNCTION record_lexicon_dialogue_units(
  p_user_id         uuid,
  p_source_id       uuid,        -- dialogue_turns.id（turn 级幂等键保证不重计）
  p_session_id      uuid,        -- dialogue_sessions.id（learning_events 归属）
  p_scene_category  text,
  p_scene_detail    text,        -- 子场景（第一轮收窄后才有值，可空）
  p_used_correctly  boolean,     -- 这一轮用对了吗（null = 本轮不做正确性判定）
  p_is_known_gap    boolean,     -- 是否来自母语兜底暴露的缺口
  p_sample_sentence text,        -- 用户这一轮的转写原文（作为 occurrence 例句）
  p_units           jsonb        -- [{ "lemma": "...", "display_form": "...", "entry_kind": "..." }, ...]
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit        jsonb;
  v_lemma       text;
  v_kind        text;
  v_entry_id    uuid;
  v_new_spoken  int;
  v_recorded    int := 0;
BEGIN
  IF p_units IS NULL OR jsonb_typeof(p_units) <> 'array' THEN
    RETURN 0;
  END IF;

  FOR v_unit IN SELECT * FROM jsonb_array_elements(p_units)
  LOOP
    v_lemma := nullif(trim(v_unit->>'lemma'), '');

    IF v_lemma IS NOT NULL THEN
      -- entry_kind 枚举收敛（与 material 版保持一致）。
      v_kind := lower(trim(coalesce(v_unit->>'entry_kind', '')));
      v_kind := (CASE
        WHEN v_kind IN ('word','phrase','collocation','slang','idiom','pattern') THEN v_kind
        WHEN v_kind IN ('phrasal verb','phrasal-verb')                            THEN 'phrase'
        ELSE NULL
      END);

      -- 新建或更新词条。
      -- · 新词（INSERT 路径）：origin='spoken'，spoken_count 从 1 开始。
      -- · 已有词（UPDATE 路径）：only increment spoken_count + total_count + last_used_at；
      --   origin 字段不覆盖——'captured' 先到的就是 'captured'，说出来不改它的"出身"。
      -- · excluded 防复活：DO UPDATE 的 WHERE 过滤 excluded 行，
      --   RETURNING 无行 → v_entry_id 保持 NULL → 后续 IF 跳过。
      v_entry_id   := NULL;
      v_new_spoken := NULL;
      INSERT INTO lexicon_entries (
        user_id, lemma, sense_key, display_form, entry_kind,
        origin, total_count, spoken_count,
        first_spoken_at, first_seen_at, last_used_at
      ) VALUES (
        p_user_id, v_lemma, 'default',
        nullif(v_unit->>'display_form', ''),
        v_kind,
        'spoken', 1, 1, now(), now(), now()
      )
      ON CONFLICT (user_id, lemma, sense_key) DO UPDATE
        SET total_count     = lexicon_entries.total_count + 1,
            spoken_count    = lexicon_entries.spoken_count + 1,
            correct_count   = lexicon_entries.correct_count
                              + CASE WHEN p_used_correctly = true THEN 1 ELSE 0 END,
            first_spoken_at = COALESCE(lexicon_entries.first_spoken_at, now()),
            last_used_at    = now()
        WHERE lexicon_entries.status <> 'excluded'
      RETURNING id, spoken_count INTO v_entry_id, v_new_spoken;

      IF v_entry_id IS NOT NULL THEN
        -- spoken_count 从 0 变 1（或新词首次说出）→ 自动写 breakthrough 事件。
        -- 这是北极星指标，必须百分之百由 RPC 内部写，不依赖任何模型判断（需求设计 §5.1 / §7）。
        IF v_new_spoken = 1 THEN
          INSERT INTO learning_events (user_id, session_id, entry_id, event_type, aspect)
          VALUES (p_user_id, p_session_id, v_entry_id, 'breakthrough', 'vocab');
        END IF;

        -- 对话流水：source_type 硬写 'dialogue'，input_lang 硬写 'target'（对话输出恒为目标语言）。
        INSERT INTO lexicon_occurrences (
          entry_id, user_id,
          source_type, source_id,
          scene_category, scene_detail,
          input_lang, source_granularity, source_direction,
          used_correctly, is_known_gap,
          sample_sentence
        ) VALUES (
          v_entry_id, p_user_id,
          'dialogue', p_source_id,
          p_scene_category, p_scene_detail,
          'target', 'sentence', 'express',
          p_used_correctly, p_is_known_gap,
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
GRANT EXECUTE ON FUNCTION record_lexicon_dialogue_units(
  uuid, uuid, uuid, text, text, boolean, boolean, text, jsonb
) TO service_role;
