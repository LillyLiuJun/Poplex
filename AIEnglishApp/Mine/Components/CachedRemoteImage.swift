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
    }

    init(signedUrl: String, stableKey: String, @ViewBuilder placeholder: () -> Placeholder) {
        self.signedUrl = signedUrl
        self.stableKey = stableKey
        self.placeholder = placeholder()
    }

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: stableKey) {
            if let cached = ImageCache.shared.get(stableKey) {
                image = cached
                return
            }
            guard let url = URL(string: signedUrl),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let ui = UIImage(data: data) else { return }
            ImageCache.shared.set(ui, forKey: stableKey)
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
