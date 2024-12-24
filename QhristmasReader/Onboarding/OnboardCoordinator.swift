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
			delegate.onboardCoordinator(self, shouldShowGiverUI: false)
		case .give:
			delegate.onboardCoordinator(self, shouldShowRecipientUI: false)
		}
	}

	func coordinatorDidFinish(_ coordinator: any Coordinator) {}
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
		engine.browserVC.title = "Select Event Host"
		engine.browserVC.navigationItem.largeTitleDisplayMode = .always
		engine.clientDelegate = self

		guard let nav = chainNavigationController else { return }
		engine.showBrowser(on: nav)
	}

	nonisolated
	func localNetworkEngineClient(_ localNetworkEngineClient: LocalNetworkEngineClient, finishedWithEvent: LocalNetworkEngineClient.Event) {
		switch finishedWithEvent {
		case .userTapDone, .connectionMade:
			Task { @MainActor in
				localNetworkEngineClient.browserVC.dismiss(animated: true)

				let viewModel = OnboardRecipientSelectorView.ViewModel(engine: localNetworkEngineClient)

				let next = OnboardRecipientSelectorView(coordinator: self, viewModel: viewModel)
				let vc = UIHostingController(rootView: next)
				vc.view.clipsToBounds = true

				chainNavigationController?.pushViewController(vc, animated: true)
			}
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
	func onboardView(_ onboardView: OnboardRecipientSelectorView, didSelectRecipientsFromList recipients: Set<Recipient.DTO>) {
		let coordinator = RecipientCoordinator(
			parentNavigationCoordinator: self,
			client: onboardView.viewModel.engine,
			selectedRecipients: recipients)

		addChildCoordinator(coordinator)
	}
}
