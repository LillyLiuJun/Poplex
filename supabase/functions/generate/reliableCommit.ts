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
      }),
    },
  );
  const body = await checkedJson(response, "commit_generated_content");
  return parseCommittedContent(body, options.requestId);
}
