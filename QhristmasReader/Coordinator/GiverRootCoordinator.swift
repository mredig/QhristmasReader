import SwiftUI
import UIKit
import SwiftPizzaSnips
@preconcurrency import SwiftPizzaSnips

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

	private var httpTask: Task<Void, Error>?
	private var syncHost: LocalNetworkEngineServer

	init(
		parentCoordinator: (any Coordinator)?,
		delegate: Delegate,
		coreDataStack: CoreDataStack
	) async {
		async let syncHostLoad = LocalNetworkEngineServer(username: DefaultsManager.shared[.username], coreDataStack: coreDataStack)
		self.parentCoordinator = parentCoordinator
		self.delegate = delegate
		self.coreDataStack = coreDataStack
		self.httpTask = Task {
			do {
				try await HTTPHost.startListening(coreDataStack: coreDataStack)
			} catch {
				print("Error listening for http connections: \(error)")
			}
		}

		let syncHost = await syncHostLoad
		self.syncHost = syncHost
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
				Text("Reset to mode selection screen")
			})
		let vc = UIHostingController(rootView: placeholder)
		vc.tabBarItem.title = "App Mode Reset"
		vc.tabBarItem.image = UIImage(systemName: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90")

		let syncServerControlVM = SyncServerControlView.ViewModel(server: syncHost)
		let serverControlView = SyncServerControlView(viewModel: syncServerControlVM)
		let serverControlVC = UIHostingController(rootView: serverControlView)
		serverControlVC.tabBarItem.title = "Sync Server Control"
		serverControlVC.tabBarItem.image = UIImage(systemName: "server.rack")

		tabBarController.viewControllers = [
			giverList.navigationController,
			serverControlVC,
			vc
		]
	}
	
	func coordinatorDidFinish(_ coordinator: any Coordinator) {
		httpTask?.cancel()
	}
}
