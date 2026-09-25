import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseDayStart } from "./dayStart.ts";

Deno.test("parseDayStart: 合法 ISO8601 归一化为 UTC 字符串", () => {
  assertEquals(
    parseDayStart("2026-09-10T06:00:00Z"),
    "2026-09-10T06:00:00.000Z",
  );
});

Deno.test("parseDayStart: 带偏移的时刻换算为 UTC 瞬间", () => {
  // 客户端本地 00:00（+08:00）→ 对应的 UTC 时刻是前一天 16:00
  assertEquals(
    parseDayStart("2026-09-10T00:00:00+08:00"),
    "2026-09-09T16:00:00.000Z",
  );
});

Deno.test("parseDayStart: 缺失参数返回 null（RPC 走兜底）", () => {
  assertEquals(parseDayStart(null), null);
});

Deno.test("parseDayStart: 空串返回 null（RPC 走兜底）", () => {
  assertEquals(parseDayStart(""), null);
});

Deno.test("parseDayStart: 非法字符串返回 null，不报错", () => {
  assertEquals(parseDayStart("not-a-date"), null);
});
