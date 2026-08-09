// delete-account Edge Function
// 删除调用者（匿名用户）的全部数据，符合 App Store Review 5.1.1(v) 账号删除要求。
// 安全：从 JWT 验证用户身份，service_role key 仅存在于环境变量，绝不下发客户端。

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET   = "material_images";

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

async function deleteStorageObjects(uid: string): Promise<void> {
  // List all objects for this user in the material_images bucket
  const listRes = await fetch(
    `${SUPABASE_URL}/storage/v1/object/list/${STORAGE_BUCKET}`,
    {
      method: "POST",
      headers: svcHeaders,
      body: JSON.stringify({ prefix: `${uid}/`, limit: 1000, offset: 0 }),
    }
  );
  if (!listRes.ok) {
    console.warn("[delete-account] storage list failed, skipping cleanup");
    return;
  }
  const objects: { name: string }[] = await listRes.json();
  if (!Array.isArray(objects) || objects.length === 0) return;

  const paths = objects.map((o) => `${uid}/${o.name}`);
  const delRes = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${STORAGE_BUCKET}`,
    {
      method: "DELETE",
      headers: svcHeaders,
      body: JSON.stringify({ prefixes: paths }),
    }
  );
  if (!delRes.ok) {
    console.warn("[delete-account] storage delete failed:", await delRes.text());
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

    // 2. 删除 Storage 对象（不影响 DB 删除，失败只告警）
    await deleteStorageObjects(uid);

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

    console.log(`[delete-account] completed for uid=${uid}`);
    return json({ success: true });
  } catch (e) {
    console.error("[delete-account] error:", e);
    return json({ error: "internal_error", message: String(e) }, 500);
  }
});
