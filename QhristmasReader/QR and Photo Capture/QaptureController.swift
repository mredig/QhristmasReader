@preconcurrency import AVFoundation
import UIKit
import VectorExtor

@MainActor
class QaptureController: UIViewController {
	@MainActor
	protocol Delegate: AnyObject {
		func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID)
	}

	private var previewLayer: AVCaptureVideoPreviewLayer?
	private var outlineLayer: CAShapeLayer?

	private let instructionsLabel = UILabel().with {
		$0.font = .preferredFont(forTextStyle: .title1)
	}

	private let cameraView = UIView()

	weak var delegate: Delegate?

	private var lastCapture: Date = .distantPast

	private let captureSession: AVCaptureSession

	var vibrateOnIDRecognition = true

	init() {
		let captureSession = AVCaptureSession()
		self.captureSession = captureSession
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Code Scanner"
		navigationItem.largeTitleDisplayMode = .never
		view.backgroundColor = .systemBackground

		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(instructionsLabel)
		instructionsLabel.isUserInteractionEnabled = false
		instructionsLabel.text = "Tap and hold anywhere to activate camera barcode scanner"
		instructionsLabel.numberOfLines = 0
		instructionsLabel.lineBreakMode = .byWordWrapping
		instructionsLabel.textColor = .secondaryLabel
		instructionsLabel.textAlignment = .center
		view.addSubview(cameraView)
		constraints += view.constrain(instructionsLabel, inset: NSDirectionalEdgeInsets(scalar: 24))
		constraints += view.constrain(cameraView)

		let scannerImage = UIImage.barcodeScanner
		let scannerImageView = UIImageView(image: scannerImage).with {
			$0.contentMode = .scaleAspectFit
		}
		cameraView.addSubview(scannerImageView)
		cameraView.isHidden = true
		constraints += cameraView.constrain(scannerImageView)

		guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
		let videoInput: AVCaptureDeviceInput

		do {
			videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
		} catch {
			return
		}

		captureSession.sessionPreset = .vga640x480
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
		cameraView.layer.addSublayer(previewLayer)
		self.previewLayer = previewLayer

		let outline = CAShapeLayer()
		outline.strokeColor = UIColor.systemBlue.cgColor
		outline.fillColor = UIColor.clear.cgColor
		outline.lineWidth = 3
		outline.frame = view.layer.bounds
		self.outlineLayer = outline
		cameraView.layer.addSublayer(outline)

		let tap = UILongPressGestureRecognizer(target: self, action: #selector(cameraToggleTap))
		tap.minimumPressDuration = 0
		view.addGestureRecognizer(tap)

		cameraView.bringSubviewToFront(scannerImageView)
	}

	@objc
	private func cameraToggleTap(_ sender: UIGestureRecognizer) {
		switch sender.state {
		case .began:
			cameraView.isHidden = false
			Task.detached { [captureSession] in
				captureSession.startRunning()
			}
		case .ended, .cancelled, .failed:
			cameraView.isHidden = true
			Task.detached { [captureSession] in
				captureSession.stopRunning()
			}
		default: break
		}
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()

		previewLayer?.frame = view.layer.bounds
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
	nonisolated func metadataOutput(
		_ output: AVCaptureMetadataOutput,
		didOutput metadataObjects: [AVMetadataObject],
		from connection: AVCaptureConnection
	) {
		guard
			let metadataObject = metadataObjects.first,
			let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
			let code = readableObject.stringValue,
			let id = UUID(uuidString: code)
		else { return }
		Task { @MainActor in
			guard
				lastCapture.addingTimeInterval(2) < .now
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

			if vibrateOnIDRecognition {
				AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
			}
			delegate?.qaptureController(self, didCaptureID: id)
		}
	}
}

extension CGPoint {
	func swapXAndY() -> CGPoint {
		CGPoint(x: y, y: x)
	}
}

extension AVCaptureSession: @retroactive @unchecked Sendable {}
