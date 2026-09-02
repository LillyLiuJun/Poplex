// 生成次数限制 · 第 3 刀：本次请求的「当地日期上下文」。
//
// ★ 全部日期逻辑只允许出现在这一个文件里。将来若改为「按用户档案存的时区
//   计算」，只改这一处，调用方与测试都不动。
//
// 为什么不让客户端直接传日期：传日期意味着客户端可以在 D-1 / D / D+1 三个
// 桶里任选，轮着用能拿到三倍额度。传时区偏移并校验范围后，可选桶只剩两个
// （跨零点改设备时区能落到相邻桶，最多约两倍——已接受的取舍）。

export interface UsageContext {
  /** 分桶日期（YYYY-MM-DD），当地日期；偏移缺失/非法时回退到 UTC 当日。 */
  usageDate: string;
  /** 下一个当地 0 点的 ISO8601 时刻（含偏移后缀，如 2026-09-03T00:00:00+08:00）。 */
  resetsAt: string;
  /** 校验通过的偏移分钟数；回退时为 null。 */
  offsetMinutes: number | null;
}

/** 真实时区的 UTC 偏移范围（UTC-12 ~ UTC+14，分钟）。 */
export const MIN_OFFSET_MINUTES = -720;
export const MAX_OFFSET_MINUTES = 840;

function isValidOffset(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isInteger(value) &&
    value >= MIN_OFFSET_MINUTES &&
    value <= MAX_OFFSET_MINUTES
  );
}

/** 把 ±分钟数格式化成 ISO8601 偏移后缀，如 +480 → "+08:00"。 */
function offsetSuffix(offsetMinutes: number): string {
  const sign = offsetMinutes < 0 ? "-" : "+";
  const absolute = Math.abs(offsetMinutes);
  const hours = String(Math.floor(absolute / 60)).padStart(2, "0");
  const minutes = String(absolute % 60).padStart(2, "0");
  return `${sign}${hours}:${minutes}`;
}

/** date（YYYY-MM-DD 的 UTC 当日）加一天，处理月/年进位。 */
function nextUtcDate(date: string): string {
  const [year, month, day] = date.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day + 1)).toISOString().slice(0, 10);
}

/**
 * 解析本次请求的用量上下文。nowMs 必须是「请求时刻」的同一时钟源取值，
 * 调用方保证校验与落库共用同一个 usageDate 值（RPC 内不得用 now() 现算）。
 */
export function resolveUsageContext(
  rawOffset: unknown,
  nowMs: number,
): UsageContext {
  if (!isValidOffset(rawOffset)) {
    // 旧客户端 / 非法值：回退到 UTC 当日。
    const utcDate = new Date(nowMs).toISOString().slice(0, 10);
    return {
      usageDate: utcDate,
      resetsAt: `${nextUtcDate(utcDate)}T00:00:00Z`,
      offsetMinutes: null,
    };
  }

  const offsetMinutes = rawOffset;
  // UTC 时刻加偏移 = 当地墙钟时刻；toISOString 取出的日期部分即当地日期。
  const localDate = new Date(nowMs + offsetMinutes * 60_000)
    .toISOString()
    .slice(0, 10);
  // 下一个当地 0 点：当地日期的次日 00:00 用同一偏移表达，
  // 即 nextLocalDateT00:00:00±HH:MM，构造上就是那个时刻的 ISO8601。
  const resetsAt = `${nextUtcDate(localDate)}T00:00:00${
    offsetSuffix(offsetMinutes)
  }`;
  return { usageDate: localDate, resetsAt, offsetMinutes };
}
