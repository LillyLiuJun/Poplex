-- Slice 1 · 第 2 刀：get_tab2_home RPC 重构
-- 修复 §8.1 三个独立子查询不同源 bug；新增 featured / hero_photos / moment_count；
-- 修复 §8.2 quote 阈值中英混用；新旧字段并行（§9.5）。
-- 设计依据：docs/prd/Tab2_Hero卡_数据提取与展示_设计方案_v1.md §3、§6、§8、§9

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

  WITH
  -- ① 分类级：词数 / last_material_at / preview_words（现有逻辑不变）
  cat_words AS (
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

  -- ② 场景频次表：供 featured 排序键④ 和 sub_scenes 共用，避免多处各自 COUNT
  scene_counts AS (
    SELECT
      lo.scene_category,
      lo.scene_detail,
      COUNT(*)::int AS occurrence_count
    FROM   lexicon_occurrences lo
    JOIN   lexicon_entries     le ON le.id = lo.entry_id
    WHERE  lo.user_id         = p_user_id
      AND  lo.scene_category IS NOT NULL
      AND  lo.scene_detail   IS NOT NULL
      AND  le.status          = 'active'
    GROUP  BY lo.scene_category, lo.scene_detail
  ),

  -- ③ 分类 moment 总数（供顶部 +N 计数，§9.3）
  moment_counts AS (
    SELECT scene_category, COUNT(*)::int AS moment_count
    FROM   scene_counts
    GROUP  BY scene_category
  ),

  -- ④ 单图绑定预处理（§3.5）：分类恰好只有 1 张真实照片时，记下 material_id
  single_photo_mat AS (
    SELECT scene_category, (array_agg(material_id))[1] AS material_id
    FROM (
      SELECT DISTINCT lo.scene_category, m.id AS material_id
      FROM   lexicon_occurrences lo
      JOIN   materials m ON m.id = lo.source_id
      WHERE  lo.user_id         = p_user_id
        AND  lo.scene_category IS NOT NULL
        AND  m.raw_content->>'source_image_path' IS NOT NULL
    ) dist_photo
    GROUP  BY scene_category
    HAVING COUNT(material_id) = 1
  ),

  -- ⑤ featured moment（§8.1 同源修复 + §3.3 五层排序 + §3.5 单图绑定）
  -- DISTINCT ON 按 scene_category 分组，从同一条 material 取全部字段。
  featured AS (
    SELECT DISTINCT ON (lo.scene_category)
      lo.scene_category,
      lo.scene_detail,
      m.id                                  AS material_id,
      m.raw_content->>'user_original'       AS user_original,
      m.raw_content->>'target_expression'   AS target_expression,
      m.raw_content->>'native_meaning'      AS native_meaning,
      m.raw_content->>'source_image_path'   AS image_url,
      lo.input_lang,
      lo.source_direction,
      lo.source_granularity,
      m.created_at,
      sc.occurrence_count,
      le.spoken_count
    FROM   lexicon_occurrences lo
    JOIN   materials       m   ON m.id  = lo.source_id
    JOIN   lexicon_entries le  ON le.id = lo.entry_id AND le.status = 'active'
    JOIN   scene_counts    sc  ON sc.scene_category = lo.scene_category
                              AND sc.scene_detail   = lo.scene_detail
    LEFT JOIN single_photo_mat spm ON spm.scene_category = lo.scene_category
    WHERE  lo.user_id          = p_user_id
      AND  lo.scene_category  IS NOT NULL
      AND  lo.scene_detail    IS NOT NULL
      AND  lo.source_granularity <> 'word'   -- 查词不参选 featured（§3.2）
    ORDER  BY lo.scene_category,
      -- ⓪ 单图绑定（§3.5）：仅单图分类生效，多图分类此键恒为 1
      CASE WHEN spm.material_id IS NOT NULL AND m.id = spm.material_id THEN 0 ELSE 1 END,
      -- ① 方向 × 粒度（§3.3 第一层）
      CASE
        WHEN lo.source_direction='express'    AND lo.source_granularity='sentence' THEN 1
        WHEN lo.source_direction='express'    AND lo.source_granularity='passage'  THEN 2
        WHEN lo.source_direction='comprehend' AND lo.source_granularity='sentence' THEN 3
        WHEN lo.source_direction='comprehend' AND lo.source_granularity='passage'  THEN 4
        ELSE 9
      END,
      -- ② 意图明确度（§3.3 第二层）
      CASE
        WHEN m.raw_content->>'source_image_path' IS NOT NULL
         AND m.raw_content->>'user_original'     IS NOT NULL THEN 1
        WHEN m.raw_content->>'user_original'     IS NOT NULL THEN 2
        ELSE 3
      END,
      -- ③ 新鲜度（§3.3 第三层）
      CASE WHEN le.spoken_count = 0 THEN 0 ELSE 1 END,
      -- ④ 场景高频（§3.3 第四层）
      sc.occurrence_count DESC,
      -- ⑤ 兜底（§3.3 第五层）
      m.created_at DESC
  ),

  -- ⑥ 顶部拼图照片（§6.2）：每分类最多 5 张，featured 有图时强制置 slot 1（§3.6）
  hero_photos AS (
    SELECT
      ranked.scene_category,
      jsonb_agg(
        jsonb_build_object(
          'material_id', ranked.material_id,
          'image_url',   ranked.image_url,
          'is_featured', ranked.is_featured
        )
        ORDER BY ranked.slot ASC
      ) AS photos
    FROM (
      SELECT
        r.scene_category,
        r.material_id,
        r.image_url,
        COALESCE(r.material_id = f.material_id, false) AS is_featured,
        ROW_NUMBER() OVER (
          PARTITION BY r.scene_category
          ORDER BY COALESCE(r.material_id = f.material_id, false) DESC,
                   r.created_at DESC
        ) AS slot
      FROM (
        -- 每分类内按 material_id 去重，保留最新 created_at
        SELECT DISTINCT ON (lo.scene_category, m.id)
          lo.scene_category,
          m.id          AS material_id,
          m.raw_content->>'source_image_path' AS image_url,
          m.created_at
        FROM   lexicon_occurrences lo
        JOIN   materials m ON m.id = lo.source_id
        WHERE  lo.user_id         = p_user_id
          AND  lo.scene_category IS NOT NULL
          AND  m.raw_content->>'source_image_path' IS NOT NULL
        ORDER  BY lo.scene_category, m.id, m.created_at DESC
      ) r
      LEFT JOIN featured f ON f.scene_category = r.scene_category
    ) ranked
    WHERE ranked.slot <= 5
    GROUP BY ranked.scene_category
  ),

  -- ⑦ sub_scenes（旧结构，§9.5 并行保留；§8.2 quote 阈值已修正）
  sub_scenes AS (
    SELECT
      sc.scene_category,
      sc.scene_detail,
      sc.occurrence_count,
      -- §8.2 修正：native 字符数≥6，target 词数≥4，null（纯图片）不适用
      (
        SELECT m_raw.raw_content->>'user_original'
        FROM   lexicon_occurrences lo3
        JOIN   materials m_raw ON m_raw.id = lo3.source_id
        WHERE  lo3.user_id        = p_user_id
          AND  lo3.scene_category = sc.scene_category
          AND  lo3.scene_detail   = sc.scene_detail
          AND  (
            CASE lo3.input_lang
              WHEN 'native' THEN
                length(m_raw.raw_content->>'user_original') >= 6
              WHEN 'target' THEN
                array_length(
                  regexp_split_to_array(trim(m_raw.raw_content->>'user_original'), '\s+'), 1
                ) >= 4
              ELSE false
            END
          )
        ORDER  BY lo3.created_at DESC
        LIMIT  1
      )                                          AS quote,
      (
        SELECT m_te.raw_content->>'target_expression'
        FROM   lexicon_occurrences lo5
        JOIN   materials m_te ON m_te.id = lo5.source_id
        WHERE  lo5.user_id        = p_user_id
          AND  lo5.scene_category = sc.scene_category
          AND  lo5.scene_detail   = sc.scene_detail
          AND  m_te.raw_content->>'target_expression' IS NOT NULL
        ORDER  BY lo5.created_at DESC
        LIMIT  1
      )                                          AS target_expression,
      (
        SELECT m_img.raw_content->>'source_image_path'
        FROM   lexicon_occurrences lo4
        JOIN   materials m_img ON m_img.id = lo4.source_id
        WHERE  lo4.user_id        = p_user_id
          AND  lo4.scene_category = sc.scene_category
          AND  lo4.scene_detail   = sc.scene_detail
          AND  m_img.raw_content->>'source_image_path' IS NOT NULL
        ORDER  BY lo4.created_at DESC
        LIMIT  1
      )                                          AS image_url
    FROM scene_counts sc
  )

  SELECT jsonb_agg(
    jsonb_build_object(
      'scene_category',   cw.scene_category,
      'word_count',       cw.word_count,
      'unlocked',         cw.word_count >= 20,
      'last_material_at', cw.last_material_at,
      -- 新增字段（§9.1）
      'moment_count',     COALESCE(mc.moment_count, 0),
      'featured',         CASE WHEN f.scene_category IS NOT NULL THEN
                            jsonb_build_object(
                              'scene_detail',       f.scene_detail,
                              'occurrence_count',   f.occurrence_count,
                              'material_id',        f.material_id,
                              'user_original',      f.user_original,
                              'target_expression',  f.target_expression,
                              'native_meaning',     f.native_meaning,
                              'image_url',          f.image_url,
                              'input_lang',         f.input_lang,
                              'source_direction',   f.source_direction,
                              'source_granularity', f.source_granularity,
                              'created_at',         f.created_at,
                              'spoken_count',       f.spoken_count
                            )
                          ELSE NULL END,
      'hero_photos',      COALESCE(hp.photos, '[]'::jsonb),
      -- 旧字段（§9.5 并行保留，前端切换后删）
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
  FROM      cat_words     cw
  LEFT JOIN moment_counts mc  ON mc.scene_category = cw.scene_category
  LEFT JOIN featured      f   ON f.scene_category  = cw.scene_category
  LEFT JOIN hero_photos   hp  ON hp.scene_category = cw.scene_category;

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
