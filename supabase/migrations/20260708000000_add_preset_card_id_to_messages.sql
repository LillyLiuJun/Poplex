ALTER TABLE messages ADD COLUMN IF NOT EXISTS preset_card_id text;

-- 扩展 input_type 允许值，加入 'preset_card'（引导页预制场景卡路径）
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_input_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_input_type_check
  CHECK (input_type IN ('text', 'image', 'preset_card'));
