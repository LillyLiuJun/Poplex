import SwiftUI
import PhotosUI

/// 选中的用户照片与预设样例都按原比例占满内容宽度。
/// 输入侧已限制为 1:2.25–2.25:1，因此这里无需再用固定高度二次约束。
enum OnboardingImagePreviewLayout {
    static func height(containerWidth: CGFloat, imageSize: CGSize) -> CGFloat {
        guard containerWidth > 0, imageSize.width > 0, imageSize.height > 0 else {
            return AppTheme.Size.onboardingPreviewHeight
        }

        return containerWidth * imageSize.height / imageSize.width
    }
}

enum OnboardingPhotoAspectValidationResult: Equatable {
    case accepted
    case tooTall
    case tooWide
    case invalid
}

enum OnboardingPhotoAspectValidator {
    static func validate(imageSize: CGSize) -> OnboardingPhotoAspectValidationResult {
        guard imageSize.width > 0, imageSize.height > 0 else { return .invalid }

        let limit = AppTheme.Size.onboardingMaxPhotoAspectRatio
        if imageSize.height > imageSize.width * limit { return .tooTall }
        if imageSize.width > imageSize.height * limit { return .tooWide }
        return .accepted
    }
}

enum OnboardingPhotoAutoScroll {
    static func isNeeded(
        photoBottom: CGFloat,
        continueTop: CGFloat,
        clearance: CGFloat
    ) -> Bool {
        photoBottom > continueTop - clearance
    }

    static func spacerHeight(
        viewportBottom: CGFloat,
        continueTop: CGFloat,
        clearance: CGFloat
    ) -> CGFloat {
        max(0, viewportBottom - continueTop + clearance)
    }
}

private enum OnboardingSelectionLayout {
    static let coordinateSpace = "onboardingSelectionViewport"
    static let scrollAnchor = "onboardingSelectedPhotoClearance"
}

private enum OnboardingCaptureLayout {
    // 页面级坐标空间：翻页手势的 startLocation 与样例图条的 frame 都以此为参照
    static let pageSpace = "onboardingCapturePage"
}

private struct CarouselFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect?

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

private struct SelectedPhotoBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private struct ContinueTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

/// Onboarding 第三页：用户亲手实操 —— 选素材（拍照/相册/预设卡）→ AI 生成 → 展示产出。
/// 布局参考 ai_studio_code(31).html：虚线动作卡（拍照主 CTA + 相册文字链接）
/// + 横滑预设卡条；结果渲染为与第一页同构的时刻卡，形成"看到样品→亲手做出"闭环。
struct OnboardingCaptureView: View {
    var viewModel: OnboardingViewModel
    var isActive: Bool = true
    var onBack: () -> Void
    var onComplete: () -> Void

    @AppStorage("ai_consent_accepted_at") private var aiConsentAt: Double = 0
    @State private var pendingCard: PresetCard?
    @State private var pendingImage: UIImage?
    @State private var activeSheet: CaptureSource?
    @State private var showConsentSheet = false
    // Holds the photo picked inside the sheet until the sheet has fully
    // dismissed. Writing it straight into `pendingImage` would reshape the
    // layout underneath the sheet in the same transaction that tears the
    // sheet down, which desyncs the presentation state on device and leaves
    // both entry buttons dead afterwards.
    @State private var stagedImage: UIImage?
    @State private var photoValidationMessage: String?
    @State private var selectedPhotoBottom: CGFloat?
    @State private var continueTop: CGFloat?
    @State private var selectionRevision = 0
    @State private var autoScrolledRevision: Int?
    @State private var appeared = false
    @State private var skeletonPulse = false
    // 样例图横滑条在页面坐标空间里的 frame；翻页手势起点落在其中时不翻页
    @State private var carouselFrame: CGRect?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSelecting: Bool { viewModel.selectedCard == nil && viewModel.selectedImage == nil }
    private var hasSelection: Bool { pendingCard != nil || pendingImage != nil }

    private var resultImage: Image? {
        if let image = viewModel.selectedImage { return Image(uiImage: image) }
        if let card = viewModel.selectedCard { return Image(card.imageName) }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            OnboardingAuraBackground()

            // Content area morphs in-place on Continue.
            if isSelecting {
                selectionContent
                    .transition(.opacity)
            } else {
                resultContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSelecting)
        .contentShape(Rectangle())
        .onHorizontalSwipe(
            ignoredFrames: { [carouselFrame].compactMap { $0 } },
            onRight: handleBack
        )
        .coordinateSpace(name: OnboardingCaptureLayout.pageSpace)
        .overlay(alignment: .topLeading) {
            OnboardingBackButton(action: backButtonAction)
                .padding(.top, AppTheme.Space.paddingCard)
                .padding(.leading, AppTheme.Space.paddingM)
        }
        // One sheet, switched by CaptureSource — never two live modals at once,
        // so SwiftUI's presentation state can't desync between camera & photo.
        // Both sources write into `stagedImage`; the result is applied in
        // onDismiss, after the presentation is fully torn down.
        .sheet(item: $activeSheet, onDismiss: applyStagedImage) { source in
            switch source {
            case .camera:
                CameraCaptureView(
                    onImage: { stagedImage = $0 },
                    onClose: { activeSheet = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            case .photoLibrary:
                PHPickerView(
                    image: $stagedImage,
                    onFinish: { activeSheet = nil }
                )
            }
        }
        // 三页并排渲染，onAppear 启动即触发——入场动画必须在页面真正可见时才播
        .onAppear { if isActive { appeared = true } }
        .onChange(of: isActive) { _, active in if active { appeared = true } }
        .sheet(isPresented: $showConsentSheet) {
            AIConsentView(onAgree: { performSelection() })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onPreferenceChange(CarouselFramePreferenceKey.self) { carouselFrame = $0 }
    }

    // MARK: - Back

    // Runs in the sheet's onDismiss, i.e. only once the modal is gone, so the
    // preview/Continue layout change can never race the dismissal animation.
    // Selecting a photo (any source) also clears a previously picked card.
    private func applyStagedImage() {
        guard let image = stagedImage else { return }
        stagedImage = nil

        switch OnboardingPhotoAspectValidator.validate(imageSize: image.size) {
        case .accepted:
            photoValidationMessage = nil
            pendingImage = image
            pendingCard = nil
            registerNewSelection()
        case .tooTall:
            photoValidationMessage = "Photo is too tall — use 1:2.25 to 2.25:1."
        case .tooWide:
            photoValidationMessage = "Photo is too wide — use 1:2.25 to 2.25:1."
        case .invalid:
            photoValidationMessage = "Couldn't read this photo. Choose another."
        }
    }

    private func handleBack() {
        // 右滑只在选照片态返回上一页。结果态（含样例图生成）禁止右滑：
        // 生成结果是一次性产出，误触右滑会直接丢失，且没有撤销途径。
        // 结果态想重拍走左上角返回按钮（backButtonAction）。
        guard isSelecting else { return }
        onBack()
    }

    private func backButtonAction() {
        if isSelecting {
            onBack()
        } else {
            // Reset scroll tracking so selectionContent re-scrolls to reveal
            // the image + Continue button when the user returns.
            autoScrolledRevision = nil
            selectedPhotoBottom = nil
            continueTop = nil
            viewModel.reset()
        }
    }

    // MARK: - Selection content (action card + preset carousel + Continue)

    private var selectionContent: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ZStack(alignment: .bottom) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Color.clear
                                .frame(height: 36)
                                .padding(.top, AppTheme.Space.paddingCard)
                            
                        selectionHeader
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        actionCard(
                            availableWidth: geo.size.width
                                - AppTheme.Space.paddingPage
                                - AppTheme.Space.paddingPage
                        )
                            .padding(.top, AppTheme.Space.paddingSection)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.25)
                            .background {
                                if hasSelection {
                                    GeometryReader { photoGeo in
                                        Color.clear.preference(
                                            key: SelectedPhotoBottomPreferenceKey.self,
                                            value: photoGeo.frame(
                                                in: .named(OnboardingSelectionLayout.coordinateSpace)
                                            ).maxY
                                        )
                                    }
                                }
                            }

                        if hasSelection {
                            Color.clear
                                .frame(
                                    height: OnboardingPhotoAutoScroll.spacerHeight(
                                        viewportBottom: geo.size.height,
                                        continueTop: continueTop ?? geo.size.height,
                                        clearance: AppTheme.Space.paddingSection
                                    )
                                )
                                .id(OnboardingSelectionLayout.scrollAnchor)
                        }

                        if !hasSelection {
                            Text("Or try a sample")
                                .font(AppTheme.Font.compactSectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                                .padding(.top, AppTheme.Space.paddingSection)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.35)

                            presetCarousel
                                .padding(.top, AppTheme.Space.paddingM)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.4)
                        }
                            
                            Spacer()
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance)
                        .frame(minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    VStack(spacing: AppTheme.Space.paddingCard) {
                        AutoDismissingAppToast(
                            message: $photoValidationMessage,
                            systemImage: "exclamationmark.triangle",
                            lifetime: AppTheme.Motion.onboardingPhotoToastLifetime
                        )

                        OnboardingPrimaryButton(
                            title: "Continue",
                            isEnabled: hasSelection,
                            action: confirmSelection
                        )
                        .background {
                            GeometryReader { buttonGeo in
                                Color.clear.preference(
                                    key: ContinueTopPreferenceKey.self,
                                    value: buttonGeo.frame(
                                        in: .named(OnboardingSelectionLayout.coordinateSpace)
                                    ).minY
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                }
                .coordinateSpace(name: OnboardingSelectionLayout.coordinateSpace)
                .onPreferenceChange(SelectedPhotoBottomPreferenceKey.self) { bottom in
                    selectedPhotoBottom = bottom
                    scrollSelectedPhotoIfNeeded(proxy: proxy, viewportBottom: geo.size.height)
                }
                .onPreferenceChange(ContinueTopPreferenceKey.self) { top in
                    continueTop = top
                    scrollSelectedPhotoIfNeeded(proxy: proxy, viewportBottom: geo.size.height)
                }
            }
        }
    }

    private func registerNewSelection() {
        selectionRevision += 1
        autoScrolledRevision = nil
        selectedPhotoBottom = nil
        // 选中后样例图条消失，同步清掉屏蔽区，避免旧 frame 残留误伤该区域的返回手势
        carouselFrame = nil
    }

    private func scrollSelectedPhotoIfNeeded(
        proxy: ScrollViewProxy,
        viewportBottom: CGFloat
    ) {
        guard hasSelection,
              autoScrolledRevision != selectionRevision,
              let selectedPhotoBottom,
              let continueTop,
              OnboardingPhotoAutoScroll.isNeeded(
                  photoBottom: selectedPhotoBottom,
                  continueTop: continueTop,
                  clearance: AppTheme.Space.paddingSection
              ) else { return }

        autoScrolledRevision = selectionRevision
        DispatchQueue.main.async {
            if reduceMotion {
                proxy.scrollTo(OnboardingSelectionLayout.scrollAnchor, anchor: .bottom)
            } else {
                withAnimation(AppTheme.Motion.onboardingPhotoAutoScroll) {
                    proxy.scrollTo(OnboardingSelectionLayout.scrollAnchor, anchor: .bottom)
                }
            }
        }
    }

    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Snap what's around\nyou to start")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Point at your desk, coffee, or view — no preparation needed.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppTheme.Space.paddingCard)
    }

    // MARK: 空输入区；已选照片时原位变为预览卡

    private func actionCard(availableWidth: CGFloat) -> some View {
        Group {
            if pendingImage != nil || pendingCard != nil {
                ZStack(alignment: .topTrailing) {
                    if let image = pendingImage {
                        userImagePreview(image, availableWidth: availableWidth)
                    } else if let card = pendingCard,
                              let image = UIImage(named: card.imageName) {
                        userImagePreview(image, availableWidth: availableWidth)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(duration: 0.2)) {
                            pendingImage = nil
                            pendingCard = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .padding(8)
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.9, pressedOpacity: 0.8))
                }
            } else {
                VStack(spacing: AppTheme.Space.paddingM) {
                    OnboardingCaptureIllustration()

                    Text("Add your photo")
                        .font(AppTheme.Font.ctaLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    VStack(spacing: AppTheme.Space.paddingS) {
                        OnboardingUploadActionButton(
                            title: "Camera",
                            systemImage: "camera",
                            action: { activeSheet = .camera }
                        )

                        OnboardingUploadActionButton(
                            title: "Gallery",
                            systemImage: "photo.on.rectangle",
                            action: { activeSheet = .photoLibrary }
                        )
                    }
                    .frame(width: AppTheme.Size.onboardingUploadActionWidth)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.glassContainer))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.glassContainer)
                        .strokeBorder(
                            AppTheme.Color.borderDashed,
                            style: StrokeStyle(
                                lineWidth: AppTheme.Size.onboardingUploadBorderWidth,
                                dash: [
                                    AppTheme.Size.onboardingUploadDashLength,
                                    AppTheme.Size.onboardingUploadDashGap
                                ]
                            )
                        )
                }
            }
        }
    }

    private func userImagePreview(_ image: UIImage, availableWidth: CGFloat) -> some View {
        let previewHeight = OnboardingImagePreviewLayout.height(
            containerWidth: availableWidth,
            imageSize: image.size
        )

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: availableWidth, height: previewHeight)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.glassContainer))
            .allowsHitTesting(false)
    }

    // MARK: 预设卡横滑条（相机不可用/没有照片时的兜底入口）

    private var presetCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Space.paddingM) {
                ForEach(PresetCard.all) { card in
                    PresetCarouselTile(
                        card: card,
                        isSelected: pendingCard?.id == card.id && pendingImage == nil
                    ) {
                        // 预设卡落库与打标都需要网络：断网时不允许选择，
                        // 避免「离线走完 onboarding → 服务端无记录」的静默丢数据。
                        // 文案与 feat/onboarding-error-states 的断网档一致。
                        guard NetworkMonitor.shared.isConnected else {
                            photoValidationMessage = "Network unavailable. Check your network and try again."
                            return
                        }
                        // Sample 选中会同时让横滑列表消失并生成自然比例预览。
                        // 这里若用 spring，PreferenceKey 会先读到动画中间帧，
                        // 一次性自动避让便可能提前消耗在错误位置。先让布局一次到位，
                        // 只保留真正承担反馈的 onboardingPhotoAutoScroll 动画。
                        pendingCard = card
                        pendingImage = nil
                        registerNewSelection()
                    }
                }
            }
            // 给选中态的放大留出绘制空间，避免被 ScrollView 裁掉
            .padding(AppTheme.Space.paddingXS)
        }
        .background {
            // 把样例图条在页面坐标空间里的 frame 上报出去：翻页手势起点落在
            // 其中时归 ScrollView 消费，不翻页。竖屏滚动时 frame 随布局实时更新。
            GeometryReader { geo in
                Color.clear.preference(
                    key: CarouselFramePreferenceKey.self,
                    value: geo.frame(in: .named(OnboardingCaptureLayout.pageSpace))
                )
            }
        }
    }

    private func confirmSelection() {
        if aiConsentAt == 0 {
            showConsentSheet = true
        } else {
            performSelection()
        }
    }

    private func performSelection() {
        if let image = pendingImage {
            Task { await viewModel.startWithImage(image) }
        } else if let card = pendingCard {
            // 选卡后网络断开：Continue 时再拦一道——生成依赖联网落库与打标。
            // 文案与 feat/onboarding-error-states 的断网档一致。
            guard NetworkMonitor.shared.isConnected else {
                photoValidationMessage = "Network unavailable. Check your network and try again."
                return
            }
            Task { await viewModel.startWithCard(card) }
        }
    }

    // MARK: - Result content (moment card as hero, 方案 A 统一时刻卡)

    private var resultContent: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 36)
                            .padding(.top, AppTheme.Space.paddingCard)

                        resultHeader
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.bottom, AppTheme.Space.paddingCard)

                        if viewModel.isLoading {
                            loadingCard
                                .transition(.opacity)
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer()
                        } else if let result = viewModel.generationResult {
                            resultCard(result)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer()
                        } else {
                            // 生成失败：插画 + 文案(+重试) 在剩余空间整体居中，
                            // 取代原来甩在左上、中间留白的排版。
                            fallbackStage(isFailed: viewModel.retryCount >= 2)
                                .transition(.opacity)
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(.bottom, 120) // Give space for absolute bottom button
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            
            if !viewModel.isLoading {
                bottomButton
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.generationResult != nil)
    }

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            (Text("Here's your first ") + Text("moment.").foregroundStyle(AppTheme.Color.brandStrong))
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your photo, now something you can say.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppTheme.Space.paddingCard)
    }

    // MARK: 结果卡：与第一页样品卡同构 —— 用户亲手做出的第一张卡

    private func resultCard(_ card: AICard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = resultImage {
                OnboardingMomentCard(
                    image: image,
                    sentence: card.primaryEnglish,
                    translation: card.nativeMeaning,
                    photoHeight: 195
                )
            }
        }
    }

    // MARK: 生成中：照片定格 + 暖色骨架（呼吸脉冲）+ 状态文案（与结果卡同构）

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            VStack(alignment: .leading, spacing: 0) {
                if let image = resultImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 195)
                        .clipped()
                        .allowsHitTesting(false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(AppTheme.Color.imagePlaceholderBg)
                        .frame(width: 60, height: 12)
                        .padding(.bottom, 2)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(AppTheme.Color.imagePlaceholderBg)
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(AppTheme.Color.imagePlaceholderBg)
                        .frame(width: 180, height: 14)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .opacity(skeletonPulse ? 0.45 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: skeletonPulse
                )
            }
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(AppTheme.Color.border.opacity(0.6), lineWidth: 1)
            )
            .shadow(
                color: AppTheme.Shadow.cardColor,
                radius: AppTheme.Shadow.cardRadius,
                x: AppTheme.Shadow.cardX,
                y: AppTheme.Shadow.cardY
            )
            .onAppear { skeletonPulse = true }

            Text("Turning your moment into English…")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, 2)
        }
    }

    // MARK: 兜底态：纸雕插画 + 文案(+重试)，在内容区剩余空间整体居中
    // isFailed = 重试两次后放弃（引导进 App）；否则为可重试的出错态。
    private func fallbackStage(isFailed: Bool) -> some View {
        VStack(spacing: AppTheme.Space.paddingSection) {
            OnboardingFallbackIllustration(kind: isFailed ? .explore : .retry)

            VStack(spacing: AppTheme.Space.paddingCard) {
                Text(isFailed
                     ? "No worries — you can explore inside the app."
                     : (viewModel.errorMessage ?? "Something went wrong. Want to try again?"))
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)

                if !isFailed {
                    Button(action: { Task { await viewModel.retry() } }) {
                        Text("Try again")
                            .font(AppTheme.Font.buddy)
                            .foregroundStyle(AppTheme.Color.brandStrong)
                            .padding(.horizontal, AppTheme.Space.paddingCard)
                            .padding(.vertical, AppTheme.Space.paddingS)
                            .background(AppTheme.Color.brandWash, in: Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.generationResult != nil || viewModel.retryCount >= 2 {
            OnboardingPrimaryButton(
                title: viewModel.retryCount >= 2 ? "Let's dive in." : "Get Started",
                action: onComplete
            )
        }
    }
}

// MARK: - Sub-views

/// 方案 C 的空输入插画：用已有实色 token 叠出纸雕层次，不用半透明橙。
/// Path 内的坐标是矢量资产本身，不参与页面布局度量。
private struct OnboardingCaptureIllustration: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                let scaleX = size.width / AppTheme.Size.onboardingUploadIllustrationWidth
                let scaleY = size.height / AppTheme.Size.onboardingUploadIllustrationHeight

                func scaledPath(_ build: (inout Path) -> Void) -> Path {
                    var source = Path()
                    build(&source)
                    return source.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
                }

                let back = scaledPath { path in
                    path.move(to: CGPoint(x: 30, y: 16))
                    path.addCurve(
                        to: CGPoint(x: 78, y: 55),
                        control1: CGPoint(x: 50, y: 8),
                        control2: CGPoint(x: 86, y: 16)
                    )
                    path.addCurve(
                        to: CGPoint(x: 30, y: 16),
                        control1: CGPoint(x: 59, y: 66),
                        control2: CGPoint(x: 10, y: 47)
                    )
                    path.closeSubpath()
                }
                context.fill(back, with: .color(AppTheme.Color.brandTint))

                let middle = scaledPath { path in
                    path.move(to: CGPoint(x: 42, y: 48))
                    path.addCurve(
                        to: CGPoint(x: 68, y: 22),
                        control1: CGPoint(x: 34, y: 36),
                        control2: CGPoint(x: 48, y: 23)
                    )
                    path.addCurve(
                        to: CGPoint(x: 42, y: 48),
                        control1: CGPoint(x: 83, y: 22),
                        control2: CGPoint(x: 76, y: 55)
                    )
                    path.closeSubpath()
                }
                context.fill(middle, with: .color(AppTheme.Color.neutralFaint))

                let front = scaledPath { path in
                    path.move(to: CGPoint(x: 28, y: 44))
                    path.addCurve(
                        to: CGPoint(x: 50, y: 20),
                        control1: CGPoint(x: 24, y: 31),
                        control2: CGPoint(x: 36, y: 19)
                    )
                    path.addCurve(
                        to: CGPoint(x: 72, y: 43),
                        control1: CGPoint(x: 65, y: 20),
                        control2: CGPoint(x: 79, y: 31)
                    )
                    path.addCurve(
                        to: CGPoint(x: 28, y: 44),
                        control1: CGPoint(x: 67, y: 57),
                        control2: CGPoint(x: 32, y: 57)
                    )
                    path.closeSubpath()
                }
                context.drawLayer { layer in
                    layer.addFilter(.shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    ))
                    layer.fill(front, with: .color(AppTheme.Color.cardBg))
                }

                let accent = scaledPath { path in
                    path.move(to: CGPoint(x: 66, y: 21))
                    path.addCurve(
                        to: CGPoint(x: 77, y: 32),
                        control1: CGPoint(x: 73, y: 19),
                        control2: CGPoint(x: 80, y: 25)
                    )
                    path.addCurve(
                        to: CGPoint(x: 66, y: 21),
                        control1: CGPoint(x: 74, y: 39),
                        control2: CGPoint(x: 61, y: 34)
                    )
                    path.closeSubpath()
                }
                context.drawLayer { layer in
                    layer.addFilter(.shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    ))
                    layer.fill(accent, with: .color(AppTheme.Color.brandStrong))
                }
            }

            Image(systemName: "camera")
                .font(.system(size: AppTheme.Size.onboardingCaptureGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.brandStrong)
        }
        .frame(
            width: AppTheme.Size.onboardingUploadIllustrationWidth,
            height: AppTheme.Size.onboardingUploadIllustrationHeight
        )
        .accessibilityHidden(true)
    }
}

/// 兜底态（生成失败 / 放弃）的纸雕插画：与空输入区叠纸同族——三层暖色纸卡
/// 叠出层次，前景卡上几条淡描边暗示"本该长出的时刻卡"，右上角一枚小橙徽标
/// 呼应动作（retry = 刷新；explore = 前进）。橙色仅用于 ≤30pt 的小面积角标。
private struct OnboardingFallbackIllustration: View {
    enum Kind {
        case retry   // 可重试的出错态
        case explore // 放弃后引导进 App

        var glyph: String {
            switch self {
            case .retry:   return "arrow.clockwise"
            case .explore: return "arrow.right"
            }
        }
    }

    let kind: Kind

    private var cardSize: CGFloat { AppTheme.Size.onboardingFallbackCardSize }
    private var badge: CGFloat { AppTheme.Size.onboardingFallbackBadge }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 叠纸层
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.brandTint)
                    .frame(width: cardSize + 16, height: cardSize + 8)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -8, y: 6)

                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.neutralFaint.opacity(0.5))
                    .frame(width: cardSize + 8, height: cardSize + 4)
                    .rotationEffect(.degrees(4))
                    .offset(x: 6, y: 2)

                // 前景纸卡 + 淡描边"文字条"
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Color.cardBg)
                    .frame(width: cardSize, height: cardSize)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 7) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 34, height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 46, height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(AppTheme.Color.border)
                                .frame(width: 24, height: 5)
                        }
                        .padding(.leading, 12)
                    }
                    .shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    )
            }
            .frame(
                width: AppTheme.Size.onboardingFallbackIllustrationWidth,
                height: AppTheme.Size.onboardingFallbackIllustrationHeight
            )

            // 橙色角标
            Image(systemName: kind.glyph)
                .font(.system(size: AppTheme.Size.onboardingFallbackBadgeGlyph, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: badge, height: badge)
                .background(AppTheme.Color.brandStrong, in: Circle())
                .offset(x: 4, y: -2)
        }
        .frame(
            width: AppTheme.Size.onboardingFallbackIllustrationWidth,
            height: AppTheme.Size.onboardingFallbackIllustrationHeight
        )
        .accessibilityHidden(true)
    }
}

/// 空输入区里的直接动作。没有 chevron，因为点击后立即调起系统选择器，
/// 并不进入新的信息层级。
private struct OnboardingUploadActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: systemImage)
                    .font(.system(
                        size: AppTheme.Size.onboardingUploadActionGlyph,
                        weight: .regular
                    ))

                Text(title)
                    .font(AppTheme.Font.compactActionLabel)
            }
            .foregroundStyle(AppTheme.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.barControl)
            .background(AppTheme.Color.cardBg, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(AppTheme.Color.border, lineWidth: AppTheme.Size.onboardingUploadBorderWidth)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// 预设卡横滑条中的卡片：底部渐变标签 + 选中橙描边/勾号（修复原 accentColor
/// 引用空颜色集导致渲染成系统蓝的问题）。
private struct PresetCarouselTile: View {
    let card: PresetCard
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                Image(card.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: AppTheme.Size.onboardingSampleWidth,
                        height: AppTheme.Size.onboardingSampleHeight
                    )
                    .clipped()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppTheme.Color.cameraControl, AppTheme.Color.brandStrong)
                        .padding(AppTheme.Space.paddingS)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .stroke(AppTheme.Color.brandStrong, lineWidth: isSelected ? 3 : 0)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            // Restrict the tappable area to the visible tile — the aspect-fill
            // image overflows the clip invisibly and would steal neighbors' taps.
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingCaptureView(
        viewModel: OnboardingViewModel(),
        onBack: {},
        onComplete: {}
    )
}
