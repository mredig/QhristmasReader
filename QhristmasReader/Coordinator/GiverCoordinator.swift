import UIKit
import SwiftUI
import CoreData
import SwiftPizzaSnips

class GiverCoordinator: NSObject, NavigationChildCoordinator {
	var parentNavigationCoordinator: (any NavigationCoordinatorChain)?
	var childCoordinators: [any Coordinator] = []

	var rootController: UIViewController {
		hostingController
	}
	private var hostingController: ListViewController!

	let scannerVM: ScannerViewModel
	let coreDataStack: CoreDataStack

	init(
		parentNavigationCoordinator: (any NavigationCoordinator),
		coreDataStack: CoreDataStack
	) {
		self.parentNavigationCoordinator = parentNavigationCoordinator
		self.coreDataStack = coreDataStack

		do {
			let vm = try ScannerViewModel(coreDataStack: coreDataStack)
			self.scannerVM = vm
		} catch {
			fatalError("Error loading scanner vm: \(error)")
		}
		super.init()

		let listVC = ListViewController(
			viewModel: scannerVM,
			coordinator: self,
			coreDataStack: coreDataStack)
		self.hostingController = listVC
		scannerVM.delegate = self
	}

	func start() {
		chainNavigationController?.pushViewController(rootController, animated: true)
	}
	
	func coordinatorDidFinish(_ coordinator: any Coordinator) {}

	private func showSyncScreen(asHost: Bool, username: String) {
		Task {
			let syncCoordinator = await SyncCoordinator(
				parentNavigationCoordinator: self,
				asHost: asHost,
				username: username,
				coreDataStack: coreDataStack)
			addChildCoordinator(syncCoordinator)
		}
	}

	private func showGift(_ id: UUID) {
		do {
			let viewModel = try GiftDetailViewModel(canEdit: true, imageID: id, coreDataStack: coreDataStack)

			let vc = GiftDetailController(viewModel: viewModel)
			vc.view.clipsToBounds = true
			vc.navigationItem.largeTitleDisplayMode = .never
			chainNavigationController?.pushViewController(vc, animated: true)
		} catch {
			print("Error showing gift: \(error)")
		}
	}
}

extension GiverCoordinator: ListViewController.Coordinator {
	func listViewControllerDidTapScannerButton(_ listViewController: ListViewController) {
		let scannerView = QRCodeScannerView { [weak self] code in
			self?.scannerVM.foundCode(code)
		}

		let vc = UIHostingController(rootView: scannerView)
		vc.navigationItem.title = "Code Scanner"
		vc.navigationItem.largeTitleDisplayMode = .never
		chainNavigationController?.pushViewController(vc, animated: true)
	}
	
	func listViewControllerDidTapSyncButton(_ listViewController: ListViewController) {
		let alert = UIAlertController(title: "Sync Mode", message: "Are you hosting or joining a session?", preferredStyle: .alert)
		let hosting = UIAlertAction(
			title: "Hosting",
			style: .default) { [weak self] action in
				self?.showSyncScreen(asHost: true, username: DefaultsManager.shared[.username])
			}
		let joining = UIAlertAction(
			title: "Joining",
			style: .default) { [weak self] action in
				self?.showSyncScreen(asHost: false, username: DefaultsManager.shared[.username])
			}

		let cancel = UIAlertAction(title: "Cancel", style: .cancel)

		[
			hosting,
			joining,
			cancel
		]
			.forEach { alert.addAction($0) }

		chainNavigationController?.present(alert, animated: true)
	}
	
	func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL) {
		let uuidStr = item.deletingPathExtension().lastPathComponent
		guard let uuid = UUID(uuidString: uuidStr) else {
			print("Invalid uuid string: \(uuidStr)")
			return
		}

		showGift(uuid)
	}
	
	func storedItemList(_ storedItemList: StoredItemList, didAttemptDeletionOf objectID: NSManagedObjectID) {
		do {
			try deleteGift(objectWithID: objectID, scannerVM: storedItemList.viewModel)
		} catch {
			print("Error deleting gift: \(error)")
		}
	}

	private func deleteGift(objectWithID objectID: NSManagedObjectID, scannerVM: ScannerViewModel) throws {
		let context = coreDataStack.mainContext

		try context.performAndWait {
			let gift = try scannerVM.fro.object(for: objectID)
			gift.isArchived = true
			gift.update()
			try context.save()
		}
	}
}

extension GiverCoordinator: ScannerViewModel.Delegate {
	func scannerViewModel(
		_ scannerViewModel: ScannerViewModel,
		didFindCodeMatch code: UUID,
		withImage image: UIImage
	) {
		showGift(code)
	}
	
	func scannerViewModel(_ scannerViewModel: ScannerViewModel, didNotFindCodeMatch code: UUID) {
		let picker = UIImagePickerController()
		picker.sourceType = .camera
		picker.cameraCaptureMode = .photo
		picker.cameraDevice = .rear
		picker.delegate = self
		picker.isModalInPresentation = true
		picker.modalPresentationStyle = .fullScreen
		chainNavigationController?.present(picker, animated: true)
	}
}

extension GiverCoordinator: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true)
	}

	func imagePickerController(
		_ picker: UIImagePickerController,
		didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
	) {
		defer { picker.dismiss(animated: true) }
		guard
			let image = info[.originalImage] as? UIImage
		else {
			return
		}
		Task {
			let context = coreDataStack.newBackgroundContext()
			guard let id = scannerVM.capturingImageID else { return }
			async let dbSave: Void = context.perform {
				_ = Gift(imageID: id, context: context)

				try context.save()
			}

			let scaledImage = await image.imageByScaling(toSize: CGSize(scalar: 640), mode: .pixels)
			async let imageSave: Void = {
				guard let scaledImage else { return }
				await Gift.storeImage(scaledImage, for: id)
			}()

			try await dbSave
			await imageSave
		}
	}
}
