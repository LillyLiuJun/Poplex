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
    // 样例卡横滑条的 ScrollViewReader id：相机权限被拒时"Use a sample instead"用它滚过去
    static let sampleCarouselID = "onboardingSampleCarousel"
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
    // 相机权限被拒：不弹通用 alert，Camera 行内变成说明 + 两个出口（F-3/C-1）
    @State private var cameraPermissionDenied = false
    // 顶部渐隐随滚动出现（F-4）；selectionContent / resultContent 互斥显示，共用一个值
    @State private var scrollOffset: CGFloat = 0
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
            // 这里原本又画了一层 OnboardingAuraBackground —— 与 OnboardingView 在
            // 三页背后铺的那层重复。光晕移进背景层之后重复就会叠成双份亮度（点阵
            // 底纹同理），故移除；背景由 OnboardingView 统一提供。

            // Content area morphs in-place on Continue.
            if isSelecting {
                selectionContent
                    .transition(.opacity)
            } else {
                resultContent
                    .transition(.opacity)
            }

            // 顶部渐隐随滚动出现（F-4）：静止时标题完整，一滚才吃掉标题顶部。
            //
            // 挂在 body 的外层 ZStack、而不是各自内容里：selectionContent 的层级是
            // GeometryReader → ScrollViewReader → ZStack，遮罩若放在最内层 ZStack 里，
            // 就成了 GeometryReader 的后代——此时 .ignoresSafeArea(edges: .top) 已经
            // 没有安全区可让它扩展（外层 GeometryReader 已把安全区吃掉），遮罩顶只到
            // 安全区上沿、且 z 序被限制在该子树内，真机表现为「这一页滚动时遮罩不出现」。
            // Screen1 / Screen2 / resultContent 的遮罩本来就是 GeometryReader 的兄弟节点，
            // 所以只有选择页翻车。提到最外层后四处结构一致，也顺便去掉了重复实例。
            OnboardingTopFade(scrollOffset: scrollOffset)
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
                .padding(.leading, AppTheme.Size.onboardingBackLeading)
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
        .onAppear { if isActive { triggerEntrance() } }
        .onChange(of: isActive) { _, active in if active { triggerEntrance() } }
        // 选择页与结果页共用同一个 scrollOffset（同一时刻只渲染其中一个）。切换的瞬间
        // 新页面的 ScrollView 还没上报，旧值会残留一帧、顶部渐隐闪一下——切换时清零。
        .onChange(of: isSelecting) { _, _ in scrollOffset = 0 }
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
                // 浮于底部 Continue 之上：原来错用 barControl(44) 当 CTA 高度，
                // 但 CTA 实际高度是 inputBarMinHeight(52)，导致 toast 与按钮重叠 12pt
                // （F-2 修正）。距安全区下沿 = Continue 底距(12) + CTA 高(52) + 间距(12)。
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom
                    + AppTheme.Size.inputBarMinHeight
                    + AppTheme.Space.paddingM)
            }
        }
    }

    private func triggerEntrance() {
        guard !appeared else { return }
        DispatchQueue.main.async {
            appeared = true
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
            ScrollViewReader { scrollProxy in
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
                                    // 与空态的虚线卡同一个「标题组→内容」间距：两态切换时内容顶不跳。
                                    .padding(.top, AppTheme.Space.onboardingHeaderToContent)
                                    .transition(.opacity)
                            } else {
                                actionCard(scrollProxy: scrollProxy)
                                    .padding(.top, AppTheme.Space.onboardingHeaderToContent)
                                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.25)

                                Text("Or try a sample")
                                    .font(AppTheme.Font.compactSectionTitleSerif)
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                    // 虚线卡与例图区是两个组：32
                                    .padding(.top, AppTheme.Space.onboardingHeaderToContent)
                                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.35)

                                presetCarousel
                                    .id(OnboardingCaptureLayout.sampleCarouselID)
                                    // 标签是例图条的引导语，与「标题→副标」是同一种关系：8
                                    .padding(.top, AppTheme.Space.onboardingTitleToLead)
                                    // 右侧出血到屏幕边缘：四张卡总宽 464（104×4 + 16×3）> 内容宽 362，本来就要滑，
                                    // 让最后一张被屏幕边缘切开是最有效的可滚动暗示。
                                    // 代价是右边不再有对齐轴——滑动内容本就不该当作对齐元素。
                                    .padding(.trailing, -AppTheme.Space.paddingPage)
                                    .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.4)

                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for the absolute bottom button
                        .frame(minHeight: geo.size.height)
                        .onboardingScrollOffsetProbe()   // iOS 17 走 PreferenceKey 兜底，iOS 18+ 无副作用
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onboardingScrollOffsetTracking($scrollOffset)

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
                    // 与 resultContent / Screen1 / Screen2 一致：距安全区下沿（F-2 统一语义）。
                    .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
                }
                .animation(.easeInOut(duration: 0.3), value: hasSelection)
            }
        }
    }

    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
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

    private func actionCard(scrollProxy: ScrollViewProxy) -> some View {
        // 试调：卡内上下收紧为 24，释放空间给下方示例图片区；内部内容节奏保持不变。
        VStack(spacing: AppTheme.Space.paddingCard) {
            OnboardingCaptureIllustration()

            Text("Add your photo")
                .font(AppTheme.Font.onboardingUploadTitle)
                .foregroundStyle(AppTheme.Color.textPrimary)

            // 相机权限被拒：不弹通用 alert，行内给两个出口（F-3/C-1）——
            // Open Settings，以及滚到下方已有的「Or try a sample」预设卡区，被拒不是死路。
            if cameraPermissionDenied {
                CameraAccessDeniedNotice(
                    onOpenSettings: { PermissionService.openSettings() },
                    onUseSample: {
                        withAnimation {
                            scrollProxy.scrollTo(OnboardingCaptureLayout.sampleCarouselID, anchor: .top)
                        }
                    }
                )
            }

            VStack(spacing: AppTheme.Space.paddingS) {
                OnboardingUploadActionButton(
                    title: "Camera",
                    systemImage: "camera",
                    action: checkCameraPermission
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

    /// 与 InputBar 共用同一份 `PermissionService`，消除相机权限检查的两套实现（F-3/C-1）。
    /// `.undetermined` 时 await 请求结果，授权后才置 `activeSheet`——首次进入时如果不等
    /// 授权就先呈现 sheet，session 会在权限未决下配置完成，用户点「允许」后画面仍不出现。
    private func checkCameraPermission() {
        switch PermissionService.cameraStatus {
        case .granted:
            cameraPermissionDenied = false
            activeSheet = .camera
        case .undetermined:
            Task {
                if await PermissionService.requestCamera() {
                    cameraPermissionDenied = false
                    activeSheet = .camera
                } else {
                    cameraPermissionDenied = true
                }
            }
        case .denied:
            cameraPermissionDenied = true
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
            // 卡间距 12 → 16：四张卡此前挤成一片色块，读不出「这是四个独立选项」。
            HStack(spacing: AppTheme.Space.paddingCard) {
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
                            // 结果页特例 12（非 24）：长句时卡底距遮罩顶只剩 8pt。与标题→副标
                            // 的 8→12 恰好抵消，卡片位置与改前逐像素相同。
                            .padding(.bottom, AppTheme.Space.onboardingResultHeaderToCard)

                        if let image = resultImage {
                            // 照片高度锁定、卡片顶对齐（F-6，替换 N-3 §3.2 的居中+自适应）——
                            // 卡片总高 = 锁定照片高 + 文字区实际高，随内容自然伸缩，
                            // 变化量落在卡片下边缘，不落在照片上。
                            OnboardingResultCard(
                                image: image,
                                state: resultCardState,
                                onRetry: { Task { await viewModel.retry() } }
                            )
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .animation(.easeInOut(duration: 0.35), value: viewModel.generationResult != nil)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for absolute bottom button
                    .frame(minHeight: geo.size.height)
                    .onboardingScrollOffsetProbe()   // iOS 17 走 PreferenceKey 兜底，iOS 18+ 无副作用
                }
                .scrollBounceBehavior(.basedOnSize)
                .onboardingScrollOffsetTracking($scrollOffset)
            }

            OnboardingBottomFade()

            // F-5：撤回「生成中就渲染禁用态 Continue」——卡片位置在 F-6 后已经稳定，
            // 按钮生成中不出现，结果落地时才淡入 + 轻微上移（非硬出现，见
            // OnboardingResultBottomButton 的入场动效）。
            if !viewModel.isLoading {
                OnboardingResultBottomButton(
                    isSuccess: viewModel.generationResult != nil,
                    action: onComplete
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
            }
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
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
            (Text("Here's your first ") + Text("moment.").foregroundStyle(AppTheme.Color.brandStrong))
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // 副标颜色与前三页统一（此前是 textMuted #7C7773 4.4:1，浅了两档色阶，
            // 而它承载的是全流程最该被读到的那句点题话）。
            Text("Your photo, now something you can say.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
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

/// 相机权限被拒时的行内说明（F-3/C-1）：被拒不能是死路，给两个出口。
/// 橙做文字走 `brandInk`（唯一合规出口），底用 `imagePlaceholderBg`（既有浅色填充语义）。
private struct CameraAccessDeniedNotice: View {
    var onOpenSettings: () -> Void
    var onUseSample: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text("Camera access is off")
                .font(AppTheme.Font.compactActionLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Turn it on in Settings, or use one of the samples below.")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Space.paddingCard) {
                Button("Open Settings", action: onOpenSettings)
                Button("See samples", action: onUseSample)
            }
            .font(AppTheme.Font.statusNote)
            .foregroundStyle(AppTheme.Color.brandInk)
            .padding(.top, AppTheme.Space.paddingXS)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.imagePlaceholderBg, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .buttonStyle(.plain)
    }
}

/// 结果页时刻卡：生成中 / 成功 / 失败三态共用一个容器与同一张照片（N-3，高度策略 F-6 改）。
/// 照片高度锁定（onboardingResultPhotoHeight），卡片总高 = 照片高 + 文字区实际高，
/// 随内容自然伸缩、顶对齐——不再用「卡片总高恒定 + 照片自适应」反向推导：那套策略下
/// 卡片总高不变但照片会随文字长度反向伸缩，照片是画面主体，一动就是「跳」。
/// 现在变化量落在卡片下边缘（没人盯着看），照片、MOMENT 标签、卡顶逐帧恒定。
/// 三态文字区统一为「标签行 / 说明行 / 第三行」同构结构，只有内容区做 crossfade。
private struct OnboardingResultCard: View {
    enum Phase: Equatable {
        case loading
        case success(sentence: String, translation: String?)
        case failure(copy: String)
    }

    let image: Image
    let state: Phase
    var onRetry: () -> Void = {}

    @State private var skeletonPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 照片高度锁定（F-6，AppTheme.Size.onboardingResultPhotoHeight）——不再随
            // 文字区高度反算，四态（含失败态）共用同一个数，照片下沿因此逐帧恒定。
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.Size.onboardingResultPhotoHeight)
                .clipped()
                .allowsHitTesting(false)

            textRegion
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.25), value: state)
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

/// 结果页底部按钮：生成中禁用态 Continue → 成功后原位切可用态 + 文案变 Get Started，
/// 位置全程不动。切到可用态时叠一次 scale 0.98→1.0（0.25s，reduceMotion 跳过）——
/// 这是整个 onboarding 唯一的"完成"时刻。
/// 结果页底部按钮：只在 `!isLoading` 时挂载（F-5，撤回「生成中就渲染禁用态 Continue」
/// 的上一轮决定）——挂载即淡入 + 6pt 上移（非硬出现），reduceMotion 时只淡入。
/// isSuccess 从 false→true（重试成功等场景）时再叠一次 scale 0.98→1.0 的完成态 pop。
private struct OnboardingResultBottomButton: View {
    let isSuccess: Bool
    let action: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var appearedButton = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingPrimaryButton(
            title: isSuccess ? "Get Started" : "Continue",
            action: action
        )
        .scaleEffect(scale)
        .opacity(appearedButton ? 1 : 0)
        .offset(y: (appearedButton || reduceMotion) ? 0 : 6)
        .animation(.easeOut(duration: 0.25), value: appearedButton)
        .onAppear {
            // 延到下一帧再翻，否则初始隐藏态来不及渲染，淡入会被 SwiftUI 跳过
            // （与 OnboardingScreen1View.triggerEntrance 同款处理）。
            DispatchQueue.main.async { appearedButton = true }
        }
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
