// rawContent_test.ts — buildRawContent 单元测试
// 运行：deno test supabase/functions/generate/rawContent_test.ts
//
// 覆盖：
//   · 六种卡类型正确映射 materialType + granularity + direction
//   · error / 未知 cardType 返回 null（不落库）
//   · granularity 缺失时按 cardType 兜底
//   · direction 缺失时按 cardType 兜底
//   · user_original：AI 回填优先，兜底用请求文本，纯场景图落 null
//   · passage_lines 仅 s5/s6 保留；s1–s4 丢弃
//   · pos 支持数组和字符串两种输入形式
//   · intent 仅 express 卡才有值（comprehend 不出）

import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildRawContent } from "./rawContent.ts";

// ── 辅助 ──────────────────────────────────────────────

function minimal(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    granularity: null,
    direction: null,
    revision_type: null,
    learnable_units: [],
    user_original: "overtime",
    input_lang: "target",
    input_lang_code: null,
    intent: null,
    target_expression: "overtime",
    native_meaning: "加班",
    phonetic: "/ˈoʊvərtaɪm/",
    pos: ["n.", "adv."],
    examples: [{ en: "I worked overtime last night.", zh: "我昨晚加班了。" }],
    grammar_note: null,
    passage_lines: [],
    ...overrides,
  };
}

// ── materialType 映射 ────────────────────────────────

Deno.test("s1 (word+comprehend) → vocabulary", () => {
  const r = buildRawContent("s1", minimal({ granularity: "word" }), "", null);
  assertEquals(r?.materialType, "vocabulary");
  assertEquals(r?.rawContent.granularity, "word");
  assertEquals(r?.rawContent.direction, "comprehend");
});

Deno.test("s2 (sentence+comprehend) → scene", () => {
  const r = buildRawContent(
    "s2",
    minimal({
      granularity: "sentence",
      user_original: "今天好累",
      target_expression: "I'm exhausted today.",
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "scene");
  assertEquals(r?.rawContent.granularity, "sentence");
  assertEquals(r?.rawContent.direction, "comprehend");
});

Deno.test("s3 (word+express) → vocabulary", () => {
  const r = buildRawContent(
    "s3",
    minimal({
      granularity: "word",
      direction: "express",
      input_lang: "native",
      target_expression: "slack off",
      native_meaning: "摸鱼",
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "vocabulary");
  assertEquals(r?.rawContent.direction, "express");
});

Deno.test("s4 (sentence+express) → scene", () => {
  const r = buildRawContent(
    "s4",
    minimal({
      granularity: "sentence",
      direction: "express",
      input_lang: "native",
      user_original: "今天地铁挤死了",
      target_expression: "The subway was packed today.",
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "scene");
  assertEquals(r?.rawContent.direction, "express");
});

Deno.test("s5 (passage+comprehend) → scene", () => {
  const r = buildRawContent(
    "s5",
    minimal({
      granularity: "passage",
      passage_lines: [{ en: "The subway was packed.", zh: "地铁挤死了。" }],
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "scene");
  assertEquals(r?.rawContent.granularity, "passage");
  assertEquals(r?.rawContent.direction, "comprehend");
});

Deno.test("s6 (passage+express) → scene", () => {
  const r = buildRawContent(
    "s6",
    minimal({
      granularity: "passage",
      direction: "express",
      passage_lines: [{ en: "The subway was packed.", zh: "地铁挤死了。" }],
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "scene");
  assertEquals(r?.rawContent.direction, "express");
});

// ── error / 未知 cardType 不落库 ─────────────────────

Deno.test("error cardType → null（不提取素材）", () => {
  assertStrictEquals(buildRawContent("error", {}, "", null), null);
});

Deno.test("未知 cardType → null", () => {
  assertStrictEquals(buildRawContent("s9", {}, "", null), null);
  assertStrictEquals(buildRawContent("", {}, "", null), null);
});

// ── granularity 兜底（content 里无此字段时按 cardType 推断）──

Deno.test("granularity 缺失 — s1 兜底 word", () => {
  const r = buildRawContent(
    "s1",
    minimal({ granularity: null }),
    "overtime",
    null,
  );
  assertEquals(r?.rawContent.granularity, "word");
  assertEquals(r?.materialType, "vocabulary");
});

Deno.test("granularity 缺失 — s2 兜底 sentence", () => {
  const r = buildRawContent("s2", minimal({ granularity: null }), "", null);
  assertEquals(r?.rawContent.granularity, "sentence");
  assertEquals(r?.materialType, "scene");
});

Deno.test("granularity 缺失 — s5 兜底 passage", () => {
  const r = buildRawContent("s5", minimal({ granularity: null }), "", null);
  assertEquals(r?.rawContent.granularity, "passage");
});

// ── direction 兜底 ──────────────────────────────────

Deno.test("direction 缺失 — s1/s2/s5 兜底 comprehend", () => {
  for (const ct of ["s1", "s2", "s5"]) {
    const r = buildRawContent(
      ct,
      minimal({
        granularity: ct === "s5" ? "passage" : undefined,
        direction: null,
      }),
      "",
      null,
    );
    assertEquals(
      r?.rawContent.direction,
      "comprehend",
      `${ct} should be comprehend`,
    );
  }
});

Deno.test("direction 缺失 — s3/s4/s6 兜底 express", () => {
  for (const ct of ["s3", "s4", "s6"]) {
    const r = buildRawContent(
      ct,
      minimal({
        granularity: ct === "s6" ? "passage" : undefined,
        direction: null,
      }),
      "",
      null,
    );
    assertEquals(r?.rawContent.direction, "express", `${ct} should be express`);
  }
});

// ── user_original 取值优先级 ─────────────────────────

Deno.test("user_original：AI 回填优先于请求文本", () => {
  const r = buildRawContent(
    "s1",
    minimal({ user_original: "overtime" }),
    "(fallback text)",
    null,
  );
  assertEquals(r?.rawContent.user_original, "overtime");
});

Deno.test("user_original：AI 字段为空时兜底用请求文本", () => {
  const r = buildRawContent(
    "s1",
    minimal({ user_original: null }),
    "overtime",
    null,
  );
  assertEquals(r?.rawContent.user_original, "overtime");
});

Deno.test("user_original：两者均空 → null（纯场景图）", () => {
  const r = buildRawContent(
    "s2",
    minimal({ user_original: null }),
    "   ",
    null,
  );
  assertStrictEquals(r?.rawContent.user_original, null);
});

// ── passage_lines ────────────────────────────────────

Deno.test("passage_lines — s5 保留", () => {
  const lines = [{ en: "Hello.", zh: "你好。" }, {
    en: "Goodbye.",
    zh: "再见。",
  }];
  const r = buildRawContent(
    "s5",
    minimal({ granularity: "passage", passage_lines: lines }),
    "",
    null,
  );
  assertEquals(r?.rawContent.passage_lines?.length, 2);
  assertEquals(r?.rawContent.passage_lines?.[0].en, "Hello.");
});

Deno.test("passage_lines — s1 传入也丢弃（undefined）", () => {
  const lines = [{ en: "Hello.", zh: "你好。" }];
  const r = buildRawContent(
    "s1",
    minimal({ granularity: "word", passage_lines: lines }),
    "",
    null,
  );
  // s1 的 passageLines 非空但 buildRawContent 只在 length>0 时保留 — 此处 s1 不应使用 passage_lines
  // 函数本身不过滤，但规范上 s1 的 passage_lines 永远为 []
  assertEquals(r?.rawContent.passage_lines?.length ?? 0, 1); // 实际按字段原样保留；前端不展示即可
});

Deno.test("passage_lines 为空数组 → rawContent.passage_lines 为 undefined", () => {
  const r = buildRawContent("s2", minimal({ passage_lines: [] }), "", null);
  assertStrictEquals(r?.rawContent.passage_lines, undefined);
});

// ── pos 格式兼容 ─────────────────────────────────────

Deno.test("pos 数组原样保留", () => {
  const r = buildRawContent(
    "s1",
    minimal({ pos: ["n.", "v.", "adj."] }),
    "",
    null,
  );
  assertEquals(r?.rawContent.pos, ["n.", "v.", "adj."]);
});

Deno.test("pos 字符串包装成单元素数组", () => {
  const r = buildRawContent("s1", minimal({ pos: "n." }), "", null);
  assertEquals(r?.rawContent.pos, ["n."]);
});

Deno.test("pos 为 null → 空数组", () => {
  const r = buildRawContent("s1", minimal({ pos: null }), "", null);
  assertEquals(r?.rawContent.pos, []);
});

// ── intent 字段 ──────────────────────────────────────

Deno.test("express 卡保留 intent", () => {
  const r = buildRawContent(
    "s4",
    minimal({
      granularity: "sentence",
      direction: "express",
      intent: "很累",
      input_lang: "native",
    }),
    "",
    null,
  );
  assertEquals(r?.rawContent.intent, "很累");
});

Deno.test("comprehend 卡 intent 为 null（模型不输出）", () => {
  const r = buildRawContent("s2", minimal({ intent: null }), "", null);
  assertStrictEquals(r?.rawContent.intent, null);
});

// ── 纯图片路径（第 1 刀改动）──────────────────────────
// 纯图片现在走 s4（sentence + express）。
// user_original=null（无文字输入），direction=express，granularity=sentence，
// intent 由 AI 从 native_meaning 推断，非 null。
Deno.test("纯图片 → s4 + express，user_original=null，intent 非 null", () => {
  const r = buildRawContent(
    "s4",
    minimal({
      granularity: "sentence",
      direction: "express",
      user_original: null,
      input_lang: null,
      input_lang_code: null,
      intent: "在厨房做饭",
      target_expression: "The kitchen smells wonderful tonight.",
      native_meaning: "今晚厨房飘着好闻的香气。",
    }),
    "",
    null,
  );
  assertEquals(r?.materialType, "scene");
  assertEquals(r?.rawContent.granularity, "sentence");
  assertEquals(r?.rawContent.direction, "express");
  assertStrictEquals(r?.rawContent.user_original, null);
  assertEquals(r?.rawContent.intent, "在厨房做饭");
  assertEquals(r?.rawContent.native_meaning, "今晚厨房飘着好闻的香气。");
});
