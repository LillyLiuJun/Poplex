import SwiftUI
import AVFoundation

// Right circle button mode — derived from content + loading state.
// Focused-but-empty is intentionally the same as idle: camera stays visible
// because the user may want to take a photo rather than type.
private enum RightButtonMode: Equatable {
    case camera   // idle or focused with no content
    case send     // has text or an image → tap submits
    case loading  // response in flight → spinner, no action
}

struct InputBar: View {
    @Binding var text: String
    @Binding var image: UIImage?
    var isLoading: Bool
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var activeSheet: CaptureSource?
    @State private var showCameraPermissionAlert = false
    // Staged until the sheet is fully dismissed; applying it in onDismiss prevents
    // the thumbnail layout change from racing the sheet teardown on device.
    @State private var stagedImage: UIImage?
    @State private var showAttachmentMenu = false

    // MARK: - Derived state

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil
    }

    private var rightButtonMode: RightButtonMode {
        if isLoading { return .loading }
        return hasContent ? .send : .camera
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Transparent layer captures taps anywhere outside the menu.
            if showAttachmentMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showAttachmentMenu = false
                        }
                    }
            }

            // Capsule + popup anchored to the bottom-leading corner of the capsule.
            ZStack(alignment: .bottomLeading) {
                capsule

                if showAttachmentMenu {
                    attachmentMenu
                        // Rise above the capsule: 52pt height + 8pt gap.
                        .offset(x: 0, y: -(52 + AppTheme.Space.paddingS))
                        .transition(
                            .scale(scale: 0.85, anchor: .bottomLeading)
                                .combined(with: .opacity)
                        )
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingS)
        }
        // Single sheet, source-switched — two live modals can never co-exist,
        // so SwiftUI's presentation state cannot desync between camera and picker.
        .sheet(item: $activeSheet, onDismiss: applyStagedImage) { source in
            switch source {
            case .camera:
                CameraCaptureView(onImage: { stagedImage = $0 }, onClose: { activeSheet = nil })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            case .photoLibrary:
                PHPickerView(image: $stagedImage, onFinish: { activeSheet = nil })
            }
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is required to take photos. Open Settings to allow access.")
        }
    }

    // MARK: - Capsule (the single glass container)
    // Everything visible lives inside one glassCapsule() — no nested glass.

    private var capsule: some View {
        VStack(spacing: 0) {
            // Thumbnail above the input row when an image is staged (iMessage layout).
            if let img = image {
                thumbnailRow(img)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal:   .scale(scale: 0.85).combined(with: .opacity)
                    ))
            }
            inputRow
        }
        .frame(minHeight: 52)
        .glassCapsule()
        .animation(.easeOut(duration: 0.2), value: image != nil)
    }

    // MARK: - Input row:  [+]  [TextField]  [●]

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            plusButton
            textField
            // 4pt padding gives the 44pt button breathing room inside the 52pt capsule.
            rightCircleButton
                .padding(AppTheme.Space.paddingXS)
        }
        .padding(.leading, AppTheme.Space.paddingS)
    }

    // MARK: - + Button (attachment menu trigger)

    private var plusButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showAttachmentMenu.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.Color.textPrimary)
                // 44pt hit area — prevents accidental TextField focus when aiming for +.
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .contentShape(Rectangle())
                .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAttachmentMenu)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }

    // MARK: - TextField (no inner background — text sits directly on the glass)

    private var textField: some View {
        TextField("", text: $text, axis: .vertical)
            .lineLimit(1...4)
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textPrimary)
            .tint(AppTheme.Color.interactive)
            .focused($isFocused)
            .overlay(alignment: .leadingFirstTextBaseline) {
                // Custom placeholder gives token-controlled color (textFaint / ash).
                // Baseline-aligned so placeholder and typed text sit on the same line.
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your moment")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textFaint)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: text) { _, newValue in
                // A trailing newline after deleting the last character leaves the
                // field visually empty but suppresses the placeholder. Collapse it.
                if !newValue.isEmpty,
                   newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = ""
                }
            }
    }

    // MARK: - Right circle button  (camera ⇄ arrow.up ⇄ spinner)
    // Color stays nearBlack in all states; only the icon changes.

    private var rightCircleButton: some View {
        Button {
            switch rightButtonMode {
            case .camera:  checkCameraPermission()
            case .send:    isFocused = false; onSend()
            case .loading: break
            }
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.Color.interactive)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                rightButtonIcon
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: rightButtonMode)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(rightButtonMode == .loading)
    }

    @ViewBuilder
    private var rightButtonIcon: some View {
        switch rightButtonMode {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.85)
        case .send:
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        case .camera:
            Image(systemName: "camera.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    // MARK: - Attachment menu popup

    private var attachmentMenu: some View {
        VStack(spacing: 0) {
            menuItem(icon: "camera.fill", label: "Camera") {
                showAttachmentMenu = false
                checkCameraPermission()
            }
            Divider()
                .overlay(AppTheme.Color.border)
            menuItem(icon: "photo.on.rectangle", label: "Photo Library") {
                showAttachmentMenu = false
                activeSheet = .photoLibrary
            }
        }
        .glassContainer(cornerRadius: AppTheme.Radius.medium)
        .fixedSize()
    }

    private func menuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Space.paddingS) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                Text(label)
                    .font(AppTheme.Font.englishBody)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppTheme.Color.textPrimary)
            .padding(.horizontal, AppTheme.Space.paddingCard)
            .padding(.vertical, AppTheme.Space.paddingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Thumbnail row (inside capsule, above input row)

    @ViewBuilder
    private func thumbnailRow(_ img: UIImage) -> some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                    // clipShape clips drawing but not hit-testing; disable image hits
                    // so the remove button behind it stays reachable.
                    .allowsHitTesting(false)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { image = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color(uiColor: .systemGray3))
                        .offset(x: 6, y: -6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Space.paddingS)
        .padding(.top, AppTheme.Space.paddingS)
    }

    // MARK: - Helpers

    private func applyStagedImage() {
        guard let staged = stagedImage else { return }
        stagedImage = nil
        image = staged
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            activeSheet = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { activeSheet = .camera }
                }
            }
        default:
            showCameraPermissionAlert = true
        }
    }
}
