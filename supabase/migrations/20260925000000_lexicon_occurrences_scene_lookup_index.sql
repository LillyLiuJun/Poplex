-- get_tab2_home_topics_v6（20260910000500）按 (user_id, scene_category,
-- scene_detail, source_type='material') 过滤 lexicon_occurrences 两处：
--   ① scene_counts CTE：聚合每个活动的 occurrence_count（GROUP BY 前的过滤）
--   ② activities CTE 里的 cover LATERAL：每条截断后的活动（rn<=5）取最新带图素材
-- 该迁移自己的注释承认这条谓词上没有索引，靠 rn<=5 先截断把伤害限在有限条数内，
-- 但截断前的 scene_counts 聚合、以及截断后仍要跑的每条 LATERAL，都还是对
-- lexicon_occurrences 做无索引过滤扫描。这里补上索引，不改任何查询逻辑。
CREATE INDEX IF NOT EXISTS idx_lexicon_occurrences_user_scene
  ON public.lexicon_occurrences (user_id, source_type, scene_category, scene_detail);
