import Foundation
import UIKit

@MainActor
protocol Coordinator: AnyObject {
	var parentCoordinator: (any Coordinator)? { get }
	var childCoordinators: [any Coordinator] { get set }

	var rootController: UIViewController { get }

	func start()
	/// remember to call `superFinish(_:)` with custom implementations
	func finish() async

	func coordinatorDidFinish(_ coordinator: any Coordinator)

	/// remember to call `superChildDidFinish(_:)` with custom implementations
	func childDidFinish(_ child: any Coordinator) async
}

extension Coordinator {
	/// Cannot call `super` on protocol extensions, so this pattern allows providing a default
	/// implementation as well as a supplemental call when providing a custom implementation
	func superChildDidFinish(_ child: any Coordinator) async {
		guard
			let index = childCoordinators.firstIndex(where: { $0 === child })
		else { return }
		childCoordinators.remove(at: index)
	}

	func childDidFinish(_ child: any Coordinator) async {
		await superChildDidFinish(child)
	}

	func superFinish() async {
		coordinatorDidFinish(self)
		await parentCoordinator?.childDidFinish(self)
	}

	func finish() async {
		await superFinish()
	}

	func addChildCoordinator(_ childCoordinator: any Coordinator, andStart start: Bool = true) {
		childCoordinators.append(childCoordinator)

		if start {
			childCoordinator.start()
		}
	}
}

protocol NavigationChildCoordinator: Coordinator {
	var parentNavigationCoordinator: (any NavigationCoordinator)? { get }
}

extension NavigationChildCoordinator {
	var parentCoordinator: (any Coordinator)? { parentNavigationCoordinator }

	var navigationController: UINavigationController? { parentNavigationCoordinator?.navigationController }
}
