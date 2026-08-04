-- ─────────────────────────────────────────────────────────────
-- Tab2 解锁判定：移除"累计输入 ≥5"条件，仅保留"任一分类 ≥20 词"。
-- 只重定义 get_tab2_home，改动一处：v_unlocked。
-- （input_count 仍照常统计并返回，客户端已不再据此展示/判定，无害保留。）
-- 与 20260730010000_tab2_home_rpcs.sql 中的 get_tab2_home 函数体一致，仅第 139 行逻辑变更。
-- ─────────────────────────────────────────────────────────────
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
  -- ── Tab1 输入总数（所有 materials 不分类型）──
  SELECT COUNT(*)::int INTO v_input_count
  FROM   materials
  WHERE  user_id = p_user_id;

  -- ── 每个分类的词条统计 ──
  WITH cat_words AS (
    SELECT
      lo.scene_category,
      COUNT(DISTINCT lo.entry_id)::int          AS word_count,
      MAX(lo.created_at)                         AS last_material_at,
      -- 最近入账 3 个 lemma（收起态预览）
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
  -- ── 子场景列表（每个分类下，按出现次数降序）──
  sub_scenes AS (
    SELECT
      lo.scene_category,
      lo.scene_detail,
      COUNT(*)::int                              AS occurrence_count,
      -- 最近一条有内容（≥6 字）的 user_original
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
      -- 对应的 image_url（lexicon_occurrences→materials→messages 两步 join）
      (
        SELECT msg.image_url
        FROM   lexicon_occurrences lo4
        JOIN   materials m4  ON m4.id  = lo4.source_id
        JOIN   messages  msg ON msg.id = m4.source_message_id
        WHERE  lo4.user_id        = p_user_id
          AND  lo4.scene_category = lo.scene_category
          AND  lo4.scene_detail   = lo.scene_detail
          AND  lo4.scene_detail IS NOT NULL
          AND  msg.image_url IS NOT NULL
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
            'scene_detail',     ss.scene_detail,
            'occurrence_count', ss.occurrence_count,
            'quote',            ss.quote,
            'image_url',        ss.image_url
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

  -- ── 解锁判定：任一分类 ≥20 词（已移除 input_count ≥5 条件）──
  SELECT COALESCE(MAX((cat->>'word_count')::int), 0) INTO v_max_words
  FROM   jsonb_array_elements(COALESCE(v_categories, '[]'::jsonb)) AS cat;
  v_unlocked := (v_max_words >= 20);

  v_result := jsonb_build_object(
    'unlocked',     v_unlocked,
    'input_count',  v_input_count,
    'categories',   COALESCE(v_categories, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_tab2_home(uuid) TO service_role;

-- PostgREST 架构缓存重载（函数签名未变，稳妥起见仍触发一次）
NOTIFY pgrst, 'reload schema';
