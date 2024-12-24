import UIKit
import SwiftUI
import SwiftPizzaSnips

@MainActor
class RecipientCoordinator: NavigationChildCoordinator {
	let parentNavigationCoordinator: (any NavigationCoordinatorChain)?
	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController {
		recipientBase
	}
	private var recipientBase: UIHostingController<RecipientBaseView>!

	let client: LocalNetworkEngineClient
	let selectedRecipients: Set<Recipient.DTO>

	init(
		parentNavigationCoordinator: (any NavigationCoordinatorChain),
		client: LocalNetworkEngineClient,
		selectedRecipients: Set<Recipient.DTO>
	) {
		self.parentNavigationCoordinator = parentNavigationCoordinator
		self.client = client
		self.selectedRecipients = selectedRecipients

		let baseView = RecipientBaseView(
			selectedRecipients: selectedRecipients.sorted(by: { $0.name < $1.name}),
			coordinator: self)
		let vc = UIHostingController(rootView: baseView)
		self.recipientBase = vc
	}

	func start() {
		chainNavigationController?.pushViewController(rootController, animated: true)
	}
	
	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
}

extension RecipientCoordinator: RecipientBaseView.Coordinator {
	func recipientBaseViewDidTapScan(_ recipientBaseView: RecipientBaseView) {
		let qaptureController = QaptureController()

		qaptureController.delegate = self

		chainNavigationController?.pushViewController(qaptureController, animated: true)
	}
}

extension RecipientCoordinator: QaptureController.Delegate {
	func qaptureController(_ qaptureController: QaptureController, didCaptureID uuid: UUID) {
		print(uuid)
	}
}
