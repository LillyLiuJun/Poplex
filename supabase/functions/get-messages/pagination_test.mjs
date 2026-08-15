import test from "node:test";
import assert from "node:assert/strict";

test("历史超过单页时会继续拉取，且保留全部消息顺序", async () => {
  const pagination = await import("./pagination.mjs");
  const pages = [
    Array.from({ length: 300 }, (_, index) => ({ id: index + 1 })),
    Array.from({ length: 2 }, (_, index) => ({ id: index + 301 })),
  ];

  const result = await pagination.fetchAllMessagePages(async (offset, limit) => {
    assert.equal(limit, 300);
    return pages[offset / limit] ?? [];
  });

  assert.equal(result.length, 302);
  assert.deepEqual(result.map((message) => message.id),
    Array.from({ length: 302 }, (_, index) => index + 1));
});
