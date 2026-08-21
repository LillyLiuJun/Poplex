import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createReconcileHandler } from "./index.ts";

const SUPABASE_URL = "http://localhost:54321";
const USER_ID = "11111111-1111-1111-1111-111111111111";
const SECRET = "reconcile-secret";
const FIXED_NOW = Date.parse("2026-08-21T12:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;

function iso(ts: number): string {
  return new Date(ts).toISOString();
}

function req(opts: {
  auth?: string | null;
  secret?: string | null;
} = {}): Request {
  const headers: HeadersInit = {};
  if (opts.auth !== null) {
    headers["Authorization"] = opts.auth ?? "Bearer good-token";
  }
  if (opts.secret !== null) {
    headers["x-reconcile-secret"] = opts.secret ?? SECRET;
  }
  return new Request("http://localhost/reconcile-orphan-images", {
    method: "POST",
    headers,
  });
}

interface ObjectEntry {
  name: string;
  created_at: string;
}

interface FakeOpts {
  authOk?: boolean;
  messageUrls?: Array<string | null>;
  materialPaths?: Array<string | null>;
  messageStatus?: number;
  materialStatus?: number;
  objects?: ObjectEntry[];
  listStatus?: number;
  deleteStatus?: number;
  onDeleteBodies?: (batch: string[]) => void;
}

function fakeFetch(opts: FakeOpts = {}): typeof fetch {
  const authOk = opts.authOk ?? true;
  const messageUrls = opts.messageUrls ?? [];
  const materialPaths = opts.materialPaths ?? [];
  const objects = opts.objects ?? [];
  const listStatus = opts.listStatus ?? 200;
  const deleteStatus = opts.deleteStatus ?? 200;
  return (async (input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    const method = init?.method ?? "GET";

    if (url.includes("/auth/v1/user")) {
      if (!authOk) {
        return new Response(JSON.stringify({ error: "invalid token" }), {
          status: 401,
        });
      }
      return new Response(JSON.stringify({ id: USER_ID }), { status: 200 });
    }

    if (url.includes("/rest/v1/messages")) {
      const messageStatus = opts.messageStatus ?? 200;
      if (messageStatus !== 200) {
        return new Response(JSON.stringify({ error: "messages failed" }), {
          status: messageStatus,
        });
      }
      return new Response(
        JSON.stringify(messageUrls.map((image_url) => ({ image_url }))),
        { status: 200 },
      );
    }

    if (url.includes("/rest/v1/materials")) {
      const materialStatus = opts.materialStatus ?? 200;
      if (materialStatus !== 200) {
        return new Response(JSON.stringify({ error: "materials failed" }), {
          status: materialStatus,
        });
      }
      return new Response(
        JSON.stringify(materialPaths.map((p) => ({ source_image_path: p }))),
        { status: 200 },
      );
    }

    if (url.includes("/storage/v1/object/list/")) {
      if (listStatus !== 200) {
        return new Response(JSON.stringify({ error: "list failed" }), {
          status: listStatus,
        });
      }
      const body = JSON.parse(String(init?.body ?? "{}"));
      const offset: number = body.offset ?? 0;
      return new Response(
        JSON.stringify(objects.slice(offset, offset + 1000)),
        { status: 200 },
      );
    }

    if (url.includes("/storage/v1/object/") && method === "DELETE") {
      if (deleteStatus !== 200) {
        return new Response(JSON.stringify({ error: "delete failed" }), {
          status: deleteStatus,
        });
      }
      const body = JSON.parse(String(init?.body ?? "{}"));
      opts.onDeleteBodies?.([...(body.prefixes ?? [])] as string[]);
      return new Response(JSON.stringify([]), { status: 200 });
    }

    throw new Error(`unexpected fetch: ${method} ${url}`);
  }) as unknown as typeof fetch;
}

function makeHandler(
  fetchImpl: typeof fetch,
): (r: Request) => Promise<Response> {
  return createReconcileHandler({
    supabaseUrl: SUPABASE_URL,
    serviceKey: "svc-key",
    reconcileSecret: SECRET,
    fetch: fetchImpl,
    now: () => FIXED_NOW,
    minAgeMs: DAY_MS,
  });
}

Deno.test("unreferenced old objects are deleted", async () => {
  const objects = [
    { name: "a.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
    { name: "b.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
  ];
  const deleted: string[][] = [];
  const handler = makeHandler(fakeFetch({
    objects,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));

  const res = await handler(req());
  const body = await res.json();

  assertEquals(res.status, 200);
  assertEquals(body.scanned, 2);
  assertEquals(body.deleted, 2);
  assertEquals(body.kept_referenced, 0);
  assertEquals(body.kept_recent, 0);
  assertEquals(deleted.length, 1);
  assertEquals(
    deleted[0].sort(),
    [`${USER_ID}/a.jpg`, `${USER_ID}/b.jpg`].sort(),
  );
});

Deno.test("referenced objects are kept (messages and materials)", async () => {
  const objects = [
    { name: "ref-by-message.jpg", created_at: iso(FIXED_NOW - 3 * DAY_MS) },
    { name: "ref-by-material.jpg", created_at: iso(FIXED_NOW - 3 * DAY_MS) },
    { name: "asset-marked.jpg", created_at: iso(FIXED_NOW - 3 * DAY_MS) },
    { name: "orphan.jpg", created_at: iso(FIXED_NOW - 3 * DAY_MS) },
  ];
  const deleted: string[][] = [];
  const handler = makeHandler(fakeFetch({
    messageUrls: [
      `${USER_ID}/ref-by-message.jpg`,
      "asset:preset1", // 本地素材标记：不进引用集合，也不该造成误删
    ],
    materialPaths: [`${USER_ID}/ref-by-material.jpg`],
    objects,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));

  const res = await handler(req());
  const body = await res.json();

  assertEquals(res.status, 200);
  assertEquals(body.kept_referenced, 2);
  // asset-marked.jpg 在 Storage 里确实存在且无引用（"asset:" 标记本身不进引用集合），
  // 与 orphan.jpg 一样都属于孤儿 → 一并删除。
  assertEquals(body.deleted, 2);
  assertEquals(
    deleted[0].sort(),
    [`${USER_ID}/asset-marked.jpg`, `${USER_ID}/orphan.jpg`].sort(),
  );
});

Deno.test("recent unreferenced objects are kept (24h window)", async () => {
  const objects = [
    { name: "fresh.jpg", created_at: iso(FIXED_NOW - 1 * 60 * 60 * 1000) },
    { name: "stale.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
  ];
  const deleted: string[][] = [];
  const handler = makeHandler(fakeFetch({
    objects,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));

  const res = await handler(req());
  const body = await res.json();

  assertEquals(res.status, 200);
  assertEquals(body.kept_recent, 1);
  assertEquals(body.deleted, 1);
  assertEquals(deleted[0], [`${USER_ID}/stale.jpg`]);
});

Deno.test("object with missing created_at is kept (conservative)", async () => {
  const objects = [
    // created_at 缺失：宁可漏删不可误删
    { name: "no-date.jpg", created_at: null as unknown as string },
  ];
  const deleted: string[][] = [];
  const handler = makeHandler(fakeFetch({
    objects,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));

  const res = await handler(req());
  const body = await res.json();

  assertEquals(res.status, 200);
  assertEquals(body.kept_recent, 1);
  assertEquals(body.deleted, 0);
});

Deno.test("secret gate: missing or wrong secret is rejected", async () => {
  const handler = makeHandler(fakeFetch());

  const resMissing = await handler(req({ secret: null }));
  assertEquals(resMissing.status, 403);

  const resWrong = await handler(req({ secret: "wrong" }));
  assertEquals(resWrong.status, 403);
});

Deno.test("auth: missing header or invalid token is rejected", async () => {
  const handler = makeHandler(fakeFetch());

  const resMissing = await handler(req({ auth: null }));
  assertEquals(resMissing.status, 401);

  const resBad = makeHandler(fakeFetch({ authOk: false }));
  const res = await resBad(req());
  assertEquals(res.status, 401);
});

Deno.test("storage list failure returns 502 scan_failed", async () => {
  const handler = makeHandler(fakeFetch({ listStatus: 500 }));
  const res = await handler(req());
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error, "scan_failed");
});

Deno.test("storage delete failure returns 502 delete_failed", async () => {
  const objects = [
    { name: "a.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
  ];
  const handler = makeHandler(fakeFetch({ objects, deleteStatus: 500 }));
  const res = await handler(req());
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(body.error, "delete_failed");
  // 失败前的批次已删除的要如实回传（本测试里第一批就失败 → 空）
  assertEquals(body.deleted_paths, []);
});

Deno.test("reference fetch failure aborts the run — no deletions (fail closed)", async () => {
  const objects = [
    { name: "a.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
    { name: "b.jpg", created_at: iso(FIXED_NOW - 2 * DAY_MS) },
  ];
  const deleted: string[][] = [];

  // messages 引用查询失败：绝不能带着残缺名单进入删除流程
  const handlerMsg = makeHandler(fakeFetch({
    objects,
    messageStatus: 500,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));
  const resMsg = await handlerMsg(req());
  assertEquals(resMsg.status, 502);
  assertEquals((await resMsg.json()).error, "scan_failed");

  // materials 引用查询失败：同理
  const handlerMat = makeHandler(fakeFetch({
    objects,
    materialStatus: 500,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));
  const resMat = await handlerMat(req());
  assertEquals(resMat.status, 502);
  assertEquals((await resMat.json()).error, "scan_failed");

  // 两次运行都不得发出任何 DELETE
  assertEquals(deleted.length, 0);
});

Deno.test("pagination: second page is scanned and deleted too", async () => {
  const objects: ObjectEntry[] = [];
  for (let i = 0; i < 1002; i++) {
    objects.push({
      name: `img-${i}.jpg`,
      created_at: iso(FIXED_NOW - 2 * DAY_MS),
    });
  }
  const deleted: string[][] = [];
  const handler = makeHandler(fakeFetch({
    objects,
    onDeleteBodies: (batch) => deleted.push(batch),
  }));

  const res = await handler(req());
  const body = await res.json();

  assertEquals(res.status, 200);
  assertEquals(body.scanned, 1002);
  assertEquals(body.deleted, 1002);
  // 1002 个分两批 DELETE
  assertEquals(deleted.length, 2);
  assertEquals(deleted[0].length + deleted[1].length, 1002);
});
