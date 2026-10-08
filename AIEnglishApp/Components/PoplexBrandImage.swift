import SwiftUI

// MARK: - 品牌图形（矢量素材，不打包字体、不实时排版）

/// 素材名 → asset catalog。imageset 都勾了 Preserve Vector Data。
/// 素材源文件在 `docs/brand/assets/`，以那里的 SVG 为准；这里只是 catalog 里的副本。
enum PoplexBrandAsset {
    /// 横排组合：单图形 + 暖墨字标。用在浅色背景上的页头。
    static let lockupMark = "PoplexLockupMark"
    /// 暖墨字标，**Template 渲染**：只给 Tab2 页脚签名着灰色用（品牌规范里唯一允许改色的场景）。
    static let wordmarkTemplate = "PoplexWordmarkInk"
    /// 单图形：与 `poplex-mark-orange.svg` 同一份路径，带固有尺寸（高 96pt）。
    /// 原为系统启动屏专用；2026-10-07 起启动屏改为纯暖纸，现由 `PoplexSproutMark` 使用。
    static let launchMark = "PoplexLaunchMark"

    /// `launchMark` 的固有高度。改它必须同步改 imageset 里 SVG 的 width/height。
    static let launchMarkHeight: CGFloat = 96
}

/// 横排组合：单图形 + 暖墨字标（`poplex-lockup-mark.svg`，画布 1087.9×400）。
///
/// 素材画布四周有留白：橙色图形的可见高度只占画布高的 83.3%，上沿离画布顶 8.3%，
/// 左沿离画布左 12.857 单位。所以**以图形可见高度为输入**，frame 高度由它推出，
/// 并把留白量暴露出来，让调用方把图形的可见边缘对到版面上。
/// 品牌规范：组合高度（frame）不低于 32pt。
struct PoplexLockupMark: View {
    static let minimumHeight: CGFloat = 32
    /// 图形可见高 / 画布高（333.3 / 400，测自 SVG）。
    static let markHeightRatio: CGFloat = 333.3 / 400
    /// 图形可见上沿离画布顶 / 画布高。
    static let topInsetRatio: CGFloat = 33.35 / 400
    /// 图形可见左沿离画布左 / 画布高（单位同为 SVG 画布单位，除以高度 400）。
    static let leadingInsetRatio: CGFloat = 12.857 / 400

    /// 图形的可见高度。
    let markHeight: CGFloat

    var frameHeight: CGFloat { Self.frameHeight(forMarkHeight: markHeight) }
    var topInset: CGFloat { frameHeight * Self.topInsetRatio }
    var leadingInset: CGFloat { frameHeight * Self.leadingInsetRatio }

    static func frameHeight(forMarkHeight h: CGFloat) -> CGFloat {
        max(h / markHeightRatio, minimumHeight)
    }

    var body: some View {
        Image(PoplexBrandAsset.lockupMark)
            .resizable()
            .scaledToFit()
            .frame(height: frameHeight)
            .accessibilityLabel("Poplex")
    }
}

/// 单色字标（`poplex-wordmark-ink.svg` 的 Template 渲染）。
/// 只用于 Tab2 页脚签名，颜色由调用方传页脚灰色 token。
///
/// 尺寸输入是 **P 的字高**（与旧版字标同一个口径）：素材画布含上升部和下降部，
/// P 的字高只占画布高的 60.9%，frame 高度由它推出。
struct PoplexWordmarkMono: View {
    /// P 的字高 / 画布高（700.5 / 1150.2，测自 SVG）。
    static let capHeightRatio: CGFloat = 700.5 / 1150.2

    let capHeight: CGFloat
    let color: Color

    var body: some View {
        Image(PoplexBrandAsset.wordmarkTemplate)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: capHeight / Self.capHeightRatio)
            .foregroundStyle(color)
            .accessibilityLabel("Poplex")
    }
}

/// 单个芽苗 P 标志（来自 `poplex-launch-mark.svg` 矢量，固有宽高比 447.44 : 586.44）。
/// 支持品牌橙原色渲染，或单色 Template 渲染（例如 Tab2 底部灰色）。
struct PoplexSproutMark: View {
    static let aspectRatio: CGFloat = 447.44 / 586.44

    let height: CGFloat
    var tintColor: Color? = nil

    var body: some View {
        if let tintColor {
            Image(PoplexBrandAsset.launchMark)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: height * Self.aspectRatio, height: height)
                .foregroundStyle(tintColor)
                .accessibilityLabel("Poplex Mark")
        } else {
            Image(PoplexBrandAsset.launchMark)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: height * Self.aspectRatio, height: height)
                .accessibilityLabel("Poplex Mark")
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        PoplexLockupMark(markHeight: 40)
        PoplexWordmarkMono(capHeight: 12.5, color: AppTheme.Color.textMuted)
        HStack(spacing: 16) {
            PoplexSproutMark(height: 24)
            PoplexSproutMark(height: 24, tintColor: AppTheme.Color.textMuted)
        }
    }
    .padding(40)
    .background(AppTheme.Color.pageBg)
}
