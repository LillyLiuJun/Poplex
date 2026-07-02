// Supabase Edge Function: get-materials
// 读取 materials 表的场景素材，供 Tab2 展示用。
// 使用 service role key 访问 DB，绕开 anon key 直连 PostgREST 的权限问题。

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) {
    return json({ error: "missing_config" }, 500);
  }

  try {
    const url = new URL(`${SUPABASE_URL}/rest/v1/materials`);
    url.searchParams.set("select", "*");
    url.searchParams.set("material_type", "eq.scene");
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
