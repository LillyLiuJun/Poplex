-- 引导生成的素材与 Tab1 普通素材共用 materials 表，
-- 用 source 列区分来源，清理时只删 onboarding 行，普通素材不受影响。
ALTER TABLE materials
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'tab1'
    CHECK (source IN ('tab1', 'onboarding'));
