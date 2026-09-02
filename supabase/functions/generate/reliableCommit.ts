export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface CommittedContent {
  request_id: string;
  user_message_id: string;
  assistant_message_id: string;
  material_id: string;
  card_type: string;
  card_content: Record<string, unknown>;
  extracted_concept: string | null;
  already_committed: boolean;
  /**
   * How many superseded onboarding rows this commit's cleanup removed.
   * Only an onboarding commit for a user who has not finished onboarding can
   * be non-zero. Reported so a destructive step leaves a trace; absent when
   * the result came from resolving an already-committed request rather than
   * from the RPC.
   */
  cleaned_up_messages?: number;
  cleaned_up_materials?: number;
}

interface ReliableCommitConnection {
  supabaseUrl: string;
  apiKey: string;
  authorization: string | null;
  fetch?: FetchLike;
}

export type AuthenticateCallerOptions = ReliableCommitConnection;

export interface ResolveCommittedRequestOptions
  extends ReliableCommitConnection {
  requestId: string;
  verifiedUserId?: string;
}

export interface ResolveCommittedRequestResult {
  userId: string | null;
  committed: CommittedContent | null;
}

export interface CommitGeneratedContentOptions
  extends ReliableCommitConnection {
  requestId: string;
  userMessage: Record<string, unknown>;
  assistantMessage: Record<string, unknown>;
  material: Record<string, unknown>;
  /**
   * 生成次数分桶日期（YYYY-MM-DD），由调用方在入口算好传入。RPC 内不得用
   * now() 现算——否则 23:59:59 的校验与 00:00:02 的落库会分到两个桶。
   */
  usageDate: string;
  /**
   * false 时跳过扣减。豁免（onboarding）由调用方用服务端事实判定后传入，
   * RPC 内部仍会用自己的服务端判据再查一遍（防御纵深）——source 是客户端
   * 可伪造的，两道门都不能只看 source。
   */
  countUsage?: boolean;
}

interface MessageRow {
  id?: unknown;
  request_id?: unknown;
  role?: unknown;
  card_type?: unknown;
  card_content?: unknown;
  extracted_concept?: unknown;
}

interface MaterialRow {
  id?: unknown;
  request_id?: unknown;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function requestHeaders(
  apiKey: string,
  authorization: string,
): Record<string, string> {
  return {
    "Authorization": authorization,
    "apikey": apiKey,
  };
}

async function checkedJson(
  response: Response,
  operation: string,
): Promise<unknown> {
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `${operation} failed with ${response.status}${
        detail ? `: ${detail}` : ""
      }`,
    );
  }
  return await response.json();
}

function asObject(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function parseCommittedContent(
  value: unknown,
  requestId: string,
): CommittedContent {
  const row = asObject(value);
  if (!row) {
    throw new Error("commit_generated_content returned an invalid response");
  }
  if (
    typeof row.request_id !== "string" ||
    row.request_id.toLowerCase() !== requestId.toLowerCase()
  ) {
    throw new Error("request_id mismatch in commit response");
  }
  if (
    !isUuid(row.user_message_id) ||
    !isUuid(row.assistant_message_id) ||
    !isUuid(row.material_id)
  ) {
    throw new Error("commit_generated_content returned invalid durable IDs");
  }

  const cardContent = asObject(row.card_content);
  if (typeof row.card_type !== "string" || !cardContent) {
    throw new Error(
      "commit_generated_content returned an incomplete stored card",
    );
  }
  if (typeof row.already_committed !== "boolean") {
    throw new Error(
      "commit_generated_content returned an invalid commit state",
    );
  }

  return {
    request_id: requestId,
    user_message_id: row.user_message_id,
    assistant_message_id: row.assistant_message_id,
    material_id: row.material_id,
    card_type: row.card_type,
    card_content: cardContent,
    extracted_concept: typeof row.extracted_concept === "string"
      ? row.extracted_concept
      : null,
    already_committed: row.already_committed,
    // Spread rather than assign undefined: an older RPC that doesn't report
    // these must yield an object of exactly the previous shape.
    ...(typeof row.cleaned_up_messages === "number"
      ? { cleaned_up_messages: row.cleaned_up_messages }
      : {}),
    ...(typeof row.cleaned_up_materials === "number"
      ? { cleaned_up_materials: row.cleaned_up_materials }
      : {}),
  };
}

export async function resolveCommittedRequest(
  options: ResolveCommittedRequestOptions,
): Promise<ResolveCommittedRequestResult> {
  const authenticatedUserId = options.verifiedUserId ??
    await authenticateCaller(options);
  if (!authenticatedUserId) return { userId: null, committed: null };

  const fetchImpl = options.fetch ?? fetch;
  const userId = authenticatedUserId;
  if (!UUID_PATTERN.test(options.requestId)) return { userId, committed: null };

  const encodedUserId = encodeURIComponent(userId);
  const encodedRequestId = encodeURIComponent(options.requestId);
  const headers = requestHeaders(options.apiKey, options.authorization!);
  const messagesResponse = await fetchImpl(
    `${options.supabaseUrl}/rest/v1/messages?select=id,request_id,role,card_type,card_content,extracted_concept&user_id=eq.${encodedUserId}&request_id=eq.${encodedRequestId}&role=in.(user,assistant)`,
    { headers },
  );
  const messages = await checkedJson(
    messagesResponse,
    "resolve committed messages",
  );
  if (!Array.isArray(messages)) {
    throw new Error("resolve committed messages returned an invalid response");
  }

  const userMessage = (messages as MessageRow[]).find((row) =>
    row.role === "user"
  );
  const assistantMessage = (messages as MessageRow[]).find((row) =>
    row.role === "assistant"
  );
  if (!userMessage || !assistantMessage) return { userId, committed: null };
  if (
    userMessage.request_id !== options.requestId ||
    assistantMessage.request_id !== options.requestId ||
    !isUuid(userMessage.id) ||
    !isUuid(assistantMessage.id)
  ) {
    throw new Error("stored message request_id mismatch or durable ID missing");
  }
  const storedCardContent = asObject(assistantMessage.card_content);
  if (typeof assistantMessage.card_type !== "string" || !storedCardContent) {
    throw new Error("stored assistant card is incomplete");
  }

  const materialResponse = await fetchImpl(
    `${options.supabaseUrl}/rest/v1/materials?select=id,request_id&user_id=eq.${encodedUserId}&request_id=eq.${encodedRequestId}&limit=1`,
    { headers },
  );
  const materials = await checkedJson(
    materialResponse,
    "resolve committed material",
  );
  if (!Array.isArray(materials)) {
    throw new Error("resolve committed material returned an invalid response");
  }
  const material = materials[0] as MaterialRow | undefined;
  if (!material) return { userId, committed: null };
  if (
    material.request_id !== options.requestId || !isUuid(material.id)
  ) {
    throw new Error(
      "stored material request_id mismatch or durable ID missing",
    );
  }

  return {
    userId,
    committed: {
      request_id: options.requestId,
      user_message_id: userMessage.id,
      assistant_message_id: assistantMessage.id,
      material_id: material.id,
      card_type: assistantMessage.card_type,
      card_content: storedCardContent,
      extracted_concept: typeof assistantMessage.extracted_concept === "string"
        ? assistantMessage.extracted_concept
        : null,
      already_committed: true,
    },
  };
}

export async function authenticateCaller(
  options: AuthenticateCallerOptions,
): Promise<string | null> {
  const fetchImpl = options.fetch ?? fetch;
  if (!options.authorization) return null;

  const authResponse = await fetchImpl(`${options.supabaseUrl}/auth/v1/user`, {
    headers: requestHeaders(options.apiKey, options.authorization),
  });
  if (!authResponse.ok) {
    if (authResponse.status === 401 || authResponse.status === 403) {
      await authResponse.body?.cancel();
      return null;
    }
    const detail = await authResponse.text();
    throw new Error(
      `authentication failed with ${authResponse.status}${
        detail ? `: ${detail}` : ""
      }`,
    );
  }

  const authBody = asObject(await authResponse.json());
  const userId = typeof authBody?.id === "string" ? authBody.id : null;
  return userId;
}

export async function commitGeneratedContent(
  options: CommitGeneratedContentOptions,
): Promise<CommittedContent> {
  if (!options.authorization) {
    throw new Error("authorization is required for durable commit");
  }
  const fetchImpl = options.fetch ?? fetch;
  const response = await fetchImpl(
    `${options.supabaseUrl}/rest/v1/rpc/commit_generated_content`,
    {
      method: "POST",
      headers: {
        ...requestHeaders(options.apiKey, options.authorization),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_request_id: options.requestId,
        p_user_message: options.userMessage,
        p_assistant_message: options.assistantMessage,
        p_material: options.material,
        p_usage_date: options.usageDate,
        p_count_usage: options.countUsage ?? true,
      }),
    },
  );
  const body = await checkedJson(response, "commit_generated_content");
  return parseCommittedContent(body, options.requestId);
}

// ──────────────────────────────────────────────────────
// 生成次数限制 · 第 3 刀：服务键（service role）查询。
// 这两个调用只能走 service key（check_generation_quota_for_user 仅
// service_role 可执行；profiles 读走 service key 不依赖 RLS 策略形状）。
// ──────────────────────────────────────────────────────

export interface ServiceKeyConnection {
  supabaseUrl: string;
  serviceRoleKey: string;
  fetch?: FetchLike;
}

export interface GenerationQuotaStatus {
  usedCount: number;
  limit: number;
  allowed: boolean;
}

export async function checkGenerationQuotaForUser(
  options: ServiceKeyConnection & { userId: string; usageDate: string },
): Promise<GenerationQuotaStatus> {
  const fetchImpl = options.fetch ?? fetch;
  const response = await fetchImpl(
    `${options.supabaseUrl}/rest/v1/rpc/check_generation_quota_for_user`,
    {
      method: "POST",
      headers: {
        ...requestHeaders(
          options.serviceRoleKey,
          `Bearer ${options.serviceRoleKey}`,
        ),
        "Content-Type": "application/json",
        // RETURNS TABLE 的 RPC 在 PostgREST 默认回 JSON 数组；object 媒体
        // 类型让它直接回单对象（本函数恒返回一行）。2026-09-02 线上事故：
        // 不带这个头时真实 PostgREST 回数组、解析器按对象读 → 每次预检 502。
        // 解析侧另做数组容忍（见下），双保险。
        "Accept": "application/vnd.pgrst.object+json",
      },
      body: JSON.stringify({
        p_user_id: options.userId,
        p_usage_date: options.usageDate,
      }),
    },
  );
  const body = await checkedJson(response, "check_generation_quota_for_user");
  // 容忍两种形状：带了 object 头应回单对象；若仍回单行数组，取第一行。
  const row = asObject(Array.isArray(body) ? body[0] : body);
  if (
    !row ||
    typeof row.used_count !== "number" ||
    typeof row.limit !== "number" ||
    typeof row.allowed !== "boolean"
  ) {
    throw new Error(
      "check_generation_quota_for_user returned an invalid response",
    );
  }
  return {
    usedCount: row.used_count,
    limit: row.limit,
    allowed: row.allowed,
  };
}

/**
 * 服务端 onboarding 判据：profile 行存在且 onboarding_completed_at 仍为空。
 * 与 commit RPC 的豁免门同口径——profile 行缺失按「不免」处理（RPC 里
 * FOUND=false 时 COALESCE 落到 false），两个判定结果必须一致。
 */
export async function isOnboardingStillOpen(
  options: ServiceKeyConnection & { userId: string },
): Promise<boolean> {
  const fetchImpl = options.fetch ?? fetch;
  const encodedUserId = encodeURIComponent(options.userId);
  const response = await fetchImpl(
    `${options.supabaseUrl}/rest/v1/profiles?select=onboarding_completed_at&id=eq.${encodedUserId}`,
    {
      headers: requestHeaders(
        options.serviceRoleKey,
        `Bearer ${options.serviceRoleKey}`,
      ),
    },
  );
  const rows = await checkedJson(response, "resolve onboarding completion");
  if (!Array.isArray(rows)) {
    throw new Error("resolve onboarding completion returned an invalid response");
  }
  const profile = (rows as Array<{ onboarding_completed_at?: unknown }>)[0];
  if (!profile) return false;
  return profile.onboarding_completed_at == null;
}
