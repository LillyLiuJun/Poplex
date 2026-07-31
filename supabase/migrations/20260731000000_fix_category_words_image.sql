-- Fix: get_category_words 图片路径取法
--
-- 原来通过 materials.source_message_id → messages.image_url JOIN 取图片路径，
-- 但 saveMaterial 从未写入 source_message_id，JOIN 永远返回 NULL。
--
-- 修法：直接读 materials.raw_content->>'source_image_path'，
-- 与 get-materials 保持一致（路径由 get-category-words Edge Function 签名后下发）。

DROP FUNCTION IF EXISTS get_category_words(uuid, text);

CREATE OR REPLACE FUNCTION get_category_words(
  p_user_id       uuid,
  p_scene_category text
)
RETURNS TABLE(
  lemma           text,
  display_form    text,
  entry_kind      text,
  pos             text,
  granularity     text,
  source_type     text,
  sample_sentence text,
  source_image_path text
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
    -- 直接取 materials.raw_content 里的 Storage 路径（Edge Function 负责签名）
    (
      SELECT m.raw_content->>'source_image_path'
      FROM   materials m
      WHERE  m.id = lo.source_id
        AND  m.raw_content->>'source_image_path' IS NOT NULL
        AND  m.raw_content->>'source_image_path' <> ''
      LIMIT  1
    )                        AS source_image_path
  FROM   lexicon_occurrences lo
  JOIN   lexicon_entries     le ON le.id = lo.entry_id
  WHERE  lo.user_id           = p_user_id
    AND  lo.scene_category    = p_scene_category
    AND  le.status             = 'active'
  ORDER  BY le.lemma, lo.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_category_words(uuid, text) TO service_role;
