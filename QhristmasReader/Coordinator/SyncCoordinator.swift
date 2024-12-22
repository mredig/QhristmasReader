import UIKit
import SwiftPizzaSnips

class SyncCoordinator: NavigationChildCoordinator {
	var parentNavigationCoordinator: (any NavigationCoordinatorChain)?
	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController {
		syncController
	}
	let syncController: SyncController

	let coreDataStack: CoreDataStack

	init(
		parentNavigationCoordinator: (any NavigationCoordinatorChain),
		asHost: Bool,
		username: String,
		coreDataStack: CoreDataStack
	) async {
		self.parentNavigationCoordinator = parentNavigationCoordinator
		self.coreDataStack = coreDataStack

		let syncVC = await SyncController(asHost: asHost, username: username, coreDataStack: coreDataStack)
		self.syncController = syncVC
	}

	func start() {
		chainNavigationController?.pushViewController(rootController, animated: true)
	}
	
	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
}
