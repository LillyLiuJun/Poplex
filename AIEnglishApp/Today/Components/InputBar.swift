import SwiftUI
import AVFoundation

struct InputBar: View {
    @Binding var text: String
    @Binding var image: UIImage?
    var isLoading: Bool
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var activeSheet: CaptureSource?
    @State private var showCameraPermissionAlert = false
    // Holds the photo picked inside the sheet until the sheet has fully
    // dismissed. Writing it straight into `image` would insert the thumbnail
    // row (layout change) in the same transaction that tears the sheet down,
    // which desyncs the presentation state on device and leaves the camera /
    // library buttons dead afterwards.
    @State private var stagedImage: UIImage?

    private var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil) && !isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            if let selectedImage = image {
                thumbnailPreview(selectedImage)
            }
            inputRow
        }
        .padding(AppTheme.Space.paddingCard)
        .glassContainer()
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.bottom, AppTheme.Space.paddingS)
        // One sheet, switched by CaptureSource — never two live modals at once,
        // so SwiftUI's presentation state can't desync between camera & photo.
        // Both sources write into `stagedImage`; the result is applied in
        // onDismiss, after the presentation is fully torn down.
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

    private var inputRow: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Button { checkCameraPermission() } label: {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Color.textAccent)
            }
            .buttonStyle(PressableButtonStyle())
            Button { activeSheet = .photoLibrary } label: {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Color.textAccent)
            }
            .buttonStyle(PressableButtonStyle())
            TextField("Anything in your life....", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(AppTheme.Space.paddingS)
                .background(AppTheme.Color.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    // Collapse whitespace/newline-only content to a true empty
                    // string so the placeholder reappears (a lingering "\n"
                    // otherwise suppresses it while the field looks blank).
                    if !newValue.isEmpty,
                       newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        text = ""
                    }
                }
            Button {
                isFocused = false
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle")
                    .font(.title)
                    .foregroundStyle(canSend ? AppTheme.Color.textAccent : AppTheme.Color.textSecondary)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSend)
        }
    }

    @ViewBuilder
    private func thumbnailPreview(_ img: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                // clipShape only clips drawing, not hit-testing: the filled
                // photo overflows this frame invisibly and would eat taps on
                // the camera/library buttons below. Keep the X button live,
                // so disable hits on the image only.
                .allowsHitTesting(false)
            Button { image = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, Color(uiColor: .systemGray3))
                    .font(.system(size: 18))
                    .offset(x: 6, y: -6)
            }
        }
        .padding(.leading, AppTheme.Space.paddingS)
    }

    // Runs in the sheet's onDismiss, i.e. only once the modal is gone, so the
    // thumbnail-row layout change can never race the dismissal animation.
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
