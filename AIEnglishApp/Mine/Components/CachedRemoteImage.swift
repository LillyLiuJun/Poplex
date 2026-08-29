import SwiftUI
import UIKit

// 用 stableKey（material_id 或 source_image_path）作为缓存 key，
// 而非签名 URL 本身——签名 URL 每次重签都会变，用它当 key 会导致每次刷新都重新下载同一张图。
struct CachedRemoteImage<Placeholder: View>: View {
    let signedUrl: String
    let stableKey: String
    let placeholder: Placeholder

    init(signedUrl: String, stableKey: String, placeholder: Placeholder) {
        self.signedUrl = signedUrl
        self.stableKey = stableKey
        self.placeholder = placeholder
        // 在视图首次 body 计算前读取两级缓存，避免「已缓存却先闪占位」的一帧。
        // 图片气泡尺寸固定且较小；未命中才进入下方异步网络路径。
        self._image = State(initialValue: ImageCache.shared.get(stableKey))
    }

    init(signedUrl: String, stableKey: String, @ViewBuilder placeholder: () -> Placeholder) {
        self.init(signedUrl: signedUrl, stableKey: stableKey, placeholder: placeholder())
    }

    @State private var image: UIImage?
    // Download failed (network error, timeout, or bad data — the guard below
    // doesn't distinguish which). Without this, a failure looked identical to
    // "still loading": image stayed nil forever, placeholder kept spinning, no
    // way to tell the two apart (code review finding). MVP-only fix: show a
    // distinct static state instead of an infinitely spinning lie. It does not
    // retry — reconnecting won't revive it until this view is torn down and
    // rebuilt (e.g. scrolling off/back on, or leaving and reopening the tab).
    // Tap-to-retry and network-aware auto-retry are recorded in
    // 优化需求全量清单_v1.md, not built here.
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didFail {
                ImageLoadFailedPlaceholder()
            } else {
                placeholder
            }
        }
        .task(id: stableKey) {
            // Reset both — not just didFail. This view's identity can outlive a
            // single stableKey (e.g. Tab2's HeroCollageView reuses the same grid
            // slot across a refresh with no .id()), so `image` from the PREVIOUS
            // stableKey would otherwise still be non-nil here: the `if let image`
            // branch in body would keep showing the stale photo through the new
            // download, and would still win over `didFail` even if the new
            // download fails — the failed-state placeholder would never render
            // (code review finding). Both resets happen before the first `await`
            // below, in the same synchronous scope as a cache hit's `image =
            // cached`, so a cache hit never flashes an empty frame in between.
            image = nil
            didFail = false
            if let cached = ImageCache.shared.get(stableKey) {
                image = cached
                return
            }
            guard let url = URL(string: signedUrl) else {
                didFail = true
                return
            }
            // Snapshot which "clear epoch" this download started in. Account
            // deletion calls ImageCache.shared.clearAll() from a completely
            // separate flow (Settings), with no way to cancel image tasks that
            // happen to be in flight elsewhere in the app at that moment —
            // Task.isCancelled alone can't see that (this task was never
            // cancelled, it's just unlucky timing). Without this check, a
            // download that finishes after clearAll() would write the previous
            // account's photo straight back to disk right after the app told
            // the user "all local data cleared" (code review finding).
            let generationAtStart = ImageCache.shared.generation
            // A stale task (superseded when stableKey changed again, hence
            // cancelled) must not write shared state on top of whatever the
            // newer task already did. `try?` alone can't tell "genuinely
            // failed" apart from "cancelled" — both throw here — so check
            // Task.isCancelled explicitly before treating a thrown error as a
            // real failure (code review finding).
            let data: Data
            do {
                (data, _) = try await URLSession.shared.data(from: url)
            } catch {
                if !Task.isCancelled { didFail = true }
                return
            }
            guard let ui = UIImage(data: data) else {
                if !Task.isCancelled { didFail = true }
                return
            }
            // Checking the generation and writing must be one atomic step, not
            // two — a separate "check, then write" leaves a window for
            // clearAll() to run in between: the check passes, then the write
            // lands right after the clear finished, resurrecting the previous
            // account's photo (code review finding on the first version of
            // this fix). setIfCurrent does both under the same lock clearAll()
            // uses to bump the generation.
            guard ImageCache.shared.setIfCurrent(ui, forKey: stableKey, expectedGeneration: generationAtStart) else { return }
            // Only the shared `image` write is gated on cancellation: a
            // cancelled task's success can otherwise race past a newer task
            // and clobber it with the wrong photo. The cache write above is
            // safe regardless of cancellation — it's keyed to THIS stableKey
            // and helps whoever needs it next.
            guard !Task.isCancelled else { return }
            image = ui
        }
    }
}

// L1 内存 + L2 磁盘双层缓存
// key = stableKey（Storage 路径），跨 session 稳定，重签 URL 不影响命中
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let memory = NSCache<NSString, UIImage>()
    private let diskDir: URL
    // Bumped by clearAll(). A download that started before a clear can check
    // this after it finishes to tell "the cache I'm about to write into is
    // still the same one I started with" from "an account deletion cleared it
    // out from under me" — see CachedRemoteImage.task's generationAtStart.
    //
    // Locked, not a plain Int: clearAll() and a CachedRemoteImage.task's read
    // of `generation` run on different threads with no other ordering between
    // them (this class is @unchecked Sendable precisely because it does its
    // own synchronization) — an unguarded Int here would be a real data race,
    // not just a theoretical one.
    private let lock = NSLock()
    private var _generation = 0
    var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return _generation
    }

    private init() {
        memory.countLimit = 100
        memory.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDir = caches.appendingPathComponent("img_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    func get(_ key: String) -> UIImage? {
        if let img = memory.object(forKey: key as NSString) { return img }
        if let data = try? Data(contentsOf: diskPath(for: key)),
           let img = UIImage(data: data) {
            memory.setObject(img, forKey: key as NSString)
            return img
        }
        return nil
    }

    func set(_ image: UIImage, forKey key: String) {
        writeUnlocked(image, forKey: key)
    }

    /// Atomically checks `expectedGeneration` against the current generation
    /// and writes only if they still match, under the same lock clearAll()
    /// uses to bump the generation. Checking and writing as two separate
    /// steps (read `generation`, then call `set`) leaves a window for
    /// clearAll() to run in between them — the check would pass, then the
    /// write lands right after the clear finished, resurrecting a stale
    /// (possibly deleted-account's) photo (code review finding).
    /// - Returns: `false`, without writing, when the generation has moved on.
    ///
    /// **Known residual race, accepted (code review, 2026-08-29):** a brand-new
    /// download task that takes its `generationAtStart` snapshot *after*
    /// clearAll() has already bumped it will legitimately match here and
    /// write — even though it's still the deleted account's photo. Closing
    /// this fully needs either a task registry (clearAll() cancels and awaits
    /// every in-flight download before returning) or a cross-check against
    /// live auth state, both bigger than this cache class should own.
    /// Left open because the leak this allows is self-bounded: `stableKey`
    /// embeds the old account's userId, a post-deletion account is always a
    /// fresh anonymous user with a different id, so no live code path ever
    /// requests this key again — the file is a true orphan, invisible to the
    /// app, and gets swept by the very next clearAll() regardless of key.
    @discardableResult
    func setIfCurrent(_ image: UIImage, forKey key: String, expectedGeneration: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _generation == expectedGeneration else { return false }
        writeUnlocked(image, forKey: key)
        return true
    }

    private func writeUnlocked(_ image: UIImage, forKey key: String) {
        if let data = image.jpegData(compressionQuality: 0.85) {
            memory.setObject(image, forKey: key as NSString, cost: data.count)
            try? data.write(to: diskPath(for: key), options: .atomic)
        } else {
            memory.setObject(image, forKey: key as NSString)
        }
    }

    func clearMemoryForTesting() { memory.removeAllObjects() }

    /// 清空内存与磁盘两层——仅用于注销 / 删除账号。
    ///
    /// 这里存的是**用户自己上传的照片**。删号后若不清，照片仍留在设备上，
    /// 而 UI 已经告诉用户「全部数据已删除」——那不是清理不彻底，是承诺没兑现。
    ///
    /// 逐个删文件而不是删整个目录：目录被 App 持有（init 里创建过），
    /// 删掉后同一进程内的后续写入会静默失败。
    /// - Returns: 未能删除的文件数。调用方据此判断能否宣称「已清空」。
    @discardableResult
    func clearAll() -> Int {
        lock.lock()
        _generation += 1
        lock.unlock()
        memory.removeAllObjects()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskDir, includingPropertiesForKeys: nil
        ) else {
            // 目录读不出来 → 无法确认是否已空，按「有残留」上报
            return fm.fileExists(atPath: diskDir.path) ? 1 : 0
        }
        var failed = 0
        for file in files {
            do { try fm.removeItem(at: file) } catch { failed += 1 }
        }
        // 目录可能已被系统回收（Caches 会被自动清理），或刚被上面删空。
        // 不重建的话，同一进程内后续 set() 会静默写不进磁盘，只剩内存缓存。
        try? fm.createDirectory(at: diskDir, withIntermediateDirectories: true)
        return failed
    }

    private func diskPath(for key: String) -> URL {
        // key 通常是 "bucket/userId/uuid.jpg"，取最后两段作为文件名避免冲突
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return diskDir.appendingPathComponent(safe + ".jpg")
    }
}
