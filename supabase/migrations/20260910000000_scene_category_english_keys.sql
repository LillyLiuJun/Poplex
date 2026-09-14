-- Migration: scene_category English keys (Method A — backwards-compatible)
--
-- Strategy: DROP the old Chinese-only CHECK constraint on both tables and
-- ADD a new constraint that accepts BOTH the legacy Chinese values and the
-- new English values. New records written by the updated Edge Function will
-- use English keys.
--
-- Plan A data normalisation (PM-approved 2026-09-10): legacy Chinese values
-- in existing rows are converted in-place to their English keys, so one
-- logical category is no longer split across two raw values (Tab2 grouping,
-- counts, milestones, dialogue seed all key off the raw value). Zero data
-- loss — the conversion is a pure value swap. The dual-track CHECK and the
-- backwards-compat maps (SceneCategoryMap.swift, dialogue/CATEGORY_LABELS)
-- are thereby downgraded to pure defence against stragglers.
--
-- dialogue_sessions additionally carries a pre-English-keys drift value
-- 'Work' (written by an earlier iteration before 'Work & Study' existed);
-- it is repaired in the same pass since resumed sessions key off this value.
--
-- Statement order matters: the OLD constraint must be dropped BEFORE the
-- UPDATEs run — the old Chinese-only CHECK would reject the converted
-- English values (verified live: ERROR 23514 on first attempt).

-- ── 1. Drop old Chinese-only CHECKs ──────────────────────────────────────────

ALTER TABLE materials
  DROP CONSTRAINT IF EXISTS materials_scene_category_check;

ALTER TABLE lexicon_occurrences
  DROP CONSTRAINT IF EXISTS lexicon_occurrences_scene_category_check;

-- ── 2. Normalise legacy values → English keys ────────────────────────────────

UPDATE materials
  SET scene_category = CASE scene_category
    WHEN '家庭与人际' THEN 'Home & Family'
    WHEN '工作与学业' THEN 'Work & Study'
    WHEN '日常起居'   THEN 'Daily Routine'
    WHEN '饮食'       THEN 'Food & Drink'
    WHEN '购物消费'   THEN 'Shopping'
    WHEN '出行交通'   THEN 'Travel & Commute'
    WHEN '运动健康'   THEN 'Health & Fitness'
    WHEN '休闲娱乐'   THEN 'Hobbies & Leisure'
    WHEN '科技数码'   THEN 'Digital & Tech'
    WHEN '天气环境'   THEN 'Weather & Nature'
    WHEN '情绪社交'   THEN 'Social & Feelings'
    WHEN '其他'       THEN 'Other'
    ELSE scene_category
  END
  WHERE scene_category IN (
    '家庭与人际', '工作与学业', '日常起居', '饮食', '购物消费',
    '出行交通', '运动健康', '休闲娱乐', '科技数码', '天气环境',
    '情绪社交', '其他'
  );

UPDATE lexicon_occurrences
  SET scene_category = CASE scene_category
    WHEN '家庭与人际' THEN 'Home & Family'
    WHEN '工作与学业' THEN 'Work & Study'
    WHEN '日常起居'   THEN 'Daily Routine'
    WHEN '饮食'       THEN 'Food & Drink'
    WHEN '购物消费'   THEN 'Shopping'
    WHEN '出行交通'   THEN 'Travel & Commute'
    WHEN '运动健康'   THEN 'Health & Fitness'
    WHEN '休闲娱乐'   THEN 'Hobbies & Leisure'
    WHEN '科技数码'   THEN 'Digital & Tech'
    WHEN '天气环境'   THEN 'Weather & Nature'
    WHEN '情绪社交'   THEN 'Social & Feelings'
    WHEN '其他'       THEN 'Other'
    ELSE scene_category
  END
  WHERE scene_category IN (
    '家庭与人际', '工作与学业', '日常起居', '饮食', '购物消费',
    '出行交通', '运动健康', '休闲娱乐', '科技数码', '天气环境',
    '情绪社交', '其他'
  );

UPDATE dialogue_sessions
  SET scene_category = CASE scene_category
    WHEN '其他' THEN 'Other'
    WHEN 'Work' THEN 'Work & Study'
    ELSE scene_category
  END
  WHERE scene_category IN ('其他', 'Work');

-- ── 3. Add dual-track CHECKs (accept legacy + English) ───────────────────────

ALTER TABLE materials
  ADD CONSTRAINT materials_scene_category_check CHECK (scene_category IN (
    -- Legacy Chinese values (defence: no new rows should use these after Plan A)
    '家庭与人际', '工作与学业', '日常起居', '饮食', '购物消费',
    '出行交通', '运动健康', '休闲娱乐', '科技数码', '天气环境',
    '情绪社交', '其他',
    -- New English values (all new records will use these)
    'Home & Family', 'Work & Study', 'Daily Routine', 'Food & Drink',
    'Shopping', 'Travel & Commute', 'Health & Fitness', 'Hobbies & Leisure',
    'Digital & Tech', 'Weather & Nature', 'Social & Feelings', 'Other'
  ));

ALTER TABLE lexicon_occurrences
  ADD CONSTRAINT lexicon_occurrences_scene_category_check CHECK (scene_category IN (
    -- Legacy Chinese values
    '家庭与人际', '工作与学业', '日常起居', '饮食', '购物消费',
    '出行交通', '运动健康', '休闲娱乐', '科技数码', '天气环境',
    '情绪社交', '其他',
    -- New English values
    'Home & Family', 'Work & Study', 'Daily Routine', 'Food & Drink',
    'Shopping', 'Travel & Commute', 'Health & Fitness', 'Hobbies & Leisure',
    'Digital & Tech', 'Weather & Nature', 'Social & Feelings', 'Other'
  ));
