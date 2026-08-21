import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createSavePresetCardHandler, SavePresetCardDeps } from "./index.ts";

const SUPABASE_URL = "http://localhost:54321";
const ANON_KEY = "anon-key";

function req(
  body: unknown,
  authHeader: string | null = "Bearer good-token",
): Request {
  const headers: HeadersInit = { "Content-Type": "application/json" };
  if (authHeader) headers["Authorization"] = authHeader;
  return new Request("http://localhost/save-preset-card", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function fakeFetch(
  opts: {
    authOk?: boolean;
    userId?: string;
    rpcStatus?: number;
    rpcBody?: unknown;
    onRpcCall?: (body: unknown) => void;
  } = {},
): typeof fetch {
  const authOk = opts.authOk ?? true;
  const userId = opts.userId ?? "11111111-1111-1111-1111-111111111111";
  const rpcStatus = opts.rpcStatus ?? 200;
  const rpcBody = opts.rpcBody ?? {
    request_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    user_message_id: "22222222-2222-2222-2222-222222222222",
    assistant_message_id: "33333333-3333-3333-3333-333333333333",
    material_id: null,
    already_committed: false,
  };
  return (async (input: string | URL | Request) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.includes("/auth/v1/user")) {
      if (!authOk) {
        return new Response(JSON.stringify({ error: "invalid token" }), {
          status: 401,
        });
      }
      return new Response(JSON.stringify({ id: userId }), { status: 200 });
    }
    if (url.includes("/rest/v1/rpc/commit_generated_content")) {
      return new Response(JSON.stringify(rpcBody), { status: rpcStatus });
    }
    throw new Error(`unexpected fetch: ${url}`);
  }) as unknown as typeof fetch;
}

function makeDeps(
  overrides: Partial<SavePresetCardDeps> = {},
): Partial<SavePresetCardDeps> {
  return {
    supabaseUrl: SUPABASE_URL,
    anonKey: ANON_KEY,
    fetch: fakeFetch(),
    randomUUID: () => "generated-uuid",
    ...overrides,
  };
}

Deno.test("save-preset-card rejects a request with no Authorization header", async () => {
  const handler = createSavePresetCardHandler(makeDeps());
  const res = await handler(
    req({ preset_card_id: "c1", static_english: "hi" }, null),
  );
  assertEquals(res.status, 401);
});

Deno.test("save-preset-card rejects when auth lookup fails", async () => {
  const handler = createSavePresetCardHandler(
    makeDeps({ fetch: fakeFetch({ authOk: false }) }),
  );
  const res = await handler(
    req({ preset_card_id: "c1", static_english: "hi" }),
  );
  assertEquals(res.status, 401);
});

Deno.test("save-preset-card rejects a missing preset_card_id", async () => {
  const handler = createSavePresetCardHandler(makeDeps());
  const res = await handler(req({ static_english: "hi" }));
  assertEquals(res.status, 400);
});

Deno.test("save-preset-card commits via the atomic RPC and returns durable IDs", async () => {
  let capturedBody: Record<string, unknown> | undefined;
  const fetchImpl =
    (async (input: string | URL | Request, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input.toString();
      if (url.includes("/auth/v1/user")) {
        return new Response(
          JSON.stringify({ id: "11111111-1111-1111-1111-111111111111" }),
          { status: 200 },
        );
      }
      if (url.includes("/rest/v1/rpc/commit_generated_content")) {
        capturedBody = JSON.parse(init!.body as string);
        return new Response(
          JSON.stringify({
            request_id: capturedBody!.p_request_id,
            user_message_id: "22222222-2222-2222-2222-222222222222",
            assistant_message_id: "33333333-3333-3333-3333-333333333333",
            material_id: null,
            already_committed: false,
          }),
          { status: 200 },
        );
      }
      throw new Error(`unexpected fetch: ${url}`);
    }) as unknown as typeof fetch;

  const handler = createSavePresetCardHandler(makeDeps({ fetch: fetchImpl }));
  const res = await handler(req({
    request_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    preset_card_id: "sample-card-1",
    static_english: "A cup of coffee sits on the table.",
    static_chinese: "桌上放着一杯咖啡。",
    image_name: "sample1",
  }));

  assertEquals(res.status, 200);
  const bodyOut = await res.json();
  assertEquals(bodyOut.ok, true);
  assertEquals(bodyOut.request_id, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
  assertEquals(bodyOut.user_message_id, "22222222-2222-2222-2222-222222222222");
  assertEquals(
    bodyOut.assistant_message_id,
    "33333333-3333-3333-3333-333333333333",
  );
  assertEquals(bodyOut.already_committed, false);

  // The RPC never receives a material payload — preset cards have no scene card.
  assertEquals(capturedBody!.p_material, null);
  const userMessage = capturedBody!.p_user_message as Record<string, unknown>;
  assertEquals(userMessage.preset_card_id, "sample-card-1");
  assertEquals(userMessage.image_url, "asset:sample1");

  // 时间线反序修复的契约:user 行不显式传 created_at(用数据库时钟),
  // 排序行为完全由 SQL 迁移的 GREATEST(now(), user+1ms) 保证——
  // Edge 时钟与 DB 时钟混排只会带来维护成本,迁移单独上线即闭环。
  assertEquals(userMessage.created_at, undefined);
});

Deno.test("save-preset-card generates a request_id for old clients that omit one", async () => {
  let capturedBody: Record<string, unknown> | undefined;
  const fetchImpl =
    (async (input: string | URL | Request, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input.toString();
      if (url.includes("/auth/v1/user")) {
        return new Response(
          JSON.stringify({ id: "11111111-1111-1111-1111-111111111111" }),
          { status: 200 },
        );
      }
      capturedBody = JSON.parse(init!.body as string);
      return new Response(
        JSON.stringify({
          request_id: capturedBody!.p_request_id,
          user_message_id: "22222222-2222-2222-2222-222222222222",
          assistant_message_id: "33333333-3333-3333-3333-333333333333",
          material_id: null,
          already_committed: false,
        }),
        { status: 200 },
      );
    }) as unknown as typeof fetch;

  const handler = createSavePresetCardHandler(
    makeDeps({ fetch: fetchImpl, randomUUID: () => "server-generated-id" }),
  );
  const res = await handler(
    req({ preset_card_id: "c1", static_english: "hi" }),
  );
  const bodyOut = await res.json();
  assertEquals(res.status, 200);
  assertEquals(bodyOut.request_id, "server-generated-id");
  assertEquals(capturedBody!.p_request_id, "server-generated-id");
});

Deno.test("save-preset-card returns 502 and never fakes success when the RPC fails", async () => {
  const handler = createSavePresetCardHandler(makeDeps({
    fetch: fakeFetch({ rpcStatus: 500, rpcBody: { message: "boom" } }),
  }));
  const res = await handler(
    req({ preset_card_id: "c1", static_english: "hi" }),
  );
  assertEquals(res.status, 502);
});

Deno.test("save-preset-card returns 502 when the RPC response is missing durable IDs", async () => {
  const handler = createSavePresetCardHandler(makeDeps({
    fetch: fakeFetch({ rpcBody: { already_committed: false } }),
  }));
  const res = await handler(
    req({ preset_card_id: "c1", static_english: "hi" }),
  );
  assertEquals(res.status, 502);
});

Deno.test("save-preset-card surfaces already_committed on an idempotent retry", async () => {
  const handler = createSavePresetCardHandler(makeDeps({
    fetch: fakeFetch({
      rpcBody: {
        request_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        user_message_id: "22222222-2222-2222-2222-222222222222",
        assistant_message_id: "33333333-3333-3333-3333-333333333333",
        material_id: null,
        already_committed: true,
      },
    }),
  }));
  const res = await handler(req({
    request_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    preset_card_id: "c1",
    static_english: "hi",
  }));
  const bodyOut = await res.json();
  assertEquals(bodyOut.already_committed, true);
});
