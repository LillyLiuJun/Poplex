-- 刀 4a · Tab2 话题卡 1.0：get_tab2_home 加 last_material_at / new_material_count（topics v6）
-- 依据：docs/prd/Tab2_话题卡_1.0上线方案与切片_v1.md §9 / §10（刀 4a = 只加数据，不动 UI）。
-- 基于 20260909010000_get_tab2_home_topics_v5 改造，四处改动：
--   ① 签名 get_tab2_home(uuid) → get_tab2_home(uuid, timestamptz DEFAULT NULL)：
--     p_day_start = 客户端算好的「本地今日 00:00 对应的 UTC 时刻」（§10.6 方案 B）。
--     Postgres 不允许 CREATE OR REPLACE 改参数列表 → 必须先 DROP；
--     DROP 会连函数 ACL 一起删掉，故本迁移末尾重新挂上 20260831115529 的收口。
--   ② 函数体开头日界兜底：p_day_start 缺失时退回服务端按 UTC 计算今天（见函数内注释）。
--   ③ 输出新增 last_material_at：值 = cat_words.sort_last_at（v5 已算好，只是从未放进 JSON）。
--   ④ 输出新增 new_material_count：今日新存的不同素材数，并入 ① cat_words 同趟
--     聚合（FILTER created_at >= v_day_start），不为此再开一趟 occurrence 全表扫描。
--   ORDER BY 不动：v5 的 word_count DESC, sort_last_at DESC 保留，排序在客户端做（刀 4b）。
--
-- 口径（对外的产品承诺，写死在此）：
--   new_material_count 【不筛】 source_granularity <> 'word'——查词也算「存了新东西」。
--   与 occurrence_count（排除 word）刻意不同（§10.2 表格），不要为了一致把它们统一。
--   按 source_id 去重：一张照片抽出 8 个词只算 1 条。

DROP FUNCTION IF EXISTS get_tab2_home(uuid);

CREATE OR REPLACE FUNCTION get_tab2_home(
  p_user_id   uuid,
  p_day_start timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day_start    timestamptz;
  -- v_user_tz：现在没有来源、故意保留为 NULL。这是为将来「服务端存用户时区」
  -- 方案（§10.6 方案 A）预留的迁移点——届时只改本函数开头那一行兜底（把
  -- COALESCE(v_user_tz, 'UTC') 换成真实来源），客户端零改动。
  v_user_tz      text := NULL;
  v_input_count  int;
  v_max_words    int;
  v_unlocked     bool;
  v_categories   jsonb;
  v_result       jsonb;
BEGIN
  -- 日界兜底（§10.6）：1.0 由客户端传 p_day_start = 本地今日 00:00 的 UTC 时刻；
  -- 缺失时退回服务端按 UTC 计算今天。
  -- 注：用三参 date_trunc(field, timestamptz, zone) 而非「AT TIME ZONE + 隐式转换」——
  -- 后者在 v_user_tz ≠ 会话时区（UTC）时会把本地零点墙钟误当 UTC 解读，差出时区偏移；
  -- 三参形式对任何时区都正确，今天（v_user_tz 恒 NULL → UTC）两者行为完全一致。
  v_day_start := COALESCE(
    p_day_start,
    date_trunc('day', now(), COALESCE(v_user_tz, 'UTC'))
  );

  SELECT COUNT(*)::int INTO v_input_count
  FROM   materials
  WHERE  user_id = p_user_id;

  WITH
  -- ① 分类级：词数 / not_spoken_count / sort_last_at / new_material_count
  --    not_spoken_count 必须 COUNT(DISTINCT entry_id) FILTER——
  --    驱动表是 occurrences，一个词条在多条 occurrence 里出现会被数多次，
  --    COUNT(*) FILTER 会虚高（同 scene_counts 曾中过的坑，见其注释）。
  --    【不加】source_type 过滤：词条数语义，对话里说过的词也属于该类别的词库。
  --    new_material_count（§10.2）口径：
  --    【不筛】source_granularity <> 'word'——查词也是「存了新东西」，
  --    与 occurrence_count 的「非 word」口径刻意不同，不要统一。
  --    按 source_id 去重：一张照片抽出 8 个词只算 1 条。
  --    并入本 CTE 同趟扫描（FILTER created_at >= v_day_start），
  --    不为此再开一趟 occurrence 全表扫描（实测再开一趟约 +1.3ms）。
  --    对话记账接线后，本节字段按 §9.7 整体重做，届时一并定夺 source_type。
  cat_words AS (
    SELECT
      lo.scene_category,
      COUNT(DISTINCT lo.entry_id)::int          AS word_count,
      COUNT(DISTINCT lo.entry_id) FILTER (WHERE le.spoken_count = 0)::int
                                                AS not_spoken_count,
      MAX(lo.created_at)                         AS sort_last_at,
      (COUNT(DISTINCT lo.source_id)
        FILTER (WHERE lo.created_at >= v_day_start))::int
                                                AS new_material_count
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
      'scene_category',     cw.scene_category,
      'word_count',         cw.word_count,
      'unlocked',           cw.word_count >= 20,
      'not_spoken_count',   cw.not_spoken_count,
      'last_talked_at',     lt.last_talked_at,
      'last_material_at',   cw.sort_last_at,
      'new_material_count', cw.new_material_count,
      'activity_count',     COALESCE(mc.moment_count, 0),
      'activities',         COALESCE(act.items, '[]'::jsonb)
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

-- 权限：DROP + CREATE 会重置 ACL（回到默认 PUBLIC EXECUTE），
-- 必须重新挂上 20260831115529 的收口——
-- 客户端只能走 Edge Function（service_role），不得直连 RPC 自选 p_user_id。
REVOKE EXECUTE ON FUNCTION public.get_tab2_home(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_tab2_home(uuid, timestamptz) TO service_role;
