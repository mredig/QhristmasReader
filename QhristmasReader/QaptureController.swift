import AVFoundation
import UIKit

class QaptureController: UIViewController {
	protocol Delegate: AnyObject {
		func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID)
	}

	private var previewLayer: AVCaptureVideoPreviewLayer?

	weak var delegate: Delegate?

	private var lastCapture: Date = .distantPast

	override func viewDidLoad() {
		super.viewDidLoad()

		let captureSession = AVCaptureSession()
		guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
		let videoInput: AVCaptureDeviceInput

		do {
			videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
		} catch {
			return
		}

		guard captureSession.canAddInput(videoInput) else { return }
		captureSession.addInput(videoInput)

		let metadataOutput = AVCaptureMetadataOutput()
		guard captureSession.canAddOutput(metadataOutput) else { return }
		metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
		captureSession.addOutput(metadataOutput)
		metadataOutput.metadataObjectTypes = [.qr]

		let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		previewLayer.frame = view.layer.bounds
		previewLayer.videoGravity = .resize
		view.layer.addSublayer(previewLayer)
		self.previewLayer = previewLayer

		Task.detached {
			captureSession.startRunning()
		}
	}
}

extension QaptureController: AVCaptureMetadataOutputObjectsDelegate {
	func metadataOutput(
		_ output: AVCaptureMetadataOutput,
		didOutput metadataObjects: [AVMetadataObject],
		from connection: AVCaptureConnection
	) {
		guard
			lastCapture.addingTimeInterval(2) < .now,
			let metadataObject = metadataObjects.first,
			let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
			let code = readableObject.stringValue,
			let id = UUID(uuidString: code)
		else { return }
		lastCapture = .now

		delegate?.qaptureController(self, didCaptureID: id)
	}
}
