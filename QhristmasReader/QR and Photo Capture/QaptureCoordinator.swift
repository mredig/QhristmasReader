import SwiftPizzaSnips
import UIKit

class QaptureCoordinator: NavigationChildCoordinator {
	let parentNavigationCoordinator: (any NavigationCoordinatorChain)?
	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController {
		qaptureController
	}
	private let qaptureController = QaptureController()

	let viewModel: ScannerViewModel

	init(
		parentNavigationCoordinator: (any NavigationCoordinatorChain),
		viewModel: ScannerViewModel
	) {
		self.parentNavigationCoordinator = parentNavigationCoordinator
		self.viewModel = viewModel

		qaptureController.delegate = self
	}

	func start() {
		chainNavigationController?.pushViewController(rootController, animated: true)
	}

	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
}

extension QaptureCoordinator: QaptureController.Delegate {
	func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID) {
		viewModel.foundCode(uuid)
	}
}
