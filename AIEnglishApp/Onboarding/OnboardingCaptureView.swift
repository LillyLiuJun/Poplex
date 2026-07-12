import SwiftUI
import PhotosUI

struct OnboardingCaptureView: View {
    var viewModel: OnboardingViewModel
    var onBack: () -> Void
    var onComplete: () -> Void

    @State private var pendingCard: PresetCard?
    @State private var pendingImage: UIImage?
    @State private var activeSheet: CaptureSource?

    private var isSelecting: Bool { viewModel.selectedCard == nil && viewModel.selectedImage == nil }
    private var hasSelection: Bool { pendingCard != nil || pendingImage != nil }
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            backButton
                .padding(.leading, AppTheme.Space.paddingCard)
                .padding(.top, AppTheme.Space.paddingCard)

            // Title stays fixed — it's the same question regardless of phase.
            Text("What's happening\naround you right now?")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingCard)
                .padding(.bottom, AppTheme.Space.paddingCard)

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
        .sheet(item: $activeSheet) { source in
            switch source {
            case .camera:
                CameraCaptureView(
                    onImage: { image in
                        pendingImage = image
                        pendingCard = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            case .photoLibrary:
                PHPickerView(
                    image: $pendingImage,
                    onFinish: { activeSheet = nil }
                )
            }
        }
        .onChange(of: pendingImage) { _, newImage in
            // Selecting a photo (any source) clears a previously picked card.
            if newImage != nil { pendingCard = nil }
        }
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
    }

    private func handleBack() {
        if isSelecting {
            onBack()
        } else {
            viewModel.reset()
        }
    }

    // MARK: - Selection content (camera + grid + Continue)

    private var selectionContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        CaptureButton(icon: "camera", label: "Take a photo") {
                            activeSheet = .camera
                        }
                        CaptureButton(icon: "photo.on.rectangle", label: "Choose photo") {
                            activeSheet = .photoLibrary
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    Text("Nothing in mind? Try one of these.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.top, AppTheme.Space.paddingSection)
                        .padding(.bottom, AppTheme.Space.paddingCard)

                    // Picked image preview (camera / library)
                    if let image = pendingImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                        .stroke(Color.accentColor, lineWidth: 3)
                                )
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(8)
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, AppTheme.Space.paddingCard)
                    }

                    LazyVGrid(columns: columns, spacing: AppTheme.Space.paddingCard) {
                        ForEach(PresetCard.all) { card in
                            PresetCardTile(
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
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, hasSelection ? 100 : 72)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            if hasSelection {
                Button(action: confirmSelection) {
                    Text("Continue")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingCard)
                .padding(.bottom, 56)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasSelection)
    }

    private func confirmSelection() {
        if let image = pendingImage {
            Task { await viewModel.startWithImage(image) }
        } else if let card = pendingCard {
            Task { await viewModel.startWithCard(card) }
        }
    }

    // MARK: - Result content (image thumbnail + generated text as hero)

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Small thumbnail — visual anchor, not the hero
            Group {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let card = viewModel.selectedCard {
                    Image(card.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingSection)

            // Generated content — the real hero
            Group {
                if viewModel.isLoading {
                    skeletonView
                } else if let result = viewModel.generationResult {
                    generatedContentView(result)
                } else if viewModel.retryCount >= 2 {
                    failedView
                } else {
                    errorView
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            Spacer()

            if !viewModel.isLoading {
                bottomButton
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, 56)
            }
        }
    }

    // MARK: - States

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: i == 2 ? 160 : .infinity)
                    .frame(height: 22)
            }
        }
    }

    @ViewBuilder
    private func generatedContentView(_ card: AICard) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(card.primaryEnglish)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let trigger = card.sceneTrigger {
                Text(trigger)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("That's a moment from your life — now it's yours in English.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .padding(.top, AppTheme.Space.paddingXS)
        }
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text(viewModel.errorMessage ?? "Something went wrong.")
                .font(.body)
                .foregroundStyle(AppTheme.Color.textSecondary)
            Button("Try again") { Task { await viewModel.retry() } }
                .buttonStyle(.bordered)
        }
    }

    private var failedView: some View {
        Text("No worries — you can explore inside the app.")
            .font(.body)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.generationResult != nil || viewModel.retryCount >= 2 {
            Button(action: onComplete) {
                Text(viewModel.retryCount >= 2 ? "Let's dive in." : "Get Started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Sub-views

private struct CaptureButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        }
        .foregroundStyle(AppTheme.Color.textPrimary)
    }
}

private struct PresetCardTile: View {
    let card: PresetCard
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                    )
                    .scaleEffect(isSelected ? 1.03 : 1.0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
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
