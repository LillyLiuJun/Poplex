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
        .sheet(item: $activeSheet) { source in
            switch source {
            case .camera:
                CameraCaptureView(onImage: { img in image = img })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            case .photoLibrary:
                PHPickerView(image: $image, onFinish: { activeSheet = nil })
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
            Button { image = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, Color(uiColor: .systemGray3))
                    .font(.system(size: 18))
                    .offset(x: 6, y: -6)
            }
        }
        .padding(.leading, AppTheme.Space.paddingS)
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
