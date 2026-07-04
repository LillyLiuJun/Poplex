import SwiftUI
import AVFoundation

struct InputBar: View {
    @Binding var text: String
    @Binding var image: UIImage?
    var isLoading: Bool
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
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
        .sheet(isPresented: $showCamera) {
            CameraPickerView(onImage: { img in image = img }, onCancel: {})
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PHPickerView(image: $image)
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
            Button { showPhotoLibrary = true } label: {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Color.textAccent)
            }
            TextField("Describe your moment in Chinese or English...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(AppTheme.Space.paddingS)
                .background(AppTheme.Color.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isFocused)
            Button {
                isFocused = false
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle")
                    .font(.title)
                    .foregroundStyle(canSend ? AppTheme.Color.textAccent : AppTheme.Color.textSecondary)
            }
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
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                }
            }
        default:
            showCameraPermissionAlert = true
        }
    }
}
