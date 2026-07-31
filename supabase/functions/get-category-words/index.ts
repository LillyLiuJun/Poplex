// Supabase Edge Function: get-category-words
// 返回指定分类下的全量活跃词条，供 Tab2 词表展开视图使用。
// 按需调用（不在首屏一次性拉全量），只有用户展开某个分类时才调。

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
    const body = await req.json();
    const sceneCategory = typeof body?.scene_category === "string" ? body.scene_category : null;
    if (!sceneCategory) {
      return json({ error: "missing_scene_category" }, 400);
    }

    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_category_words`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
      body: JSON.stringify({
        p_user_id: userId,
        p_scene_category: sceneCategory,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("[get-category-words] rpc error:", err);
      return json({ error: "rpc_failed" }, 500);
    }

    const rows = await res.json() as Array<Record<string, unknown>>;

    // 收集需要签名的 Storage 路径
    const paths: string[] = [];
    for (const row of rows) {
      const p = row.source_image_path;
      if (typeof p === "string" && p) paths.push(p);
    }

    // 批量签发（与 get-materials 相同模式，有效期 1 小时）
    const signedMap = new Map<string, string>();
    if (paths.length > 0) {
      try {
        const signRes = await fetch(
          `${SUPABASE_URL}/storage/v1/object/sign/material_images`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
              "apikey": SUPABASE_SVC_KEY,
              "Content-Type": "application/json",
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
        console.error("[get-category-words] sign failed:", e);
      }
    }

    // 把签名 URL 注入为 image_url，移除原始路径字段
    const result = rows.map(row => {
      const path = row.source_image_path;
      const { source_image_path: _, ...rest } = row;
      if (typeof path !== "string" || !path) return rest;
      const signedUrl = signedMap.get(path);
      return signedUrl ? { ...rest, image_url: signedUrl } : rest;
    });

    return json(result);
  } catch (e) {
    console.error("[get-category-words] error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
