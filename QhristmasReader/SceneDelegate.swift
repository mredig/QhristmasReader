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
}

extension SceneDelegate: ListViewController.Coordinator {
	func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL) {
		print(item)
	}

	func listViewControllerDidTapScannerButton(_ listViewController: ListViewController) {
		print("Show cam")
	}

	func listViewControllerDidTapSyncButton(_ listViewController: ListViewController) {
		print("Show sync")
	}
}
