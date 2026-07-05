// Supabase Edge Function: get-messages
// 返回当前用户的历史消息，供 Tab1 历史记录展示。
// 按 created_at 升序（最旧在前），前端按日期分组展示。

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
      headers: { "Authorization": authHeader, "apikey": SUPABASE_SVC_KEY },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const userId = await getAuthUserId(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  try {
    const url = new URL(`${SUPABASE_URL}/rest/v1/messages`);
    url.searchParams.set(
      "select",
      "id,role,input_type,user_content,card_type,card_content,created_at"
    );
    url.searchParams.set("user_id", `eq.${userId}`);
    url.searchParams.set("status", "eq.delivered");
    url.searchParams.set("order", "created_at.asc");
    url.searchParams.set("limit", "300");

    const res = await fetch(url.toString(), {
      headers: {
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
    });

    if (!res.ok) {
      const errBody = await res.text();
      console.error("[get-messages] db error:", res.status, errBody);
      return json({ error: "db_error", status: res.status, detail: errBody }, 502);
    }

    const messages = await res.json();
    return json(messages);
  } catch (e) {
    console.error("[get-messages] error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
