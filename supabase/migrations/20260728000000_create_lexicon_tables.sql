-- Slice 1 · 词汇账本（lexicon）数据地基。
-- 两张全新表：lexicon_entries（去重后的词条 = 练习清单）+ lexicon_occurrences（每次使用的流水 = 证据）。
-- 权威依据：Agent内容组织与成长系统_PRD_v2.md §5.4。
--
-- 与 PRD §5.4 的两处刻意偏离（已回写 PRD）：
--   1. definition_native（不是 definition_zh）—— CLAUDE.md 硬约束：母语不许写死，用 native 不用 zh。
--   2. 不建 intent_lang —— 它 = input_lang 且在同一行，纯冗余；§5.4 权威 schema 本就未列。
--
-- 安全范式（沿用 messages/materials）：Edge Function 用 service key 写入 user_id；
-- 表上开 RLS 作纵深防御；无 uid 的读写在 Edge 层直接 401。
-- 这两张表是首次创建（此前线上不存在），故约束全部写在 CREATE TABLE 内，无需 ALTER 补列。

-- ─────────────────────────────────────────────────────────────
-- 表 A：lexicon_entries —— 去重后的词条（练习清单）
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lexicon_entries (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL,                          -- 词库按用户隔离
  lemma           text        NOT NULL,                          -- 规范化后的词形，去重依据
  sense_key       text        NOT NULL DEFAULT 'default',        -- 一词多义分义（§5.2.4）；MVP 预留不启用
  display_form    text,                                          -- 展示原形（"set up"；pattern 存句型模板本身）
  entry_kind      text        CHECK (entry_kind IN ('word','phrase','collocation','slang','idiom','pattern')),
  tier            text        CHECK (tier IN ('framework','domain')),  -- 分层（§5.2.1），MVP 由静态词表判
  origin          text        CHECK (origin IN ('captured','spoken')), -- 首次入账是被捕获还是被说出（§7.2）
  pos             text,                                          -- 词性（可能为空，见 §5.4.1）
  phonetic        text,                                          -- 音标（可能为空）
  definition_native text,                                        -- 母语释义（可能为空；弱化展示）
  total_count     int         NOT NULL DEFAULT 1,                -- "碰过"几次（缓存，真值以 occurrences 为准）
  correct_count   int         NOT NULL DEFAULT 0,                -- 用对的次数
  spoken_count    int         NOT NULL DEFAULT 0,                -- 说出来过几次 ← 练习状态来源；=0 即"还没说过"
  first_spoken_at timestamptz,                                   -- 第一次说出的时间（null=还没说过）；突破事件判定依据
  first_seen_at   timestamptz,                                   -- 第一次碰到
  last_used_at    timestamptz,                                   -- 最近一次用（排序用）
  status          text        NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active','archived','excluded')),  -- excluded=用户删除，防复活（§6.3.5）
  created_at      timestamptz NOT NULL DEFAULT now(),
  -- 去重键：同一用户下 lemma+义项唯一。sense_key 默认 'default'，一词多义启用时才产生多行。
  CONSTRAINT uq_lexicon_entries_user_lemma_sense UNIQUE (user_id, lemma, sense_key)
);

-- For review / All 镜头：按用户 + 分层 + 频率排。
CREATE INDEX IF NOT EXISTS idx_lexicon_entries_user_tier_count
  ON lexicon_entries (user_id, tier, total_count DESC);

-- Not yet / Spoken 镜头：按用户 + 练习状态查。
CREATE INDEX IF NOT EXISTS idx_lexicon_entries_user_spoken
  ON lexicon_entries (user_id, spoken_count);

-- ─────────────────────────────────────────────────────────────
-- 表 B：lexicon_occurrences —— 每次使用的流水（证据，只增不改）
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lexicon_occurrences (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id           uuid        NOT NULL REFERENCES lexicon_entries (id) ON DELETE RESTRICT,  -- 属于哪个词条；RESTRICT=有流水就禁物理删（证据不可抹，§5.3.1）
  user_id            uuid        NOT NULL,                       -- 冗余存一份便于直接按用户查
  source_type        text        CHECK (source_type IN ('material','dialogue')),  -- 来自素材还是对话
  source_id          uuid,                                       -- materials.id 或 messages.id（继承链、反查来源）
  scene_category     text,                                       -- 情境；对话来源按当前推断话题记（§5.2.2）
  used_correctly     boolean,                                    -- 这次用对了吗；null=不适用（§6.2.3 正确性判定）
  input_lang         text        CHECK (input_lang IN ('native','target','other')),  -- 角色，非语言码（§5.2.6）
  input_lang_code    text,                                       -- 具体语言码 ja/fr…；other 时必填，其余可空
  source_granularity text        CHECK (source_granularity IN ('word','sentence','passage')),  -- 继承素材粒度；意图强度信号
  source_direction   text        CHECK (source_direction IN ('comprehend','express')),         -- 继承素材方向；同上
  intent_text        text,                                       -- 归一化母语意图短语（§5.2.7）；comprehend 来源为 null
  is_known_gap       boolean     NOT NULL DEFAULT false,         -- 是否来自母语兜底暴露的"想说但不会"
  sample_sentence    text,                                       -- 这次用到时的原句（= 用户实际说出来那句）
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- Recent 镜头 / 时间线：按用户 + 时间倒序。
CREATE INDEX IF NOT EXISTS idx_lexicon_occurrences_user_created
  ON lexicon_occurrences (user_id, created_at DESC);

-- 反查某词条的全部流水（数频率、词详情页）。
CREATE INDEX IF NOT EXISTS idx_lexicon_occurrences_entry
  ON lexicon_occurrences (entry_id);

-- 意图频率与同义组聚合（§5.2.7）；intent_text 多为 null，用部分索引省空间。
CREATE INDEX IF NOT EXISTS idx_lexicon_occurrences_user_intent
  ON lexicon_occurrences (user_id, intent_text)
  WHERE intent_text IS NOT NULL;

-- ─────────────────────────────────────────────────────────────
-- RLS（纵深防御，与 materials/messages 一致）
-- 写入由 Edge Function 持 service key 完成（绕过 RLS）；策略保证任何直连客户端只能碰自己的行。
-- ─────────────────────────────────────────────────────────────
ALTER TABLE lexicon_entries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE lexicon_occurrences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_lexicon_entries"
  ON lexicon_entries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_lexicon_entries"
  ON lexicon_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_select_own_lexicon_occurrences"
  ON lexicon_occurrences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_lexicon_occurrences"
  ON lexicon_occurrences FOR INSERT
  WITH CHECK (auth.uid() = user_id);
