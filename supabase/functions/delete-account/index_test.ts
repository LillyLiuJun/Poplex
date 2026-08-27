import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { deleteStorageObjects } from "./storage.ts";

const UID = "11111111-1111-1111-1111-111111111111";
const BASE = "http://localhost:54321";
const BUCKET = "material_images";

/// 用一个内存里的假 Storage 驱动测试：
/// list 按 offset/limit 切片，delete 真的把对象从数组里移除——
/// 这样「删成功后不推进 offset」这条才有意义可验，用固定 stub 是验不出来的。
function makeStorage(opts: {
  objects: string[];
  failListAtOffset?: number;
  failDeleteForNames?: (names: string[]) => boolean;
  /// 「删掉一部分却返回非 2xx」——模拟 Storage 的非原子批删语义。
  /// 返回值是本次实际被删掉的对象名。
  partialDeleteFor?: (names: string[]) => string[];
}) {
  const remaining = [...opts.objects];
  const listCalls: number[] = [];
  let deleteCalls = 0;

  const fetchImpl = (async (url: string | URL, init?: RequestInit) => {
    const u = String(url);
    if (u.includes("/object/list/")) {
      const body = JSON.parse(String(init?.body ?? "{}"));
      listCalls.push(body.offset);
      if (opts.failListAtOffset !== undefined && body.offset === opts.failListAtOffset) {
        return new Response("boom", { status: 500 });
      }
      const page = remaining
        .slice(body.offset, body.offset + body.limit)
        .map((name) => ({ name }));
      return new Response(JSON.stringify(page), { status: 200 });
    }
    if (u.includes(`/object/${BUCKET}`)) {
      deleteCalls++;
      const body = JSON.parse(String(init?.body ?? "{}"));
      const names: string[] = body.prefixes.map((p: string) => p.replace(`${UID}/`, ""));
      if (opts.partialDeleteFor) {
        for (const n of opts.partialDeleteFor(names)) {
          const i = remaining.indexOf(n);
          if (i >= 0) remaining.splice(i, 1);
        }
        return new Response("partial", { status: 500 });
      }
      if (opts.failDeleteForNames?.(names)) {
        return new Response("nope", { status: 500 });
      }
      for (const n of names) {
        const i = remaining.indexOf(n);
        if (i >= 0) remaining.splice(i, 1);
      }
      return new Response("{}", { status: 200 });
    }
    throw new Error("unexpected url " + u);
  }) as unknown as typeof fetch;

  return {
    deps: { fetch: fetchImpl, baseUrl: BASE, headers: {}, bucket: BUCKET, pageSize: 2 },
    remaining,
    listCalls,
    deleteCount: () => deleteCalls,
  };
}

Deno.test("清空少于一页的对象并确认完成", async () => {
  const s = makeStorage({ objects: ["a.jpg"] });
  const r = await deleteStorageObjects(UID, s.deps);
  assertEquals(r, { removed: 1, failed: 0, complete: true });
  assertEquals(s.remaining.length, 0);
});

Deno.test("超过一页时继续分页，不再只删前 N 个", async () => {
  // 旧实现写死 limit:1000 / offset:0，第 1000 张之后的图永远留在服务器上。
  // pageSize=2、5 个对象 → 必须全部删掉。
  const s = makeStorage({ objects: ["a", "b", "c", "d", "e"] });
  const r = await deleteStorageObjects(UID, s.deps);
  assertEquals(r.removed, 5);
  assertEquals(r.complete, true);
  assertEquals(s.remaining.length, 0);
});

Deno.test("删除成功后不推进 offset —— 推进会跳过同样多的对象", async () => {
  const s = makeStorage({ objects: ["a", "b", "c", "d"] });
  await deleteStorageObjects(UID, s.deps);
  // 已删对象会从列表消失，所以每次都该从 0 开始取
  assertEquals(s.listCalls.every((o) => o === 0), true);
  assertEquals(s.remaining.length, 0);
});

Deno.test("列举失败时如实上报未完成，不谎称已清空", async () => {
  const s = makeStorage({ objects: ["a", "b", "c", "d"], failListAtOffset: 0 });
  const r = await deleteStorageObjects(UID, s.deps);
  assertEquals(r.complete, false);
  assertEquals(r.removed, 0);
});

Deno.test("删除失败时推进 offset 避免死循环，并上报残留数", async () => {
  // 第一页删不掉：必须跳过它继续，否则同一页会被反复重试直到撞上限
  const s = makeStorage({
    objects: ["a", "b", "c", "d"],
    failDeleteForNames: (names) => names.includes("a"),
  });
  const r = await deleteStorageObjects(UID, s.deps);
  assertEquals(r.complete, false);
  assertEquals(r.failed, 2);      // 失败那一页的两个对象
  assertEquals(r.removed, 2);     // 后一页仍被删掉
  assertEquals(s.remaining.sort(), ["a", "b"]);
});

Deno.test("空 bucket 直接返回已完成", async () => {
  const s = makeStorage({ objects: [] });
  const r = await deleteStorageObjects(UID, s.deps);
  assertEquals(r, { removed: 0, failed: 0, complete: true });
  assertEquals(s.deleteCount(), 0);   // 没有对象就不该发删除请求
});

Deno.test("批删「部分成功却返回非 2xx」：会跳项，但绝不谎称已清空", async () => {
  // 这条不是在验证「正确」，而是把当前的取舍锁成可执行规格。
  //
  // Storage 的批量 DELETE 若删掉了一部分却返回非 2xx，我们按整页推进 offset，
  // 于是页内未删成功的对象会被跳过 —— 残留数偏小。
  // 之所以接受：`complete` 仍为 false，用户照样收到「有残留」提示，
  // 不会出现「谎称已清空」。彻底解决需逐个删除或重新列举比对，成本高得多。
  //
  // 若将来改成逐个删除或列举比对，本测试应当失败 —— 那正是提醒你更新它的信号。
  const s = makeStorage({
    objects: ["a", "b", "c", "d"],
    partialDeleteFor: (names) => names.slice(0, 1),   // 只删掉每页第一个
  });

  const r = await deleteStorageObjects(UID, s.deps);

  // 最关键的一条：不管跳了多少，都必须如实报告「没清干净」
  assertEquals(r.complete, false);
  // 确实有对象被跳过 —— 这是已知局限，不是回归
  assertEquals(s.remaining.length > 0, true);
});
