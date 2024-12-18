import UIKit
import SwiftPizzaSnips
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	let navigationController = UINavigationController(rootViewController: UIViewController())

	let viewModel: ScannerViewModel
	private var alertActions: Set<WeakBox<UIAlertAction>> = []

	static var coreDataStack: CoreDataStack {
		(UIApplication.shared.delegate as! AppDelegate).coreDataStack
	}
	var coreDataStack: CoreDataStack { Self.coreDataStack }

	override init() {
		let cds = Self.coreDataStack
		do {
			let vm = try ScannerViewModel(coreDataStack: cds)
			self.viewModel = vm
		} catch {
			fatalError("Error loading scanner vm: \(error)")
		}

		super.init()
	}

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: windowScene)
		self.window = window

		viewModel.delegate = self
		let listVC = ListViewController(viewModel: viewModel, coordinator: self, coreDataStack: coreDataStack)
		navigationController.setViewControllers([listVC], animated: false)
		window.rootViewController = navigationController

		window.makeKeyAndVisible()
	}

	func sceneDidDisconnect(_ scene: UIScene) {}
	func sceneDidBecomeActive(_ scene: UIScene) {}
	func sceneWillResignActive(_ scene: UIScene) {}
	func sceneWillEnterForeground(_ scene: UIScene) {}
	func sceneDidEnterBackground(_ scene: UIScene) {}

	private func showGift(_ id: UUID) {
		do {
			let viewModel = try GiftDetailViewModel(canEdit: true, imageID: id, coreDataStack: coreDataStack)

			let vc = GiftDetailController(viewModel: viewModel)
			vc.view.clipsToBounds = true
			vc.navigationItem.largeTitleDisplayMode = .never
			navigationController.pushViewController(vc, animated: true)
		} catch {
			print("Error showing gift: \(error)")
		}
	}
}

extension SceneDelegate: ListViewController.Coordinator {
	func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL) {
		let uuidStr = item.deletingPathExtension().lastPathComponent
		guard let uuid = UUID(uuidString: uuidStr) else {
			print("Invalid uuid string: \(uuidStr)")
			return
		}

		showGift(uuid)
	}

	func listViewControllerDidTapScannerButton(_ listViewController: ListViewController) {
		let scannerView = QRCodeScannerView { [weak self] code in
			self?.viewModel.foundCode(code)
		}

		let vc = UIHostingController(rootView: scannerView)
		vc.navigationItem.title = "Code Scanner"
		vc.navigationItem.largeTitleDisplayMode = .never
		navigationController.pushViewController(vc, animated: true)
	}

	func listViewControllerDidTapSyncButton(_ listViewController: ListViewController) {

		let alert = UIAlertController(title: "Sync Mode", message: "Are you hosting or joining a session?", preferredStyle: .alert)
		let textFieldUpdate = UIAction() { [weak self] action in
			guard let textField = action.sender as? UITextField else { return }
			self?.updateAlertActions(textField: textField)
		}
		alert.addTextField {
			$0.placeholder = "Your Name"
			if let username = DefaultsManager.shared[.username] {
				$0.text = username
			}
			$0.addAction(textFieldUpdate, for: .allEditingEvents)
		}
		let hosting = UIAlertAction(
			title: "Hosting",
			style: .default) { [weak self, weak alert] action in
				guard
					let name = alert?.textFields?.first?.text?.emptyIsNil
				else { return }
				DefaultsManager.shared[.username] = name
				self?.showSyncScreen(asHost: true, username: name)
			}
		let joining = UIAlertAction(
			title: "Joining",
			style: .default) { [weak self, weak alert] action in
				guard
					let name = alert?.textFields?.first?.text?.emptyIsNil
				else { return }
				DefaultsManager.shared[.username] = name
				self?.showSyncScreen(asHost: false, username: name)
			}
		alertActions = [
			.init(content: hosting),
			.init(content: joining)
		]

		let cancel = UIAlertAction(title: "Cancel", style: .cancel)

		[
			hosting,
			joining,
			cancel
		]
			.forEach { alert.addAction($0) }

		navigationController.present(alert, animated: true)
	}

	private func updateAlertActions(textField: UITextField) {
		let enable = textField.text?.isOccupied ?? false
		for alertAction in self.alertActions {
			alertAction.content?.isEnabled = enable
		}
	}

	private func showSyncScreen(asHost: Bool, username: String) {
		Task {
			let syncVC = await SyncController(asHost: asHost, username: username, coreDataStack: coreDataStack)

			navigationController.pushViewController(syncVC, animated: true)
		}
	}
}

extension SceneDelegate: ScannerViewModel.Delegate {
	func scannerViewModel(_ scannerViewModel: ScannerViewModel, didNotFindCodeMatch code: UUID) {
		let picker = UIImagePickerController()
		picker.sourceType = .camera
		picker.cameraCaptureMode = .photo
		picker.cameraDevice = .rear
		picker.delegate = self
		picker.isModalInPresentation = true
		picker.modalPresentationStyle = .fullScreen
		navigationController.present(picker, animated: true)
	}

	func scannerViewModel(
		_ scannerViewModel: ScannerViewModel,
		didFindCodeMatch code: UUID,
		withImage image: UIImage
	) {
		showGift(code)
	}
}

extension SceneDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true)
	}

	func imagePickerController(
		_ picker: UIImagePickerController,
		didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
	) {
		defer { picker.dismiss(animated: true) }
		guard
			let image = info[.originalImage] as? UIImage
		else {
			return
		}
		Task {
			let context = coreDataStack.newBackgroundContext()
			guard let id = viewModel.capturingImageID else { return }
			async let dbSave: Void = context.perform {
				_ = Gift(imageID: id, context: context)

				try context.save()
			}

			let scaledImage = await image.imageByScaling(toSize: CGSize(scalar: 640))
			async let imageSave: Void = viewModel.storeImage(scaledImage, for: id)

			try await dbSave
			await imageSave
		}
	}
}
