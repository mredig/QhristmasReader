import UIKit
import CoreData
import SwiftPizzaSnips
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	let navigationController = UINavigationController(rootViewController: UIViewController())

	private var alertActions: Set<WeakBox<UIAlertAction>> = []

	static var coreDataStack: CoreDataStack {
		(UIApplication.shared.delegate as! AppDelegate).coreDataStack
	}
	var coreDataStack: CoreDataStack { Self.coreDataStack }

	private(set) var rootCoordinator: RootCoordinator!

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: windowScene)
		self.window = window

		let rootCoordinator = RootCoordinator(coreDataStack: coreDataStack, window: window)
		self.rootCoordinator = rootCoordinator

		rootCoordinator.start()
	}

	func sceneDidDisconnect(_ scene: UIScene) {}
	func sceneDidBecomeActive(_ scene: UIScene) {}
	func sceneWillResignActive(_ scene: UIScene) {}
	func sceneWillEnterForeground(_ scene: UIScene) {}
	func sceneDidEnterBackground(_ scene: UIScene) {}
}
