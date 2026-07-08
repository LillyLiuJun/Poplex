// Supabase Edge Function: get-messages
// 返回当前用户的历史消息，供 Tab1 历史记录展示。
// 按 created_at 升序（最旧在前），前端按日期分组展示。

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
      "id,role,input_type,user_content,card_type,card_content,created_at,image_url"
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

    const messages = await res.json() as Array<Record<string, unknown>>;

    // 批量签发 image_url 的 1h 访问链接，注入为 signed_image_url
    const paths = messages.map(m => m.image_url as string).filter(Boolean);
    const signedMap = new Map<string, string>();
    if (paths.length > 0) {
      try {
        const signRes = await fetch(
          `${SUPABASE_URL}/storage/v1/object/sign/${STORAGE_BUCKET}`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
              "apikey": SUPABASE_SVC_KEY,
            },
            body: JSON.stringify({ paths, expiresIn: 3600 }),
          }
        );
        if (signRes.ok) {
          const signed = await signRes.json() as Array<{ path: string; signedURL: string; error: string | null }>;
          for (const s of signed) {
            if (s.signedURL && !s.error) {
              signedMap.set(s.path, `${SUPABASE_URL}/storage/v1${s.signedURL}`);
            }
          }
        }
      } catch (e) {
        console.error("[get-messages] sign failed:", e);
      }
    }

    const result = messages.map(m => {
      const path = m.image_url as string | null;
      const signedUrl = path ? signedMap.get(path) : undefined;
      return signedUrl ? { ...m, signed_image_url: signedUrl } : m;
    });

    return json(result);
  } catch (e) {
    console.error("[get-messages] error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
