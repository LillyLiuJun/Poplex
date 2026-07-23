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
        ZStack {
            OnboardingAuraBackground()

            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.leading, AppTheme.Space.paddingCard)
                    .padding(.top, AppTheme.Space.paddingCard)

                // Content area morphs in-place on Continue.
                if isSelecting {
                    selectionContent
                        .transition(.opacity)
                } else {
                    resultContent
                        .transition(.opacity)
                }
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

    private var backButton: some View {
        Button(action: handleBack) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(AppTheme.Space.paddingS)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    selectionHeader
                        .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                    actionCard
                        .padding(.top, AppTheme.Space.paddingSection)
                        .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.15)

                    Text("NO PHOTO READY? TRY A SAMPLE")
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .tracking(0.6)
                        .padding(.top, AppTheme.Space.paddingSection)
                        .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.25)

                    presetCarousel
                        .padding(.top, AppTheme.Space.paddingCard)
                        .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.3)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, hasSelection ? 100 : 72)
            }
            .scrollBounceBehavior(.basedOnSize)

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
                .font(AppTheme.Font.screenTitle)
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
        VStack(spacing: AppTheme.Space.paddingCard) {
            if let image = pendingImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    // clip 只裁绘制不裁命中——展示用，放弃命中防止吞掉下方链接点击
                    .allowsHitTesting(false)

                HStack(spacing: AppTheme.Space.paddingSection) {
                    linkButton("Retake", source: .camera)
                    linkButton("Photos", source: .photoLibrary)
                }
            } else {
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .frame(width: AppTheme.Size.iconBadge, height: AppTheme.Size.iconBadge)
                    .background(AppTheme.Color.brandSubtleBg, in: Circle())

                Text("Take a quick photo to see instant results")
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .multilineTextAlignment(.center)

                OnboardingPrimaryButton(title: "Take a Photo") {
                    activeSheet = .camera
                }

                Button(action: { activeSheet = .photoLibrary }) {
                    Text("Choose from Photos")
                        .font(AppTheme.Font.buddy)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .underline()
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.98, pressedOpacity: 0.6))
            }
        }
        .padding(AppTheme.Space.paddingPage)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(AppTheme.Color.borderDashed, style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
    }

    private func linkButton(_ title: String, source: CaptureSource) -> some View {
        Button(action: { activeSheet = source }) {
            Text(title)
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.brandStrong)
                .underline()
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, pressedOpacity: 0.6))
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
        VStack(alignment: .leading, spacing: 0) {
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

            if let trigger = card.sceneTrigger {
                Text(trigger)
                    .font(AppTheme.Font.buddy)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .frame(width: 100, height: 120)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        Text(card.title)
                            .font(AppTheme.Font.pos)
                            .foregroundStyle(AppTheme.Color.cameraControl)
                            .lineLimit(1)
                            .padding(.horizontal, AppTheme.Space.paddingXS)
                            .padding(.vertical, AppTheme.Space.paddingXS)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.clear, AppTheme.Color.cameraBg.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

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
