import SwiftUI

/// Tab2 Hero 卡顶部拼图（设计方案 §6 / demo tab2-hero-collage-redesign.html）。
/// 只铺用户真实照片，1–5 张按 c1–c5 排布；叠加分类标签(左上) / pops(右上) / +N(左下)。
/// 照片已由 RPC 排好序（featured 若有图置 slot 0，§3.6），本视图不再排序。
struct HeroCollageView: View {
    let photos: [Tab2HeroPhoto]      // 已排序，最多取前 5
    let categoryLabel: String        // 英文分类名（大写展示）
    let popsText: String             // e.g. "34 pops"
    let moreCount: Int               // +N more moments；≤0 不显示

    private let gap: CGFloat = 3
    private var tiles: [Tab2HeroPhoto] { Array(photos.prefix(5)) }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                collage(in: geo.size)
            }
            HeroTopOverlay(categoryLabel: categoryLabel, popsText: popsText, moreCount: moreCount)
        }
        .frame(height: 178)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Collage layouts (c1–c5)

    @ViewBuilder
    private func collage(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        switch tiles.count {
        case 0:
            placeholder                       // 防御：无图应走 CategoryPresetArtView
        case 1:
            tile(tiles[0], w, h)
        case 2:
            let cw = (w - gap) / 2
            HStack(spacing: gap) { tile(tiles[0], cw, h); tile(tiles[1], cw, h) }
        case 3:
            let lw = (w - gap) * 0.62, rw = w - gap - lw, rh = (h - gap) / 2
            HStack(spacing: gap) {
                tile(tiles[0], lw, h)
                VStack(spacing: gap) { tile(tiles[1], rw, rh); tile(tiles[2], rw, rh) }
            }
        case 4:
            let cw = (w - gap) / 2, ch = (h - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) { tile(tiles[0], cw, ch); tile(tiles[1], cw, ch) }
                HStack(spacing: gap) { tile(tiles[2], cw, ch); tile(tiles[3], cw, ch) }
            }
        default:  // 5
            let lw = (w - gap) * 0.44, rw = w - gap - lw
            let rcw = (rw - gap) / 2, ch = (h - gap) / 2
            HStack(spacing: gap) {
                tile(tiles[0], lw, h)
                VStack(spacing: gap) {
                    HStack(spacing: gap) { tile(tiles[1], rcw, ch); tile(tiles[2], rcw, ch) }
                    HStack(spacing: gap) { tile(tiles[3], rcw, ch); tile(tiles[4], rcw, ch) }
                }
            }
        }
    }

    private func tile(_ photo: Tab2HeroPhoto, _ w: CGFloat, _ h: CGFloat) -> some View {
        CachedRemoteImage(
            signedUrl: photo.imageUrl,
            stableKey: photo.stableImageKey ?? photo.imageUrl,
            placeholder: { placeholder }
        )
        .frame(width: w, height: h)
        .clipped()
        .saturation(0.9)
    }

    private var placeholder: some View {
        Rectangle().fill(AppTheme.Color.cardBg)
    }
}

// MARK: - Hero 顶部叠加层（拼图 / 预设图共用）
// 渐变暗角 + 分类标签(左上) + pops(右上) + +N more moments(左下)。

struct HeroTopOverlay: View {
    let categoryLabel: String
    let popsText: String
    let moreCount: Int

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.36), location: 0.0),
                    .init(color: .clear,               location: 0.32),
                    .init(color: .clear,               location: 0.60),
                    .init(color: .black.opacity(0.34), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                HStack(alignment: .center) {
                    Text(categoryLabel.uppercased())
                        .font(AppTheme.Font.pos)
                        .fontWeight(.bold)
                        .tracking(1.3)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    Spacer()
                    Text(popsText)
                        .font(AppTheme.Font.cardMeta)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Space.paddingS)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.24), in: Capsule())
                }
                Spacer()
                if moreCount > 0 {
                    HStack {
                        Text("+\(moreCount) more moments")
                            .font(AppTheme.Font.cardMeta)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
