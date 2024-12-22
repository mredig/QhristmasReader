import UIKit

protocol NavigationCoordinatorChain: Coordinator {
	var nextNavigationParent: NavigationCoordinatorChain? { get }
	var chainNavigationController: UINavigationController? { get }
}

extension NavigationCoordinatorChain {
	var chainNavigationController: UINavigationController? { nextNavigationParent?.chainNavigationController }
}

extension NavigationCoordinatorChain where Self: NavigationCoordinator {
	var chainNavigationController: UINavigationController? { navigationController }
}
