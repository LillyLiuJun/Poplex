import AVFoundation
import Speech
import UIKit

/// Centralises microphone + speech-recognition permission checks and requests.
///
/// Both permissions are required before the conversation page can record or
/// transcribe audio. They are requested together in sequence (mic first, then
/// speech) because iOS shows the mic dialog again if speech recognition is
/// denied while mic was already granted from a prior session.
enum PermissionService {

    // MARK: - Status

    enum Status { case granted, denied, undetermined }

    static var micStatus: Status {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:       return .granted
        case .denied:        return .denied
        case .undetermined:  return .undetermined
        @unknown default:    return .denied
        }
    }

    static var speechStatus: Status {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:                     return .granted
        case .denied, .restricted:            return .denied
        case .notDetermined:                  return .undetermined
        @unknown default:                     return .denied
        }
    }

    static var areBothGranted: Bool {
        micStatus == .granted && speechStatus == .granted
    }

    // MARK: - Requests

    /// Request mic permission. Must be called from a non-main context (iOS may
    /// present a system dialog; it blocks until the user responds).
    static func requestMic() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission {
                continuation.resume(returning: $0)
            }
        }
    }

    static func requestSpeech() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Request whichever of the two permissions are still undetermined.
    /// Returns true only if both end up granted.
    static func requestNeeded() async -> Bool {
        if micStatus == .undetermined {
            guard await requestMic() else { return false }
        }
        if speechStatus == .undetermined {
            guard await requestSpeech() else { return false }
        }
        return areBothGranted
    }

    // MARK: - Settings deep-link

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
