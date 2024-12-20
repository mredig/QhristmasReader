import SwiftUI
import SwiftPizzaSnips

@Observable
@MainActor
class ScannerViewModel {
	@MainActor
	protocol Delegate: AnyObject {
		func scannerViewModel(_ scannerViewModel: ScannerViewModel, didFindCodeMatch code: UUID, withImage image: UIImage)
		func scannerViewModel(_ scannerViewModel: ScannerViewModel, didNotFindCodeMatch code: UUID)
	}

	private(set) var capturingImageID: UUID?

	weak var delegate: Delegate?

	static let storageDirectory: URL = .applicationSupportDirectory.appending(component: "Images")

	let fro: FetchedResultObserver<Gift>
	private(set) var latestSnapshot: FetchedResultObserver<Gift>.DiffableDataSourceType?

	init(coreDataStack: CoreDataStack) throws {
		let request = Gift.fetchRequest()
		request.predicate = NSPredicate(format: "isArchived == NO")
		request.sortDescriptors = [
			.init(keyPath: \Gift.label, ascending: true)
		]

		self.fro = try FetchedResultObserver(
			fetchRequest: request,
			managedObjectContext: coreDataStack.mainContext)

		Task {
			try fro.start()
			for await snapshot in fro.resultStream {
				self.latestSnapshot = snapshot
			}
		}
	}

	func foundCode(_ code: UUID) {
		let url = Gift.url(for: code)

		do {
			let imageData = try Data(contentsOf: url)
			guard
				let image = UIImage(data: imageData)
			else { throw Error.notImage }
			delegate?.scannerViewModel(self, didFindCodeMatch: code, withImage: image)
		} catch {
			capturingImageID = code
			delegate?.scannerViewModel(self, didNotFindCodeMatch: code)
		}
	}

	enum Error: Swift.Error {
		case notImage
	}
}
