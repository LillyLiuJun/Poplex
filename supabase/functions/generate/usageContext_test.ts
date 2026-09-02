// 第 3 刀：分桶日期/重置时刻纯函数测试。
// 全部日期逻辑只允许存在于 usageContext.ts，这里的用例就是那份逻辑的契约。

import { assertEquals } from "jsr:@std/assert";
import {
  MAX_OFFSET_MINUTES,
  MIN_OFFSET_MINUTES,
  resolveUsageContext,
} from "./usageContext.ts";

const ms = (iso: string) => Date.parse(iso);

Deno.test("resolveUsageContext buckets by the device-local date for a positive offset", () => {
  assertEquals(
    resolveUsageContext(480, ms("2026-08-21T12:00:00.000Z")),
    {
      usageDate: "2026-08-21",
      resetsAt: "2026-08-22T00:00:00+08:00",
      offsetMinutes: 480,
    },
  );
});

Deno.test("resolveUsageContext flips the bucket when local time crosses midnight", () => {
  // UTC 20:00 + 8 小时 = 当地次日 04:00 —— 桶必须按当地日期翻页。
  assertEquals(
    resolveUsageContext(480, ms("2026-08-21T20:00:00.000Z")),
    {
      usageDate: "2026-08-22",
      resetsAt: "2026-08-23T00:00:00+08:00",
      offsetMinutes: 480,
    },
  );
});

Deno.test("resolveUsageContext buckets a negative offset on the previous local date", () => {
  // UTC 02:00 - 5 小时 = 当地前一天 21:00。
  assertEquals(
    resolveUsageContext(-300, ms("2026-08-21T02:00:00.000Z")),
    {
      usageDate: "2026-08-20",
      resetsAt: "2026-08-21T00:00:00-05:00",
      offsetMinutes: -300,
    },
  );
});

Deno.test("resolveUsageContext falls back to the UTC day when the offset is missing", () => {
  assertEquals(
    resolveUsageContext(undefined, ms("2026-08-21T12:00:00.000Z")),
    {
      usageDate: "2026-08-21",
      resetsAt: "2026-08-22T00:00:00Z",
      offsetMinutes: null,
    },
  );
});

Deno.test("resolveUsageContext falls back for non-integer offsets", () => {
  for (const bad of ["480", 480.5, null, true, {}, [480]]) {
    assertEquals(
      resolveUsageContext(bad, ms("2026-08-21T12:00:00.000Z")).usageDate,
      "2026-08-21",
      `offset ${JSON.stringify(bad)} must fall back to the UTC day`,
    );
    assertEquals(
      resolveUsageContext(bad, ms("2026-08-21T12:00:00.000Z")).offsetMinutes,
      null,
    );
  }
});

Deno.test("resolveUsageContext rejects offsets outside the real timezone range", () => {
  for (const bad of [MIN_OFFSET_MINUTES - 1, MAX_OFFSET_MINUTES + 1, 1000, -1000]) {
    assertEquals(
      resolveUsageContext(bad, ms("2026-08-21T12:00:00.000Z")).offsetMinutes,
      null,
      `offset ${bad} must fall back`,
    );
    assertEquals(
      resolveUsageContext(bad, ms("2026-08-21T12:00:00.000Z")).resetsAt,
      "2026-08-22T00:00:00Z",
    );
  }
});

Deno.test("resolveUsageContext keeps UTC semantics for a zero offset", () => {
  assertEquals(
    resolveUsageContext(0, ms("2026-08-21T12:00:00.000Z")),
    {
      usageDate: "2026-08-21",
      resetsAt: "2026-08-22T00:00:00+00:00",
      offsetMinutes: 0,
    },
  );
});

Deno.test("resolveUsageContext rolls the resets_at month and year correctly", () => {
  assertEquals(
    resolveUsageContext(480, ms("2026-08-31T20:00:00.000Z")).resetsAt,
    "2026-09-02T00:00:00+08:00",
  );
  assertEquals(
    resolveUsageContext(480, ms("2026-12-31T20:00:00.000Z")).resetsAt,
    "2027-01-02T00:00:00+08:00",
  );
});

Deno.test("resolveUsageContext handles sub-hour offsets", () => {
  // +05:30（印度）。
  assertEquals(
    resolveUsageContext(330, ms("2026-08-21T20:00:00.000Z")),
    {
      usageDate: "2026-08-22",
      resetsAt: "2026-08-23T00:00:00+05:30",
      offsetMinutes: 330,
    },
  );
});

Deno.test("resolveUsageContext uses the same instant for the bucket and the user row", () => {
  // 第 2 刀的不变量：分桶与 user 行时间戳同瞬间取值。锁定时刻在 23:59:59.999，
  // 当地（+1）已是次日——桶必须与「当地当日」一致，而不是与落库时刻漂移。
  assertEquals(
    resolveUsageContext(60, ms("2026-08-21T23:59:59.999Z")),
    {
      usageDate: "2026-08-22",
      resetsAt: "2026-08-23T00:00:00+01:00",
      offsetMinutes: 60,
    },
  );
});
