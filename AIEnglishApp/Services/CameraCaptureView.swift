import SwiftUI
import AVFoundation
import UIKit

// MARK: - Capture model (owns the AVCaptureSession)
//
// Full-screen custom camera built on AVFoundation so we can:
//  · fill a tall screen with no 4:3 letterboxing (resizeAspectFill)
//  · own the controls (shutter / flip / flash) and give instant feedback
//  · pre-warm the session so opening feels fast
//
// UIImagePickerController cannot do the above, which is why we replace it here.

@Observable
final class CameraCaptureModel: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    // UI-facing state (mutated on main)
    var flashMode: AVCaptureDevice.FlashMode = .off
    var position: AVCaptureDevice.Position = .back
    var isReady = false

    private let sessionQueue = DispatchQueue(label: "app.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var captureCompletion: ((UIImage?) -> Void)?

    // MARK: Lifecycle

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.isReady = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = camera(for: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    // MARK: Controls

    func cycleFlash() {
        switch flashMode {
        case .off:  flashMode = .on
        case .on:   flashMode = .auto
        default:    flashMode = .off
        }
    }

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = (position == .back) ? .front : .back
        position = newPosition
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let current = self.videoInput {
                self.session.removeInput(current)
            }
            if let device = self.camera(for: newPosition),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoInput = input
            }
            self.session.commitConfiguration()
        }
    }

    // MARK: Capture

    func capture(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureCompletion = completion

            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            if let connection = self.photoOutput.connection(with: .video) {
                // Keep the saved photo upright regardless of preview rotation.
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                connection.isVideoMirrored = (self.position == .front) && connection.isVideoMirroringSupported
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        DispatchQueue.main.async { [weak self] in
            self?.captureCompletion?(image)
            self?.captureCompletion = nil
        }
    }
}

// MARK: - Preview layer bridge

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Full-screen camera surface

struct CameraCaptureView: View {
    var onImage: (UIImage) -> Void
    // Closing is delegated to the presenter (which sets its `activeSheet = nil`)
    // instead of `@Environment(\.dismiss)`. Self-dismissing while the capture
    // path also mutates the presenter's state desyncs `.sheet(item:)` and leaves
    // the entry points dead after the first real photo. This mirrors PHPickerView.
    var onClose: () -> Void

    @State private var model = CameraCaptureModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            AppTheme.Color.cameraBg.ignoresSafeArea()

            CameraPreview(session: model.session)
                .ignoresSafeArea()
                .opacity(model.isReady ? 1 : 0)

            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .padding(AppTheme.Space.paddingPage)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: Controls

    private var topControls: some View {
        HStack {
            CameraControlButton(icon: "xmark") { onClose() }
            Spacer()
            CameraControlButton(icon: flashIcon) { model.cycleFlash() }
        }
    }

    private var bottomControls: some View {
        HStack {
            Spacer()
            ShutterButton(isCapturing: isCapturing) { takePhoto() }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            CameraControlButton(icon: "arrow.triangle.2.circlepath.camera") {
                model.flipCamera()
            }
        }
    }

    private var flashIcon: String {
        switch model.flashMode {
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        default:    return "bolt.slash.fill"
        }
    }

    // MARK: Actions

    private func takePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        model.capture { image in
            isCapturing = false
            if let image {
                // The presenter stages the photo and applies it in the sheet's
                // onDismiss — it must NOT reshape its layout here, while the
                // sheet is still up (that desyncs presentation state on device).
                onImage(image)
            }
            // Same single close path as the X button and PHPickerView: hand the
            // close back to the presenter's binding rather than self-dismissing.
            onClose()
        }
    }
}

// MARK: - Reusable camera control button (icon on translucent scrim)

private struct CameraControlButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.Color.cameraControl)
                .frame(width: 44, height: 44)
                .background(AppTheme.Color.cameraControlBg, in: Circle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Shutter

private struct ShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Color.cameraControl, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(AppTheme.Color.cameraControl)
                    .frame(width: 58, height: 58)
                    .scaleEffect(isCapturing ? 0.85 : 1.0)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeInOut(duration: 0.12), value: isCapturing)
    }
}
