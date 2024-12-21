import UIKit
import SwiftPizzaSnips

@MainActor
protocol NavigationCoordinator: NSObject, Coordinator, UINavigationControllerDelegate {
	var navigationController: UINavigationController { get }
	var previousViewControllers: [UIViewController] { get set }

	func navigationController(
		_ navigationController: UINavigationController,
		removedViewControllers viewControllers: [UIViewController])
}

extension NavigationCoordinator {
	func addChildCoordinator(_ childCoordinator: any Coordinator, andStart start: Bool = true) {
		childCoordinators.append(childCoordinator)

		guard start else { return }
		childCoordinator.start()
	}
}

extension NavigationCoordinator {
	func superNavigationController(
		_ navigationController: UINavigationController,
		removedViewControllers viewControllers: [UIViewController]
	) {
		for removedVC in viewControllers {
			guard
				let childCoord = childCoordinators.first(where: { $0.rootController === removedVC })
			else { continue }

			Task { await childCoord.finish() }
		}
	}

	func navigationController(
		_ navigationController: UINavigationController,
		removedViewControllers viewControllers: [UIViewController]
	) {
		superNavigationController(navigationController, removedViewControllers: viewControllers)
	}

	func superNavigationController(
		_ navigationController: UINavigationController,
		didShow viewController: UIViewController,
		animated: Bool
	) {
		defer { previousViewControllers = navigationController.viewControllers }

		guard navigationController.viewControllers.count < previousViewControllers.count else { return }

		let diff = navigationController.viewControllers.difference(from: previousViewControllers)
		if diff.removals.isOccupied {
			let removedVCs: [UIViewController] = diff.removals.compactMap {
				guard case .remove(offset: _, element: let vc, associatedWith: _) = $0 else { return nil }
				return vc
			}
			self.navigationController(navigationController, removedViewControllers: removedVCs)
		}
	}
}
