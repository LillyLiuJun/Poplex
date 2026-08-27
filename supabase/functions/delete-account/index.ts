// delete-account Edge Function
// 删除调用者（匿名用户）的全部数据，符合 App Store Review 5.1.1(v) 账号删除要求。
// 安全：从 JWT 验证用户身份，service_role key 仅存在于环境变量，绝不下发客户端。

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET   = "material_images";

import { deleteStorageObjects } from "./storage.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const svcHeaders = {
  "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
  "apikey": SUPABASE_SVC_KEY,
  "Content-Type": "application/json",
  "Prefer": "return=minimal",
};

async function dbDelete(table: string, uid: string): Promise<void> {
  const col = table === "profiles" ? "id" : "user_id";
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${table}?${col}=eq.${uid}`,
    { method: "DELETE", headers: svcHeaders }
  );
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`DELETE ${table} failed: ${res.status} ${body}`);
  }
}


Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // 1. JWT 验证：走 /auth/v1/user 验签，不自行解码 token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !SUPABASE_URL || !SUPABASE_SVC_KEY) {
      return json({ error: "unauthorized" }, 401);
    }

    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": authHeader,
        "apikey": SUPABASE_SVC_KEY,
      },
    });
    if (!userRes.ok) return json({ error: "unauthorized" }, 401);
    const user = await userRes.json();
    const uid: string | undefined = typeof user?.id === "string" ? user.id : undefined;
    if (!uid) return json({ error: "unauthorized" }, 401);

    console.log(`[delete-account] starting deletion for uid=${uid}`);

    // 2. 删除 Storage 对象。失败**不阻断**账号删除——账号必须删掉，
    //    不能因为图片没清干净就留下一个半删除的账号。但结果要如实带回给客户端。
    const storage = await deleteStorageObjects(uid, {
      fetch,
      baseUrl: SUPABASE_URL,
      headers: svcHeaders,
      bucket: STORAGE_BUCKET,
    });

    // 3. 按外键依赖顺序逐表删除（RESTRICT 约束决定顺序）
    // learning_events → (dialogue_sessions, lexicon_entries) 均为 RESTRICT
    await dbDelete("learning_events", uid);
    // dialogue_turns → dialogue_sessions (RESTRICT)
    await dbDelete("dialogue_turns", uid);
    await dbDelete("dialogue_sessions", uid);
    // lexicon_occurrences → lexicon_entries (RESTRICT)
    await dbDelete("lexicon_occurrences", uid);
    await dbDelete("lexicon_entries", uid);
    await dbDelete("messages", uid);
    await dbDelete("materials", uid);

    // 4. 删除 auth 用户（profiles 有 ON DELETE CASCADE，自动级联删除）
    const deleteUserRes = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${uid}`,
      {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
          "apikey": SUPABASE_SVC_KEY,
        },
      }
    );
    if (!deleteUserRes.ok) {
      const body = await deleteUserRes.text();
      throw new Error(`auth.admin.deleteUser failed: ${deleteUserRes.status} ${body}`);
    }

    console.log(
      `[delete-account] completed for uid=${uid}`,
      `storage removed=${storage.removed} failed=${storage.failed}`
    );
    // 账号与数据库数据已确定删除；storage_cleared 单独如实上报，
    // 让客户端能区分「全清干净」与「账号删了但有图片没清掉」，
    // 而不是无条件宣称「全部数据已删除」。
    return json({
      success: true,
      storage_cleared: storage.complete,
      storage_leftover: storage.failed,
    });
  } catch (e) {
    console.error("[delete-account] error:", e);
    return json({ error: "internal_error", message: String(e) }, 500);
  }
});
