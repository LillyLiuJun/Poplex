// Supabase Edge Function: get-tab2-home
// Tab2 首页数据：解锁状态、分类卡、子场景、预览词。
// 调用 get_tab2_home PG 函数，通过 JWT 鉴权限定到当前用户。
// image_url 字段存的是 Storage 路径，在此统一签名后再返回给客户端。

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET   = "material_images";
const SIGNED_URL_TTL   = 3600; // 1 hour

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

// 批量签名：收集 sub_scenes[].image_url + featured.image_url + hero_photos[].image_url
// 里的所有 Storage 路径，一次请求换成签名 URL。
async function signImagePaths(
  categories: Array<Record<string, unknown>>
): Promise<Array<Record<string, unknown>>> {
  // 收集所有非空路径（去重）
  const paths = new Set<string>();
  const collect = (v: unknown) => {
    if (typeof v === "string" && v) paths.add(v);
  };
  for (const cat of categories) {
    (cat.sub_scenes as Array<Record<string, unknown>> | undefined)
      ?.forEach((s) => collect(s.image_url));
    const featured = cat.featured as Record<string, unknown> | null | undefined;
    if (featured) collect(featured.image_url);
    (cat.hero_photos as Array<Record<string, unknown>> | undefined)
      ?.forEach((p) => collect(p.image_url));
  }

  if (paths.size === 0) return categories;

  const signedMap = new Map<string, string>();
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
        body: JSON.stringify({
          paths: Array.from(paths),
          expiresIn: SIGNED_URL_TTL,
        }),
      }
    );
    if (signRes.ok) {
      const signed = await signRes.json() as Array<{ path: string; signedURL: string; error: string | null }>;
      for (const s of signed) {
        if (s.signedURL && !s.error) {
          signedMap.set(s.path, `${SUPABASE_URL}/storage/v1${s.signedURL}`);
        }
      }
    } else {
      console.error("[get-tab2-home] sign failed:", await signRes.text());
    }
  } catch (e) {
    console.error("[get-tab2-home] sign error:", e);
  }

  const sign = (v: unknown): string | null =>
    typeof v === "string" ? (signedMap.get(v) ?? null) : null;

  // 替换路径为签名 URL：
  //   · sub_scenes / featured 的 image_url 是可空字段——签名失败留 null，不透原始路径
  //   · hero_photos 的 image_url 前端模型为非空——签名失败的整张从拼图剔除
  return categories.map((cat) => {
    const out: Record<string, unknown> = { ...cat };

    const scenes = cat.sub_scenes as Array<Record<string, unknown>> | undefined;
    if (scenes) out.sub_scenes = scenes.map((s) => ({ ...s, image_url: sign(s.image_url) }));

    const featured = cat.featured as Record<string, unknown> | null | undefined;
    if (featured) out.featured = { ...featured, image_url: sign(featured.image_url) };

    const hero = cat.hero_photos as Array<Record<string, unknown>> | undefined;
    if (hero) {
      out.hero_photos = hero
        .map((p) => ({ ...p, image_url: sign(p.image_url) }))
        .filter((p) => {
          if (!p.image_url) {
            console.warn("[get-tab2-home] hero_photo sign failed, dropped:", p.material_id);
            return false;
          }
          return true;
        });
    }

    return out;
  });
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

    const data = await res.json() as { categories?: Array<Record<string, unknown>> };
    if (Array.isArray(data?.categories)) {
      data.categories = await signImagePaths(data.categories);
    }
    return json(data);
  } catch (e) {
    console.error("[get-tab2-home] error:", e);
    return json({ error: "internal_error" }, 500);
  }
});
