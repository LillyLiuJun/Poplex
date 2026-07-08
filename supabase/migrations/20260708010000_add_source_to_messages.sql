ALTER TABLE messages ADD COLUMN IF NOT EXISTS source text
  CHECK (source IN ('onboarding', 'tab1'));
