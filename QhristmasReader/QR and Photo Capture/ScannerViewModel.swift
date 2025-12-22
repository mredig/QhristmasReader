import SwiftUI
@preconcurrency import SwiftPizzaSnips
import CoreData

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

	var includeGivenGifts = false {
		didSet { updateFRO() }
	}
	var includeArchived = false {
		didSet { updateFRO() }
	}

	let fro: FetchedResultObserver<Gift>
	private(set) var latestSnapshot: FetchedResultObserver<Gift>.DiffableDataSourceType?

	init(coreDataStack: CoreDataStack) throws {
		let request = Self.createFetchRequest(includeArchived: false, includeGiven: false)

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

	private static func createFetchRequest(includeArchived: Bool, includeGiven: Bool) -> NSFetchRequest<Gift> {
		let request = Gift.fetchRequest()

		var predicateBuilder: [NSPredicate] = []
		if includeGiven == false {
			predicateBuilder.append(NSPredicate(format: "isGiven == NO"))
		}
		if includeArchived == false {
			predicateBuilder.append(NSPredicate(format: "isArchived == NO"))
		}

		let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicateBuilder)
		request.predicate = compound
		request.sortDescriptors = [
			.init(keyPath: \Gift.label, ascending: true)
		]

		return request
	}

	private func updateFRO() {
		let updatedRequest = Self.createFetchRequest(includeArchived: includeArchived, includeGiven: includeGivenGifts)

		do {
			try fro.updateFetchRequest(updatedRequest)
		} catch {
			print("Error updating request: \(error)")
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
