// subScene_test.ts — validateSubScene 单元测试
// 运行：deno test supabase/functions/generate/subScene_test.ts
//
// 覆盖：
//   · 合法英文标签（含空格/撇号/连字符）原样通过
//   · 前后空白 trim；纯空白/空串 → null
//   · 目标语言脚本外（中文、非 ASCII 字母）→ null
//   · 首字符非字母 → null
//   · 非字符串输入 → null
//   · 超过 24 字符截断；截断后 trimEnd 生效

import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { MAX_SUB_SCENE, validateSubScene } from "./subScene.ts";

// ── 合法输入 ─────────────────────────────────────────

Deno.test("合法英文标签原样通过", () => {
  assertEquals(validateSubScene("Cooking"), "Cooking");
  assertEquals(validateSubScene("Watching sports"), "Watching sports");
});

Deno.test("撇号/连字符属于放行字符集", () => {
  assertEquals(validateSubScene("Dad's cooking"), "Dad's cooking");
  assertEquals(validateSubScene("Coffee-to-go"), "Coffee-to-go");
});

Deno.test("前后空白被 trim", () => {
  assertEquals(validateSubScene("  Cooking  "), "Cooking");
  assertEquals(validateSubScene("\tCommuting\n"), "Commuting");
});

// ── 降级为 null ──────────────────────────────────────

Deno.test("空串/纯空白 → null", () => {
  assertStrictEquals(validateSubScene(""), null);
  assertStrictEquals(validateSubScene("   "), null);
});

Deno.test("中文 → null（目标语言脚本外）", () => {
  assertStrictEquals(validateSubScene("做饭"), null);
  assertStrictEquals(validateSubScene("Cooking 做饭"), null);
});

Deno.test("非 ASCII 英文字符 → null（café 的 é）", () => {
  assertStrictEquals(validateSubScene("café"), null);
});

Deno.test("首字符非字母 → null", () => {
  assertStrictEquals(validateSubScene("-to-go"), null);
  assertStrictEquals(validateSubScene("'s cooking"), null);
});

Deno.test("非字符串输入 → null", () => {
  assertStrictEquals(validateSubScene(42), null);
  assertStrictEquals(validateSubScene(null), null);
  assertStrictEquals(validateSubScene(undefined), null);
  assertStrictEquals(validateSubScene({ label: "Cooking" }), null);
});

// ── 截断 ─────────────────────────────────────────────

Deno.test("超过 24 字符截断到 24", () => {
  const r = validateSubScene("a".repeat(30));
  assertStrictEquals(r, "a".repeat(MAX_SUB_SCENE));
  assertStrictEquals(r?.length, 24);
});

Deno.test("截断后 trimEnd：第 24 位是空格时去掉", () => {
  // "a"*23 + " b" = 25 字符；slice(0,24) 尾部是空格，trimEnd 后只剩 23 个 a
  const r = validateSubScene("a".repeat(23) + " b");
  assertStrictEquals(r, "a".repeat(23));
});
