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
    // configureSession() can add zero inputs (permission race, device busy, no
    // camera hardware) and startRunning() is a no-op in that case — isReady
    // used to be set unconditionally true, so a black session got presented as
    // a normal viewfinder with no loading/failure state (F-3/C-3).
    var failedToStart = false

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
            let ok = !self.session.inputs.isEmpty && self.session.isRunning
            DispatchQueue.main.async {
                self.isReady = ok
                self.failedToStart = !ok
            }
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
            // `capturePhoto` throws NSInternalInconsistencyException with no active/enabled
            // video connection (e.g. the black-session state from C-3, or a mid-session
            // interruption like a phone call). Fail soft instead of crashing (F-3/C-2).
            guard let connection = self.photoOutput.connection(with: .video),
                  connection.isActive, connection.isEnabled else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.captureCompletion = completion

            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            // Keep the saved photo upright regardless of preview rotation.
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.isVideoMirrored = (self.position == .front) && connection.isVideoMirroringSupported
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
    // Guards against a stale capture (timeout already fired, or vice versa)
    // resolving after the shutter has already been unlocked for a retry.
    @State private var activeCaptureToken: UUID?
    @State private var captureIssue: String?

    var body: some View {
        ZStack {
            AppTheme.Color.cameraBg.ignoresSafeArea()

            if model.failedToStart {
                // configureSession() came up with zero inputs — no viewfinder to show,
                // no shutter that could do anything. Replace the whole camera chrome
                // with an explanation and two ways forward (F-3/C-3), not a black
                // screen with a shutter that would just crash on tap (C-2).
                CameraFailedToStartView(
                    onOpenSettings: { PermissionService.openSettings() },
                    onUseSample: onClose
                )
            } else {
                CameraPreview(session: model.session)
                    .ignoresSafeArea()
                    .opacity(model.isReady ? 1 : 0)

                VStack {
                    topControls
                    Spacer()
                    bottomControls
                }
                .padding(AppTheme.Space.paddingPage)
                .overlay(alignment: .bottom) {
                    AutoDismissingAppToast(
                        message: $captureIssue,
                        systemImage: "exclamationmark.triangle",
                        lifetime: AppTheme.Motion.toastLifetime
                    )
                    .padding(.bottom, toastBottomInset)
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // Clears the shutter row (72pt circle + paddingPage) so the toast doesn't sit on top of it.
    private let toastBottomInset: CGFloat = 120

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
        captureIssue = nil
        let token = UUID()
        activeCaptureToken = token

        model.capture { image in
            guard activeCaptureToken == token else { return }
            activeCaptureToken = nil
            isCapturing = false
            if let image {
                // The presenter stages the photo and applies it in the sheet's
                // onDismiss — it must NOT reshape its layout here, while the
                // sheet is still up (that desyncs presentation state on device).
                onImage(image)
                // Same single close path as the X button and PHPickerView: hand the
                // close back to the presenter's binding rather than self-dismissing.
                onClose()
            } else {
                // No active connection (interruption mid-session) — stay on the
                // camera and unlock the shutter instead of silently closing empty.
                captureIssue = "Couldn't take that photo. Try again."
            }
        }

        // `capturePhoto`'s delegate callback isn't guaranteed to fire (session
        // interrupted by a call, backgrounded mid-capture, …). Without this the
        // shutter locks forever with no visible reason (F-3/C-2).
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard activeCaptureToken == token else { return }
            activeCaptureToken = nil
            isCapturing = false
            captureIssue = "That took too long. Try again."
        }
    }
}

// MARK: - Failed-to-start state (F-3/C-3): session came up with no input.
// Sits on the same cameraBg the live preview would — cameraControl (white) is
// the only tone this file uses for anything on that background, so text and
// icon share it rather than reaching for an .opacity() midtone.

private struct CameraFailedToStartView: View {
    var onOpenSettings: () -> Void
    var onUseSample: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingSection) {
            Spacer()

            VStack(spacing: AppTheme.Space.paddingCard) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(AppTheme.Color.cameraControl)

                VStack(spacing: AppTheme.Space.paddingS) {
                    Text("Camera unavailable")
                        .font(AppTheme.Font.screenTitle)
                        .foregroundStyle(AppTheme.Color.cameraControl)

                    Text("Turn on camera access in Settings, or use one of the sample photos instead.")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.cameraControl)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingSection)

            Spacer()

            VStack(spacing: AppTheme.Space.paddingM) {
                Button(action: onOpenSettings) {
                    Text("Open Settings")
                        .font(AppTheme.Font.compactActionLabel)
                        .foregroundStyle(AppTheme.Color.cameraControl)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppTheme.Size.barControl)
                        .background(AppTheme.Color.cameraControlBg, in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: onUseSample) {
                    Text("Use a sample instead")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.cameraControl)
                        .frame(height: AppTheme.Size.barControl)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.bottom, AppTheme.Space.paddingSection)
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
