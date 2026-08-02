-- E0 · 对话 session 与 turn 落库（E1 的数据地基）
-- 两张全新表：dialogue_sessions（一场练习）+ dialogue_turns（每一轮）。
-- 权威依据：对话页与成长层_需求设计_v1.md §5.3 + 接口契约_v1.md §4.1。
--
-- 安全范式照抄 20260728000000_create_lexicon_tables.sql：
--   Edge Function 用 service key 写入 user_id；表上开 RLS 作纵深防御；无 uid 直接 401。
--
-- 注意：音频不存，只存转写文本（隐私级别与 PRD §8 + 需求设计 §十·D 一致）。

-- ─────────────────────────────────────────────────────────────
-- 表 A：dialogue_sessions —— 一场练习的边界
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dialogue_sessions (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid        NOT NULL,
  scene_category text,                       -- Tab2 分类卡传入，中文枚举值
  scene_detail   text,                       -- 第一轮收窄后回填（接口契约 §2.2）
  turn_count     int         NOT NULL DEFAULT 0,
  ended_at       timestamptz,                -- NULL = 进行中
  end_reason     text        CHECK (end_reason IN ('user_exit','idle_timeout','error')),
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- 按用户查进行中 / 历史 session（resume + Tab2 刷新用）。
CREATE INDEX IF NOT EXISTS idx_dialogue_sessions_user_created
  ON dialogue_sessions (user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────
-- 表 B：dialogue_turns —— 每一轮的文字记录
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dialogue_turns (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  turn_id        uuid,                       -- 客户端生成的幂等键（仅 user turns 携带；接口契约 §4.1）
  session_id     uuid        NOT NULL REFERENCES dialogue_sessions (id) ON DELETE RESTRICT,
  user_id        uuid        NOT NULL,       -- 冗余，便于直接按用户查；RESTRICT 防止物理删 session 时遗漏
  role           text        NOT NULL CHECK (role IN ('user','assistant')),
  text           text,                       -- 转写文本（user）或模型回复（assistant）；不存音频
  asr_confidence numeric(4,3),              -- 0–1，系统 Speech 框架拿不到时为 NULL（接口契约 §2.2）
  duration_ms    int,                        -- 用户这一轮说了多久（需求设计 §7.4：先攒着，不做呈现）
  word_count     int,                        -- 词数（需求设计 §7.4：先攒着，不做呈现）
  created_at     timestamptz NOT NULL DEFAULT now(),
  -- 幂等键唯一约束：同一 turn_id 不得重复插入（NULL 之间不触发 UNIQUE，允许多个 assistant turns 无 turn_id）。
  CONSTRAINT uq_dialogue_turns_turn_id UNIQUE (turn_id)
);

-- 按 session 查全部轮次（resume 重放上下文用）。
CREATE INDEX IF NOT EXISTS idx_dialogue_turns_session_created
  ON dialogue_turns (session_id, created_at);

-- 按用户查（数据审计 / 隐私删除用）。
CREATE INDEX IF NOT EXISTS idx_dialogue_turns_user
  ON dialogue_turns (user_id);

-- ─────────────────────────────────────────────────────────────
-- RLS（纵深防御，与 lexicon 两张表一致）
-- ─────────────────────────────────────────────────────────────
ALTER TABLE dialogue_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dialogue_turns    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_dialogue_sessions"
  ON dialogue_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_dialogue_sessions"
  ON dialogue_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_select_own_dialogue_turns"
  ON dialogue_turns FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_dialogue_turns"
  ON dialogue_turns FOR INSERT
  WITH CHECK (auth.uid() = user_id);
