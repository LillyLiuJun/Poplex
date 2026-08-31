export type MaterialMutation = "delete" | "restore";

export interface MaterialMutationDependencies {
  supabaseUrl: string;
  serviceRoleKey: string;
  fetch: typeof fetch;
  now: () => Date;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    );
}

export function createMaterialMutationHandler(
  mutation: MaterialMutation,
  overrides: Partial<MaterialMutationDependencies> = {},
): (req: Request) => Promise<Response> {
  const deps: MaterialMutationDependencies = {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    fetch: overrides.fetch ?? fetch,
    now: overrides.now ?? (() => new Date()),
    ...overrides,
  };

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !deps.supabaseUrl || !deps.serviceRoleKey) {
      return json({ error: "unauthorized" }, 401);
    }

    try {
      const userResponse = await deps.fetch(
        `${deps.supabaseUrl}/auth/v1/user`,
        {
          headers: {
            "Authorization": authHeader,
            "apikey": deps.serviceRoleKey,
          },
        },
      );
      if (!userResponse.ok) return json({ error: "unauthorized" }, 401);
      const user = await userResponse.json();
      if (!isUuid(user?.id)) return json({ error: "unauthorized" }, 401);

      const body = await req.json().catch(() => null);
      if (!body || !isUuid(body.id)) return json({ error: "missing_id" }, 400);

      const id = encodeURIComponent(body.id);
      const userId = encodeURIComponent(user.id);
      const updateResponse = await deps.fetch(
        `${deps.supabaseUrl}/rest/v1/materials?id=eq.${id}&user_id=eq.${userId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${deps.serviceRoleKey}`,
            "apikey": deps.serviceRoleKey,
            "Prefer": "return=representation",
          },
          body: JSON.stringify({
            deleted_at: mutation === "delete" ? deps.now().toISOString() : null,
          }),
        },
      );
      if (!updateResponse.ok) return json({ error: "db_error" }, 502);

      const rows = await updateResponse.json().catch(() => null);
      if (!Array.isArray(rows) || rows.length === 0) {
        return json({ error: "not_found" }, 404);
      }
      return json({ ok: true });
    } catch (error) {
      console.error(`[${mutation}-material] unexpected error`, error);
      return json({ error: "internal_error" }, 500);
    }
  };
}
