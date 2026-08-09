// submit-feedback Edge Function
// App 内反馈（方案 C）：验证用户 JWT → 以 service_role 写入 feedback 表并回填 user_id。
// 安全：不本地解码 token，走 /auth/v1/user 验签；service_role key 仅存在于环境变量。

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CATEGORIES = ["bug", "suggestion", "other"];
const BODY_MAX = 1000;
const EMAIL_MAX = 254;

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

function clean(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  if (!t) return null;
  return t.slice(0, max);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // 1. JWT 验证
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !SUPABASE_URL || !SUPABASE_SVC_KEY) {
      return json({ error: "unauthorized" }, 401);
    }
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { "Authorization": authHeader, "apikey": SUPABASE_SVC_KEY },
    });
    if (!userRes.ok) return json({ error: "unauthorized" }, 401);
    const user = await userRes.json();
    const uid: string | undefined = typeof user?.id === "string" ? user.id : undefined;
    if (!uid) return json({ error: "unauthorized" }, 401);

    // 2. 解析 + 校验
    const payload = await req.json().catch(() => null);
    if (!payload || typeof payload !== "object") {
      return json({ error: "invalid_body" }, 400);
    }
    const category = typeof payload.category === "string" ? payload.category : "";
    if (!CATEGORIES.includes(category)) {
      return json({ error: "invalid_category" }, 400);
    }
    const body = clean(payload.body, BODY_MAX);
    if (!body) {
      return json({ error: "empty_body" }, 400);
    }
    const contactEmail = clean(payload.contact_email, EMAIL_MAX);
    if (contactEmail && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contactEmail)) {
      return json({ error: "invalid_email" }, 400);
    }
    const appVersion = clean(payload.app_version, 32);
    const deviceInfo = clean(payload.device_info, 128);

    // 3. 简单频率限制：同一用户 10 秒内只收一条，防连点/灌垃圾
    const since = new Date(Date.now() - 10_000).toISOString();
    const recentRes = await fetch(
      `${SUPABASE_URL}/rest/v1/feedback?user_id=eq.${uid}&created_at=gte.${since}&select=id&limit=1`,
      { headers: { "Authorization": `Bearer ${SUPABASE_SVC_KEY}`, "apikey": SUPABASE_SVC_KEY } }
    );
    if (recentRes.ok) {
      const recent = await recentRes.json();
      if (Array.isArray(recent) && recent.length > 0) {
        return json({ error: "too_frequent" }, 429);
      }
    }

    // 4. 写入（service_role）
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/feedback`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({
        user_id: uid,
        category,
        body,
        contact_email: contactEmail,
        app_version: appVersion,
        device_info: deviceInfo,
      }),
    });
    if (!insertRes.ok) {
      const t = await insertRes.text();
      return json({ error: "insert_failed", detail: t }, 500);
    }

    return json({ success: true });
  } catch (e) {
    return json({ error: "internal_error", message: String(e) }, 500);
  }
});
