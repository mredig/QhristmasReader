import UIKit

protocol NavigationChildCoordinator: NavigationCoordinatorChain {
	var parentNavigationCoordinator: (any NavigationCoordinatorChain)? { get }
}

extension NavigationChildCoordinator {
	var parentCoordinator: (any Coordinator)? { parentNavigationCoordinator }
	var nextNavigationParent: (any NavigationCoordinatorChain)? { parentNavigationCoordinator }
}
