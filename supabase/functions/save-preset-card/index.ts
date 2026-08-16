// Supabase Edge Function: save-preset-card
// 预设卡轻量落库：引导页预设卡的英文描述是 App 内置静态文案（零 AI 调用），
// 原本只在客户端内存里交接给 Tab1 首屏，重启后从服务端拉历史就查无此卡。
// 本函数把静态文案作为一条正常消息记录写入 messages（user + assistant 两条），
// 使 Tab1 历史重启后仍能看到这张卡。不调任何 AI，纯一次轻量写入。

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

// 关键：走 /auth/v1/user 端点让 Supabase【验证 JWT 签名与过期】后返回 user，
// 不本地解码 token。拿不到 uid 一律 401。
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

async function insertMessage(
  row: Record<string, unknown>,
  userId: string,
  imageUrl: string | null = null
): Promise<boolean> {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({ ...row, user_id: userId, image_url: imageUrl }),
    });
    return res.ok;
  } catch (e) {
    console.error("save-preset-card insertMessage failed:", e);
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const userId = await getAuthUserId(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  let body: {
    preset_card_id?: string;
    static_english?: string;
    static_chinese?: string;
    image_name?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const { preset_card_id, static_english, static_chinese, image_name } = body;
  if (!preset_card_id || !static_english) {
    return json({ error: "missing preset_card_id or static_english" }, 400);
  }

  // 幂等保护（窗口化）：同卡 60 秒内的重复写入才跳过，防止连点/网络重发。
  // 不能按「该用户是否写过这张卡」去重——重试/隔天再生成是合法的独立记录
  // （生产验证：历史已存同卡导致重试被吞，重启后新内容消失）。
  try {
    const checkUrl = new URL(`${SUPABASE_URL}/rest/v1/messages`);
    checkUrl.searchParams.set("select", "id");
    checkUrl.searchParams.set("user_id", `eq.${userId}`);
    checkUrl.searchParams.set("preset_card_id", `eq.${preset_card_id}`);
    checkUrl.searchParams.set("role", "eq.user");
    checkUrl.searchParams.set("created_at", `gt.${new Date(Date.now() - 60_000).toISOString()}`);
    checkUrl.searchParams.set("limit", "1");
    const checkRes = await fetch(checkUrl.toString(), {
      headers: {
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
      },
    });
    if (checkRes.ok) {
      const existing = await checkRes.json();
      if (Array.isArray(existing) && existing.length > 0) {
        return json({ ok: true, deduplicated: true });
      }
    }
  } catch (e) {
    console.error("save-preset-card dedupe check failed (continuing):", e);
  }

  // user 行：气泡。预设卡图片是 App 内置 asset（非 storage），
  // image_url 存 "asset:<imageName>" 标记，客户端解码时用本地素材渲染。
  // user_content 与客户端 MessageRecord 的 preset_card 兜底文案一致。
  const userOk = await insertMessage(
    {
      role: "user",
      input_type: "preset_card",
      user_content: "Describe this image",
      preset_card_id,
      status: "delivered",
    },
    userId,
    image_name ? `asset:${image_name}` : null
  );

  // assistant 行：静态学习卡（与客户端 PresetCard.staticCard 同构）。
  const cardOk = await insertMessage(
    {
      role: "assistant",
      card_type: "card",
      card_content: {
        granularity: "sentence",
        direction: "express",
        target_expression: static_english,
        native_meaning: static_chinese ?? null,
      },
      status: "delivered",
    },
    userId
  );

  if (!userOk || !cardOk) {
    return json({ error: "insert failed" }, 502);
  }
  return json({ ok: true });
});
