import UIKit
import SwiftPizzaSnips

class RootCoordinator: NSObject, NavigationCoordinator {
	let navigationController = UINavigationController()
	var previousViewControllers: [UIViewController] = []
	var rootController: UIViewController { navigationController }

	let parentNavigationCoordinator: (any NavigationCoordinatorChain)? = nil
	var childCoordinators: [any Coordinator] = []

	let coreDataStack: CoreDataStack
	let window: UIWindow

	private var onboardCoordinator: OnboardCoordinator!

	private var asyncPresentationTask: Task<Void, Never>?

	init(coreDataStack: CoreDataStack, window: UIWindow) {
		self.coreDataStack = coreDataStack
		self.window = window
		super.init()
		navigationController.delegate = self
	}

	func start() {
		window.rootViewController = navigationController
		window.makeKeyAndVisible()

		let onboardCoordinator = OnboardCoordinator(parentCoordinator: self, delegate: self)
		self.onboardCoordinator = onboardCoordinator
		addChildCoordinator(onboardCoordinator)
	}

	func coordinatorDidFinish(_ coordinator: any Coordinator) {}

	private func performAsyncPresentationTask(@_implicitSelfCapture _ presentation: @escaping @Sendable @MainActor () async -> Void) {
		guard asyncPresentationTask == nil else { return }

		let newTask = Task {
			await presentation()

			asyncPresentationTask = nil
		}
		asyncPresentationTask = newTask
	}
}

extension RootCoordinator: OnboardCoordinator.Delegate {
	func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowGiverUI animated: Bool) {
		performAsyncPresentationTask {
			let giverRoot = await GiverRootCoordinator(
				parentCoordinator: self,
				delegate: self,
				coreDataStack: coreDataStack)

			addChildCoordinator(giverRoot)
			window.rootViewController = giverRoot.tabBarController
		}
	}

	func onboardCoordinator(_ onboardCoordinator: OnboardCoordinator, shouldShowRecipientUI animated: Bool) {

	}
}

extension RootCoordinator: GiverRootCoordinator.Delegate {
	func giverRootCoordinatorDidActivateAppModeReset(_ giverRootCoordinator: GiverRootCoordinator) {
		Task {
			await giverRootCoordinator.finish()
		}

		window.rootViewController = navigationController
		navigationController.popToRootViewController(animated: false)
	}
}

extension RootCoordinator: UINavigationControllerDelegate {
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		superNavigationController(navigationController, didShow: viewController, animated: animated)
	}
}
