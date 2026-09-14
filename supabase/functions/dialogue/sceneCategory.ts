// Dialogue 写入防线（review finding #1）：统一客户端传入的 scene_category。
//
// 背景：dialogue_sessions.scene_category 无 CHECK 约束，handleStart 曾原样落库。
// 线上实测（2026-09-11）：迁移 20260910000000 应用之后仍有 3 条 'Work' 新写入，
// 与 374 条 'Work & Study' 分裂并存——一次性迁移挡不住持续漂移，防线必须在写入点。
import { normalizeSceneCategory } from "../_shared/constants.ts";

/**
 * 归一化客户端传入的 scene_category：
 *  - 合法英文 key → 原样通过
 *  - 中文 legacy 值 → 映射为英文 key（对旧 build 宽容）
 *  - 'Work' → 'Work & Study'（已知历史漂移值，与迁移 20260910000000 同款特例）
 *  - 其余无效值 → null，由调用方显式 400 拒收——拒绝优于落 Other，
 *    落 Other 会造成「Work 语义变 Other」的二次分裂且调用方无感知
 */
export function normalizeDialogueSceneCategory(
  raw: string | null | undefined,
): string | null {
  if (!raw) return null;
  if (raw === "Work") return "Work & Study";
  return normalizeSceneCategory(raw);
}
