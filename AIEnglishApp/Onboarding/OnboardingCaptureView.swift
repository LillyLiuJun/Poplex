import SwiftUI
import PhotosUI

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
    @State private var appeared = false
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
                .padding(.top, AppTheme.Size.onboardingBackInset)
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
            // 弹窗高度固定（仅 medium）：不可拉大——拉大会让"内容在上、按钮在下"
            // 的布局中间出现大片空白。文案多时在弹窗内部滚动，按钮始终可见。
            // 拖拽指示隐藏（没有可展开的大档）；下拉关闭手势仍有效。
            // contentInteraction(.scrolls)：把拖动手势交给内容区滚动，
            // 而不是上拉调整弹窗高度（弹窗只有 medium 一档，上拉无意义）。
            // interactiveDismissDisabled：禁止下滑拖动关闭——弹窗是决策点，
            // 只能通过 Agree / Not now 显式离开，防误触；也彻底消除"可拉动"感。
            AIConsentView(onAgree: { performSelection() })
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationContentInteraction(.scrolls)
                .interactiveDismissDisabled()
        }
        .onPreferenceChange(CarouselFramePreferenceKey.self) { carouselFrame = $0 }
        // 被拒：清视图层暂存选中——图片不上屏、Continue 回到禁用态（fail-open 唯一例外）。
        // 不要在 performSelection 清 pending*：backButtonAction 返回选择页时依赖它们保留以重显图片。
        .onChange(of: viewModel.errorKind) { _, kind in
            if kind == .contentBlocked {
                pendingImage = nil
                pendingCard = nil
            }
        }
        .overlay(alignment: .bottom) {
            // 被拒 toast：4s 自动消失。挂在 body 外层——被拒后切回选择页（空上传区），
            // toast 必须高于两个内容区才能显示；选择页底部有 Continue 按钮（禁用态也在），
            // 故底部偏移沿用原 errorToast 惯例，浮于按钮之上。
            if viewModel.errorKind == .contentBlocked {
                AutoDismissingAppToast(
                    message: Binding(
                        get: {
                            viewModel.errorKind == .contentBlocked
                                ? "This content can't be processed. Try another one."
                                : nil
                        },
                        set: { if $0 == nil { viewModel.errorKind = nil } }
                    ),
                    systemImage: "exclamationmark.triangle",
                    lifetime: AppTheme.Motion.toastLifetime
                )
                // 浮于底部 Continue 之上：沿用原 errorToast 的底部偏移惯例，
                // 否则 toast 与选择页底部按钮（含禁用态）重叠 11-16pt。
                .ignoresSafeArea(.container, edges: .bottom)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom + AppTheme.Size.barControl)
            }
        }
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
            // 选中后样例图条消失，同步清掉屏蔽区，避免旧 frame 残留误伤该区域的返回手势
            carouselFrame = nil
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
            viewModel.reset()
        }
    }

    // MARK: - Selection content (action card + preset carousel + Continue)

    private var selectionContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题顶部位置只由 onboardingHeaderTop 一个数决定（N-1 单一真源）。
                        selectionHeader
                            .padding(.top, AppTheme.Size.onboardingHeaderTop)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        if hasSelection {
                            // 已选照片：固定容器（顶部=副标题下方，底部=Continue 按钮上方），
                            // 不再随图片比例撑开布局，也无需滚动避让。
                            // minHeight 保底「正常字号时顶到按钮」的高度：大字号/小屏下
                            // 照片区不被压缩、保持此高度，页面转为可滚动。
                            photoPreviewArea
                                .frame(minHeight: geo.size.height - AppTheme.Size.onboardingPhotoPreviewFixedOverhead)
                                .padding(.top, AppTheme.Space.paddingCard)
                                .transition(.opacity)
                        } else {
                            actionCard()
                                .padding(.top, AppTheme.Space.paddingPage)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.25)

                            Text("Or try a sample")
                                .font(AppTheme.Font.compactSectionTitleSerif)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                                .padding(.top, AppTheme.Space.titleToContent)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.35)

                            presetCarousel
                                .padding(.top, AppTheme.Space.paddingCard)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.4)

                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for the absolute bottom button
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .bottom)

                OnboardingBottomFade()

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
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                // 与 resultContent / Screen1 / Screen2 一致：贴底 8pt（#31 设计）。
                // merge 时曾被自动合并静默丢回 56pt 上浮，已修复。
                .ignoresSafeArea(.container, edges: .bottom)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
            }
            .animation(.easeInOut(duration: 0.3), value: hasSelection)
        }
    }

    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
            Text("Snap what's around\nyou to start")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Point at your desk, coffee, or view — no preparation needed.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 空输入区（虚线动作卡）；选照片后由 photoPreviewArea 接替

    private func actionCard() -> some View {
        // 试调：卡内上下收紧为 24，释放空间给下方示例图片区；内部内容节奏保持不变。
        VStack(spacing: AppTheme.Space.paddingCard) {
            OnboardingCaptureIllustration()

            Text("Add your photo")
                .font(AppTheme.Font.onboardingUploadTitle)
                .foregroundStyle(AppTheme.Color.textPrimary)

            VStack(spacing: AppTheme.Space.paddingS) {
                OnboardingUploadActionButton(
                    title: "Camera",
                    systemImage: "camera",
                    action: { activeSheet = .camera }
                )

                OnboardingUploadActionButton(
                    title: "Gallery",
                    systemImage: "photo",
                    action: { activeSheet = .photoLibrary }
                )
            }
            .frame(width: AppTheme.Size.onboardingUploadActionWidth)
            .padding(.top, AppTheme.Space.paddingS) // 16+8=24 标题→Camera
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.onboardingUploadCardVertical)
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

    // MARK: 已选照片预览区：固定容器（顶部=标题下方、底部=Continue 按钮上方），
    // 不随图片比例撑开布局。图片保留原比例完整显示——过宽按宽边缩放（下方留白）、
    // 过窄按高边缩放（两侧留白）；容器内水平居中、顶部对齐，不同比例图片的
    // 顶部始终在同一条线上。无底纹，仅保留圆角裁剪。

    private var photoPreviewArea: some View {
        // 固定容器由调用处提供：外层 frame(minHeight: 视口 - onboardingPhotoPreviewFixedOverhead)
        // 保底「正常字号恰好顶到 Continue 按钮上方」的高度，大字号/小屏下不压缩、页面滚动。
        // GeometryReader 把容器的确定尺寸提案传给图片：scaledToFit 按原比例贴边缩放
        // （横图贴宽、竖图贴高），frame alignment .top = 水平居中 + 顶部对齐。
        GeometryReader { geo in
            Group {
                if let image = pendingImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let card = pendingCard,
                          let image = UIImage(named: card.imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            // 圆角裁剪 + 关闭按钮都挂在图片自身上：图片在容器内缩放后宽度不定
            // （竖图两侧留白），挂在容器上圆角裁不到图片、按钮会悬空在留白处。
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(alignment: .topTrailing) {
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
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        pendingCard = card
                        pendingImage = nil
                        // 选中后样例图条消失，同步清掉屏蔽区，避免旧 frame 残留误伤该区域的返回手势
                        carouselFrame = nil
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
            Task { await viewModel.startWithCard(card) }
        }
    }

    // MARK: - Result content (moment card as hero, N-3 三态共用一个容器与同一张照片)

    private var resultContent: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题顶部位置只由 onboardingHeaderTop 一个数决定（N-1 单一真源）。
                        resultHeader
                            .padding(.top, AppTheme.Size.onboardingHeaderTop)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.bottom, AppTheme.Space.paddingCard)

                        if let image = resultImage {
                            // 卡片总高（cardHeight）纯几何、不随内容变化——卡内 photoHeight
                            // 由 OnboardingResultCard 自己按文字区实测高度 clamp(180,320)
                            // 求出，卡片外框因此在生成中/成功两态之间保持恒定（N-3 §3.2）。
                            OnboardingResultCard(
                                image: image,
                                state: resultCardState,
                                cardHeight: max(0, geo.size.height - AppTheme.Size.onboardingResultCardFixedOverhead),
                                onRetry: { Task { await viewModel.retry() } }
                            )
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for absolute bottom button
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .bottom)
            }

            OnboardingBottomFade()

            // 生成中就渲染禁用态 Continue（材质切换靠 N-2 的 0.2s 过渡），
            // 位置全程不动，成功后原位切可用态 + 文案变 Get Started。
            OnboardingResultBottomButton(
                isLoading: viewModel.isLoading,
                isSuccess: viewModel.generationResult != nil,
                action: onComplete
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .ignoresSafeArea(.container, edges: .bottom)
            .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
        }
        // 状态条不随网络恢复自动消失：保留到用户点 Try again 成功（或换素材/离开）——
        // 重试入口稳定可预期；真机监控信号不可靠，自动消失会吞掉入口。
    }

    /// 三态：生成中 / 成功 / 失败（断网/其它，fail-open——内容在、状态条说明原因、
    /// Try again 可重试、Continue 可用）。落在 OnboardingResultCard 内部渲染。
    private var resultCardState: OnboardingResultCard.Phase {
        if viewModel.isLoading { return .loading }
        if let result = viewModel.generationResult {
            return .success(sentence: result.primaryEnglish, translation: result.nativeMeaning)
        }
        if let copy = viewModel.errorKind?.failureBarCopy { return .failure(copy: copy) }
        return .loading
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
    }
}

// MARK: - Sub-views

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
                    .symbolRenderingMode(.monochrome)
                    .font(.system(
                        size: AppTheme.Size.onboardingUploadActionGlyph,
                        weight: .regular
                    ))
                    .foregroundStyle(AppTheme.Color.textMuted)

                Text(title)
                    .font(AppTheme.Font.compactActionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Size.barControl)
            .background(AppTheme.Color.cardBg, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        AppTheme.Color.onboardingUploadActionBorder,
                        lineWidth: AppTheme.Size.onboardingUploadActionBorderWidth
                    )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// 结果页时刻卡：生成中 / 成功 / 失败三态共用一个容器与同一张照片（N-3）。
/// 卡片总高（cardHeight）由调用处按视口几何算出、与内容无关；照片高度反过来
/// 由「cardHeight − 实测文字区高」clamp 到 [180, 320] 得出——文字区量多少，
/// 照片就让多少，卡片外框因此不随生成中→成功、也不随素材长短变化。
/// 三态文字区统一为「标签行 / 说明行 / 第三行」同构结构，只有内容区做 crossfade。
private struct OnboardingResultCard: View {
    enum Phase: Equatable {
        case loading
        case success(sentence: String, translation: String?)
        case failure(copy: String)
    }

    let image: Image
    let state: Phase
    let cardHeight: CGFloat
    var onRetry: () -> Void = {}

    @State private var textRegionHeight: CGFloat = 140
    @State private var skeletonPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var photoHeight: CGFloat {
        min(320, max(180, cardHeight - textRegionHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .clipped()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.35), value: photoHeight)

            textRegion
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: ResultTextHeightKey.self, value: g.size.height)
                    }
                )
                .animation(.easeInOut(duration: 0.25), value: state)
        }
        .onPreferenceChange(ResultTextHeightKey.self) { textRegionHeight = $0 }
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
    }

    @ViewBuilder
    private var textRegion: some View {
        switch state {
        case .loading:
            loadingText.transition(.opacity)
        case .success(let sentence, let translation):
            successText(sentence, translation).transition(.opacity)
        case .failure(let copy):
            failureText(copy).transition(.opacity)
        }
    }

    // MARK: 生成中：骨架模拟真实行数/行高，脉冲不含照片；状态文案挂在文字区里（与成功/失败同构）

    private var loadingText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .fill(AppTheme.Color.imagePlaceholderBg)
                .frame(width: 56, height: 11)

            VStack(alignment: .leading, spacing: 8) {
                skeletonLine(widthFraction: 1)
                skeletonLine(widthFraction: 1)
                skeletonLine(widthFraction: 0.7)
            }

            VStack(alignment: .leading, spacing: 6) {
                skeletonLine(widthFraction: 1, height: 14)
                skeletonLine(widthFraction: 0.55, height: 14)
            }

            Text("Turning your moment into English…")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.top, 2)
        }
        .opacity(skeletonPulse ? 0.55 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: skeletonPulse
        )
    }

    private func skeletonLine(widthFraction: CGFloat, height: CGFloat = 16) -> some View {
        GeometryReader { g in
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .fill(AppTheme.Color.imagePlaceholderBg)
                .frame(width: g.size.width * widthFraction, height: height)
        }
        .frame(height: height)
    }

    // MARK: 成功：与原 OnboardingMomentCard 文字区同一配方

    private func successText(_ sentence: String, _ translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MOMENT")
                .font(AppTheme.Font.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.bottom, 2)

            Text(sentence)
                .font(AppTheme.Font.englishPrimary)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .fixedSize(horizontal: false, vertical: true)

            if let translation, !translation.isEmpty {
                Text(translation)
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: 失败：断网/其它（fail-open——内容在、说明原因、Try again 可重试、Continue 可用）。
    // 定稿规格（N-3 §3.4）：图标走 danger（≤24pt 图形，合规），文案走 textPrimary——
    // 红色文字按钮在 iOS 语义里读作"破坏性操作"，Try again 是建设性动作，红只留在图标上。
    // 无容器：这是常驻页面元素，不是 AppToast 那种浮层，借浮层深底材质是类别错误。
    // 触区 44：`.frame(height: barControl)` + `.contentShape(Rectangle())`。

    private func failureText(_ copy: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COULDN'T GENERATE")
                .font(AppTheme.Font.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(AppTheme.Color.danger)

            Text(copy)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppTheme.Space.paddingS)

            Button(action: onRetry) {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                        .foregroundStyle(AppTheme.Color.danger)
                    Text("Try again")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .frame(height: AppTheme.Size.barControl)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, AppTheme.Space.paddingXS)
        }
    }
}

private struct ResultTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 结果页底部按钮：生成中禁用态 Continue → 成功后原位切可用态 + 文案变 Get Started，
/// 位置全程不动。切到可用态时叠一次 scale 0.98→1.0（0.25s，reduceMotion 跳过）——
/// 这是整个 onboarding 唯一的"完成"时刻。
private struct OnboardingResultBottomButton: View {
    let isLoading: Bool
    let isSuccess: Bool
    let action: () -> Void

    @State private var scale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingPrimaryButton(
            title: isSuccess ? "Get Started" : "Continue",
            isEnabled: !isLoading,
            action: action
        )
        .scaleEffect(scale)
        .onChange(of: isSuccess) { old, new in
            guard new, !old, !reduceMotion else { return }
            scale = 0.98
            withAnimation(.easeOut(duration: 0.25)) { scale = 1.0 }
        }
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
