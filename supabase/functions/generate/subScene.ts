// subScene.ts — classifyScene 的子场景标签校验
// 把 Gemini 返回的 sub_scene 提取为合法的"复现活动"标签：
// 只接受目标语言脚本（MVP = English-as-target）、最多 24 字符，
// 一切不合格输入优雅降级为 null（材料照常落库，只是不带 scene_detail）。
// 字符集与客户端 validatedTargetSceneDetail 保持一致；换目标语言时两边都改。

/** 与目标语言绑定；MVP = English-as-target。换目标语言时只改这一行。 */
export const TARGET_SCRIPT = /^[A-Za-z][A-Za-z\s'\-]*$/;
export const MAX_SUB_SCENE = 24;

export function validateSubScene(raw: unknown): string | null {
  const rawSub = typeof raw === "string" ? raw.trim() : "";
  return rawSub && TARGET_SCRIPT.test(rawSub)
    ? rawSub.slice(0, MAX_SUB_SCENE).trimEnd()
    : null;
}
