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

	let client: HTTPClient
	let selectedRecipients: Set<Recipient.ListDTO>

	init(
		parentNavigationCoordinator: (any NavigationCoordinatorChain),
		client: HTTPClient,
		selectedRecipients: Set<Recipient.ListDTO>
	) {
		self.parentNavigationCoordinator = parentNavigationCoordinator
		self.client = client
		self.selectedRecipients = selectedRecipients

		let baseView = RecipientBaseView(
			selectedRecipients: selectedRecipients.sorted(by: { $0.name < $1.name}),
			coordinator: self)
		let vc = UIHostingController(rootView: baseView)
		vc.view.clipsToBounds = true
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
		Task {
			do {
				let recipientsSet = Set(selectedRecipients.map(\.id))
				let result = try await client.queryGift(id: uuid, for: recipientsSet)

				let resultView = {
					if result.matchingCrossover.isOccupied {
						let allRecipients = (result.allRecipients ?? selectedRecipients).sorted(by: { $0.name < $1.name })
						return RecipientQueryResultView(message: result.message, result: .yours(allRecipients), myDTOs: selectedRecipients)
					} else {
						let all = result.allRecipients.map { recipients in recipients.sorted(by: { $0.name < $1.name })}
						return RecipientQueryResultView(message: result.message, result: .others(all), myDTOs: selectedRecipients)
					}
				}()

				let vc = UIHostingController(rootView: resultView)
				vc.navigationItem.largeTitleDisplayMode = .inline

				chainNavigationController?.pushViewController(vc, animated: true)
			} catch {
				print("Error querying gift: \(error)")
			}
		}
	}
}
