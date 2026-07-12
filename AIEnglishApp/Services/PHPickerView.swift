import SwiftUI
import PhotosUI

// Which capture modal is currently presented. A single `.sheet(item:)` driven
// by this enum guarantees only one modal is ever live, so SwiftUI's
// presentation state can never desync (which happens with multiple sheets).
enum CaptureSource: Identifiable {
    case camera
    case photoLibrary
    var id: Int { hashValue }
}

struct PHPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    // Called after the user picks or cancels, so the presenter closes the sheet
    // via its own binding instead of the picker dismissing itself (self-dismiss
    // leaves the SwiftUI binding stuck and breaks later modals).
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        init(_ parent: PHPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onFinish()   // cancelled or unsupported item
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    self?.parent.image = object as? UIImage
                    self?.parent.onFinish()
                }
            }
        }
    }
}
