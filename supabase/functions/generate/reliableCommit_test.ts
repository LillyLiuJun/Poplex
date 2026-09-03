import { assertEquals, assertRejects } from "jsr:@std/assert";

import {
  checkGenerationQuotaForUser,
  commitGeneratedContent,
  isOnboardingStillOpen,
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
        usageDate: "2026-08-21",
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
    usageDate: "2026-08-21",
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
        usageDate: "2026-08-21",
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
          usageDate: "2026-08-21",
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
    usageDate: "2026-08-21",
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

// 第 2 刀：usageDate / countUsage 原样透传给 RPC——分桶日期由 Edge 入口计算，
// 免计开关由调用方显式决定，两者都不在传输层做任何改写。
Deno.test("commitGeneratedContent forwards the quota parameters to the RPC", async () => {
  let capturedInit: RequestInit | undefined;
  await commitGeneratedContent({
    supabaseUrl: "https://project.supabase.co",
    apiKey: "publishable-key",
    authorization: "Bearer caller-token",
    requestId,
    userMessage: { role: "user" },
    assistantMessage: { role: "assistant" },
    material: { material_type: "scene" },
    usageDate: "2026-08-21",
    countUsage: false,
    fetch: (_input, init) => {
      capturedInit = init;
      return Promise.resolve(jsonResponse({
        request_id: requestId,
        user_message_id: "33333333-3333-4333-8333-333333333333",
        assistant_message_id: "44444444-4444-4444-8444-444444444444",
        material_id: "55555555-5555-4555-8555-555555555555",
        card_type: "s4",
        card_content: {},
        already_committed: false,
      }));
    },
  });

  const payload = JSON.parse(String(capturedInit?.body));
  assertEquals(payload.p_usage_date, "2026-08-21");
  assertEquals(payload.p_count_usage, false);
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
  /** 服务端 onboarding 事实：profile 的完成标记。缺省 = 未完成（豁免开着）。 */
  onboardingCompleted?: boolean;
  /** check_generation_quota_for_user 的返回。缺省 = 已用 2 / 上限 5 / 放行。 */
  quotaStatus?: { usedCount: number; limit: number; allowed: boolean };
  /** 落账后 usage 读取的返回（第二次 quota RPC）；缺省与 quotaStatus 相同。
   *  用于模拟「前置校验放行（4/5）→ 本次生成落账后额度用尽（5/5）」的真实
   *  时序——成功响应据此携带 allowed:false，客户端立即锁定。 */
  quotaStatusAfterCommit?: { usedCount: number; limit: number; allowed: boolean };
  /** 额度 RPC 的 HTTP 状态（模拟服务端查询故障）。 */
  quotaCheckStatus?: number;
  /** 成功后的 usage 读取的 HTTP 状态（与预检分开，模拟「生成成功但读取挂掉」）。 */
  usageReadStatus?: number;
  /** service role key。缺省为有效值；传 "" 模拟环境变量缺失。 */
  privilegedApiKey?: string;
}

function createHandlerHarness(options: HandlerHarnessOptions = {}) {
  const calls = { auth: 0, gemini: 0, storage: 0, rpc: 0 };
  // 第 3 刀新增的两个服务键读取，单独计数（既有的 calls 断言不能变）。
  const quotaCalls = { profiles: 0, quotaRpc: 0 };
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
    if (url.includes("/rest/v1/profiles?")) {
      quotaCalls.profiles++;
      return Promise.resolve(jsonResponse([{
        id: userId,
        onboarding_completed_at: options.onboardingCompleted
          ? "2026-08-01T00:00:00.000Z"
          : null,
      }]));
    }
    if (url.endsWith("/rest/v1/rpc/check_generation_quota_for_user")) {
      quotaCalls.quotaRpc++;
      const failStatus = quotaCalls.quotaRpc === 1
        ? options.quotaCheckStatus // 第一次 = 前置校验（豁免流程里是 usage 读取，同口径）
        : options.usageReadStatus; // 第二次起 = 成功后的 usage 读取
      if (failStatus !== undefined) {
        return Promise.resolve(jsonResponse({ message: "boom" }, failStatus));
      }
      const quota = quotaCalls.quotaRpc === 1
        ? options.quotaStatus ?? { usedCount: 2, limit: 5, allowed: true }
        : options.quotaStatusAfterCommit ?? options.quotaStatus ??
          { usedCount: 2, limit: 5, allowed: true };
      return Promise.resolve(jsonResponse({
        used_count: quota.usedCount,
        limit: quota.limit,
        allowed: quota.allowed,
      }));
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
    privilegedApiKey: options.privilegedApiKey === undefined
      ? "service-role-key"
      : options.privilegedApiKey,
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

  return { handler, calls, rpcPayloads, quotaCalls };
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

// 第 3 刀：豁免判定由 Edge 用服务端事实（profile 完成标记）做出——source 是
// 辅助信号，profile 未完成 + source=onboarding 才豁免；一个判定结果同时驱动
// 「跳过前置校验」与 p_count_usage=false。
Deno.test("generate exempts an in-onboarding request: skips the pre-check and requests no counting", async () => {
  const { handler, rpcPayloads, quotaCalls } = createHandlerHarness({
    nowIso: "2026-08-21T23:59:00.000Z",
  });
  const response = await handler(generationRequest());

  assertEquals(response.status, 200);
  assertEquals(quotaCalls, { profiles: 1, quotaRpc: 1 }); // 1 = 成功后的 usage 读取，非前置校验
  const payload = rpcPayloads[0];
  assertEquals(payload.p_usage_date, "2026-08-21");
  assertEquals(payload.p_count_usage, false);
});

Deno.test("generate exempts an in-onboarding request and carries the latest usage on success", async () => {
  const { handler, rpcPayloads, quotaCalls } = createHandlerHarness({
    onboardingCompleted: false,
    nowIso: "2026-08-21T23:59:00.000Z",
    quotaStatus: { usedCount: 0, limit: 5, allowed: true },
  });
  const response = await handler(generationRequest());

  assertEquals(response.status, 200);
  assertEquals(quotaCalls, { profiles: 1, quotaRpc: 1 }); // 成功后的 usage 读取，免除前置校验
  assertEquals(rpcPayloads[0].p_count_usage, false); // 引导期不计入日常用量
  const body = await response.json();
  assertEquals(body.usage, {
    used: 0,
    limit: 5,
    allowed: true,
    resets_at: "2026-08-22T00:00:00Z",
  });
});

// ─────────────────────────────────────────────────────────────
// 第 3 刀：前置校验 / 429 / 时区分桶 / usage 字段
// ─────────────────────────────────────────────────────────────

Deno.test("generate returns 429 before Gemini when the daily limit is reached", async () => {
  const { handler, calls } = createHandlerHarness({
    quotaStatus: { usedCount: 5, limit: 5, allowed: false },
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
    utc_offset_minutes: 480,
  }));

  assertEquals(response.status, 429);
  assertEquals(await response.json(), {
    error: "daily_limit_reached",
    used: 5,
    limit: 5,
    resets_at: "2026-08-22T00:00:00+08:00",
  });
  assertEquals(calls.gemini, 0);
  assertEquals(calls.rpc, 0);
});

Deno.test("generate checks the quota for a user who completed onboarding even with a forged source", async () => {
  const { handler, rpcPayloads, quotaCalls } = createHandlerHarness({
    onboardingCompleted: true,
    quotaStatus: { usedCount: 5, limit: 5, allowed: false },
  });
  const response = await handler(generationRequest()); // source=onboarding，伪造的

  // 完成过 onboarding：豁免关闭 → 前置校验拦截。
  assertEquals(response.status, 429);
  assertEquals(quotaCalls, { profiles: 1, quotaRpc: 1 });
  assertEquals(rpcPayloads.length, 0);
});

Deno.test("generate never exempts a non-onboarding source even mid-onboarding", async () => {
  const { handler, rpcPayloads, quotaCalls } = createHandlerHarness({
    quotaStatus: { usedCount: 4, limit: 5, allowed: true },
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
  }));

  assertEquals(response.status, 200);
  // source 非 onboarding → 不读 profile（短路的辅助信号），直接走校验。
  assertEquals(quotaCalls.profiles, 0);
  assertEquals(quotaCalls.quotaRpc, 2); // 前置校验 + 成功后的 usage 读取
  assertEquals(rpcPayloads[0].p_count_usage, true);
});

Deno.test("generate passes a device-local bucket date derived from the client offset", async () => {
  const { handler, rpcPayloads } = createHandlerHarness({
    nowIso: "2026-08-21T20:00:00.000Z", // UTC 20:00 + 8 小时 = 当地次日
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
    utc_offset_minutes: 480,
  }));

  assertEquals(response.status, 200);
  assertEquals(rpcPayloads[0].p_usage_date, "2026-08-22");
});

Deno.test("generate success carries the latest usage for the frontend", async () => {
  const { handler } = createHandlerHarness({
    quotaStatus: { usedCount: 3, limit: 5, allowed: true },
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
    utc_offset_minutes: 480,
  }));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.usage, {
    used: 3,
    limit: 5,
    allowed: true,
    resets_at: "2026-08-22T00:00:00+08:00",
  });
});

Deno.test("generate success carries the post-commit verdict: last slot consumed → allowed false", async () => {
  // 真实时序：前置校验时 4/5 放行，本次生成落账后额度用尽 5/5——成功响应
  // 携带 allowed:false，前端在最后一次卡片生成完成的同时锁定输入栏。
  const { handler, calls } = createHandlerHarness({
    quotaStatus: { usedCount: 4, limit: 5, allowed: true },
    quotaStatusAfterCommit: { usedCount: 5, limit: 5, allowed: false },
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
    utc_offset_minutes: 480,
  }));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.usage, {
    used: 5,
    limit: 5,
    allowed: false,
    resets_at: "2026-08-22T00:00:00+08:00",
  });
  assertEquals(calls.gemini, 1);
});

Deno.test("generate duplicate responses also carry the latest usage", async () => {
  const { handler, calls } = createHandlerHarness({
    duplicate: true,
    quotaStatus: { usedCount: 3, limit: 5, allowed: true },
  });
  const response = await handler(generationRequest(requestId, {
    utc_offset_minutes: 480,
  }));

  assertEquals(response.status, 200);
  assertEquals((await response.json()).usage, {
    used: 3,
    limit: 5,
    allowed: true,
    resets_at: "2026-08-22T00:00:00+08:00",
  });
  // 幂等路径不产生模型费用、不重复落库。
  assertEquals(calls.gemini, 0);
  assertEquals(calls.rpc, 0);
});

Deno.test("generate fails closed when the quota check is unavailable", async () => {
  const { handler, calls } = createHandlerHarness({ quotaCheckStatus: 500 });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
  }));

  assertEquals(response.status, 502);
  assertEquals(await response.json(), { error: "quota_check_unavailable" });
  assertEquals(calls.gemini, 0);
});

Deno.test("generate fails closed when the service role key is not configured", async () => {
  const { handler, calls } = createHandlerHarness({
    privilegedApiKey: "",
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
  }));

  assertEquals(response.status, 502);
  assertEquals(await response.json(), { error: "quota_check_unavailable" });
  assertEquals(calls.gemini, 0);
});

Deno.test("generate keeps success when the post-commit usage read fails", async () => {
  // 预检放行、落库成功、usage 读取失败 → 仍是 200，只是没有 usage 字段
  // （省略而非失败，否则客户端会重试并卡死在幂等路径上）。
  const { handler, rpcPayloads, quotaCalls } = createHandlerHarness({
    usageReadStatus: 500,
  });
  const response = await handler(generationRequest(requestId, {
    source: "tab1",
  }));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.usage, undefined);
  assertEquals(rpcPayloads.length, 1);
  assertEquals(quotaCalls.quotaRpc, 2); // 预检 1 次 + usage 读取 1 次
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

// ─────────────────────────────────────────────────────────────
// 第 3 刀：服务键查询函数（额度预检 + onboarding 服务端判据）
// ─────────────────────────────────────────────────────────────

Deno.test("checkGenerationQuotaForUser forwards the caller-computed date with service-key auth", async () => {
  let captured: { url?: string; init?: RequestInit } = {};
  const quota = await checkGenerationQuotaForUser({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "service-role-key",
    userId,
    usageDate: "2026-08-22",
    fetch: (input, init) => {
      captured = { url: String(input), init };
      return Promise.resolve(jsonResponse({
        used_count: 4,
        limit: 5,
        allowed: true,
      }));
    },
  });

  assertEquals(captured.url, "https://project.supabase.co/rest/v1/rpc/check_generation_quota_for_user");
  assertEquals(captured.init?.headers, {
    "Authorization": "Bearer service-role-key",
    "apikey": "service-role-key",
    "Content-Type": "application/json",
    "Accept": "application/vnd.pgrst.object+json",
  });
  assertEquals(JSON.parse(String(captured.init?.body)), {
    p_user_id: userId,
    p_usage_date: "2026-08-22",
  });
  assertEquals(quota, { usedCount: 4, limit: 5, allowed: true });
});

Deno.test("checkGenerationQuotaForUser tolerates the PostgREST array shape (single row)", async () => {
  // 2026-09-02 线上事故的回归测试：RETURNS TABLE 的 RPC 不带 object 头时
  // PostgREST 回 JSON 数组（本项目 get_category_words 同款行为）。解析器必须
  // 两种形状都过，不能只信假响应。
  const quota = await checkGenerationQuotaForUser({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "service-role-key",
    userId,
    usageDate: "2026-08-22",
    fetch: () =>
      Promise.resolve(jsonResponse([{
        used_count: 4,
        limit: 5,
        allowed: true,
      }])),
  });
  assertEquals(quota, { usedCount: 4, limit: 5, allowed: true });
});

Deno.test("checkGenerationQuotaForUser rejects a malformed RPC response", async () => {
  await assertRejects(
    () =>
      checkGenerationQuotaForUser({
        supabaseUrl: "https://project.supabase.co",
        serviceRoleKey: "service-role-key",
        userId,
        usageDate: "2026-08-22",
        fetch: () =>
          Promise.resolve(jsonResponse({ used_count: "four" })),
      }),
    Error,
    "invalid response",
  );
});

Deno.test("checkGenerationQuotaForUser rejects a denied (non-2xx) RPC response", async () => {
  await assertRejects(
    () =>
      checkGenerationQuotaForUser({
        supabaseUrl: "https://project.supabase.co",
        serviceRoleKey: "service-role-key",
        userId,
        usageDate: "2026-08-22",
        fetch: () =>
          Promise.resolve(jsonResponse({ message: "denied" }, 401)),
      }),
    Error,
    "failed with 401",
  );
});

Deno.test("isOnboardingStillOpen resolves the server-side onboarding fact", async () => {
  const cases: Array<{ rows: unknown; expected: boolean }> = [
    { rows: [{ onboarding_completed_at: null }], expected: true },
    { rows: [{ onboarding_completed_at: "2026-08-01T00:00:00Z" }], expected: false },
    // profile 行缺失 → 不免（与 RPC 的 FOUND=false 同口径）。
    { rows: [], expected: false },
  ];
  for (const { rows, expected } of cases) {
    const result = await isOnboardingStillOpen({
      supabaseUrl: "https://project.supabase.co",
      serviceRoleKey: "service-role-key",
      userId,
      fetch: () => Promise.resolve(jsonResponse(rows)),
    });
    assertEquals(result, expected, JSON.stringify(rows));
  }
});

Deno.test("isOnboardingStillOpen rejects a non-array profile response", async () => {
  await assertRejects(
    () =>
      isOnboardingStillOpen({
        supabaseUrl: "https://project.supabase.co",
        serviceRoleKey: "service-role-key",
        userId,
        fetch: () => Promise.resolve(jsonResponse({ id: userId })),
      }),
    Error,
    "invalid response",
  );
});
