import SwiftUI
import Combine

struct TimelineRow: View {
    let entry: TimelineEntry
    var timelineViewportFrame: CGRect = .zero
    var passageTabResetGeneration = 0
    var onImageTap: ((UIImage, CGRect) -> Void)? = nil
    var onRetry: ((_ text: String?, _ image: UIImage?, _ entryId: UUID, _ requestId: UUID?, _ bubbleEntryId: UUID?) -> Void)? = nil
    var onRetryPending: ((PendingRetryRecord) -> Void)? = nil
    var onCollapse: ((UUID) -> Void)? = nil
    @State private var passageVisibilityResetGeneration = 0

    var body: some View {
        switch entry.content {
        case .userBubble(let text, let image, let imageUrl, let imageStableKey):
            UserBubble(text: text, image: image, imageUrl: imageUrl, imageStableKey: imageStableKey, onImageTap: onImageTap)
        case .aiLoading:
            AILoadingCard()
        case .aiCard(let card):
            AICardView(
                card: card,
                passageResetSignal: PassageResetSignal(
                    tabGeneration: passageTabResetGeneration,
                    visibilityGeneration: passageVisibilityResetGeneration
                ),
                onCollapse: { onCollapse?(entry.id) }
            )
            .onGeometryChange(for: Bool.self) { proxy in
                PassageReadingLifecycle.isCompletelyOutside(
                    cardFrame: proxy.frame(in: .global),
                    viewport: timelineViewportFrame
                )
            } action: { isOutside in
                guard isOutside else { return }
                passageVisibilityResetGeneration &+= 1
            }
        case .aiError(let message):
            ErrorBanner(message: message)
        case .sendFailed(let text, let image, let requestId, let bubbleEntryId):
            SendFailedRow { onRetry?(text, image, entry.id, requestId, bubbleEntryId) }
        case .userRejected(let text, let wasImage):
            UserRejectedRow(text: text, wasImage: wasImage)
        case .pendingRetry(let record):
            PendingRetryRow(record: record) { onRetryPending?(record) }
        case .dateSeparator(let label):
            DateSeparatorView(label: label)
        }
    }
}

// MARK: - 断网待重试记录：与 Tab1 正常输入视觉一致——
// 图片气泡（图 + "Describe this image"）+ 下方错误行（样式同 SendFailedRow，点击重试）
struct PendingRetryRow: View {
    let record: PendingRetryRecord
    var onRetry: () -> Void

    var body: some View {
        // 行内气泡到重试按钮也是「用户输入→反馈」，与外部 timelineUserToAI (12pt) 视觉规格一致
        VStack(alignment: .trailing, spacing: AppTheme.Space.timelineUserToAI) {
            UserBubble(
                text: "Describe this image",
                image: PendingRetryStore.shared.photoImage(for: record),
                imageUrl: nil,
                imageStableKey: nil
            )

            Button(action: onRetry) {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Check your connection and try again.")
                        .font(AppTheme.Font.chineseFaint)
                }
                .foregroundStyle(AppTheme.Color.danger)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 被拒条目：图片转占位块（不合规图片不上屏），文本原样；下方一行轻提示
private struct UserRejectedRow: View {
    let text: String?
    let wasImage: Bool
    private let imageSize = UIScreen.main.bounds.width * 0.3   // 与 UserBubble 同尺寸，保持时间线节奏

    var body: some View {
        // 与正常 UserBubble 视觉节奏一致：图（占位）在上、文字气泡在下
        VStack(alignment: .trailing, spacing: AppTheme.Space.paddingS) {
            if wasImage {
                ImageLoadFailedPlaceholder(accessibilityLabelOverride: "Content blocked")
                    .frame(width: imageSize, height: imageSize)
            }

            if let text, !text.isEmpty {
                Text(text)
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.bubbleUserText)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.bubbleUserBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }

            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "info.circle")
                    .imageScale(.small)
                Text("This content can't be processed.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Send failed (tap to retry)
private struct SendFailedRow: View {
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: AppTheme.Space.paddingXS) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text("Check your connection and try again.")
                    .font(AppTheme.Font.chineseFaint)
            }
            .foregroundStyle(AppTheme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User bubble (right-aligned, image above text)
private struct UserBubble: View {
    let text: String?
    let image: UIImage?
    let imageUrl: String?
    let imageStableKey: String?
    var onImageTap: ((UIImage, CGRect) -> Void)?
    /// 仅供 Xcode Canvas：复用真实的图片气泡布局，但不触发远程请求。
    var showsImageLoadingPlaceholder = false

    @State private var imageFrame: CGRect = .zero
    private let imageSize = UIScreen.main.bounds.width * 0.3

    var body: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Space.timelineImageToText) {
            if let img = image {
                HStack {
                    Spacer()
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        // Clip affects drawing only — restrict hit-testing to
                        // the visible bubble so the invisible overflow can't
                        // swallow taps around the message.
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { imageFrame = $0 }
                        .onTapGesture { onImageTap?(img, imageFrame) }
                }
            } else if showsImageLoadingPlaceholder {
                imageLoadingBubble
            } else if let urlStr = imageUrl {
                HStack {
                    Spacer()
                    CachedRemoteImage(signedUrl: urlStr, stableKey: imageStableKey ?? urlStr) {
                        ImageLoadingPlaceholder()
                    }
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { imageFrame = $0 }
                    .onTapGesture {
                        let cacheKey = imageStableKey ?? urlStr
                        if let cached = ImageCache.shared.get(cacheKey) {
                            onImageTap?(cached, imageFrame)
                        }
                    }
                }
            }
            if let text, !text.isEmpty {
                HStack {
                    Spacer(minLength: AppTheme.Space.paddingHero)
                    Text(text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, AppTheme.Space.paddingM)
                        .background(AppTheme.Color.bubbleUserBg)
                        .foregroundStyle(AppTheme.Color.bubbleUserText)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
            }
        }
    }

    private var imageLoadingBubble: some View {
        HStack {
            Spacer()
            ImageLoadingPlaceholder()
                .frame(width: imageSize, height: imageSize)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
    }
}

// MARK: - Routes to the correct card view
private struct AICardView: View {
    let card: AICard
    var passageResetSignal = PassageResetSignal(tabGeneration: 0, visibilityGeneration: 0)
    var onCollapse: (() -> Void)? = nil

    var body: some View {
        switch card {
        case .card(let c):
            AICardBody(
                content: c,
                onCollapse: onCollapse,
                passageResetSignal: passageResetSignal
            )
        case .error(let c): ErrorBanner(message: c.message ?? "This content can't be processed. Try another one.")
        }
    }
}

// MARK: - AI loading placeholder（"Generating" + 三点依次出现，打字机式循环）
private struct AILoadingCard: View {
    @State private var dotCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text("Generating")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textMuted)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppTheme.Color.textMuted)
                        .frame(width: 4, height: 4)
                        .opacity(i < dotCount ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: dotCount)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 减弱动态：直接显示静态三点，不循环
        .onAppear { if reduceMotion { dotCount = 3 } }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            dotCount = (dotCount + 1) % 4   // 0→1→2→3→0：点依次出现再清空
        }
    }
}

// MARK: - Inline error message
struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTheme.Font.chineseFaint)
            .foregroundStyle(AppTheme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, AppTheme.Space.paddingCard)
    }
}

// MARK: - Date separator (悬浮居中小胶囊，消除硬分割线)
private struct DateSeparatorView: View {
    let label: String

    var body: some View {
        HStack {
            Spacer()
            Text(label)
                .font(AppTheme.Font.date)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(AppTheme.Color.dateChipBg)
                .clipShape(Capsule())
            Spacer()
        }
    }
}

// MARK: - Xcode Canvas

/// 在真实 Tab1 画布、时间线内边距和底部输入条中观察图片加载态。
/// 不创建 TodayViewModel，也不发起网络请求。
private struct Tab1ImageLoadingContextPreview: View {
    @State private var inputText = ""
    @State private var pendingImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingCard) {
                DateSeparatorView(label: "Today")
                Spacer()
                UserBubble(
                    text: "Describe this image",
                    image: nil,
                    imageUrl: nil,
                    imageStableKey: nil,
                    showsImageLoadingPlaceholder: true
                )
            }
            .padding(AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Size.inputBarMinHeight + AppTheme.Space.paddingSection)

            InputBar(text: $inputText, image: $pendingImage, isLoading: false, onSend: {})
                .background {
                    VariableBlurBackdrop(extraExtend: 16)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
        }
    }
}

#Preview("Tab 1 · Image loading in context", traits: .fixedLayout(width: 393, height: 852)) {
    Tab1ImageLoadingContextPreview()
}
