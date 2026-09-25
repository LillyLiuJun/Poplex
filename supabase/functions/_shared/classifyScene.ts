// 场景分类的共享实现：classifyScene（一次 Gemini 调用产出 scene_category + scene_detail）
// 和 fetchExistingSceneLabels（查询该用户已有标签供 classifyScene 复用而非重新起名）。
//
// generate/index.ts 的 Stage 2 和 scripts/backfill-scene-detail-relabel.ts 都从这里
// import，保证线上分类和回填重跑用的是同一份 prompt/校验逻辑，不会长出两份漂移。
// 模式同 backfill-lexicon/index.ts 复用 _shared/lexicon.ts（见其头部注释）。
// ⚠️ 之所以不能让脚本直接 import generate/index.ts：其顶层有 Deno.serve(...)，
// import 即启动 HTTP server，脚本会卡住不退出（或端口绑定失败）。

import { normalizeSceneCategory, SCENE_CATEGORIES } from "./constants.ts";
import { validateSubScene } from "../generate/subScene.ts";

function environmentValue(name: string): string {
  try {
    return Deno.env.get(name) ?? "";
  } catch {
    return "";
  }
}

const GEMINI_API_KEY = environmentValue("GEMINI_API_KEY");
// 与 generate/dialogue 各自本地的 GEMINI_URL 常量一致（仓库现有模式：每个 function 自带一份）。
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.7-flash:generateContent";
const SUPABASE_URL = environmentValue("SUPABASE_URL");
const SUPABASE_SVC_KEY = environmentValue("SUPABASE_SERVICE_ROLE_KEY");

// 该用户已有的 (scene_category, scene_detail) 标签，供 classifyScene 复用而非重新起名。
// 走 PostgREST 直查 lexicon_occurrences，不建 RPC；查询失败静默返回空字符串，不阻塞生成流程。
// 中英切换期兼容：存量行的 scene_category 可能是中文分类名（迁移放宽了 CHECK），
// 复用 constants.ts 的 normalizeSceneCategory 映射回英文 key；映射不中的老脏数据整组跳过，
// 绝不兜成 "Other"（会把认不出的东西塞进 Other，教模型「Other 什么都能装」）。
// 清库（上线前）后此兼容可简化，见 constants.ts 中 LEGACY_SCENE_CATEGORIES 的保质期注释。
export async function fetchExistingSceneLabels(userId: string): Promise<string> {
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) return "";
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/lexicon_occurrences?user_id=eq.${userId}&scene_category=not.is.null&scene_detail=not.is.null&select=scene_category,scene_detail&order=created_at.desc&limit=3000`,
      {
        headers: {
          "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
          "apikey": SUPABASE_SVC_KEY,
        },
      },
    );
    if (!res.ok) {
      console.error(
        "[fetchExistingSceneLabels] failed:",
        res.status,
        await res.text(),
      );
      return "";
    }
    const rows = await res.json() as
      { scene_category: string; scene_detail: string }[];
    const byCategory = new Map<string, Set<string>>();
    for (const row of rows) {
      if (!row.scene_category || !row.scene_detail) continue;
      // 中英切换期：中文分类老值经映射转英文 key，映射不中整组跳过（不兜 Other）。
      const category = normalizeSceneCategory(row.scene_category);
      if (!category) continue;
      // 老数据里有不满足 validateSubScene 规则的 scene_detail（中文/带斜杠/超长）；
      // 复用同一函数校验，不新写正则，避免长度/字符集两条规则跟 classifyScene 输出侧漂移。
      const clean = validateSubScene(row.scene_detail);
      if (!clean) continue;
      if (!byCategory.has(category)) {
        byCategory.set(category, new Set());
      }
      byCategory.get(category)!.add(clean);
    }
    return Array.from(byCategory.entries())
      .map(([category, details]) =>
        `${category}: ${Array.from(details).join(", ")}`
      )
      .join(" | ");
  } catch (e) {
    console.error("[fetchExistingSceneLabels] error:", e);
    return "";
  }
}

// Stage 2: 分类（scene_category）+ 子场景（scene_detail），一次 Gemini 调用。
// 返回 {category, subScene, failed}。failed=true：调用/解析失败，category 为兜底 "Other"；
// failed=false 且 subScene=null：模型正常返回但标签不合法。两者分开返回，调用方可分别计数。
// 已在 prompt 层缓解：把该用户已有的 scene_detail 喂回去要求复用。
// TODO 仍在：写入前与已有 scene_detail 比较归并（设计方案 §2.3.1）
//           才是硬保证，prompt 只是让模型倾向复用，不能保证。
export async function classifyScene(
  targetText: string,
  nativeText: string,
  userOriginal: string | undefined,
  existingLabels: string,
): Promise<{ category: string; subScene: string | null; failed: boolean }> {
  let raw = "";
  try {
    const prompt =
      `Classify this daily-life scene into ONE category. Reply in JSON ONLY.

Categories:
Home & Family, Work & Study, Daily Routine, Food & Drink, Shopping,
Travel & Commute, Health & Fitness, Hobbies & Leisure, Digital & Tech,
Weather & Nature, Social & Feelings, Other

Notes:
- Watching sport / film / show → Hobbies & Leisure
- Playing or training sport yourself → Health & Fitness
- Personal emotions or mood vented alone → Social & Feelings

Scene: "${targetText}"${
        userOriginal
          ? `\nWhat the user actually wrote: "${userOriginal}"\n← the user's own intent; trust this over Scene when they differ`
          : ""
      }
${existingLabels ? `\nActivities this user already has:\n${existingLabels}\n` : ""}
JSON: {"category":"<from list above>","sub_scene":"<recurring activity, never null>"}

sub_scene — the recurring activity this scene belongs to. It is a
GROUPING KEY: many separate occasions must share it, and the SAME
wording must come back next time the user does this again.
· If one of the user's existing activities listed above fits, reuse it
  VERBATIM. Invent a new one only when none fits.
· Strip qualifiers and specifics: "Cooking", not "Cooking dinner
  tonight"; "Fixing a device", not "Helping mum set up her new phone".
· It must say more than the category already does. Under Food & Drink,
  "Eating" is useless; "Cooking" / "Eating out" / "Grocery shopping"
  are useful.
· Target language only (English). Never echo the native language, even
  when Scene or Context is written in it. Max 24 characters.
· Aim for: Cooking / Eating out / Commuting / Driving / Running /
  Watching a show / Working / Studying / Shopping / Chores / Catching up`;

    const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          // 100 不够：thinkingBudget:0 并不能把思考压到零，刀1 加长 prompt（existing
          // labels 块 + sub_scene 说明变 6 行）后思考吃掉了文本预算，JSON 被截断
          // （2026-09-09 回填实测 67/96 次截断）。输出 JSON 本身只有二三十个 token，
          // 500 是给思考留的余量；Gemini 按实际生成计费，提高上限不增加成本。
          maxOutputTokens: 500,
          thinkingConfig: { thinkingBudget: 0 },
        },
        safetySettings: [
          {
            category: "HARM_CATEGORY_HARASSMENT",
            threshold: "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            category: "HARM_CATEGORY_HATE_SPEECH",
            threshold: "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            threshold: "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            category: "HARM_CATEGORY_DANGEROUS_CONTENT",
            threshold: "BLOCK_MEDIUM_AND_ABOVE",
          },
        ],
      }),
    });
    if (!res.ok) {
      throw new Error(
        `classifyScene failed with ${res.status}: ${await res.text()}`,
      );
    }
    const data = await res.json();
    // thinkingBudget:0 suppresses thought parts, but defensively skip any thought:true parts
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    raw = (parts.find((p: { thought?: boolean; text?: string }) =>
      !p.thought
    )?.text ?? "").trim();
    console.log(
      "[classifyScene] existingLabels tag count:",
      existingLabels ? existingLabels.split(/ \| |, /).length : 0,
    );
    console.log("[classifyScene] raw:", raw, "| parts count:", parts.length);
    const parsed = JSON.parse(raw);
    const normalizedCategory = normalizeSceneCategory(parsed.category);
    if (!normalizedCategory) {
      // 模型正常返回、JSON 也解析成功，但 category 是 normalizeSceneCategory 认不出的
      // 标签——与上面 catch 里的截断失败是两条不同病因，必须分开记日志才能分别计数。
      const finishReason = data?.candidates?.[0]?.finishReason ?? "none";
      console.warn(
        `[classifyScene] unmatched "${parsed.category}", fallback→Other` +
          ` | finishReason:${finishReason}`,
      );
    }
    const category = normalizedCategory ?? "Other";
    const subScene = validateSubScene(parsed.sub_scene);
    return { category, subScene, failed: false };
  } catch (e) {
    // raw 一并打进 error 行：截断的 JSON 是诊断的关键证据（e 本身只是 SyntaxError）。
    console.error("[classifyScene] failed:", e, "| raw:", raw);
    return { category: "Other", subScene: null, failed: true };
  }
}
