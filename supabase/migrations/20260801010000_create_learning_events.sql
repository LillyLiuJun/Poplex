-- E0 · learning_events 表（成长层事件流）
-- 这张表在 PRD_v2 里被引用了至少五次，但此前从未建过（需求设计 §〇-2 点名的"坑"）。
-- 权威依据：对话页与成长层_需求设计_v1.md §5.1。
--
-- 安全范式照抄 20260728000000_create_lexicon_tables.sql。
--
-- 四种事件谁写：
--   gap         — 母语兜底流程（用户想说但不会），必写。
--   error       — 每轮正确性判定发现语法/用法问题，由 E1b 记账写入。
--   breakthrough— 某词 spoken_count 由 0 变 1，由 record_lexicon_dialogue_units 内部自动写（北极星指标，100% 可靠）。
--   correction  — 同一词/同一 aspect 先错后对的翻转，由 E1b 记账写入。
--
-- entry_id 可空：语法类问题（gap/error）可能不属于某个具体词条（PRD §6.2.6 明确）。

CREATE TABLE IF NOT EXISTS learning_events (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL,
  session_id   uuid        REFERENCES dialogue_sessions (id) ON DELETE RESTRICT,  -- 哪一场对话；可空（将来若有非对话来源）
  entry_id     uuid        REFERENCES lexicon_entries   (id) ON DELETE RESTRICT,  -- 可空：语法类问题不挂词条
  event_type   text        CHECK (event_type IN ('gap','error','breakthrough','correction')),
  aspect       text        CHECK (aspect    IN ('vocab','grammar','collocation','pronunciation')),
  detail       jsonb,                        -- 用户说的那句 + 建议说法 + 错在哪（gap/error 用）；breakthrough 可为 null
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- 总结卡聚合：按用户 + session 拉本场事件。
CREATE INDEX IF NOT EXISTS idx_learning_events_user_session
  ON learning_events (user_id, session_id);

-- 成长层：按词条查进步 / 待提高历史。
CREATE INDEX IF NOT EXISTS idx_learning_events_entry
  ON learning_events (entry_id)
  WHERE entry_id IS NOT NULL;

-- breakthrough 查询（北极星指标统计）。
CREATE INDEX IF NOT EXISTS idx_learning_events_user_type
  ON learning_events (user_id, event_type);

-- ─────────────────────────────────────────────────────────────
-- RLS（纵深防御，与其他表一致）
-- ─────────────────────────────────────────────────────────────
ALTER TABLE learning_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_learning_events"
  ON learning_events FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_learning_events"
  ON learning_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);
