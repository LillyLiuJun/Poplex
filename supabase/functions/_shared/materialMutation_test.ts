import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createMaterialMutationHandler,
  type MaterialMutation,
} from "./materialMutation.ts";

const BASE_URL = "http://localhost:54321";
const SERVICE_KEY = "service-key";
const USER_ID = "11111111-1111-1111-1111-111111111111";
const MATERIAL_ID = "22222222-2222-2222-2222-222222222222";

function makeHandler(
  mutation: MaterialMutation,
  options: { userId?: string; rows?: unknown[] } = {},
) {
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const handler = createMaterialMutationHandler(mutation, {
    supabaseUrl: BASE_URL,
    serviceRoleKey: SERVICE_KEY,
    now: () => new Date("2026-08-31T12:00:00.000Z"),
    fetch: (async (url: string | URL, init?: RequestInit) => {
      const target = String(url);
      calls.push({ url: target, init });
      if (target.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ id: options.userId ?? USER_ID }), {
          status: 200,
        });
      }
      if (target.includes("/rest/v1/materials")) {
        return new Response(
          JSON.stringify(options.rows ?? [{ id: MATERIAL_ID }]),
          { status: 200 },
        );
      }
      throw new Error(`unexpected request: ${target}`);
    }) as typeof fetch,
  });
  return { handler, calls };
}

for (const mutation of ["delete", "restore"] as const) {
  Deno.test(`${mutation} material authenticates the caller and constrains the update to that caller`, async () => {
    const { handler, calls } = makeHandler(mutation);
    const response = await handler(
      new Request(`${BASE_URL}/functions/v1/${mutation}-material`, {
        method: "POST",
        headers: {
          "Authorization": "Bearer user-jwt",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ id: MATERIAL_ID }),
      }),
    );

    assertEquals(response.status, 200);
    assertEquals(await response.json(), { ok: true });
    assertEquals(calls.length, 2);
    assertStringIncludes(
      calls[1].url,
      `id=eq.${MATERIAL_ID}&user_id=eq.${USER_ID}`,
    );
    assertEquals(
      JSON.parse(String(calls[1].init?.body)).deleted_at,
      mutation === "delete" ? "2026-08-31T12:00:00.000Z" : null,
    );
  });
}

Deno.test("material mutation rejects a request without a verified user", async () => {
  const { handler, calls } = makeHandler("delete");
  const response = await handler(
    new Request(`${BASE_URL}/functions/v1/delete-material`, {
      method: "POST",
      body: JSON.stringify({ id: MATERIAL_ID }),
    }),
  );

  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "unauthorized" });
  assertEquals(calls.length, 0);
});

Deno.test("material mutation does not report a cross-user or absent material as success", async () => {
  const { handler } = makeHandler("restore", { rows: [] });
  const response = await handler(
    new Request(`${BASE_URL}/functions/v1/restore-material`, {
      method: "POST",
      headers: {
        "Authorization": "Bearer user-jwt",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ id: MATERIAL_ID }),
    }),
  );

  assertEquals(response.status, 404);
  assertEquals(await response.json(), { error: "not_found" });
});

Deno.test("material mutation returns a controlled error when its database call throws", async () => {
  const handler = createMaterialMutationHandler("delete", {
    supabaseUrl: BASE_URL,
    serviceRoleKey: SERVICE_KEY,
    fetch: (async () => {
      throw new Error("network unavailable");
    }) as typeof fetch,
  });
  const response = await handler(
    new Request(`${BASE_URL}/functions/v1/delete-material`, {
      method: "POST",
      headers: {
        "Authorization": "Bearer user-jwt",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ id: MATERIAL_ID }),
    }),
  );

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "internal_error" });
});
