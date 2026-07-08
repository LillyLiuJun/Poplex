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
        memory.setObject(image, forKey: key as NSString)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: diskPath(for: key), options: .atomic)
        }
    }

    private func diskPath(for key: String) -> URL {
        // key 通常是 "bucket/userId/uuid.jpg"，取最后两段作为文件名避免冲突
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return diskDir.appendingPathComponent(safe + ".jpg")
    }
}
