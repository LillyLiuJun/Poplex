-- Slice 0 (Tab2 prep): create materials table and add deleted_at for soft delete.
-- Safe to run even if the table already exists.

CREATE TABLE IF NOT EXISTS materials (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid,
  source_message_id   uuid,
  material_type       text NOT NULL CHECK (material_type IN ('scene', 'vocabulary')),
  status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'categorized')),
  scene_category      text CHECK (scene_category IN (
                        '家庭与人际','工作与学业','日常起居','饮食','购物消费',
                        '出行交通','运动健康','休闲娱乐','科技数码','天气环境',
                        '情绪社交','其他'
                      )),
  raw_content         jsonb,
  related_material_ids uuid[],
  deleted_at          timestamp with time zone,
  created_at          timestamp with time zone DEFAULT now()
);

-- If the table already existed without deleted_at, add it safely.
ALTER TABLE materials ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

-- Index to make "fetch all non-deleted materials for a user" fast.
CREATE INDEX IF NOT EXISTS idx_materials_user_active
  ON materials (user_id, created_at DESC)
  WHERE deleted_at IS NULL;
