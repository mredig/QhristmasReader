import SwiftUI
import UIKit

struct PhotoCaptureView: UIViewControllerRepresentable {
	var onFinish: (UIImage?) -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let picker = UIImagePickerController()
		picker.delegate = context.coordinator
		picker.sourceType = .camera
		return picker
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

	class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		let parent: PhotoCaptureView

		init(_ parent: PhotoCaptureView) {
			self.parent = parent
		}

		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
			guard let image = info[.originalImage] as? UIImage else {
				return parent.onFinish(nil)
			}
			parent.onFinish(image)
		}

		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			parent.onFinish(nil)
		}
	}
}
