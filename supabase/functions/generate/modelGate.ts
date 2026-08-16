// 模型层安全门判定（STEP 0）：模型对图片/文本自行判定为 error 卡时，
// 函数在落库前转 422 content_blocked，与 Gemini API 层拦截同口径。
// 纯函数，供 index.ts 调用、modelGate_test.ts 单测。

/**
 * 模型返回的卡是否为「安全/无效拦截」error 卡。
 * 宽松判定：只要 card_type 为 "error" 即视为拦截（error_type unsafe/meaningless 均在列）。
 */
export function isModelErrorCard(parsed: unknown): boolean {
  if (typeof parsed !== "object" || parsed === null) return false;
  return (parsed as { card_type?: unknown }).card_type === "error";
}
