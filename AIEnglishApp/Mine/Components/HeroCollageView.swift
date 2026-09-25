import SwiftUI

/// Tab2 Hero 卡顶部照片层（刀 4b 按规格 v3「图片取值」恢复）。
/// 只渲染**第一条有效活动**的封面——cover 由 `Tab2ActivityDisplay.photoCover` 决定，
/// 为 nil 时卡面整体走预设图，本视图根本不创建。绝不向后翻别的活动：
/// 那会给卡片配一张不属于这件事的照片，用户会以为图就是这件事。
/// 刀 3 时随旧模型（Tab2HeroPhoto）删除，本文件只留下 HeroTopOverlay；
/// 刀 4b 按 v3 规格恢复单图版；刀 6 类别标签行删除（并入左上角照片标签 chip，
/// 由卡面叠加，HeroTopOverlay 随之整体退役）。
struct Tab2HeroPhotoArt: View {
    let cover: Tab2Activity.Cover

    var body: some View {
        ZStack {
            photo
            photoTreatment
        }
        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
        .frame(maxWidth: .infinity)
        .compositingGroup()
        .mask(photoBottomFade)
    }

    private var photo: some View {
        CachedRemoteImage(
            // photoCover 已过滤掉 imageUrl 为空/nil 的 cover（Tab2ActivityDisplay.compute），
            // 这里的 ?? "" 只是让类型对上，实际走不到。
            signedUrl: cover.imageUrl ?? "",
            stableKey: cover.stableImageKey ?? cover.imageUrl ?? "",
            placeholder: { placeholder }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .saturation(AppTheme.Tab2Hero.ImageTreatment.photoSaturation)
    }

    private var photoTreatment: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Color.tab2HeroPhotoToneWarm)
                .blendMode(.multiply)
                .opacity(AppTheme.Tab2Hero.Opacity.photoToneWarm)

            Rectangle()
                .fill(AppTheme.Color.tab2HeroPhotoTonePaper)
                .blendMode(.softLight)
                .opacity(AppTheme.Tab2Hero.Opacity.photoTonePaper)

            LinearGradient(
                colors: [
                    AppTheme.Color.tab2HeroPhotoTopScrim
                        .opacity(AppTheme.Tab2Hero.Opacity.photoTopScrim),
                    AppTheme.Color.tab2HeroPhotoTopScrim
                        .opacity(AppTheme.Tab2Hero.Opacity.transparent),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: AppTheme.Tab2Hero.Layout.photoTopScrimHeight)
        }
        .allowsHitTesting(false)
    }

    private var photoBottomFade: some View {
        LinearGradient(
            stops: [
                .init(color: AppTheme.Color.textPrimary, location: 0),
                .init(
                    color: AppTheme.Color.textPrimary,
                    location: AppTheme.Tab2Hero.ImageTreatment.bottomFadeOpaqueEnd
                ),
                .init(
                    color: AppTheme.Color.textPrimary.opacity(AppTheme.Tab2Hero.Opacity.transparent),
                    location: 1
                ),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var placeholder: some View {
        Rectangle().fill(AppTheme.Color.imagePlaceholderBg)
    }
}
