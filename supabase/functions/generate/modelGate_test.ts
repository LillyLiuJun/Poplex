// 运行：deno test supabase/functions/generate/modelGate_test.ts
import { isModelErrorCard } from "./modelGate.ts";
import { assertEquals } from "jsr:@std/assert";

Deno.test("card_type: error → 拦截", () => {
  assertEquals(
    isModelErrorCard({
      card_type: "error",
      card_content: { error_type: "unsafe" },
    }),
    true,
  );
  assertEquals(
    isModelErrorCard({
      card_type: "error",
      card_content: { error_type: "meaningless" },
    }),
    true,
  );
});

Deno.test("正常卡型 → 不拦截", () => {
  assertEquals(isModelErrorCard({ card_type: "s4", card_content: {} }), false);
  assertEquals(
    isModelErrorCard({ card_type: "card", card_content: {} }),
    false,
  );
});

Deno.test("非对象 / 无 card_type → 不拦截", () => {
  assertEquals(isModelErrorCard(null), false);
  assertEquals(isModelErrorCard("error"), false);
  assertEquals(isModelErrorCard({}), false);
});
