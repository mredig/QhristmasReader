import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
	class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
		var parent: QRCodeScannerView

		init(parent: QRCodeScannerView) {
			self.parent = parent
		}

		func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
			if let metadataObject = metadataObjects.first {
				guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
				guard let stringValue = readableObject.stringValue else { return }
				AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
				parent.didFindCode(stringValue)
			}
		}
	}

	var didFindCode: (String) -> Void

	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}

	func makeUIViewController(context: Context) -> UIViewController {
		let viewController = UIViewController()

		let captureSession = AVCaptureSession()
		guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
		let videoInput: AVCaptureDeviceInput

		do {
			videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
		} catch {
			return viewController
		}

		if (captureSession.canAddInput(videoInput)) {
			captureSession.addInput(videoInput)
		} else {
			return viewController
		}

		let metadataOutput = AVCaptureMetadataOutput()

		if (captureSession.canAddOutput(metadataOutput)) {
			captureSession.addOutput(metadataOutput)
			metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
			metadataOutput.metadataObjectTypes = [.qr]
		} else {
			return viewController
		}

		let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		previewLayer.frame = viewController.view.layer.bounds
		previewLayer.videoGravity = .resizeAspectFill
		viewController.view.layer.addSublayer(previewLayer)

		Task.detached {
			captureSession.startRunning()
		}

		return viewController
	}

	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
	@State private var scannedCode: String?

	var body: some View {
		NavigationView {
			VStack {
				QRCodeScannerView { code in
					self.scannedCode = code
				}
				.edgesIgnoringSafeArea(.all)

				if let scannedCode = scannedCode {
					Text("Scanned Code: \(scannedCode)")
						.padding()
				}
			}
			.navigationBarTitle("QR Code Scanner")
		}
	}
}
#Preview {
    ContentView()
}
