-- Slice B · Tab2 首页数据 RPC
--
-- 两个函数：
--   get_tab2_home       — 首屏全量数据（解锁状态 + 分类卡内容），App 启动时调一次
--   get_category_words  — 按需拉单个分类全量词条，用户展开词表时调用

-- ─────────────────────────────────────────────────────────────
-- 1. get_tab2_home
--
-- 返回：
--   unlocked          bool        — 全局解锁（任一分类 ≥20 词 AND input_count ≥5）
--   input_count       int         — Tab1 累计输入次数（素材总数，含词卡）
--   categories        jsonb       — 每个有词分类一条（word_count ≥1 才出现）
--
-- categories[] 每条含：
--   scene_category    text
--   word_count        int         — 该分类下去重 active 词条数（解锁判定用）
--   unlocked          bool        — word_count >= 20
--   last_material_at  timestamptz — 最近一条素材的入账时间（hero 卡选取排序）
--   sub_scenes        jsonb[]     — 子场景列表，按出现次数降序
--     scene_detail      text
--     occurrence_count  int
--     quote             text      — 该子场景下最近一条 user_original（≥6 字；可空）
--     image_url         text      — 对应 source message 的 image_url（可空）
--   preview_words     text[]      — 最近入账 3 个 lemma（待解锁收起态预览）
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

  -- ── 解锁判定：任一分类 ≥20 词 AND 累计输入 ≥5 ──
  -- v_categories 已是 jsonb，直接从中取最大 word_count，避免重跑 CTE
  SELECT COALESCE(MAX((cat->>'word_count')::int), 0) INTO v_max_words
  FROM   jsonb_array_elements(COALESCE(v_categories, '[]'::jsonb)) AS cat;
  v_unlocked := (v_max_words >= 20) AND (v_input_count >= 5);

  v_result := jsonb_build_object(
    'unlocked',     v_unlocked,
    'input_count',  v_input_count,
    'categories',   COALESCE(v_categories, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_tab2_home(uuid) TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 2. get_category_words
-- 返回指定分类下的全量活跃词条，按入账时间倒序。
-- 按需调用（用户点击展开时），不在首屏一次性拉全量。
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_category_words(
  p_user_id       uuid,
  p_scene_category text
)
RETURNS TABLE(
  lemma          text,
  display_form   text,
  entry_kind     text,
  pos            text,
  granularity    text,
  source_type    text,
  sample_sentence text,
  image_url      text
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
    -- image_url 来自对应 message（lexicon_occurrences→materials→messages 两步 join）
    (
      SELECT msg.image_url
      FROM   materials m
      JOIN   messages  msg ON msg.id = m.source_message_id
      WHERE  m.id = lo.source_id
        AND  msg.image_url IS NOT NULL
      LIMIT  1
    )                        AS image_url
  FROM   lexicon_occurrences lo
  JOIN   lexicon_entries     le ON le.id = lo.entry_id
  WHERE  lo.user_id           = p_user_id
    AND  lo.scene_category    = p_scene_category
    AND  le.status             = 'active'
  ORDER  BY le.lemma, lo.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_category_words(uuid, text) TO service_role;
