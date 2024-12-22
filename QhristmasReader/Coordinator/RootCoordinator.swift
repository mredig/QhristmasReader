import UIKit
import SwiftPizzaSnips

class RootCoordinator: NSObject, NavigationCoordinator {
	let navigationController = UINavigationController()
	var previousViewControllers: [UIViewController] = []
	var rootController: UIViewController { navigationController }

	let parentNavigationCoordinator: (any NavigationCoordinatorChain)? = nil
	var childCoordinators: [any Coordinator] = []

	let coreDataStack: CoreDataStack
	let window: UIWindow

	init(coreDataStack: CoreDataStack, window: UIWindow) {
		self.coreDataStack = coreDataStack
		self.window = window
	}

	func start() {
		window.rootViewController = navigationController
		window.makeKeyAndVisible()

		let onboardCoordinator = OnboardCoordinator(parentCoordinator: self, delegate: self)
		addChildCoordinator(onboardCoordinator)
	}

	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
}

extension RootCoordinator: OnboardCoordinator.Delegate {
	func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowGiverUI animated: Bool) {
		let giverCoordinator = GiverCoordinator(parentNavigationCoordinator: self, coreDataStack: coreDataStack)
		addChildCoordinator(giverCoordinator)
	}

	func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowRecipientUI animated: Bool) {

	}
}
