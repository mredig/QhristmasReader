import SwiftUI
import SwiftPizzaSnips

@MainActor
class ListViewController: UIHostingController<StoredItemList> {
	@MainActor
	protocol Coordinator: StoredItemList.Coordinator {
		func listViewControllerDidTapScannerButton(_ listViewController: ListViewController)
		func listViewControllerDidTapSyncButton(_ listViewController: ListViewController)
	}

	unowned let coordinator: Coordinator
	let coreDataStack: CoreDataStack

	init(viewModel: ScannerViewModel, coordinator: Coordinator, coreDataStack: CoreDataStack) {
		self.coordinator = coordinator
		self.coreDataStack = coreDataStack
		super.init(rootView: StoredItemList(viewModel: viewModel, coordinator: coordinator, coreDataStack: coreDataStack))
	}
	
	@MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		configureCameraButton()
	}

	private func configureCameraButton() {
		let action = UIAction { [weak self] _ in
			guard let self else { return }
			self.coordinator.listViewControllerDidTapScannerButton(self)
		}
		let cameraButton = UIBarButtonItem(title: "Scanner", image: UIImage(systemName: "barcode.viewfinder"), primaryAction: action)

		let syncAction = UIAction(title: "Sync", image: UIImage(systemName: "point.3.connected.trianglepath.dotted")) { [weak self] _ in
			guard let self else { return }
			self.coordinator.listViewControllerDidTapSyncButton(self)

		}
		let syncButton = UIBarButtonItem(primaryAction: syncAction)


		navigationItem.rightBarButtonItem = cameraButton
		navigationItem.leftBarButtonItem = syncButton
	}
}
