-- sub_scenes 新增 target_expression 字段：当 user_original 为空时，
-- 前端降级展示 AI 生成的目标语言句子，而非只显示场景标签。
-- 取该子场景下最新一条 materials.raw_content->>'target_expression'。

CREATE OR REPLACE FUNCTION get_tab2_home(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_input_count  int;
  v_max_words    int;
  v_unlocked     bool;
  v_categories   jsonb;
  v_result       jsonb;
BEGIN
  SELECT COUNT(*)::int INTO v_input_count
  FROM   materials
  WHERE  user_id = p_user_id;

  WITH cat_words AS (
    SELECT
      lo.scene_category,
      COUNT(DISTINCT lo.entry_id)::int          AS word_count,
      MAX(lo.created_at)                         AS last_material_at,
      (
        SELECT jsonb_agg(sub.lemma ORDER BY sub.ts DESC)
        FROM (
          SELECT DISTINCT ON (le2.lemma) le2.lemma, lo2.created_at AS ts
          FROM   lexicon_occurrences lo2
          JOIN   lexicon_entries     le2 ON le2.id = lo2.entry_id
          WHERE  lo2.user_id        = p_user_id
            AND  lo2.scene_category = lo.scene_category
            AND  le2.status         = 'active'
          ORDER  BY le2.lemma, lo2.created_at DESC
          LIMIT  3
        ) sub
      )                                          AS preview_words
    FROM   lexicon_occurrences lo
    JOIN   lexicon_entries     le ON le.id = lo.entry_id
    WHERE  lo.user_id           = p_user_id
      AND  lo.scene_category IS NOT NULL
      AND  le.status             = 'active'
    GROUP  BY lo.scene_category
  ),
  sub_scenes AS (
    SELECT
      lo.scene_category,
      lo.scene_detail,
      COUNT(*)::int                              AS occurrence_count,
      -- 用户原话（≥6 字）
      (
        SELECT m_raw.raw_content->>'user_original'
        FROM   lexicon_occurrences lo3
        JOIN   materials m_raw ON m_raw.id = lo3.source_id
        WHERE  lo3.user_id        = p_user_id
          AND  lo3.scene_category = lo.scene_category
          AND  lo3.scene_detail   = lo.scene_detail
          AND  lo3.scene_detail IS NOT NULL
          AND  length(m_raw.raw_content->>'user_original') >= 6
        ORDER  BY lo3.created_at DESC
        LIMIT  1
      )                                          AS quote,
      -- AI 生成的目标语言句子（无 quote 时前端降级展示）
      (
        SELECT m_te.raw_content->>'target_expression'
        FROM   lexicon_occurrences lo5
        JOIN   materials m_te ON m_te.id = lo5.source_id
        WHERE  lo5.user_id        = p_user_id
          AND  lo5.scene_category = lo.scene_category
          AND  lo5.scene_detail   = lo.scene_detail
          AND  lo5.scene_detail IS NOT NULL
          AND  m_te.raw_content->>'target_expression' IS NOT NULL
        ORDER  BY lo5.created_at DESC
        LIMIT  1
      )                                          AS target_expression,
      -- 图片路径（直接从 raw_content 取，source_message_id 未被写入）
      (
        SELECT m_img.raw_content->>'source_image_path'
        FROM   lexicon_occurrences lo4
        JOIN   materials m_img ON m_img.id = lo4.source_id
        WHERE  lo4.user_id        = p_user_id
          AND  lo4.scene_category = lo.scene_category
          AND  lo4.scene_detail   = lo.scene_detail
          AND  lo4.scene_detail IS NOT NULL
          AND  m_img.raw_content->>'source_image_path' IS NOT NULL
        ORDER  BY lo4.created_at DESC
        LIMIT  1
      )                                          AS image_url
    FROM   lexicon_occurrences lo
    JOIN   lexicon_entries     le ON le.id = lo.entry_id
    WHERE  lo.user_id           = p_user_id
      AND  lo.scene_category IS NOT NULL
      AND  lo.scene_detail   IS NOT NULL
      AND  le.status             = 'active'
    GROUP  BY lo.scene_category, lo.scene_detail
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'scene_category',   cw.scene_category,
      'word_count',       cw.word_count,
      'unlocked',         cw.word_count >= 20,
      'last_material_at', cw.last_material_at,
      'sub_scenes', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'scene_detail',      ss.scene_detail,
            'occurrence_count',  ss.occurrence_count,
            'quote',             ss.quote,
            'target_expression', ss.target_expression,
            'image_url',         ss.image_url
          ) ORDER BY ss.occurrence_count DESC
        )
        FROM sub_scenes ss
        WHERE ss.scene_category = cw.scene_category
      ), '[]'::jsonb),
      'preview_words', COALESCE(cw.preview_words, '[]'::jsonb)
    )
    ORDER BY cw.word_count DESC, cw.last_material_at DESC
  ) INTO v_categories
  FROM cat_words cw;

  SELECT COALESCE(MAX((cat->>'word_count')::int), 0) INTO v_max_words
  FROM   jsonb_array_elements(COALESCE(v_categories, '[]'::jsonb)) AS cat;
  v_unlocked := (v_max_words >= 20);

  v_result := jsonb_build_object(
    'unlocked',    v_unlocked,
    'input_count', v_input_count,
    'categories',  COALESCE(v_categories, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;
