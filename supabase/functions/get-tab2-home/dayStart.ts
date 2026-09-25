// 刀 4a：day_start query 参数的解析（纯函数，供 index.ts 与单测共用）。
// 独立成文件是因为 index.ts 顶层会 Deno.serve——测试若 import index.ts
// 会真的拉起一个 HTTP 服务器，故可测逻辑一律放兄弟模块（仓库既有惯例）。

/// 解析客户端传来的 day_start：本地今日 00:00 对应的 UTC 时刻（ISO8601）。
/// 合法 → 归一化为 ISO8601 UTC 字符串透传给 RPC；
/// 缺失或不合法 → null，让 RPC 走服务端日界兜底（故意不报错）。
export function parseDayStart(raw: string | null): string | null {
  if (!raw) return null;
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
}
