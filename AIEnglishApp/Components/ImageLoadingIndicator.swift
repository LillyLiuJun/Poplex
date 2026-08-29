import SwiftUI

/// 远程图片首次取得时的细环。它与 AI 的 `Generating…` 明确区分：只说明图片本身还没到本机。
/// 减弱动态时保留静态环，仍提供「正在加载」的视觉线索。
struct ImageLoadingIndicator: View {
    /// 仅供 Canvas / 测试固定动态偏好；生产界面保持 nil，读取系统设置。
    var reduceMotionOverride: Bool? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0

    var body: some View {
        let shouldReduceMotion = reduceMotionOverride ?? reduceMotion

        Circle()
            .trim(from: 0.12, to: 0.84)
            .stroke(
                AppTheme.Color.imageLoadingIndicator,
                style: StrokeStyle(
                    lineWidth: AppTheme.Size.imageLoadingIndicatorStroke,
                    lineCap: .round
                )
            )
            .frame(
                width: AppTheme.Size.imageLoadingIndicatorDiameter,
                height: AppTheme.Size.imageLoadingIndicatorDiameter
            )
            .rotationEffect(.degrees(rotation))
            .accessibilityLabel("Loading image")
            .task(id: shouldReduceMotion) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { rotation = 0 }

                guard !shouldReduceMotion else { return }
                withAnimation(AppTheme.Motion.imageLoadingRotation) {
                    rotation = 360
                }
            }
    }
}

/// 图片尚未抵达本机时的缩略图占位。生产与 Canvas 共用，避免预览和实际样式走样。
struct ImageLoadingPlaceholder: View {
    var reduceMotionOverride: Bool? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
            .fill(AppTheme.Color.imageLoadingPlaceholderBg)
            .overlay(ImageLoadingIndicator(reduceMotionOverride: reduceMotionOverride))
    }
}

/// 远图下载失败（断网 / 超时 / 数据损坏——`CachedRemoteImage` 里的 `try?` 吞掉了
/// 具体原因）时的静态占位。MVP 只做到"能分清楚卡住了还是还在等"：不提供点按
/// 重试，也不接网络监测自动重试——这两项已记入 `优化需求全量清单_v1.md`。
/// 复用与 `ImageLoadingPlaceholder` 相同的底色，只换成静止的感叹号图标，
/// 让"失败"读起来像同一类占位的另一种状态，而不是一个突兀的新样式。
struct ImageLoadFailedPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
            .fill(AppTheme.Color.imageLoadingPlaceholderBg)
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Color.imageLoadingIndicator)
            }
            .accessibilityLabel("Image failed to load")
    }
}

// MARK: - Xcode Canvas

private struct ImageLoadingIndicatorPreviewTile: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            ImageLoadingPlaceholder(reduceMotionOverride: reduceMotion)
                .frame(width: 120, height: 120)

            Text(reduceMotion ? "Loading image · Static" : "Loading image")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview("Image loading · Motion", traits: .sizeThatFitsLayout) {
    ImageLoadingIndicatorPreviewTile(reduceMotion: false)
}

#Preview("Image loading · Reduce Motion", traits: .sizeThatFitsLayout) {
    ImageLoadingIndicatorPreviewTile(reduceMotion: true)
}

private struct ImageLoadFailedPreviewTile: View {
    var body: some View {
        VStack(spacing: AppTheme.Space.paddingS) {
            ImageLoadFailedPlaceholder()
                .frame(width: 120, height: 120)

            Text("Image failed to load")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview("Image load failed", traits: .sizeThatFitsLayout) {
    ImageLoadFailedPreviewTile()
}

/// All three states side by side — loading (motion), loading (reduce motion),
/// failed — the same size a real Tab1 photo bubble uses, for a quick visual
/// comparison of how "still working" and "gave up" read next to each other.
private struct ImageLoadingStatesComparisonPreview: View {
    var body: some View {
        HStack(spacing: AppTheme.Space.paddingCard) {
            VStack(spacing: AppTheme.Space.paddingS) {
                ImageLoadingPlaceholder()
                    .frame(width: 100, height: 100)
                Text("Loading").font(AppTheme.Font.statusNote).foregroundStyle(AppTheme.Color.textSecondary)
            }
            VStack(spacing: AppTheme.Space.paddingS) {
                ImageLoadingPlaceholder(reduceMotionOverride: true)
                    .frame(width: 100, height: 100)
                Text("Loading · Static").font(AppTheme.Font.statusNote).foregroundStyle(AppTheme.Color.textSecondary)
            }
            VStack(spacing: AppTheme.Space.paddingS) {
                ImageLoadFailedPlaceholder()
                    .frame(width: 100, height: 100)
                Text("Failed").font(AppTheme.Font.statusNote).foregroundStyle(AppTheme.Color.textSecondary)
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.pageBg)
    }
}

#Preview("Loading vs Failed · side by side", traits: .sizeThatFitsLayout) {
    ImageLoadingStatesComparisonPreview()
}
