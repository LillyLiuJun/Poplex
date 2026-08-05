import SwiftUI
import PhotosUI

/// Onboarding 第三页：用户亲手实操 —— 选素材（拍照/相册/预设卡）→ AI 生成 → 展示产出。
/// 布局参考 ai_studio_code(31).html：虚线动作卡（拍照主 CTA + 相册文字链接）
/// + 横滑预设卡条；结果渲染为与第一页同构的时刻卡，形成"看到样品→亲手做出"闭环。
struct OnboardingCaptureView: View {
    var viewModel: OnboardingViewModel
    var isActive: Bool = true
    var onBack: () -> Void
    var onComplete: () -> Void

    @State private var pendingCard: PresetCard?
    @State private var pendingImage: UIImage?
    @State private var activeSheet: CaptureSource?
    // Holds the photo picked inside the sheet until the sheet has fully
    // dismissed. Writing it straight into `pendingImage` would reshape the
    // layout underneath the sheet in the same transaction that tears the
    // sheet down, which desyncs the presentation state on device and leaves
    // both entry buttons dead afterwards.
    @State private var stagedImage: UIImage?
    @State private var appeared = false
    @State private var skeletonPulse = false
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
        .onHorizontalSwipe(onRight: handleBack)
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
    }

    // MARK: - Back

    // Runs in the sheet's onDismiss, i.e. only once the modal is gone, so the
    // preview/Continue layout change can never race the dismissal animation.
    // Selecting a photo (any source) also clears a previously picked card.
    private func applyStagedImage() {
        guard let image = stagedImage else { return }
        stagedImage = nil
        pendingImage = image
        pendingCard = nil
    }

    private func handleBack() {
        if isSelecting {
            onBack()
        } else {
            viewModel.reset()
        }
    }

    // MARK: - Selection content (action card + preset carousel + Continue)

    private var selectionContent: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 36)
                            .padding(.top, AppTheme.Space.paddingCard)
                            
                        selectionHeader
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        actionCard
                            .padding(.top, AppTheme.Space.paddingM)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.25)

                        if !hasSelection {
                            Text("Or try a sample")
                                .font(AppTheme.Font.englishBody)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                                .padding(.top, AppTheme.Space.paddingSection)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.35)

                            presetCarousel
                                .padding(.top, AppTheme.Space.paddingCard)
                                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.4)
                        }
                            
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, hasSelection ? 120 : 72)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            if hasSelection {
                OnboardingPrimaryButton(title: "Continue", action: confirmSelection)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasSelection)
    }

    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text("Snap what's around\nyou to start")
                .font(AppTheme.Font.pageTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Point at your desk, coffee, or view — no preparation needed.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppTheme.Space.paddingCard)
    }

    // MARK: 虚线动作卡：拍照主 CTA + 相册文字链接；已选照片时变为预览卡

    private var actionCard: some View {
        Group {
            if pendingImage != nil || pendingCard != nil {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = pendingImage {
                            Image(uiImage: image).resizable()
                        } else if let card = pendingCard {
                            Image(card.imageName).resizable()
                        }
                    }
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                    .allowsHitTesting(false)
                    
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
                HStack(spacing: AppTheme.Space.paddingSection) {
                    Button(action: { activeSheet = .camera }) {
                        VStack(spacing: AppTheme.Space.paddingM) {
                            Image(systemName: "camera")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Color.brandStrong)
                                .frame(width: 56, height: 56)
                                .background(AppTheme.Color.brandSubtleBg, in: Circle())
                            
                            Text("Camera")
                                .font(AppTheme.Font.buddy)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableButtonStyle())
                    
                    Button(action: { activeSheet = .photoLibrary }) {
                        VStack(spacing: AppTheme.Space.paddingM) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .frame(width: 56, height: 56)
                                .background(AppTheme.Color.imagePlaceholderBg, in: Circle())
                            
                            Text("Photos")
                                .font(AppTheme.Font.buddy)
                                .foregroundStyle(AppTheme.Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.vertical, AppTheme.Space.paddingM)
                .padding(AppTheme.Space.paddingPage)
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .stroke(AppTheme.Color.borderDashed, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
        }
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
                        withAnimation(.spring(duration: 0.2)) {
                            pendingCard = card
                            pendingImage = nil
                        }
                    }
                }
            }
            // 给选中态的放大留出绘制空间，避免被 ScrollView 裁掉
            .padding(AppTheme.Space.paddingXS)
        }
    }

    private func confirmSelection() {
        if let image = pendingImage {
            Task { await viewModel.startWithImage(image) }
        } else if let card = pendingCard {
            Task { await viewModel.startWithCard(card) }
        }
    }

    // MARK: - Result content (moment card as hero)

    private var resultContent: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 36)
                            .padding(.top, AppTheme.Space.paddingCard)

                        Spacer()

                        Group {
                            if viewModel.isLoading {
                                loadingCard
                                    .transition(.opacity)
                            } else if let result = viewModel.generationResult {
                                resultCard(result)
                                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                            } else if viewModel.retryCount >= 2 {
                                failedView
                                    .transition(.opacity)
                            } else {
                                errorView
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                        if viewModel.generationResult != nil {
                            Text("That's a moment from your life — now it's yours in English.")
                                .font(AppTheme.Font.chineseFaint)
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, AppTheme.Space.paddingPage)
                                .padding(.top, AppTheme.Space.paddingCard)
                                .transition(.opacity)
                        }

                        Spacer()
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

    // MARK: 结果卡：与第一页样品卡同构 —— 用户亲手做出的第一张卡

    private func resultCard(_ card: AICard) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            if let image = resultImage {
                OnboardingMomentCard(image: image, sentence: card.primaryEnglish, photoHeight: 200)
            }
        }
    }

    // MARK: 生成中：照片定格 + 暖色骨架（呼吸脉冲）+ 状态文案

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            VStack(alignment: .leading, spacing: 0) {
                if let image = resultImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .allowsHitTesting(false)
                }

                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                            .fill(AppTheme.Color.imagePlaceholderBg)
                            .frame(maxWidth: i == 2 ? 160 : .infinity)
                            .frame(height: 22)
                    }
                }
                .padding(AppTheme.Space.paddingCard)
                .opacity(skeletonPulse ? 0.45 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: skeletonPulse
                )
            }
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
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
        }
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(viewModel.errorMessage ?? "Something went wrong.")
                .font(AppTheme.Font.englishBody)
                .foregroundStyle(AppTheme.Color.textSecondary)

            Button(action: { Task { await viewModel.retry() } }) {
                Text("Try again")
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, AppTheme.Space.paddingCard)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.brandSubtleBg, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var failedView: some View {
        Text("No worries — you can explore inside the app.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
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
                    .frame(width: 90, height: 120)
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
