import SwiftUI
import UIKit

// 用 stableKey（material_id 或 source_image_path）作为缓存 key，
// 而非签名 URL 本身——签名 URL 每次重签都会变，用它当 key 会导致每次刷新都重新下载同一张图。
struct CachedRemoteImage<Placeholder: View>: View {
    let signedUrl: String
    let stableKey: String
    let placeholder: Placeholder

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

// 内存缓存：key = stableKey（material_id 或路径），重签 URL 不会导致重新下载
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
    }

    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
