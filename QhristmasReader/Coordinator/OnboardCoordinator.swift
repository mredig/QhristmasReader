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
	private var hostingController: UIHostingController<OnboardFirst>!

	unowned let delegate: Delegate

	init(
		parentCoordinator: (any NavigationCoordinator)? = nil,
		delegate: Delegate
	) {
		self.parentNavigationCoordinator = parentCoordinator
		self.delegate = delegate
		let onboardView = OnboardFirst(coordinator: self)
		self.hostingController = UIHostingController(rootView: onboardView)
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

extension OnboardCoordinator: OnboardFirst.Coordinator {
	func onboardViewDidTapNextButton(_ onboardView: OnboardFirst) {
		let next = OnboardSecond(coordinator: self)
		let vc = UIHostingController(rootView: next)

		chainNavigationController?.pushViewController(vc, animated: true)
	}
}

extension OnboardCoordinator: OnboardSecond.Coordinator {
	func onboardViewDidTapGivingButton(_ onboardView: OnboardSecond) {
		DefaultsManager.shared[.userMode] = .give

		delegate.onboardCoordinator(self, shouldShowGiverUI: true)
	}

	func onboardViewDidTapOpeningButton(_ onboardView: OnboardSecond) {
		DefaultsManager.shared[.userMode] = .get

		delegate.onboardCoordinator(self, shouldShowRecipientUI: true)
	}
}
