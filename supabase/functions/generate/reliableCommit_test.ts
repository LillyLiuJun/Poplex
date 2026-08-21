import { assertEquals, assertRejects } from "jsr:@std/assert";

import {
  commitGeneratedContent,
  resolveCommittedRequest,
} from "./reliableCommit.ts";
import { buildGenerateAccessConfig, createGenerateHandler } from "./index.ts";

const requestId = "11111111-1111-4111-8111-111111111111";
const userId = "22222222-2222-4222-8222-222222222222";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("resolveCommittedRequest stops after a rejected authentication response", async () => {
  const urls: string[] = [];
  const result = await resolveCommittedRequest({
    supabaseUrl: "https://project.supabase.co",
    apiKey: "publishable-key",
    authorization: "Bearer invalid-token",
    requestId,
    fetch: (input) => {
      urls.push(String(input));
      return Promise.resolve(jsonResponse({ message: "invalid JWT" }, 401));
    },
  });

  assertEquals(result, { userId: null, committed: null });
  assertEquals(urls, ["https://project.supabase.co/auth/v1/user"]);
});

Deno.test("resolveCommittedRequest reports an Auth service failure instead of treating it as a bad token", async () => {
  await assertRejects(
    () =>
      resolveCommittedRequest({
        supabaseUrl: "https://project.supabase.co",
        apiKey: "publishable-key",
        authorization: "Bearer caller-token",
        requestId,
        fetch: () =>
          Promise.resolve(jsonResponse({ message: "auth unavailable" }, 500)),
      }),
    Error,
    "authentication failed with 500",
  );
});

Deno.test("commitGeneratedContent rejects an RPC 500 instead of returning success", async () => {
  await assertRejects(
    () =>
      commitGeneratedContent({
        supabaseUrl: "https://project.supabase.co",
        apiKey: "publishable-key",
        authorization: "Bearer caller-token",
        requestId,
        userMessage: { role: "user" },
        assistantMessage: { role: "assistant" },
        material: { material_type: "scene" },
        fetch: () =>
          Promise.resolve(
            jsonResponse({ message: "database unavailable" }, 500),
          ),
      }),
    Error,
    "commit_generated_content failed with 500",
  );
});

Deno.test("commitGeneratedContent returns stored content and durable IDs for an already committed request", async () => {
  let capturedInit: RequestInit | undefined;
  const result = await commitGeneratedContent({
    supabaseUrl: "https://project.supabase.co",
    apiKey: "publishable-key",
    authorization: "Bearer caller-token",
    requestId,
    userMessage: { role: "user" },
    assistantMessage: { role: "assistant" },
    material: { material_type: "scene" },
    fetch: (_input, init) => {
      capturedInit = init;
      return Promise.resolve(jsonResponse({
        request_id: requestId,
        user_message_id: "33333333-3333-4333-8333-333333333333",
        assistant_message_id: "44444444-4444-4444-8444-444444444444",
        material_id: "55555555-5555-4555-8555-555555555555",
        card_type: "s4",
        card_content: { target_expression: "The subway is packed." },
        already_committed: true,
      }));
    },
  });

  assertEquals(result, {
    request_id: requestId,
    user_message_id: "33333333-3333-4333-8333-333333333333",
    assistant_message_id: "44444444-4444-4444-8444-444444444444",
    material_id: "55555555-5555-4555-8555-555555555555",
    card_type: "s4",
    card_content: { target_expression: "The subway is packed." },
    extracted_concept: null,
    already_committed: true,
  });
  const headers = new Headers(capturedInit?.headers);
  assertEquals(headers.get("Authorization"), "Bearer caller-token");
  assertEquals(headers.get("apikey"), "publishable-key");
  const payload = JSON.parse(String(capturedInit?.body));
  assertEquals("user_id" in payload, false);
});

Deno.test("commitGeneratedContent rejects an RPC response for another request", async () => {
  await assertRejects(
    () =>
      commitGeneratedContent({
        supabaseUrl: "https://project.supabase.co",
        apiKey: "publishable-key",
        authorization: "Bearer caller-token",
        requestId,
        userMessage: {},
        assistantMessage: {},
        material: {},
        fetch: () =>
          Promise.resolve(jsonResponse({
            request_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            user_message_id: "33333333-3333-4333-8333-333333333333",
            assistant_message_id: "44444444-4444-4444-8444-444444444444",
            material_id: "55555555-5555-4555-8555-555555555555",
            card_type: "s4",
            card_content: {},
            already_committed: false,
          })),
      }),
    Error,
    "request_id mismatch",
  );
});

Deno.test("commitGeneratedContent rejects empty or invalid durable IDs", async () => {
  for (const invalidUserMessageId of ["", "not-a-uuid"]) {
    await assertRejects(
      () =>
        commitGeneratedContent({
          supabaseUrl: "https://project.supabase.co",
          apiKey: "publishable-key",
          authorization: "Bearer caller-token",
          requestId,
          userMessage: {},
          assistantMessage: {},
          material: {},
          fetch: () =>
            Promise.resolve(jsonResponse({
              request_id: requestId,
              user_message_id: invalidUserMessageId,
              assistant_message_id: "44444444-4444-4444-8444-444444444444",
              material_id: "55555555-5555-4555-8555-555555555555",
              card_type: "s4",
              card_content: {},
              extracted_concept: null,
              already_committed: false,
            })),
        }),
      Error,
      "invalid durable IDs",
    );
  }
});

Deno.test("commitGeneratedContent accepts PostgreSQL UUID case normalization", async () => {
  const uppercaseRequestId = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA";
  const result = await commitGeneratedContent({
    supabaseUrl: "https://project.supabase.co",
    apiKey: "publishable-key",
    authorization: "Bearer caller-token",
    requestId: uppercaseRequestId,
    userMessage: {},
    assistantMessage: {},
    material: {},
    fetch: () =>
      Promise.resolve(jsonResponse({
        request_id: uppercaseRequestId.toLowerCase(),
        user_message_id: "33333333-3333-4333-8333-333333333333",
        assistant_message_id: "44444444-4444-4444-8444-444444444444",
        material_id: "55555555-5555-4555-8555-555555555555",
        card_type: "s4",
        card_content: {},
        already_committed: false,
      })),
  });

  assertEquals(result.request_id, uppercaseRequestId);
});

Deno.test("resolveCommittedRequest rejects an incomplete stored card", async () => {
  let call = 0;
  await assertRejects(
    () =>
      resolveCommittedRequest({
        supabaseUrl: "https://project.supabase.co",
        apiKey: "publishable-key",
        authorization: "Bearer caller-token",
        requestId,
        fetch: () => {
          call++;
          if (call === 1) return Promise.resolve(jsonResponse({ id: userId }));
          if (call === 2) {
            return Promise.resolve(jsonResponse([
              {
                id: "33333333-3333-4333-8333-333333333333",
                request_id: requestId,
                role: "user",
              },
              {
                id: "44444444-4444-4444-8444-444444444444",
                request_id: requestId,
                role: "assistant",
                card_type: null,
                card_content: null,
              },
            ]));
          }
          return Promise.resolve(jsonResponse([{
            id: "55555555-5555-4555-8555-555555555555",
            request_id: requestId,
          }]));
        },
      }),
    Error,
    "stored assistant card is incomplete",
  );
});

interface HandlerHarnessOptions {
  authStatus?: number;
  callerApiKey?: string;
  duplicate?: boolean;
  rpcStatus?: number;
  contentBlocked?: boolean;
  afterCommitThrows?: boolean;
  waitUntilThrows?: boolean;
  rpcAlreadyCommitted?: boolean;
  geminiConcept?: string;
  uploadFails?: boolean;
  /** 固定「请求时刻」时钟（dependencies.now），缺省为一个确定的过去时刻。 */
  nowIso?: string;
}

function createHandlerHarness(options: HandlerHarnessOptions = {}) {
  const calls = { auth: 0, gemini: 0, storage: 0, rpc: 0 };
  const rpcPayloads: Array<Record<string, unknown>> = [];
  const committed = {
    request_id: requestId,
    user_message_id: "33333333-3333-4333-8333-333333333333",
    assistant_message_id: "44444444-4444-4444-8444-444444444444",
    material_id: "55555555-5555-4555-8555-555555555555",
    card_type: "s4",
    card_content: {
      granularity: "sentence",
      direction: "express",
      target_expression: "The subway is packed.",
      learnable_units: [],
    },
    extracted_concept: "stored concept",
    already_committed: options.duplicate === true ||
      options.rpcAlreadyCommitted === true,
  };

  const fakeFetch = (
    input: string | URL | Request,
    init?: RequestInit,
  ): Promise<Response> => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) {
      calls.auth++;
      return Promise.resolve(jsonResponse(
        options.authStatus === 401
          ? { message: "invalid JWT" }
          : { id: userId },
        options.authStatus ?? 200,
      ));
    }
    if (url.includes("/rest/v1/messages?")) {
      return Promise.resolve(jsonResponse(
        options.duplicate
          ? [
            {
              id: committed.user_message_id,
              request_id: requestId,
              role: "user",
            },
            {
              id: committed.assistant_message_id,
              request_id: requestId,
              role: "assistant",
              card_type: committed.card_type,
              card_content: committed.card_content,
              extracted_concept: "地铁很挤",
            },
          ]
          : [],
      ));
    }
    if (url.includes("/rest/v1/materials?")) {
      return Promise.resolve(jsonResponse(
        options.duplicate
          ? [{
            id: committed.material_id,
            request_id: requestId,
          }]
          : [],
      ));
    }
    if (url.includes("generativelanguage.googleapis.com")) {
      calls.gemini++;
      return Promise.resolve(jsonResponse({
        candidates: [{
          content: {
            parts: [{
              text: JSON.stringify({
                card_type: options.contentBlocked
                  ? "error"
                  : committed.card_type,
                card_content: options.contentBlocked
                  ? { error_type: "unsafe" }
                  : committed.card_content,
                extracted_concept: options.geminiConcept ?? null,
              }),
            }],
          },
          finishReason: "STOP",
        }],
      }));
    }
    if (url.includes("/storage/v1/object/")) {
      calls.storage++;
      return Promise.resolve(new Response(null, { status: 200 }));
    }
    if (url.endsWith("/rest/v1/rpc/commit_generated_content")) {
      calls.rpc++;
      if (typeof init?.body === "string") {
        try {
          rpcPayloads.push(JSON.parse(init.body));
        } catch {
          throw new Error("commit_generated_content body is not JSON");
        }
      }
      return Promise.resolve(jsonResponse(
        options.rpcStatus === 500 ? { message: "commit failed" } : committed,
        options.rpcStatus ?? 200,
      ));
    }
    throw new Error(`unexpected fetch: ${url} ${init?.method ?? "GET"}`);
  };

  const handler = createGenerateHandler({
    geminiApiKey: "gemini-key",
    supabaseUrl: "https://project.supabase.co",
    supabaseApiKey: options.callerApiKey === undefined
      ? "publishable-key"
      : options.callerApiKey,
    fetch: fakeFetch,
    uploadImage: () => {
      calls.storage++;
      return Promise.resolve(options.uploadFails ? null : "user/photo.jpg");
    },
    deleteImage: () => {
      calls.storage++;
      return Promise.resolve();
    },
    afterCommit: options.afterCommitThrows
      ? () => {
        throw new Error("post-commit sync failure");
      }
      : () => Promise.resolve(),
    waitUntil: () => {
      if (options.waitUntilThrows) throw new Error("waitUntil sync failure");
    },
    randomUUID: () => requestId,
    now: () => new Date(options.nowIso ?? "2026-08-21T12:00:00.000Z"),
  });

  return { handler, calls, rpcPayloads };
}

Deno.test("production access config keeps caller and privileged keys separate", () => {
  const config = buildGenerateAccessConfig({
    anonKey: "anon-or-publishable-key",
    serviceRoleKey: "service-role-key",
  });

  assertEquals(config, {
    callerApiKey: "anon-or-publishable-key",
    privilegedApiKey: "service-role-key",
  });
});

function generationRequest(
  requestIdValue: unknown = requestId,
  extra: Record<string, unknown> = {},
): Request {
  const body: Record<string, unknown> = {
    image_base64: "aGVsbG8=",
    mime_type: "image/jpeg",
    source: "onboarding",
    ...extra,
  };
  if (requestIdValue !== undefined && !("request_id" in extra)) {
    body.request_id = requestIdValue;
  }
  return new Request("http://localhost/generate", {
    method: "POST",
    headers: {
      "Authorization": "Bearer caller-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("generate rejects invalid authentication before Gemini, Storage, or RPC", async () => {
  const { handler, calls } = createHandlerHarness({ authStatus: 401 });
  const response = await handler(generationRequest());

  assertEquals(response.status, 401);
  assertEquals(calls, { auth: 1, gemini: 0, storage: 0, rpc: 0 });
});

Deno.test("generate fails closed before external work when the caller API key is missing", async () => {
  const { handler, calls } = createHandlerHarness({ callerApiKey: "" });
  const response = await handler(generationRequest());

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "missing_supabase_config" });
  assertEquals(calls, { auth: 0, gemini: 0, storage: 0, rpc: 0 });
});

Deno.test("generate rejects an invalid token before parsing malformed JSON", async () => {
  const { handler, calls } = createHandlerHarness({ authStatus: 401 });
  const response = await handler(
    new Request("http://localhost/generate", {
      method: "POST",
      headers: {
        "Authorization": "Bearer invalid-token",
        "Content-Type": "application/json",
      },
      body: "{not-json",
    }),
  );

  assertEquals(response.status, 401);
  assertEquals(calls, { auth: 1, gemini: 0, storage: 0, rpc: 0 });
});

Deno.test("generate authenticates before rejecting a malformed request_id", async () => {
  const { handler, calls } = createHandlerHarness({ authStatus: 401 });
  const response = await handler(generationRequest("not-a-uuid"));

  assertEquals(response.status, 401);
  assertEquals(calls, { auth: 1, gemini: 0, storage: 0, rpc: 0 });
});

Deno.test("generate rejects a malformed request_id after successful authentication", async () => {
  const { handler, calls } = createHandlerHarness();
  const response = await handler(generationRequest("not-a-uuid"));

  assertEquals(response.status, 400);
  assertEquals(calls, { auth: 1, gemini: 0, storage: 0, rpc: 0 });
});

Deno.test("generate returns a complete committed duplicate without Gemini or Storage", async () => {
  const { handler, calls } = createHandlerHarness({ duplicate: true });
  const response = await handler(generationRequest());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.request_id, requestId);
  assertEquals(body.material_id, "55555555-5555-4555-8555-555555555555");
  assertEquals(body.extracted_concept, "地铁很挤");
  assertEquals(calls, { auth: 1, gemini: 0, storage: 0, rpc: 0 });
});

// 方案丙（写作时刻语义）：重试请求携带 original_created_at 时，
// user 行按写作时刻落库、assistant 行 = 写作时刻 + 1ms——客户端原位摆放
// 与服务器时间线一致，刷新永不跳。
Deno.test("generate commits a retry at the original write time", async () => {
  const { handler, rpcPayloads } = createHandlerHarness({
    nowIso: "2026-08-21T12:00:00.000Z",
  });
  const response = await handler(generationRequest(requestId, {
    original_created_at: "2026-08-20T08:30:00.123Z",
  }));

  assertEquals(response.status, 200);
  assertEquals(rpcPayloads.length, 1);
  const payload = rpcPayloads[0];
  const userMessage = payload.p_user_message as Record<string, unknown>;
  const assistantMessage = payload.p_assistant_message as Record<string, unknown>;
  assertEquals(userMessage.created_at, "2026-08-20T08:30:00.123Z");
  assertEquals(assistantMessage.created_at, "2026-08-20T08:30:00.124Z");
});

// 正常发送不带 original_created_at：user 行 = 请求时刻锁定，
// assistant 行不传 created_at（RPC 走 GREATEST(now(), user+1ms) 兜底），行为不变。
Deno.test("generate without original_created_at keeps request-time semantics", async () => {
  const { handler, rpcPayloads } = createHandlerHarness({
    nowIso: "2026-08-21T12:00:00.000Z",
  });
  const response = await handler(generationRequest());

  assertEquals(response.status, 200);
  const payload = rpcPayloads[0];
  const userMessage = payload.p_user_message as Record<string, unknown>;
  const assistantMessage = payload.p_assistant_message as Record<string, unknown>;
  assertEquals(userMessage.created_at, "2026-08-21T12:00:00.000Z");
  assertEquals(assistantMessage.created_at, undefined);
});

// 不可解析的 original_created_at 静默回退到请求时刻，不影响正常流程。
Deno.test("generate falls back to request time for an unparseable original_created_at", async () => {
  const { handler, rpcPayloads } = createHandlerHarness({
    nowIso: "2026-08-21T12:00:00.000Z",
  });
  const response = await handler(generationRequest(requestId, {
    original_created_at: "not-a-date",
  }));

  assertEquals(response.status, 200);
  const payload = rpcPayloads[0];
  const userMessage = payload.p_user_message as Record<string, unknown>;
  const assistantMessage = payload.p_assistant_message as Record<string, unknown>;
  assertEquals(userMessage.created_at, "2026-08-21T12:00:00.000Z");
  assertEquals(assistantMessage.created_at, undefined);
});

// 客户端时钟超前导致写作时刻在未来：截断到请求时刻，不写入未来时间戳。
Deno.test("generate clamps a future original_created_at to the request time", async () => {
  const { handler, rpcPayloads } = createHandlerHarness({
    nowIso: "2026-08-21T12:00:00.000Z",
  });
  const response = await handler(generationRequest(requestId, {
    original_created_at: "2026-09-01T00:00:00.000Z",
  }));

  assertEquals(response.status, 200);
  const payload = rpcPayloads[0];
  const userMessage = payload.p_user_message as Record<string, unknown>;
  const assistantMessage = payload.p_assistant_message as Record<string, unknown>;
  assertEquals(userMessage.created_at, "2026-08-21T12:00:00.000Z");
  assertEquals(assistantMessage.created_at, "2026-08-21T12:00:00.001Z");
});

Deno.test("generate keeps content_blocked behavior and removes the rejected upload", async () => {
  const { handler, calls } = createHandlerHarness({ contentBlocked: true });
  const response = await handler(generationRequest());
  const body = await response.json();

  assertEquals(response.status, 422);
  assertEquals(body, {
    error: "content_blocked",
    blockReason: "unsafe",
    request_id: requestId,
  });
  assertEquals(calls.gemini, 1);
  assertEquals(calls.storage, 2);
  assertEquals(calls.rpc, 0);
});

Deno.test("generate returns upload failure with request_id and skips RPC", async () => {
  const { handler, calls } = createHandlerHarness({ uploadFails: true });
  const response = await handler(generationRequest());

  assertEquals(response.status, 502);
  assertEquals(await response.json(), {
    error: "image_upload_failed",
    request_id: requestId,
  });
  assertEquals(calls.gemini, 1);
  assertEquals(calls.rpc, 0);
});

Deno.test("generate returns 502 when a new request cannot be durably committed", async () => {
  const { handler, calls } = createHandlerHarness({ rpcStatus: 500 });
  const response = await handler(generationRequest());

  assertEquals(response.status, 502);
  assertEquals(calls.auth, 1);
  assertEquals(calls.gemini, 1);
  assertEquals(calls.rpc, 1);
});

Deno.test("generate success includes every durable ID returned by the atomic commit", async () => {
  const { handler, calls } = createHandlerHarness();
  const response = await handler(generationRequest());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.request_id, requestId);
  assertEquals(body.user_message_id, "33333333-3333-4333-8333-333333333333");
  assertEquals(
    body.assistant_message_id,
    "44444444-4444-4444-8444-444444444444",
  );
  assertEquals(body.material_id, "55555555-5555-4555-8555-555555555555");
  assertEquals(calls.rpc, 1);
});

Deno.test("generate keeps durable success when afterCommit throws synchronously", async () => {
  const { handler, calls } = createHandlerHarness({ afterCommitThrows: true });
  const response = await handler(generationRequest());

  assertEquals(response.status, 200);
  assertEquals(calls.rpc, 1);
});

Deno.test("generate keeps durable success when waitUntil throws synchronously", async () => {
  const { handler, calls } = createHandlerHarness({ waitUntilThrows: true });
  const response = await handler(generationRequest());

  assertEquals(response.status, 200);
  assertEquals(calls.rpc, 1);
});

Deno.test("generate returns the stored concept when a racing RPC reports already committed", async () => {
  const { handler, calls } = createHandlerHarness({
    rpcAlreadyCommitted: true,
    geminiConcept: "racing model concept",
  });
  const response = await handler(generationRequest());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.already_committed, true);
  assertEquals(body.extracted_concept, "stored concept");
  assertEquals(calls.gemini, 1);
  assertEquals(calls.rpc, 1);
});

Deno.test("generate creates and echoes a request_id for old clients that omit it", async () => {
  const { handler } = createHandlerHarness();
  const response = await handler(generationRequest(undefined));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.request_id, requestId);
});
