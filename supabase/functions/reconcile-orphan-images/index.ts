// Supabase Edge Function: reconcile-orphan-images
// 对账并清理 Storage 孤儿图片（待办 F）：照片已上传到 material_images、
// 但生成失败 / 落库失败 → 没有任何 message/material 引用它，永久占空间。
//
// 设计：
// - 只清理「调用者自己」前缀（{userId}/）下的文件——与全项目按 user 隔离的约定一致，
//   绝不扫全库、绝不碰别人的文件。旧版无 uid 时落到 "anonymous/" 的文件不在范围内。
// - 引用集合 = messages.image_url ∪ materials.raw_content->>'source_image_path'
//   （跳过 "asset:" 本地素材标记——它们本来就不在 Storage）。
//   软删除（deleted_at）的行仍计入引用：图片要留给 restore-material 复活用。
// - 只删「上传超过 24 小时且无引用」的对象：24h 窗口保护正在上传中的新图
//   （上传先于落库；同 requestId 重试也会复用已上传的图）。
// - 门禁：合法 JWT（/auth/v1/user 验证）+ x-reconcile-secret 头匹配 RECONCILE_SECRET。
//   手动触发（curl / admin），App 不调用。

const BUCKET = "material_images";
const DEFAULT_MIN_AGE_MS = 24 * 60 * 60 * 1000;
const PAGE_SIZE = 1000;

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-reconcile-secret",
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

interface StorageObject {
  name?: unknown;
  created_at?: unknown;
}

export interface ReconcileDeps {
  supabaseUrl: string;
  serviceKey: string;
  reconcileSecret: string;
  fetch: typeof fetch;
  now: () => number;
  minAgeMs: number;
}

export function createReconcileHandler(
  overrides: Partial<ReconcileDeps> = {},
): (req: Request) => Promise<Response> {
  const deps: ReconcileDeps = {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    reconcileSecret: Deno.env.get("RECONCILE_SECRET") ?? "",
    fetch: overrides.fetch ?? fetch,
    now: overrides.now ?? Date.now,
    minAgeMs: overrides.minAgeMs ?? DEFAULT_MIN_AGE_MS,
    ...overrides,
  };

  const svcHeaders: Record<string, string> = {
    "Authorization": `Bearer ${deps.serviceKey}`,
    "apikey": deps.serviceKey,
  };

  // 与 save-preset-card 同款：走 /auth/v1/user 让 Supabase 验证 JWT，不本地解码。
  async function authenticateCaller(
    authHeader: string,
  ): Promise<string | null> {
    const res = await deps.fetch(`${deps.supabaseUrl}/auth/v1/user`, {
      headers: { "Authorization": authHeader, "apikey": deps.serviceKey },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  }

  // 收集该用户所有仍被引用的 Storage 路径（不含 asset: 本地素材标记）。
  // 任一来源查询失败 → 抛错中止（fail-closed）：引用集合不完整时绝不能进入
  // 删除流程，否则会把手头「空名单」之外的照片全删掉。宁可漏删不可误删。
  async function collectReferences(userId: string): Promise<Set<string>> {
    const refs = new Set<string>();

    const msgRes = await deps.fetch(
      `${deps.supabaseUrl}/rest/v1/messages?select=image_url&user_id=eq.${userId}`,
      { headers: svcHeaders },
    );
    if (!msgRes.ok) {
      throw new Error(`refs_messages_failed:${msgRes.status}`);
    }
    for (const row of await msgRes.json() as Array<{ image_url?: unknown }>) {
      const path = row.image_url;
      if (typeof path === "string" && path && !path.startsWith("asset:")) {
        refs.add(path);
      }
    }

    const select = encodeURIComponent("source_image_path:raw_content->>source_image_path");
    const matRes = await deps.fetch(
      `${deps.supabaseUrl}/rest/v1/materials?select=${select}&user_id=eq.${userId}`,
      { headers: svcHeaders },
    );
    if (!matRes.ok) {
      throw new Error(`refs_materials_failed:${matRes.status}`);
    }
    for (
      const row of await matRes.json() as
        Array<{ source_image_path?: unknown }>
    ) {
      const path = row.source_image_path;
      if (typeof path === "string" && path && !path.startsWith("asset:")) {
        refs.add(path);
      }
    }

    return refs;
  }

  // 分页拉取 {userId}/ 前缀下全部对象（Storage list 单页上限 1000）。
  async function listUserObjects(userId: string): Promise<StorageObject[]> {
    const all: StorageObject[] = [];
    let offset = 0;
    while (true) {
      const res = await deps.fetch(
        `${deps.supabaseUrl}/storage/v1/object/list/${BUCKET}`,
        {
          method: "POST",
          headers: { ...svcHeaders, "Content-Type": "application/json" },
          body: JSON.stringify({
            prefix: `${userId}/`,
            limit: PAGE_SIZE,
            offset,
            sortBy: { column: "created_at", order: "desc" },
          }),
        },
      );
      if (!res.ok) {
        throw new Error(`list_failed:${res.status}`);
      }
      const page = await res.json() as StorageObject[];
      all.push(...page);
      if (page.length < PAGE_SIZE) break;
      offset += PAGE_SIZE;
    }
    return all;
  }

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders() });
    }
    if (req.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    if (!deps.reconcileSecret) {
      console.error("reconcile-orphan-images: RECONCILE_SECRET not configured");
      return json({ error: "reconcile secret not configured" }, 503);
    }
    const secret = req.headers.get("x-reconcile-secret");
    if (secret !== deps.reconcileSecret) {
      return json({ error: "forbidden" }, 403);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    let userId: string | null;
    try {
      userId = await authenticateCaller(authHeader);
    } catch (e) {
      console.error("reconcile-orphan-images auth check failed:", e);
      return json({ error: "unauthorized" }, 401);
    }
    if (!userId) return json({ error: "unauthorized" }, 401);

    let refs: Set<string>;
    let objects: StorageObject[];
    try {
      refs = await collectReferences(userId);
      objects = await listUserObjects(userId);
    } catch (e) {
      console.error("reconcile-orphan-images scan failed:", e);
      return json({ error: "scan_failed" }, 502);
    }

    const cutoff = deps.now() - deps.minAgeMs;
    const toDelete: string[] = [];
    let keptReferenced = 0;
    let keptRecent = 0;
    for (const obj of objects) {
      const name = typeof obj.name === "string" ? obj.name : null;
      if (!name) continue;
      if (refs.has(`${userId}/${name}`)) {
        keptReferenced += 1;
        continue;
      }
      // created_at 缺失或不可解析时按「新图」保守处理：宁可漏删不可误删。
      const createdAt =
        typeof obj.created_at === "string" ? Date.parse(obj.created_at) : NaN;
      if (Number.isNaN(createdAt) || createdAt > cutoff) {
        keptRecent += 1;
        continue;
      }
      toDelete.push(`${userId}/${name}`);
    }

    const deletedPaths: string[] = [];
    // Storage 单次 DELETE 上限 1000 个前缀，分批。
    for (let i = 0; i < toDelete.length; i += PAGE_SIZE) {
      const batch = toDelete.slice(i, i + PAGE_SIZE);
      const delRes = await deps.fetch(
        `${deps.supabaseUrl}/storage/v1/object/${BUCKET}`,
        {
          method: "DELETE",
          headers: { ...svcHeaders, "Content-Type": "application/json" },
          body: JSON.stringify({ prefixes: batch }),
        },
      );
      if (!delRes.ok) {
        console.error(
          "reconcile-orphan-images delete failed:",
          delRes.status,
          await delRes.text(),
        );
        return json({
          error: "delete_failed",
          deleted_paths: deletedPaths,
        }, 502);
      }
      deletedPaths.push(...batch);
    }

    return json({
      ok: true,
      scanned: objects.length,
      deleted: deletedPaths.length,
      kept_referenced: keptReferenced,
      kept_recent: keptRecent,
      deleted_paths: deletedPaths,
    });
  };
}

if (import.meta.main) {
  Deno.serve(createReconcileHandler());
}
