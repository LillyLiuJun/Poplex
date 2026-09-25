// Supabase Edge Function: get-tab2-home
// Tab2 首页数据：解锁状态、分类卡与活动清单。
// 调用 get_tab2_home PG 函数，通过 JWT 鉴权限定到当前用户。
// image_url 字段存的是 Storage 路径，在此统一签名后再返回给客户端。

import { parseDayStart } from "./dayStart.ts";

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

// 批量签名：收集 activities[].cover.image_url 里的所有 Storage 路径，
// 一次请求换成签名 URL。
async function signImagePaths(
  categories: Array<Record<string, unknown>>
): Promise<Array<Record<string, unknown>>> {
  // 收集所有非空路径（去重）
  const paths = new Set<string>();
  const collect = (v: unknown) => {
    if (typeof v === "string" && v) paths.add(v);
  };
  for (const cat of categories) {
    (cat.activities as Array<Record<string, unknown>> | undefined)
      ?.forEach((a) => {
        const cover = a.cover as Record<string, unknown> | null | undefined;
        if (cover) collect(cover.image_url);
      });
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
  //   · cover.image_url 是可空字段——签名失败只置 null，不透原始路径；
  //     activity 的 scene_detail / occurrence_count 没有图也要展示，整条不丢。
  //   · cover 必须用展开语法回写（cover: {...cover, image_url: signed}），
  //     不能把 cover 整体替换成 URL——否则 material_id 丢失，
  //     客户端的图片缓存 key 和去重会失效。
  return categories.map((cat) => {
    const out: Record<string, unknown> = { ...cat };

    const activities = cat.activities as Array<Record<string, unknown>> | undefined;
    if (activities) {
      out.activities = activities.map((a) => {
        const cover = a.cover as Record<string, unknown> | null | undefined;
        if (!cover) return a;
        return { ...a, cover: { ...cover, image_url: sign(cover.image_url) } };
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
    // 刀 4a：客户端把「本地今日 00:00 对应的 UTC 时刻」放在 day_start query 参数里；
    // 缺失或不合法 → parseDayStart 返回 null，RPC 走服务端日界兜底（故意不报错）。
    const pDayStart = parseDayStart(
      new URL(req.url).searchParams.get("day_start")
    );

    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_tab2_home`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
      body: JSON.stringify({ p_user_id: userId, p_day_start: pDayStart }),
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
