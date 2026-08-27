// Storage 清理逻辑单独成模块。
//
// 拆出来的唯一原因是**可测**：`index.ts` 顶层有 `Deno.serve(...)`，
// 测试文件一 import 就会真的起一个 HTTP 服务器——于是 `deno test` 必须带
// `--allow-net --allow-env` 才能跑，还会占端口。纯逻辑放这里后，
// 测试不需要任何权限，`deno test` 原样就能跑。

const STORAGE_PAGE_SIZE = 1000;
/// 分页循环的安全上限：单用户 100 万张图已远超任何真实场景。
/// 触到它说明逻辑出了问题（例如删除一直失败却没推进 offset），
/// 宁可提前退出并如实上报，也不要让函数无限跑到平台超时。
const STORAGE_MAX_PAGES = 1000;

export interface StorageCleanupResult {
  removed: number;
  /// 确认未能删除的对象数。
  ///
  /// **注意语义**：这是「至少这么多」的下界，不是精确残留数——
  /// 列举失败时无从知道总量，用哨兵 1；触达页上限时可能为 0 但 complete 仍为 false。
  /// 判断「是否清干净」请一律看 `complete`，别拿 `failed` 当精确计数用。
  failed: number;
  /// 是否**确认**已清空。false 表示可能仍有用户图片留在服务器上。
  complete: boolean;
}

export interface StorageDeps {
  fetch: typeof fetch;
  baseUrl: string;
  headers: Record<string, string>;
  bucket: string;
  pageSize?: number;
  maxPages?: number;
}

/// 删除该用户在 Storage 里的全部图片。
///
/// 此前的实现有两个问题，都会让「已删除全部数据」这个承诺落空：
///   1. 只取前 1000 条（`limit: 1000, offset: 0`），超出部分永远留在服务器上；
///   2. 列举失败直接 return、删除失败只 console.warn，外层照样返回 success。
///
/// 现在分页取完，并如实返回是否确认清空——调用方据此决定能否宣称成功。
export async function deleteStorageObjects(
  uid: string,
  deps: StorageDeps,
): Promise<StorageCleanupResult> {
  const pageSize = deps.pageSize ?? STORAGE_PAGE_SIZE;
  const maxPages = deps.maxPages ?? STORAGE_MAX_PAGES;
  let offset = 0;
  let removed = 0;
  let failed = 0;

  for (let page = 0; page < maxPages; page++) {
    const listRes = await deps.fetch(
      `${deps.baseUrl}/storage/v1/object/list/${deps.bucket}`,
      {
        method: "POST",
        headers: deps.headers,
        body: JSON.stringify({ prefix: `${uid}/`, limit: pageSize, offset }),
      },
    );
    if (!listRes.ok) {
      console.warn("[delete-account] storage list failed at offset", offset);
      return { removed, failed: failed + 1, complete: false };
    }

    const objects: { name: string }[] = await listRes.json();
    if (!Array.isArray(objects) || objects.length === 0) {
      return { removed, failed, complete: failed === 0 };
    }

    const paths = objects.map((o) => `${uid}/${o.name}`);
    const delRes = await deps.fetch(
      `${deps.baseUrl}/storage/v1/object/${deps.bucket}`,
      {
        method: "DELETE",
        headers: deps.headers,
        body: JSON.stringify({ prefixes: paths }),
      },
    );

    if (delRes.ok) {
      removed += paths.length;
      // 删成功后**不推进 offset**：这些对象已从列表消失，下一次 offset=0
      // 取到的就是后续内容。推进反而会跳过同样多的对象。
    } else {
      console.warn("[delete-account] storage delete failed:", await delRes.text());
      failed += paths.length;
      // 删失败则**必须推进 offset**，否则同一页会被反复重试直到撞上 maxPages。
      //
      // 已知局限：这里假设批量 DELETE 是「整页成功或整页失败」。若 Storage
      // 实际删掉了部分对象却返回非 2xx，推进整页会跳过其中未删成功的那些。
      // 后果是 `complete` 已为 false（会如实告知用户），不会产生「谎称清空」，
      // 只是残留数偏小。彻底解决需逐个删除或重新列举比对，成本更高；
      // 当前按「宁可少报残留、绝不谎称清空」取舍。
      offset += objects.length;
    }

    if (objects.length < pageSize) {
      return { removed, failed, complete: failed === 0 };
    }
  }

  console.warn("[delete-account] storage cleanup hit page limit");
  return { removed, failed, complete: false };
}
