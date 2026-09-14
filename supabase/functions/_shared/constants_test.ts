// 运行：deno test supabase/functions/_shared/constants_test.ts
import { normalizeSceneCategory } from "./constants.ts";
import { assertEquals } from "jsr:@std/assert";

Deno.test("normalizeSceneCategory: exact English passthrough", () => {
  assertEquals(normalizeSceneCategory("Food & Drink"), "Food & Drink");
  assertEquals(normalizeSceneCategory("Other"), "Other");
});

Deno.test("normalizeSceneCategory: case drift", () => {
  assertEquals(normalizeSceneCategory("food & drink"), "Food & Drink");
  assertEquals(normalizeSceneCategory("digital & tech"), "Digital & Tech");
});

Deno.test("normalizeSceneCategory: and ↔ &", () => {
  assertEquals(normalizeSceneCategory("Food and Drink"), "Food & Drink");
  assertEquals(
    normalizeSceneCategory("travel and commute"),
    "Travel & Commute",
  );
});

Deno.test("normalizeSceneCategory: trailing punctuation and whitespace", () => {
  assertEquals(normalizeSceneCategory("Food & Drink."), "Food & Drink");
  assertEquals(normalizeSceneCategory("  Food & Drink  "), "Food & Drink");
  assertEquals(normalizeSceneCategory("Work & Study！"), "Work & Study");
});

// Regression (review finding #4): punctuation FOLLOWED by whitespace used to
// defeat the punctuation regex (anchored to end-of-string) → null → "Other".
Deno.test("normalizeSceneCategory: punctuation followed by whitespace", () => {
  assertEquals(normalizeSceneCategory("Daily Routine.\n"), "Daily Routine");
  assertEquals(normalizeSceneCategory("Daily Routine. \n"), "Daily Routine");
  assertEquals(normalizeSceneCategory("Daily Routine.\n\n"), "Daily Routine");
  assertEquals(normalizeSceneCategory("Food & Drink. "), "Food & Drink");
  assertEquals(normalizeSceneCategory("Other.\n"), "Other");
  assertEquals(normalizeSceneCategory("Shopping,\r\n"), "Shopping");
  assertEquals(normalizeSceneCategory("Hobbies & Leisure！\n"), "Hobbies & Leisure");
  assertEquals(normalizeSceneCategory("Work & Study。 "), "Work & Study");
});

Deno.test("normalizeSceneCategory: legacy Chinese values", () => {
  assertEquals(normalizeSceneCategory("科技数码"), "Digital & Tech");
  assertEquals(normalizeSceneCategory("饮食"), "Food & Drink");
  assertEquals(normalizeSceneCategory("其他"), "Other");
  assertEquals(normalizeSceneCategory("家庭与人际。"), "Home & Family");
});

Deno.test("normalizeSceneCategory: unknown and empty → null", () => {
  assertEquals(normalizeSceneCategory("Bananas"), null);
  assertEquals(normalizeSceneCategory(""), null);
  assertEquals(normalizeSceneCategory(null), null);
});
