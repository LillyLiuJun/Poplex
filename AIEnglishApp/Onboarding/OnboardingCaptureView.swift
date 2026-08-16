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
                        Color.clear
                            .frame(height: 36)
                            .padding(.top, AppTheme.Space.paddingCard)

                        selectionHeader
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
                .padding(.bottom, AppTheme.Space.paddingScreenBottom)
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
        .padding(.top, AppTheme.Space.paddingCard)
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
        // GeometryReader 的"理想高度"极小（同 Spacer），在 ScrollView 的 VStack 里
        // 才能正确吃掉"标题下方 → Continue 按钮上方"的剩余空间。若用 ZStack 直接
        // 作为 flexible 子项，其 ideal 高度会传递成图片原始高度，容器被撑到原图高、
        // 照片按宽边自然放大并延伸到按钮后方（ScrollView 里 minHeight 无法约束它）。
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
                            Spacer(minLength: 0)
                        } else if let result = viewModel.generationResult {
                            resultCard(result)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer(minLength: 0)
                        } else if let image = resultImage {
                            // 失败态（断网/其它）：保留用户所选素材图 + 常驻状态条（fail-open——
                            // 内容在、状态条说明原因、Try again 可重试、Continue 可用）
                            VStack(spacing: 0) {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 195)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                                    .allowsHitTesting(false)

                                if let copy = viewModel.errorKind?.failureBarCopy {
                                    FailureStatusBar(copy: copy) {
                                        Task { await viewModel.retry() }
                                    }
                                }
                            }
                            .transition(.opacity)
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for absolute bottom button
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .bottom)
            }

            OnboardingBottomFade()

            if !viewModel.isLoading {
                bottomButton
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.generationResult != nil)
        // 状态条不随网络恢复自动消失：保留到用户点 Try again 成功（或换素材/离开）——
        // 重试入口稳定可预期；真机监控信号不可靠，自动消失会吞掉入口。
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

    @ViewBuilder
    private var bottomButton: some View {
        if (viewModel.selectedCard != nil || viewModel.selectedImage != nil) {
            OnboardingPrimaryButton(
                title: viewModel.generationResult != nil ? "Get Started" : "Continue",
                action: onComplete
            )
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

/// 断网/其它失败的状态条：嵌在素材图下方、常驻（不自动消失）。
/// 网络恢复由既有 onChange 清 errorKind → 状态条随之消失（图保留）。
private struct FailureStatusBar: View {
    let copy: String
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(copy)
                .font(AppTheme.Font.chineseFaint)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AppTheme.Space.paddingCard)

            Button(action: onRetry) {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                        .foregroundStyle(AppTheme.Color.brandStrong)   // 图标点缀与 toast 一致
                    Text("Try again")
                        .font(AppTheme.Font.buddy)
                        .foregroundStyle(AppTheme.Color.textOnChip)   // 深底胶囊上的浅色文字（同 toast）
                }
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingS)
                .background(AppTheme.Color.textPrimary.opacity(0.82), in: Capsule())   // 同 toast 深底
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
