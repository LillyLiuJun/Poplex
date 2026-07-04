-- 补建 messages 表迁移文件（该表此前在 Dashboard 手工创建，现纳入版本管理）。
-- 使用 IF NOT EXISTS / ADD COLUMN IF NOT EXISTS，对已有线上表安全无副作用。
--
-- messages 表职责：记录 Tab1 每次对话的消息流。
-- · user 行：用户输入（文本 / 图片）
-- · assistant 行：AI 返回的卡片（card_type + card_content）
-- conversation_id 预留字段，用于将多条消息归入同一次对话（当前未写入，后续实现）。

CREATE TABLE IF NOT EXISTS messages (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id   uuid,                          -- 预留：对话组 ID（当前未使用）
  user_id           uuid,                          -- 归属用户；切片后与 auth.users.id 关联
  role              text        NOT NULL CHECK (role IN ('user', 'assistant')),
  input_type        text        CHECK (input_type IN ('text', 'image')),
  user_content      text,                          -- user 行：原始输入文本；assistant 行为 null
  status            text        NOT NULL DEFAULT 'delivered',
  card_type         text,                          -- assistant 行：s1/s2/s3/s4/chat/error
  card_content      jsonb,                         -- assistant 行：AI 生成的结构化卡片内容
  extracted_concept text,                          -- assistant 行：提取的词汇/短语
  created_at        timestamp with time zone DEFAULT now()
);

-- 若线上表已存在但缺某些列，安全补齐（保证线上与迁移文件一致）
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_id uuid;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS user_id         uuid;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS input_type      text;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS user_content    text;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS card_type       text;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS card_content    jsonb;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS extracted_concept text;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS created_at      timestamp with time zone DEFAULT now();

-- 按用户 + 时间倒序查对话历史的常用查询加索引
CREATE INDEX IF NOT EXISTS idx_messages_user_created
  ON messages (user_id, created_at DESC);

-- 按对话分组查询加索引（conversation_id 启用后生效）
CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON messages (conversation_id, created_at ASC)
  WHERE conversation_id IS NOT NULL;

-- RLS（与 materials 保持一致的纵深防御）
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_messages"
  ON messages FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_messages"
  ON messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);
