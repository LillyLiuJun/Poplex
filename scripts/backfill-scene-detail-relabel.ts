// 一次性脚本 · 用新版 classifyScene 重跑某用户的历史 scene 素材，回填 lexicon_occurrences.scene_detail
//
// 背景：Tab2 话题卡刀1（标签一致性）给 classifyScene 加了"复用该用户已有 scene_detail
// 标签"的机制，但线上老数据是在这机制之前生成的，标签本来就碎片化，且部分老标签本身
// 不满足 validateSubScene 的规则（中文/带斜杠/超长）。这个脚本用同一套（已加校验的）
// classifyScene + fetchExistingSceneLabels 把老素材重新分类一遍，让标签收敛。
//
// 运行前准备（PM 手工完成）：
//   1. 把 lexicon_occurrences.scene_detail 备份到 _scene_detail_backup_20260909
//      （结构：id / source_id / scene_category / scene_detail）；
//   2. 清空 lexicon_occurrences.scene_detail —— 跑的时候线上是空标签起步，按
//      created_at 正序逐条重分类，模拟真实用户"从无到有"的标签积累过程。
//   old= 一栏从备份表读，用于人工核对，不依赖 lexicon_occurrences 的当前值。
//
// 类别漂移防护：新 prompt 的输入变了，classifyScene 返回的 category 也可能跟着变。
// 本脚本把返回的 category 与该素材 occurrence 行上现存的 scene_category 比较，
// 不一致则【记录并跳过，不写入】，单独计 skipped_category_drift。不更新
// scene_category——那会连带影响 word_count 分布、hero 选取、materials.scene_category
// 同步，爆炸半径远超一个验证脚本该有的范围。
//
// 从 _shared/classifyScene.ts import，不在这里另写一份 prompt/校验逻辑——
// 避免脚本版本和线上版本长出两份行为不一致的分类逻辑。
// ⚠️ 不能 import generate/index.ts：其顶层有 Deno.serve(...)，import 即启动 HTTP
// server，脚本会卡住不退出（或端口绑定失败）；deno check 只做类型检查发现不了。
//
// ⚠️ 必须串行执行（不能改成 Promise.all 并发）：
// classifyScene 的复用机制依赖"第 N+1 条能看到前 N 条已经写回的标签"。并发跑会让所有
// 调用都读到同一份（旧的）existingLabels，既测不出复用效果，又会在这次回填里自己制造
// 出一批新的碎片标签。
//
// 用法：
//   deno run --allow-net --allow-env scripts/backfill-scene-detail-relabel.ts <user_id>
//
// 需要的环境变量（与 generate Edge Function 相同）：
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / GEMINI_API_KEY
//
// 可重复运行：每次都是按当前 raw_content 重新分类、覆盖式 UPDATE scene_detail，
// 不插入新行，没有唯一约束冲突问题。

import {
  classifyScene,
  fetchExistingSceneLabels,
} from "../supabase/functions/_shared/classifyScene.ts";

// PM 在跑脚本前手工创建的备份表（见头部注释"运行前准备"）。
const BACKUP_TABLE = "_scene_detail_backup_20260909";

function env(name: string): string {
  return Deno.env.get(name) ?? "";
}

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_SVC_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const REST_HEADERS = {
  "Content-Type": "application/json",
  "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
  "apikey": SUPABASE_SVC_KEY,
};

// 两次 Gemini 调用之间的间隔：99 次连续串行调用，避免撞到速率限制造成中途大批失败。
const CALL_INTERVAL_MS = 300;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

interface RawContent {
  target_expression?: string | null;
  native_meaning?: string | null;
  user_original?: string | null;
}

interface Material {
  id: string;
  raw_content: RawContent | null;
}

interface BackupRow {
  scene_detail: string | null;
}

async function fetchSceneMaterials(userId: string): Promise<Material[]> {
  // 先从 lexicon_occurrences 拿该用户所有 material 来源的 source_id，
  // 去重（PostgREST 无 DISTINCT，走 TS 去重，和 fetchExistingSceneLabels 同一套路）。
  const occRes = await fetch(
    `${SUPABASE_URL}/rest/v1/lexicon_occurrences?user_id=eq.${userId}&source_type=eq.material&select=source_id&limit=10000`,
    { headers: REST_HEADERS },
  );
  if (!occRes.ok) {
    throw new Error(
      `fetch lexicon_occurrences source_id failed: ${occRes.status} ${await occRes.text()}`,
    );
  }
  const occRows = await occRes.json() as { source_id: string | null }[];
  if (occRows.length >= 10000) {
    console.warn(
      "[backfill] lexicon_occurrences source_id 命中 10000 行上限，结果可能不完整，请分批处理。",
    );
  }
  const materialIds = Array.from(
    new Set(occRows.map((r) => r.source_id).filter((id): id is string => !!id)),
  );
  if (materialIds.length === 0) return [];

  // 再按 material_type='scene' 过滤出真正的场景素材；deleted_at IS NULL——
  // 已软删除素材的 scene_detail 不会在任何界面展示，重新分类它们纯属浪费 Gemini 调用。
  // order=created_at.asc：最老的先跑。复用机制顺序相关，正序才模拟真实用户的积累过程。
  // 注：id=in.(...) 拼 99 个 UUID 的 URL 约 3.7KB，远低于上限；素材上千后可能撞
  // URL 长度限制。本脚本是一次性的，不做分页处理。
  const idList = materialIds.join(",");
  const materialsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/materials?id=in.(${idList})&material_type=eq.scene&deleted_at=is.null&select=id,raw_content&order=created_at.asc`,
    { headers: REST_HEADERS },
  );
  if (!materialsRes.ok) {
    throw new Error(
      `fetch materials failed: ${materialsRes.status} ${await materialsRes.text()}`,
    );
  }
  return await materialsRes.json() as Material[];
}

// 旧标签从备份表读——跑之前 lexicon_occurrences.scene_detail 已被清空，
// 那里读不到旧值；备份表只用于人工核对，不影响本次写入。
async function fetchOldSceneDetails(materialId: string): Promise<BackupRow[]> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${BACKUP_TABLE}?source_id=eq.${materialId}&select=scene_detail`,
    { headers: REST_HEADERS },
  );
  if (!res.ok) {
    throw new Error(
      `fetch backup scene_detail failed: ${res.status} ${await res.text()}`,
    );
  }
  return await res.json() as BackupRow[];
}

// 该素材 occurrence 行上现存的 scene_category（漂移对比的基准）。
// 与 PATCH 相同口径：user_id + source_type=eq.material + source_id 三过滤缺一不可。
// 读不到就抛错让整条失败——漂移校验缺失时不能盲写。
async function fetchOccurrenceCategories(
  userId: string,
  materialId: string,
): Promise<{ scene_category: string | null }[]> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/lexicon_occurrences?user_id=eq.${userId}&source_type=eq.material&source_id=eq.${materialId}&select=scene_category`,
    { headers: REST_HEADERS },
  );
  if (!res.ok) {
    throw new Error(
      `fetch occurrence scene_category failed: ${res.status} ${await res.text()}`,
    );
  }
  return await res.json() as { scene_category: string | null }[];
}

async function writeSceneDetail(
  userId: string,
  materialId: string,
  sceneDetail: string,
): Promise<void> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/lexicon_occurrences?user_id=eq.${userId}&source_type=eq.material&source_id=eq.${materialId}`,
    {
      method: "PATCH",
      headers: { ...REST_HEADERS, "Prefer": "return=minimal" },
      body: JSON.stringify({ scene_detail: sceneDetail }),
    },
  );
  if (!res.ok) {
    throw new Error(
      `patch scene_detail failed: ${res.status} ${await res.text()}`,
    );
  }
}

async function main() {
  const userId = Deno.args[0];
  if (!userId) {
    console.error(
      "用法: deno run --allow-net --allow-env scripts/backfill-scene-detail-relabel.ts <user_id>",
    );
    Deno.exit(1);
  }
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) {
    console.error("缺少 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY 环境变量。");
    Deno.exit(1);
  }

  const materials = await fetchSceneMaterials(userId);
  console.log(`[backfill] 待重跑素材数: ${materials.length}`);

  let updated = 0;
  let skippedNull = 0;
  let failedParse = 0;
  let skippedCategoryDrift = 0;
  let failed = 0;

  // 硬要求：串行。不要把这个 for 循环改成 materials.map(...) + Promise.all。
  for (const material of materials) {
    try {
      // 旧标签读备份表（只用于人工核对）；读不到不该拦下本次写入，降级为提示文案。
      let oldLabels = "(备份表读取失败)";
      try {
        const oldRows = await fetchOldSceneDetails(material.id);
        oldLabels = Array.from(
          new Set(oldRows.map((r) => r.scene_detail ?? "(null)")),
        ).join(", ");
      } catch (e) {
        console.error(
          `[backfill] material=${material.id} 备份表读取失败（不影响本次写入）:`,
          e,
        );
      }

      // 当前线上类别——漂移对比的基准。读不到会抛错、整条算失败（见 fetchOccurrenceCategories）。
      const catRows = await fetchOccurrenceCategories(userId, material.id);

      const raw = material.raw_content ?? {};
      const targetText = raw.target_expression ?? raw.user_original ?? "";
      const nativeText = raw.native_meaning ?? raw.user_original ?? "";
      const userOriginal = raw.user_original ?? undefined;

      // 每条都重新查一次——必须看到本次运行里前面几条刚写回的标签，
      // 这正是刀1要验证、也是这个脚本存在的意义。
      const existingLabels = await fetchExistingSceneLabels(userId);
      const { category, subScene, failed: classifyFailed } = await classifyScene(
        targetText,
        nativeText,
        userOriginal,
        existingLabels,
      );

      // classifyScene 内部不抛错：failed=true 表示调用/JSON 解析失败（含输出截断），
      // 与"模型正常返回但标签不合法"（failed=false, subScene=null）分开计数。
      // 上一轮把 67 次解析失败全部伪装成 skipped_null，failed=0 误导了排查，别再混。
      if (classifyFailed) {
        console.log(
          `[backfill] material=${material.id} classifyScene 调用/解析失败，跳过（old="${oldLabels}"）`,
        );
        failedParse++;
        continue;
      }

      if (!subScene) {
        console.log(
          `[backfill] material=${material.id} old="${oldLabels}" new=(null，跳过) — classifyScene 未产出合法标签`,
        );
        skippedNull++;
        continue;
      }

      // 类别漂移检查：返回的 category 必须与 occurrence 行上的现存类别一致，
      // 否则会写成 scene_category + scene_detail 错位的对。只记录跳过，不更新
      // scene_category（见头部注释——爆炸半径远超验证脚本该有的范围）。
      const liveCategories = Array.from(
        new Set(catRows.map((r) => r.scene_category)),
      );
      if (liveCategories.length !== 1 || liveCategories[0] !== category) {
        const oldCat = liveCategories.length
          ? liveCategories.map((c) => c ?? "(null)").join(", ")
          : "(null)";
        console.log(
          `[backfill] material=${material.id} 类别漂移，跳过: "${oldCat}" → "${category}"（old="${oldLabels}"）`,
        );
        skippedCategoryDrift++;
        continue;
      }

      await writeSceneDetail(userId, material.id, subScene);
      console.log(
        `[backfill] material=${material.id} old="${oldLabels}" new="${subScene}"`,
      );
      updated++;
    } catch (e) {
      console.error(`[backfill] material=${material.id} 失败，跳过:`, e);
      failed++;
    }

    // 每条之间休息 300ms，包括失败的那条——下次 Gemini 调用前都要留出间隔。
    await sleep(CALL_INTERVAL_MS);
  }

  console.log(
    `[backfill] 完成。total=${materials.length} updated=${updated} skipped_null=${skippedNull} failed_parse=${failedParse} skipped_category_drift=${skippedCategoryDrift} failed=${failed}`,
  );
}

if (import.meta.main) {
  await main();
}
