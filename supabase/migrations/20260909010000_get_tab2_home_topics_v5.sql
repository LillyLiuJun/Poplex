-- 刀 2 · Tab2 话题卡 1.0：get_tab2_home RPC 重写（topics v5）
-- 依据：docs/prd/Tab2_话题卡_字段变更_实现规格_v2.html §2。
-- 基于 20260831061214_get_tab2_home_hero_v4 改造：
--   · 删除 featured / hero_photos CTE、它们的两个 LEFT JOIN、preview_words 子查询、
--     last_material_at 的 JSON 输出（sub_scenes 的 quote/target_expression/image_url 一并删除）；
--   · sub_scenes → activities：ranked_activities 排名 → top_activities 截断 rn <= 5
--     （独立 CTE，结构上保证截断先于 cover LATERAL）→ 再跑 cover LATERAL；
--   · 新增 not_spoken_count / last_talked_at（方案 B，读 dialogue_sessions.last_turn_at）。
--
-- 三处口径（对外的产品承诺，写死在此）：
--   ① occurrence_count = COUNT(DISTINCT source_id) FILTER (source_granularity <> 'word')：
--      一条素材 = 一次出现；granularity 为 NULL 的行（枚举容错产物）被静默排除；
--      comprehend 方向的英文输入也计为一次。
--   ② activities 新增 occurrence_count > 0 过滤：与 activity_count 口径一致
--      （旧的 sub_scenes 包含 0 计数的纯查词组，与 moment_count 不一致）。
--   ③ cover 加 deleted_at 过滤会降低照片覆盖率：某活动的图若全被软删，cover 为 null
--      退兜底图，预设图出现频率会高于原估计。行为正确。
--
-- 权限不变：CREATE OR REPLACE 保留既有 ACL
-- （20260831115529 已 REVOKE PUBLIC/anon/authenticated + GRANT service_role）。

CREATE OR REPLACE FUNCTION get_tab2_home(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
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

  WITH
  -- ① 分类级：词数 / not_spoken_count / sort_last_at（纯排序键，不输出 JSON）
  --    not_spoken_count 必须 COUNT(DISTINCT entry_id) FILTER——
  --    驱动表是 occurrences，一个词条在多条 occurrence 里出现会被数多次，
  --    COUNT(*) FILTER 会虚高（同 scene_counts 曾中过的坑，见其注释）。
  --    【不加】source_type 过滤：词条数语义，对话里说过的词也属于该类别的词库。
  cat_words AS (
    SELECT
      lo.scene_category,
      COUNT(DISTINCT lo.entry_id)::int          AS word_count,
      COUNT(DISTINCT lo.entry_id) FILTER (WHERE le.spoken_count = 0)::int
                                                AS not_spoken_count,
      MAX(lo.created_at)                         AS sort_last_at
    FROM   lexicon_occurrences lo
    JOIN   lexicon_entries     le ON le.id = lo.entry_id
    WHERE  lo.user_id           = p_user_id
      AND  lo.scene_category IS NOT NULL
      AND  le.status             = 'active'
    GROUP  BY lo.scene_category
  ),

  -- ② 场景频次表：occurrence_count = 该场景下「非 word 的不同素材」条数（= 卡面 seen N×）
  --    修正点：旧为 COUNT(*)（词条行数，虚高）→ 现为 COUNT(DISTINCT source_id) FILTER(非 word)
  --    source_type = 'material'：多态外键（material | dialogue）未来防线，对话记账接线后
  --    对话来源的行也会带 scene_category，不过滤会把「聊过做饭」也算成一次出现。
  scene_counts AS (
    SELECT
      lo.scene_category,
      lo.scene_detail,
      (COUNT(DISTINCT lo.source_id)
        FILTER (WHERE lo.source_granularity <> 'word'))::int AS occurrence_count,
      MAX(lo.created_at)
        FILTER (WHERE lo.source_granularity <> 'word')      AS activity_last_at
    FROM   lexicon_occurrences lo
    JOIN   lexicon_entries     le ON le.id = lo.entry_id
    WHERE  lo.user_id         = p_user_id
      AND  lo.scene_category IS NOT NULL
      AND  lo.scene_detail   IS NOT NULL
      AND  lo.source_type     = 'material'
      AND  le.status          = 'active'
    GROUP  BY lo.scene_category, lo.scene_detail
  ),

  -- ③ 分类 activity 总数：全量计算，不受下面 ranked_activities 的 rn <= 5 截断影响
  moment_counts AS (
    SELECT scene_category, COUNT(*)::int AS moment_count
    FROM   scene_counts
    WHERE  occurrence_count > 0
    GROUP  BY scene_category
  ),

  -- ④ 最后一次对话（方案 B，拍板于 2026-09-09）：口径 = 最后一次用户开口，
  --    读 dialogue_sessions.last_turn_at 分组 MAX，走 idx_dialogue_sessions_user_created。
  --    不扫 dialogue_turns（最大表，无热路径索引）。
  last_talked AS (
    SELECT scene_category, MAX(last_turn_at) AS last_talked_at
    FROM   dialogue_sessions
    WHERE  user_id = p_user_id
      AND  scene_category IS NOT NULL
    GROUP  BY scene_category
  ),

  -- ⑤ 活动排名：ROW_NUMBER 排名（occurrence 次数优先，活动新鲜度 tiebreak）。
  ranked_activities AS (
    SELECT sc.*,
           ROW_NUMBER() OVER (
             PARTITION BY sc.scene_category
             ORDER BY sc.occurrence_count DESC, sc.activity_last_at DESC
           ) AS rn
    FROM   scene_counts sc
    WHERE  sc.occurrence_count > 0
  ),

  -- ⑥ 截断：rn <= 5 必须先于 cover LATERAL 完成——谓词 (user_id, scene_category,
  --    scene_detail) 上没有索引，不截断的话每个活动都要扫该用户全部 occurrence 行。
  --    写成独立 CTE 做结构保证（LATERAL 的驱动表就是截断后的行集），
  --    不依赖 planner 把 WHERE 下推到 JOIN 之前。
  top_activities AS (
    SELECT * FROM ranked_activities WHERE rn <= 5   -- 卡面用 3，多给 2 作兜底余量
  ),

  -- ⑦ 活动清单：cover = 该活动最新一张带图素材；无图素材则 null（客户端走预设图）
  activities AS (
    SELECT r.scene_category,
           jsonb_agg(
             jsonb_build_object(
               'scene_detail',     r.scene_detail,
               'occurrence_count', r.occurrence_count,
               'cover',            cover.obj        -- null = 该活动无带图素材
             ) ORDER BY r.rn
           ) AS items
    FROM   top_activities r
    LEFT   JOIN LATERAL (
      SELECT jsonb_build_object(
               'material_id', m.id,
               'image_url',   m.raw_content->>'source_image_path'
             ) AS obj
      FROM   lexicon_occurrences lo
      JOIN   materials m ON m.id = lo.source_id
      WHERE  lo.user_id        = p_user_id
        AND  lo.scene_category = r.scene_category
        AND  lo.scene_detail   = r.scene_detail
        AND  lo.source_type    = 'material'          -- 多态外键，未来防线
        AND  m.deleted_at IS NULL                    -- 软删素材的流水被有意保留
        AND  m.raw_content->>'source_image_path' IS NOT NULL
      ORDER  BY m.created_at DESC
      LIMIT  1
    ) cover ON true
    GROUP  BY r.scene_category
  )

  SELECT jsonb_agg(
    jsonb_build_object(
      'scene_category',    cw.scene_category,
      'word_count',        cw.word_count,
      'unlocked',          cw.word_count >= 20,
      'not_spoken_count',  cw.not_spoken_count,
      'last_talked_at',    lt.last_talked_at,
      'activity_count',    COALESCE(mc.moment_count, 0),
      'activities',        COALESCE(act.items, '[]'::jsonb)
    )
    ORDER BY cw.word_count DESC, cw.sort_last_at DESC
  ) INTO v_categories
  FROM      cat_words     cw
  LEFT JOIN moment_counts mc  ON mc.scene_category = cw.scene_category
  LEFT JOIN last_talked   lt  ON lt.scene_category = cw.scene_category
  LEFT JOIN activities    act ON act.scene_category = cw.scene_category;

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
