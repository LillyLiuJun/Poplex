// Supabase Edge Function: get-vocabs
// 读取词汇本素材（material_type='vocabulary'），供 Tab2 词汇本子页面展示。
// 切片 C：从用户 JWT 解析 auth.uid()，只返回该用户自己的词汇（user_id 过滤）。

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
    const url = new URL(`${SUPABASE_URL}/rest/v1/materials`);
    url.searchParams.set("select", "*");
    url.searchParams.set("material_type", "eq.vocabulary");
    url.searchParams.set("user_id", `eq.${userId}`);
    url.searchParams.set("deleted_at", "is.null");
    url.searchParams.set("order", "created_at.desc");

    const res = await fetch(url.toString(), {
      headers: {
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error("DB error:", res.status, errText);
      return json({ error: "db_error" }, 502);
    }

    const data = await res.json();
    return json(data);
  } catch (e) {
    console.error("Error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
