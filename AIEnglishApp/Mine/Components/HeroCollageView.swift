import SwiftUI

/// Tab2 Hero 卡顶部照片拼图。RPC 已把 featured 照片排在 slot 1；本视图只负责以最多三张照片呈现它。
struct HeroCollageView: View {
    let photos: [Tab2HeroPhoto]
    let categoryLabel: String
    let popsText: String

    private var tiles: [Tab2HeroPhoto] { Array(photos.prefix(3)) }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                collage(in: geometry.size)
            }
            photoTreatment
            HeroTopOverlay(categoryLabel: categoryLabel, popsText: popsText, style: .photo)
        }
        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
        .frame(maxWidth: .infinity)
        .compositingGroup()
        .mask(photoBottomFade)
    }

    @ViewBuilder
    private func collage(in size: CGSize) -> some View {
        let width = size.width
        let height = size.height
        let gap = AppTheme.Tab2Hero.Layout.collageGap

        switch tiles.count {
        case 0:
            placeholder
        case 1:
            tile(tiles[0], width: width, height: height)
        case 2:
            let columnWidth = (width - gap) / 2
            HStack(spacing: gap) {
                tile(tiles[0], width: columnWidth, height: height)
                tile(tiles[1], width: columnWidth, height: height)
            }
        default:
            let featuredWidth = (width - gap) * AppTheme.Tab2Hero.Layout.collageFeaturedWidthRatio
                / (AppTheme.Tab2Hero.Layout.collageFeaturedWidthRatio + 1)
            let supportingWidth = width - gap - featuredWidth
            let supportingHeight = (height - gap) / 2
            HStack(spacing: gap) {
                tile(tiles[0], width: featuredWidth, height: height)
                VStack(spacing: gap) {
                    tile(tiles[1], width: supportingWidth, height: supportingHeight)
                    tile(tiles[2], width: supportingWidth, height: supportingHeight)
                }
            }
        }
    }

    private func tile(_ photo: Tab2HeroPhoto, width: CGFloat, height: CGFloat) -> some View {
        CachedRemoteImage(
            signedUrl: photo.imageUrl,
            stableKey: photo.stableImageKey ?? photo.imageUrl,
            placeholder: { placeholder }
        )
        .frame(width: width, height: height)
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

// MARK: - 顶部标签行（拼图 / 预设图共用）

struct HeroTopOverlay: View {
    enum Style {
        case photo
        case preset
    }

    let categoryLabel: String
    let popsText: String
    let style: Style

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(categoryLabel.uppercased())
                .font(AppTheme.Font.tab2HeroCategoryLabel)
                .tracking(AppTheme.Tab2Hero.Typography.categoryTracking)
                .foregroundStyle(labelColor)
                .shadow(
                    color: shadowColor,
                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                    x: 0,
                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                )

            Spacer(minLength: 0)

            Text(popsText)
                .font(AppTheme.Font.tab2HeroPopsLabel)
                .monospacedDigit()
                .foregroundStyle(popsColor)
                .shadow(
                    color: shadowColor,
                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                    x: 0,
                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                )
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var topInset: CGFloat {
        switch style {
        case .photo: AppTheme.Space.paddingM
        case .preset: AppTheme.Space.paddingPage
        }
    }

    private var labelColor: Color {
        switch style {
        case .photo: AppTheme.Color.tab2HeroPhotoOverlayText
        case .preset: AppTheme.Color.tab2HeroPresetLabel
        }
    }

    private var popsColor: Color {
        switch style {
        case .photo:
            AppTheme.Color.tab2HeroPhotoOverlayText.opacity(AppTheme.Tab2Hero.Opacity.photoPops)
        case .preset:
            AppTheme.Color.tab2HeroPresetLabel.opacity(AppTheme.Tab2Hero.Opacity.presetPops)
        }
    }

    private var shadowColor: Color {
        style == .photo
            ? AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow)
            : AppTheme.Color.tab2HeroPresetLabel.opacity(AppTheme.Tab2Hero.Opacity.transparent)
    }
}
