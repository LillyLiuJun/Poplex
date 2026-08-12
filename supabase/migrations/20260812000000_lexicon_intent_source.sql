-- Slice 1 · 第 1 刀：新增 intent_source 列，区分用户明示意图（stated）与
-- AI 从纯图片推断的意图（inferred），隔离两者在聚合统计中的权重。
-- 设计依据：docs/prd/Tab2_Hero卡_数据提取与展示_设计方案_v1.md §10.4.3

-- 1. 新增列（可空，历史行用 backfill 回填）
ALTER TABLE lexicon_occurrences
  ADD COLUMN IF NOT EXISTS intent_source text
  CHECK (intent_source IN ('stated', 'inferred'));

-- 2. 存量 backfill
--    条件推导：历史上 intent_text 非空的行只来自 input_lang='native' 的 express 输入
--    （用户用母语说出意图 → 'stated'）。
--    纯图片素材历史上 intent=null，不存在应标 'inferred' 的存量行，无需处理。
UPDATE lexicon_occurrences
SET intent_source = 'stated'
WHERE intent_text IS NOT NULL
  AND input_lang = 'native';

-- 3. 重建部分索引：聚合查询默认只取 stated 意图（§10.4.4 的隔离要求）
DROP INDEX IF EXISTS idx_lexicon_occurrences_user_intent;
CREATE INDEX idx_lexicon_occurrences_user_intent
  ON lexicon_occurrences (user_id, intent_text)
  WHERE intent_text IS NOT NULL AND intent_source = 'stated';
