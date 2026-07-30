// Supabase Edge Function: get-tab2-home
// Tab2 首页数据：解锁状态、分类卡、子场景、预览词。
// 调用 get_tab2_home PG 函数，通过 JWT 鉴权限定到当前用户。

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

async function getAuthUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !SUPABASE_URL || !SUPABASE_SVC_KEY) return null;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": authHeader,
        "apikey": SUPABASE_SVC_KEY,
      },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch (e) {
    console.error("getAuthUserId failed:", e);
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) {
    return json({ error: "missing_config" }, 500);
  }

  const userId = await getAuthUserId(req);
  if (!userId) {
    return json({ error: "unauthorized" }, 401);
  }

  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_tab2_home`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
      body: JSON.stringify({ p_user_id: userId }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("[get-tab2-home] rpc error:", err);
      return json({ error: "rpc_failed" }, 500);
    }

    const data = await res.json();
    return json(data);
  } catch (e) {
    console.error("[get-tab2-home] error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
