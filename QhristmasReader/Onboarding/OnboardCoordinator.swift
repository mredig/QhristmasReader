import UIKit
import SwiftPizzaSnips
import SwiftUI

@MainActor
class OnboardCoordinator: NavigationChildCoordinator {
	@MainActor
	protocol Delegate: AnyObject {
		func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowGiverUI animated: Bool)
		func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowRecipientUI animated: Bool)
	}
	var parentNavigationCoordinator: (any NavigationCoordinatorChain)?
	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController {
		hostingController
	}
	private var hostingController: UIHostingController<OnboardAppMode>!

	unowned let delegate: Delegate

	private var clientEngine: LocalNetworkEngineClient?

	init(
		parentCoordinator: (any NavigationCoordinator)? = nil,
		delegate: Delegate
	) {
		self.parentNavigationCoordinator = parentCoordinator
		self.delegate = delegate
		let onboardView = OnboardAppMode(coordinator: self)
		self.hostingController = UIHostingController(rootView: onboardView)
		hostingController.view.clipsToBounds = true
	}

	func start() {
		chainNavigationController?.pushViewController(rootController, animated: true)

		guard let userMode = DefaultsManager.shared[.userMode] else { return }
		switch userMode {
		case .get:
			delegate.onboardCoordinator(self, shouldShowRecipientUI: false)
		case .give:
			delegate.onboardCoordinator(self, shouldShowGiverUI: false)
		}
	}

	func coordinatorDidFinish(_ coordinator: any Coordinator) {}

	private func startHTTPClient(from syncClient: LocalNetworkEngineClient) async {
		defer { syncClient.disconnect() }

		do {
			let urlAddress = try await syncClient.sendHostAddressRequest()

			let client = HTTPClient(baseURL: urlAddress)

			let viewModel = OnboardRecipientSelectorView.ViewModel(client: client)

			let next = OnboardRecipientSelectorView(coordinator: self, viewModel: viewModel)
			let vc = UIHostingController(rootView: next)
			vc.view.clipsToBounds = true

			chainNavigationController?.pushViewController(vc, animated: true)
		} catch {
			print("Error retrieving ip: \(error)")

			let alertVC = UIAlertController(title: "Error", message: "Can't communicate with server. Please try again.", preferredStyle: .alert)

			alertVC.addAction(.init(title: "Ok", style: .default))

			chainNavigationController?.present(alertVC, animated: true)
		}
	}
}

extension OnboardCoordinator: OnboardAppMode.Coordinator, LocalNetworkEngineClient.Delegate {
	func onboardViewDidTapGivingButton(_ onboardView: OnboardAppMode) {
		DefaultsManager.shared[.userMode] = .give

		let next = OnboardGetGiverName(coordinator: self)
		let vc = UIHostingController(rootView: next)
		vc.view.clipsToBounds = true

		chainNavigationController?.pushViewController(vc, animated: true)
	}

	func onboardViewDidTapOpeningButton(_ onboardView: OnboardAppMode) {
		DefaultsManager.shared[.userMode] = .get

		let engine = LocalNetworkEngineClient(username: "user_" + String.random(characterCount: 6))
		clientEngine = engine
		engine.clientDelegate = self

		guard let nav = chainNavigationController else { return }
		engine.showBrowser(on: nav)
	}

	nonisolated
	func localNetworkEngineClient(_ localNetworkEngineClient: LocalNetworkEngineClient, finishedWithEvent: LocalNetworkEngineClient.Event) {
		switch finishedWithEvent {
		case .userTapDone, .connectionMade:
			Task { @MainActor in
				localNetworkEngineClient.dismissBrowser()
				await startHTTPClient(from: localNetworkEngineClient)
			}
			break
		case .userTapCancel:
			return
		}
	}
}

extension OnboardCoordinator: OnboardGetGiverName.Coordinator {
	func onboardViewDidTapNextButton(_ onboardView: OnboardGetGiverName) {
		delegate.onboardCoordinator(self, shouldShowGiverUI: true)
	}
}

extension OnboardCoordinator: OnboardRecipientSelectorView.Coordinator {
	func onboardView(_ onboardView: OnboardRecipientSelectorView, didSelectRecipientsFromList recipients: Set<Recipient.ListDTO>) {
		let coordinator = RecipientCoordinator(
			parentNavigationCoordinator: self,
			client: onboardView.viewModel.client,
			selectedRecipients: recipients)

		addChildCoordinator(coordinator)
	}
}
