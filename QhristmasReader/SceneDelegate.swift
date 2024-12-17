import UIKit
import SwiftPizzaSnips
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	let navigationController = UINavigationController(rootViewController: UIViewController())

	let viewModel = ScannerViewModel()

	var coreDataStack: CoreDataStack {
		(UIApplication.shared.delegate as! AppDelegate).coreDataStack
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

		let alert = UIAlertController(title: "Sync Mode", message: "Are you hosting or joining a session?", preferredStyle: .actionSheet)
		let hosting = UIAlertAction(
			title: "Hosting",
			style: .default) { [weak self] _ in
				self?.showSyncScreen(asHost: true)
			}
		let joining = UIAlertAction(
			title: "Joining",
			style: .default) { [weak self] _ in
				self?.showSyncScreen(asHost: false)
			}

		let cancel = UIAlertAction(title: "Cancel", style: .cancel)

		[
			hosting,
			joining,
			cancel
		]
			.forEach(alert.addAction)

		navigationController.present(alert, animated: true)
	}

	private func showSyncScreen(asHost: Bool) {
		let syncVC = SyncController(asHost: asHost)

		navigationController.pushViewController(syncVC, animated: true)
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
		viewModel.storeImage(image, for: nil)
	}
}
