import AVFoundation
import UIKit
import VectorExtor

class QaptureController: UIViewController {
	protocol Delegate: AnyObject {
		func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID)
	}

	private var previewLayer: AVCaptureVideoPreviewLayer?
	private var outlineLayer: CAShapeLayer?

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
		metadataOutput.metadataObjectTypes = [.qr, .code128, .pdf417, .microPDF417, .microQR]

		let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		previewLayer.frame = view.layer.bounds
		previewLayer.videoGravity = .resizeAspect
		view.layer.addSublayer(previewLayer)
		self.previewLayer = previewLayer

		let outline = CAShapeLayer()
		outline.strokeColor = UIColor.systemBlue.cgColor
		outline.fillColor = UIColor.clear.cgColor
		outline.lineWidth = 3
		outline.frame = view.layer.bounds
		self.outlineLayer = outline
		view.layer.addSublayer(outline)

		Task.detached {
			captureSession.startRunning()
		}
	}

	override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		coordinator.animate { [self] context in
			print(context.percentComplete)
			previewLayer?.frame = view.layer.bounds
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

//		if case let points = readableObject.corners, points.isEmpty == false, let first = points.first {
//			let size = view.layer.bounds.size
//			let path = CGMutablePath()
//			path.move(to: first.swapXAndY() * size)
//
//			for point in points.dropFirst() {
//				path.addLine(to: point.swapXAndY() * size)
//			}
//			path.closeSubpath()
//
//			outlineLayer?.path = path
//		} else {
//			outlineLayer?.path = nil
//		}

		delegate?.qaptureController(self, didCaptureID: id)
	}
}

extension CGPoint {
	func swapXAndY() -> CGPoint {
		CGPoint(x: y, y: x)
	}
}
