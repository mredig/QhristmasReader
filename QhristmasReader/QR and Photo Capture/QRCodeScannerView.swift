import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
	var didFindCode: (UUID) -> Void

	class Coordinator: NSObject, QaptureController.Delegate {
		var parent: QRCodeScannerView

		init(parent: QRCodeScannerView) {
			self.parent = parent
		}

		func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID) {
			AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
			parent.didFindCode(uuid)
		}
	}

	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}

	func makeUIViewController(context: Context) -> UIViewController {
		let controller = QaptureController()
		controller.delegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
