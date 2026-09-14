// 运行：deno test supabase/functions/dialogue/sceneCategory_test.ts
import { normalizeDialogueSceneCategory } from "./sceneCategory.ts";
import { assertEquals } from "jsr:@std/assert";

Deno.test("normalizeDialogueSceneCategory: valid English passthrough", () => {
  assertEquals(normalizeDialogueSceneCategory("Work & Study"), "Work & Study");
  assertEquals(normalizeDialogueSceneCategory("Other"), "Other");
  assertEquals(
    normalizeDialogueSceneCategory("Daily Routine"),
    "Daily Routine",
  );
});

Deno.test("normalizeDialogueSceneCategory: legacy Chinese mapped to English", () => {
  assertEquals(normalizeDialogueSceneCategory("工作与学业"), "Work & Study");
  assertEquals(normalizeDialogueSceneCategory("其他"), "Other");
  assertEquals(normalizeDialogueSceneCategory("家庭与人际"), "Home & Family");
});

Deno.test("normalizeDialogueSceneCategory: 'Work' drift repaired", () => {
  assertEquals(normalizeDialogueSceneCategory("Work"), "Work & Study");
});

Deno.test("normalizeDialogueSceneCategory: invalid values → null", () => {
  assertEquals(normalizeDialogueSceneCategory(null), null);
  assertEquals(normalizeDialogueSceneCategory(""), null);
  assertEquals(normalizeDialogueSceneCategory("   "), null);
  assertEquals(normalizeDialogueSceneCategory("Bananas"), null);
  assertEquals(normalizeDialogueSceneCategory("work"), null);
});
