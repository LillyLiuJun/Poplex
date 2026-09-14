// Tab2 scene category fixed list (MVP).
// AI picks from these options when classifying a scene material.
// Values are English keys — the single source of truth for new records.
// Legacy Chinese values in existing DB rows are handled by the backwards-
// compat mapping in SceneCategoryMap.swift and dialogue/CATEGORY_LABELS.
export const SCENE_CATEGORIES = [
  "Home & Family",
  "Work & Study",
  "Daily Routine",
  "Food & Drink",
  "Shopping",
  "Travel & Commute",
  "Health & Fitness",
  "Hobbies & Leisure",
  "Digital & Tech",
  "Weather & Nature",
  "Social & Feelings",
  "Other",
] as const;

export type SceneCategory = typeof SCENE_CATEGORIES[number];

// Legacy Chinese values → English keys (Plan A data normalisation, 2026-09-10).
// Classifiers were historically prompted with the Chinese list, and a model
// shown Chinese input may still echo a Chinese value even when the prompt now
// lists English keys.
const LEGACY_SCENE_CATEGORIES: Record<string, SceneCategory> = {
  "家庭与人际": "Home & Family",
  "工作与学业": "Work & Study",
  "日常起居": "Daily Routine",
  "饮食": "Food & Drink",
  "购物消费": "Shopping",
  "出行交通": "Travel & Commute",
  "运动健康": "Health & Fitness",
  "休闲娱乐": "Hobbies & Leisure",
  "科技数码": "Digital & Tech",
  "天气环境": "Weather & Nature",
  "情绪社交": "Social & Feelings",
  "其他": "Other",
};

// Normalise a classifier's raw category reply into a valid SceneCategory.
// Tolerant to: trailing punctuation, case drift ("food & drink"),
// "and" ↔ "&" ("Food and Drink"), extra whitespace, and legacy Chinese
// values. Returns null when the reply matches no known category.
export function normalizeSceneCategory(
  raw: string | null | undefined,
): SceneCategory | null {
  if (!raw) return null;
  // Order matters: whitespace must be collapsed/trimmed BEFORE stripping
  // trailing punctuation — otherwise "Daily Routine.\n" keeps its newline
  // after the period, the punctuation regex (anchored to end-of-string)
  // fails to match, and the whole reply normalises to null → "Other".
  const cleaned = raw
    .replace(/\s+/g, " ") // 1. collapse whitespace
    .trim() // 2. drop leading/trailing whitespace
    .replace(/[，。！？,.!?、；;：:]+$/, "") // 3. strip trailing punctuation
    .trim(); // 4. defensive trim (punctuation may have exposed whitespace)
  const legacy = LEGACY_SCENE_CATEGORIES[cleaned];
  if (legacy) return legacy;
  const folded = cleaned.toLowerCase().replace(/\band\b/g, "&");
  return SCENE_CATEGORIES.find((c) =>
      c.toLowerCase().replace(/\band\b/g, "&") === folded
    ) ?? null;
}
