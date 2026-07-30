-- Slice A · 子场景字段 + get_lexicon_scenes 统计函数
--
-- 1. scene_detail  — 子场景自由标签，由 generate Stage 2 顺带输出；
--                   归并后写入，描述"这次在干什么"（粒度：完整活动，不带修饰词）
-- 2. get_lexicon_scenes — 按 scene_category 统计有效词条数，供解锁判定复用

ALTER TABLE lexicon_occurrences
  ADD COLUMN IF NOT EXISTS scene_detail text;

-- ─────────────────────────────────────────────────────────────
-- get_lexicon_scenes
-- 返回每个分类下的去重有效词条数（status='active'）。
-- 解锁判定：entry_count >= 20 即该分类解锁。
-- Tab2 首屏 get_tab2_home 内部也会调用等价逻辑，这里单独保留以便独立测试。
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_lexicon_scenes(p_user_id uuid)
RETURNS TABLE(scene_category text, entry_count bigint)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT
    lo.scene_category,
    COUNT(DISTINCT lo.entry_id) AS entry_count
  FROM   lexicon_occurrences lo
  JOIN   lexicon_entries     le ON le.id = lo.entry_id
  WHERE  lo.user_id           = p_user_id
    AND  lo.scene_category IS NOT NULL
    AND  le.status             = 'active'
  GROUP  BY lo.scene_category
  ORDER  BY entry_count DESC;
$$;

GRANT EXECUTE ON FUNCTION get_lexicon_scenes(uuid) TO service_role;
