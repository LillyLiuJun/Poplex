-- Slice 1b · 补账 / 对账两个辅助 RPC（§5.3.1）。
--
-- 1. get_unaccounted_material_ids(p_user_id)
--    → 找出"有 material 但无 lexicon_occurrence"的素材 id 列表。
--    → 由 backfill-lexicon Edge Function 调用，得到待补账的 id 后再按 id 拉全行并重跑记账。
--
-- 2. reconcile_lexicon_counts(p_user_id)
--    → 按 occurrences 流水重算 total_count，修正缓存漂移（§5.3.1「对账作业」）。
--    → 从 SQL Editor 按需调用：SELECT * FROM reconcile_lexicon_counts('<uid>');
--    → p_user_id = NULL 时处理所有用户（管理员视角）。
--    → 返回"发现了哪些条目不一致 + 已修正"，没有不一致时返回空集。

-- ─────────────────────────────────────────────────────────────
-- 1. get_unaccounted_material_ids
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_unaccounted_material_ids(p_user_id uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  -- 找出没有任何 occurrence 记录的素材（source_type='material'）。
  -- 已软删除（deleted_at IS NOT NULL）的素材跳过——不补死账。
  SELECT m.id
  FROM   materials m
  WHERE  m.user_id    = p_user_id
    AND  m.deleted_at IS NULL
    AND  NOT EXISTS (
           SELECT 1
           FROM   lexicon_occurrences lo
           WHERE  lo.source_id    = m.id
             AND  lo.source_type  = 'material'
         );
$$;

GRANT EXECUTE ON FUNCTION get_unaccounted_material_ids(uuid) TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 2. reconcile_lexicon_counts
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION reconcile_lexicon_counts(p_user_id uuid DEFAULT NULL)
RETURNS TABLE(
  entry_id  uuid,
  lemma     text,
  old_total int,
  new_total int
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH
    -- 按流水数真实 total_count（所有 occurrence 不分来源）
    true_counts AS (
      SELECT lo.entry_id, COUNT(*)::int AS cnt
      FROM   lexicon_occurrences lo
      JOIN   lexicon_entries     le ON le.id = lo.entry_id
      WHERE  (p_user_id IS NULL OR le.user_id = p_user_id)
      GROUP  BY lo.entry_id
    ),
    -- 找出缓存值与真实值不一致的条目
    stale AS (
      SELECT le.id,
             le.lemma,
             le.total_count                  AS old_total,
             COALESCE(tc.cnt, 0)::int        AS new_total
      FROM   lexicon_entries le
      LEFT JOIN true_counts tc ON tc.entry_id = le.id
      WHERE  (p_user_id IS NULL OR le.user_id = p_user_id)
        AND  le.total_count IS DISTINCT FROM COALESCE(tc.cnt, 0)::int
    ),
    -- 一条 UPDATE 修正所有漂移
    fixed AS (
      UPDATE lexicon_entries le
      SET    total_count  = s.new_total,
             last_used_at = now()
      FROM   stale s
      WHERE  le.id = s.id
    )
  SELECT s.id, s.lemma, s.old_total, s.new_total
  FROM   stale s
  ORDER  BY s.lemma;
END;
$$;

-- 允许 service_role（Edge）调用；也允许 authenticated（用户在 SQL Editor 手动跑）
GRANT EXECUTE ON FUNCTION reconcile_lexicon_counts(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION reconcile_lexicon_counts(uuid) TO authenticated;
