// Supabase Edge Function: get-materials
// 读取 materials 表的场景素材，供 Tab2 展示用。
// 切片 C：从用户 JWT 解析 auth.uid()，只返回该用户自己的素材（user_id 过滤）。
// 优先级3：有来源图片的素材，批量签发 1 小时有效的 Storage 签名 URL，注入 source_image_url。
//          DB 只存路径（source_image_path），URL 由此处临时生成，不持久化，保护用户隐私。

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
    url.searchParams.set("material_type", "eq.scene");
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

    const materials = await res.json() as Array<Record<string, unknown>>;

    // 收集所有需要签名的图片路径（raw_content.source_image_path 有值的素材）
    const paths: string[] = [];
    for (const m of materials) {
      const rc = m.raw_content as Record<string, unknown> | null;
      const p = rc?.source_image_path;
      if (typeof p === "string" && p) paths.push(p);
    }

    // 批量签发：一次 API call 换回所有路径的签名 URL（有效期 1 小时）
    const signedMap = new Map<string, string>();
    if (paths.length > 0) {
      console.log("[get-materials] signing paths:", JSON.stringify(paths));
      try {
        const signRes = await fetch(
          `${SUPABASE_URL}/storage/v1/object/sign/${STORAGE_BUCKET}`,
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
        const signBody = await signRes.text();
        console.log("[get-materials] sign status:", signRes.status, "body:", signBody);
        if (signRes.ok) {
          const signed = JSON.parse(signBody) as Array<{ path: string; signedURL: string; error: string | null }>;
          for (const s of signed) {
            if (s.signedURL && !s.error) {
              signedMap.set(s.path, `${SUPABASE_URL}/storage/v1${s.signedURL}`);
            }
          }
          console.log("[get-materials] signedMap keys:", JSON.stringify([...signedMap.keys()]));
        }
      } catch (e) {
        console.error("[get-materials] sign failed:", e);
        // 签名失败不阻塞主流程，素材正常返回，图片 URL 缺失
      }
    } else {
      console.log("[get-materials] no paths to sign (materials count:", materials.length, ")");
    }

    // 把签名 URL 注入到 raw_content.source_image_url，供前端直接使用
    const result = materials.map(m => {
      const rc = m.raw_content as Record<string, unknown> | null;
      const path = rc?.source_image_path;
      if (typeof path !== "string" || !path) return m;
      const signedUrl = signedMap.get(path);
      if (!signedUrl) return m;
      return { ...m, raw_content: { ...rc, source_image_url: signedUrl } };
    });

    return json(result);
  } catch (e) {
    console.error("Error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
