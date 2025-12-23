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
	private let scannerImageView: UIView
	private let radarPulseLayer = CAGradientLayer()

	weak var delegate: Delegate?

	private var lastCapture: Date = .distantPast

	private var captureSession: AVCaptureSession?

	var vibrateOnIDRecognition = true

	init() {
		let scannerImage = UIImage.barcodeScanner
		let scannerImageView = UIImageView(image: scannerImage).with {
			$0.contentMode = .scaleAspectFit
		}
		self.scannerImageView = scannerImageView

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

		// Setup radar pulse animation
		setupRadarPulse()

		cameraView.addSubview(scannerImageView)
		cameraView.isHidden = true
		constraints += cameraView.constrain(scannerImageView)

		setupQameraSession()

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

		// Add session runtime error observation
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleSessionRuntimeError),
			name: .AVCaptureSessionRuntimeError,
			object: captureSession
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleSessionWasInterrupted),
			name: .AVCaptureSessionWasInterrupted,
			object: captureSession
		)
	}

	private func setupRadarPulse() {
		let color = UIColor.systemGreen

		// Setup gradient layer for radar pulse
		radarPulseLayer.type = .radial
		radarPulseLayer.colors = [
			color.withAlphaComponent(0).cgColor,
			color.withAlphaComponent(0.6).cgColor,
			color.withAlphaComponent(0.3).cgColor,
			color.withAlphaComponent(0).cgColor
		]
		radarPulseLayer.locations = [0.45, 0.97, 0.99, 1.0]
		view.layer.insertSublayer(radarPulseLayer, at: 0)
		
		// Start the animation
		startRadarPulseAnimation()
	}
	
	private func startRadarPulseAnimation() {
		let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
		let maxDimension = max(view.bounds.width, view.bounds.height)
		
		// Position gradient at center, starting small
		radarPulseLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
		radarPulseLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
		
		// Set initial bounds to a small size at center
		let initialSize: CGFloat = 0
		radarPulseLayer.bounds = CGRect(x: 0, y: 0, width: initialSize, height: initialSize)
		radarPulseLayer.position = center
		
		// Bounds animation (expand from center)
		let boundsAnimation = CABasicAnimation(keyPath: "bounds")
		boundsAnimation.fromValue = CGRect(x: 0, y: 0, width: 0, height: 0)
		boundsAnimation.toValue = CGRect(x: 0, y: 0, width: maxDimension * 2, height: maxDimension * 2)
		
		// Opacity animation (fade out)
		let opacityAnimation = CABasicAnimation(keyPath: "opacity")
		opacityAnimation.fromValue = 0.8
		opacityAnimation.toValue = 0.0
		
		// Group animations
		let animationGroup = CAAnimationGroup()
		animationGroup.animations = [boundsAnimation, opacityAnimation]
		animationGroup.duration = 1.8
		animationGroup.repeatCount = .infinity
		animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
		
		radarPulseLayer.add(animationGroup, forKey: "radarPulse")
	}
	
	private func stopRadarPulseAnimation() {
		radarPulseLayer.removeAnimation(forKey: "radarPulse")
	}

	private func setupQameraSession() {
		guard captureSession == nil else { return }

		guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
		let videoInput: AVCaptureDeviceInput

		do {
			videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
		} catch {
			return
		}

		let captureSession = AVCaptureSession()
		self.captureSession = captureSession

		captureSession.sessionPreset = .hd1280x720
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

		cameraView.bringSubviewToFront(scannerImageView)
	}

	private func cleanupQameraSession() {
		if let previewLayer {
			previewLayer.removeFromSuperlayer()
			self.previewLayer = nil
		}

		captureSession?.stopRunning()
		captureSession = nil
	}

	@objc
	private func cameraToggleTap(_ sender: UIGestureRecognizer) {
		switch sender.state {
		case .began:
			cameraView.isHidden = false
			stopRadarPulseAnimation()
			Task.detached { [captureSession] in
				captureSession?.startRunning()
			}
		case .ended, .cancelled, .failed:
			cameraView.isHidden = true
			startRadarPulseAnimation()
			Task.detached { [captureSession] in
				captureSession?.stopRunning()
			}
		default: break
		}
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()

		previewLayer?.frame = view.layer.bounds
		
		// Update radar pulse center on layout changes
		if radarPulseLayer.animation(forKey: "radarPulse") != nil {
			stopRadarPulseAnimation()
			startRadarPulseAnimation()
		}
	}

	override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		coordinator.animate { [self] context in
			print(context.percentComplete)
			previewLayer?.frame = view.layer.bounds
		}
	}

	@objc
	private func handleSessionRuntimeError(_ notification: Notification) {
		guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
			return
		}

		print("Capture session runtime error: \(error)")
		showErrorAlert(message: "error: \(error)", showRetry: true)
	}

	@objc
	private func handleSessionWasInterrupted(_ notification: Notification) {
		print("Capture session was interrupted")
		showErrorAlert(message: "interrupted", showRetry: false)
	}

	private func showErrorAlert(message: String, showRetry: Bool) {
		let alertVC = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alertVC.addAction(UIAlertAction(title: "Ok", style: .default))

		if showRetry {
			alertVC.addAction(UIAlertAction(title: "Retry", style: .destructive, handler: { [weak self] _ in
				self?.cleanupQameraSession()

				self?.setupQameraSession()
			}))
		}

		present(alertVC, animated: true)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
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
