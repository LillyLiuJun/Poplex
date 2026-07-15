import SwiftUI
import AVFoundation

private enum RightButtonMode: Equatable {
    case camera
    case send
    case loading
}

// Measures the actual rendered width of the capsule's input row.
private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// Measures the single-line width of the current text string.
private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct InputBar: View {
    @Binding var text: String
    @Binding var image: UIImage?
    var isLoading: Bool
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var activeSheet: CaptureSource?
    @State private var showCameraPermissionAlert = false
    @State private var stagedImage: UIImage?
    @State private var showAttachmentMenu = false

    // Layout measurement state
    @State private var rowWidth: CGFloat = 0
    @State private var measuredTextWidth: CGFloat = 0
    // Tracks whether the keyboard was open so we can re-focus after layout switch.
    @State private var wasKeyboardOpen = false

    // Total horizontal space consumed by fixed elements in single-line row:
    // leading-padding + plus-button + right-button + right-button-padding (×2 sides)
    private let buttonAreaWidth: CGFloat =
        AppTheme.Space.paddingS +
        AppTheme.Size.barControl +
        AppTheme.Size.barControl +
        AppTheme.Space.paddingXS * 2

    private var availableInlineWidth: CGFloat {
        max(0, rowWidth - buttonAreaWidth)
    }

    // Switches to two-row layout the moment text would overflow the inline zone.
    private var isMultiLine: Bool {
        guard availableInlineWidth > 0, !text.isEmpty else { return false }
        return measuredTextWidth > availableInlineWidth
    }

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
        capsule
            .overlay(alignment: .topLeading) {
                if showAttachmentMenu {
                    attachmentMenu
                        .offset(y: -(90 + AppTheme.Space.paddingS))
                        .transition(
                            .scale(scale: 0.85, anchor: .bottomLeading)
                                .combined(with: .opacity)
                        )
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingS)
            .onChange(of: isFocused) { _, focused in
                wasKeyboardOpen = focused
                if focused {
                    withAnimation(.easeOut(duration: 0.18)) { showAttachmentMenu = false }
                }
            }
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

    // MARK: - Capsule

    private var capsule: some View {
        VStack(spacing: 0) {
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
        .animation(.easeOut(duration: 0.2), value: isMultiLine)
    }

    // MARK: - Input row (layout switches based on text width)

    private var inputRow: some View {
        Group {
            if isMultiLine {
                multiLineInputRow
            } else {
                singleLineInputRow
            }
        }
        // Measure the full row width so we know how much space the inline text zone has.
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: RowWidthKey.self, value: geo.size.width)
            }
        )
        // Hidden single-line Text tells us how wide the current string would be at lineLimit(1).
        // This fires before the layout renders, so the switch is seamless.
        .overlay(alignment: .leading) {
            if !text.isEmpty {
                Text(text)
                    .lineLimit(1)
                    .font(AppTheme.Font.englishBody)
                    .fixedSize()
                    .opacity(0)
                    .allowsHitTesting(false)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TextWidthKey.self, value: geo.size.width)
                        }
                    )
            }
        }
        .onPreferenceChange(RowWidthKey.self) { if $0 > 0 { rowWidth = $0 } }
        .onPreferenceChange(TextWidthKey.self) { measuredTextWidth = text.isEmpty ? 0 : $0 }
        // Re-focus the TextField after the layout switch if the keyboard was already open.
        .onChange(of: isMultiLine) { _, _ in
            if wasKeyboardOpen {
                DispatchQueue.main.async { isFocused = true }
            }
        }
    }

    // MARK: - Single-line layout:  [+]  [TextField]  [●]

    private var singleLineInputRow: some View {
        HStack(alignment: .center, spacing: 0) {
            plusButton
            textField
            rightCircleButton
                .padding(AppTheme.Space.paddingXS)
        }
        .padding(.leading, AppTheme.Space.paddingS)
    }

    // MARK: - Multi-line layout:  [text — full width]
    //                             [+]      [spacer]      [●]

    private var multiLineInputRow: some View {
        VStack(spacing: 0) {
            textField
                .padding(.horizontal, AppTheme.Space.paddingCard)
                .padding(.top, AppTheme.Space.paddingCard)
                .padding(.bottom, AppTheme.Space.paddingXS)
            HStack(alignment: .center, spacing: 0) {
                plusButton
                Spacer()
                rightCircleButton
                    .padding(AppTheme.Space.paddingXS)
            }
            .padding(.leading, AppTheme.Space.paddingS)
        }
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
                .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAttachmentMenu)
        }
        .padding(.vertical, AppTheme.Space.paddingXS)
        .contentShape(Rectangle())
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }

    // MARK: - TextField

    private var textField: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("Your moment").foregroundStyle(AppTheme.Color.textFaint),
            axis: .vertical
        )
        .lineLimit(1...4)
        .fixedSize(horizontal: false, vertical: true)
        .font(AppTheme.Font.englishBody)
        .foregroundStyle(AppTheme.Color.textPrimary)
        .tint(AppTheme.Color.interactive)
        .focused($isFocused)
        // Stable identity across layout switches — prevents focus loss during the transition.
        .id("input-textfield")
        .onChange(of: text) { _, newValue in
            if !newValue.isEmpty,
               newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = ""
            }
        }
    }

    // MARK: - Right circle button  (camera ⇄ arrow.up ⇄ spinner)

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
                    .allowsHitTesting(false)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { image = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color(uiColor: .systemGray3))
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Space.paddingS)
        .padding(.top, AppTheme.Space.paddingM)
        .padding(.bottom, AppTheme.Space.paddingS)
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
