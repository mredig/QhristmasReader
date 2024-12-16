import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	let navigationController = UINavigationController(rootViewController: UIViewController())

	let viewModel = ScannerViewModel()

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: windowScene)
		self.window = window

		viewModel.delegate = self
		let listVC = ListViewController(viewModel: viewModel, coordinator: self)
		navigationController.setViewControllers([listVC], animated: false)
		window.rootViewController = navigationController

		window.makeKeyAndVisible()
	}

	func sceneDidDisconnect(_ scene: UIScene) {}

	func sceneDidBecomeActive(_ scene: UIScene) {}

	func sceneWillResignActive(_ scene: UIScene) {}

	func sceneWillEnterForeground(_ scene: UIScene) {}

	func sceneDidEnterBackground(_ scene: UIScene) {}

	private func showImage(_ image: UIImage) {
		let imageView = ZStack(alignment: .bottom) {
			Image(uiImage: image)
				.resizable(resizingMode: .stretch)
				.aspectRatio(contentMode: .fill)

			Button(
				action: {
					self.navigationController.popViewController(animated: true)
				},
				label: {
					Text("Done")
				})
		}

		let vc = UIHostingController(rootView: imageView)
		vc.navigationItem.largeTitleDisplayMode = .never
		navigationController.pushViewController(vc, animated: true)
	}
}

extension SceneDelegate: ListViewController.Coordinator {
	func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL) {
		do {
			let data = try Data(contentsOf: item)
			guard let image = UIImage(data: data) else { return }
			showImage(image)
		} catch {
			print("Error loading image: \(error)")
		}
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
		print("Show sync")
	}
}

extension SceneDelegate: ScannerViewModel.Delegate {
	func scannerViewModel(_ scannerViewModel: ScannerViewModel, didNotFindCodeMatch code: UUID) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = .camera
		picker.isModalInPresentation = true
		picker.modalPresentationStyle = .fullScreen
		navigationController.present(picker, animated: true)
	}

	func scannerViewModel(
		_ scannerViewModel: ScannerViewModel,
		didFindCodeMatch code: UUID,
		withImage image: UIImage
	) {
		showImage(image)
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
