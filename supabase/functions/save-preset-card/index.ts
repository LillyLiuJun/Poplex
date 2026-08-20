// Supabase Edge Function: save-preset-card
// 预设卡轻量落库：引导页预设卡的英文描述是 App 内置静态文案（零 AI 调用），
// 原本只在客户端内存里交接给 Tab1 首屏，重启后从服务端拉历史就查无此卡。
//
// 走与照片生成同款的原子提交 RPC（commit_generated_content，p_material 传 null）：
// user 行 + assistant 行在一次数据库事务里全有或全无，不再是两次独立 INSERT。
// request_id 是幂等键——同一次尝试的重试直接拿回上次落库结果，不会再出现
// 「user 行写成功、assistant 行写失败」的半张卡被 60 秒去重窗口误判成"已存在"、
// 从此再也补不全的问题（旧版只查 user 行是否存在，这个问题在生产验证过）。

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

interface RequestBody {
  request_id?: unknown;
  preset_card_id?: string;
  static_english?: string;
  static_chinese?: string;
  image_name?: string;
}

interface CommitResult {
  request_id?: unknown;
  user_message_id?: unknown;
  assistant_message_id?: unknown;
  already_committed?: unknown;
}

export interface SavePresetCardDeps {
  supabaseUrl: string;
  anonKey: string;
  fetch: typeof fetch;
  randomUUID: () => string;
}

export function createSavePresetCardHandler(
  overrides: Partial<SavePresetCardDeps> = {},
): (req: Request) => Promise<Response> {
  const deps: SavePresetCardDeps = {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    fetch: overrides.fetch ?? fetch,
    randomUUID: overrides.randomUUID ?? (() => crypto.randomUUID()),
    ...overrides,
  };

  // 关键：走 /auth/v1/user 端点让 Supabase【验证 JWT 签名与过期】后返回 user，
  // 不本地解码 token。拿不到 uid 一律 401——绝不用未确认身份的调用者继续写库。
  async function authenticateCaller(
    authHeader: string,
  ): Promise<string | null> {
    const res = await deps.fetch(`${deps.supabaseUrl}/auth/v1/user`, {
      headers: { "Authorization": authHeader, "apikey": deps.anonKey },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  }

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders() });
    }
    if (req.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    let userId: string | null;
    try {
      userId = await authenticateCaller(authHeader);
    } catch (e) {
      console.error("save-preset-card auth check failed:", e);
      return json({ error: "unauthorized" }, 401);
    }
    if (!userId) return json({ error: "unauthorized" }, 401);

    let body: RequestBody;
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid JSON body" }, 400);
    }

    const { preset_card_id, static_english, static_chinese, image_name } = body;
    if (!preset_card_id || !static_english) {
      return json({ error: "missing preset_card_id or static_english" }, 400);
    }

    // 旧客户端尚未发 request_id 时服务端兜底生成一个：本次落库仍然正确，只是
    // 没有跨请求的幂等保护——和 generate 函数对旧客户端的兼容策略一致。
    const requestId = isUuid(body.request_id)
      ? body.request_id
      : deps.randomUUID();

    const rpcRes = await deps.fetch(
      `${deps.supabaseUrl}/rest/v1/rpc/commit_generated_content`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader,
          "apikey": deps.anonKey,
        },
        body: JSON.stringify({
          p_request_id: requestId,
          p_user_message: {
            input_type: "preset_card",
            user_content: "Describe this image",
            preset_card_id,
            status: "delivered",
            source: "onboarding",
            image_url: image_name ? `asset:${image_name}` : null,
          },
          p_assistant_message: {
            card_type: "card",
            card_content: {
              granularity: "sentence",
              direction: "express",
              target_expression: static_english,
              native_meaning: static_chinese ?? null,
            },
            status: "delivered",
            source: "onboarding",
          },
          p_material: null,
        }),
      },
    );

    if (!rpcRes.ok) {
      console.error(
        "save-preset-card commit failed:",
        rpcRes.status,
        await rpcRes.text(),
      );
      return json({ error: "commit_failed", request_id: requestId }, 502);
    }

    const committed = await rpcRes.json() as CommitResult;
    if (
      !isUuid(committed.user_message_id) ||
      !isUuid(committed.assistant_message_id) ||
      typeof committed.already_committed !== "boolean"
    ) {
      console.error(
        "save-preset-card commit returned an invalid response:",
        committed,
      );
      return json({ error: "commit_failed", request_id: requestId }, 502);
    }

    return json({
      ok: true,
      request_id: requestId,
      user_message_id: committed.user_message_id,
      assistant_message_id: committed.assistant_message_id,
      already_committed: committed.already_committed,
    });
  };
}

if (import.meta.main) {
  Deno.serve(createSavePresetCardHandler());
}
