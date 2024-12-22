import SwiftUI
import UIKit
import SwiftPizzaSnips

@MainActor
class GiverRootCoordinator: Coordinator {
	@MainActor
	protocol Delegate: AnyObject {
		func giverRootCoordinatorDidActivateAppModeReset(_ giverRootCoordinator: GiverRootCoordinator)
	}

	let parentCoordinator: (any Coordinator)?

	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController { tabBarController }

	let tabBarController = UITabBarController()

	let coreDataStack: CoreDataStack
	unowned let delegate: Delegate

	init(
		parentCoordinator: (any Coordinator)?,
		delegate: Delegate,
		coreDataStack: CoreDataStack
	) {
		self.parentCoordinator = parentCoordinator
		self.delegate = delegate
		self.coreDataStack = coreDataStack
	}

	func start() {
		let giverList = GiverListCoordinator(
			parentCoordinator: self,
			coreDataStack: coreDataStack)

		addChildCoordinator(giverList)

		let placeholder = Button(
			action: { [weak self] in
				guard let self else { return }
				delegate.giverRootCoordinatorDidActivateAppModeReset(self)
			},
			label: {
				Text("reset")
			})
		let vc = UIHostingController(rootView: placeholder)
		vc.tabBarItem.title = "lorem"
		vc.tabBarItem.image = UIImage(systemName: "circle")

		tabBarController.viewControllers = [
			giverList.navigationController,
			vc
		]
	}
	
	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
}
