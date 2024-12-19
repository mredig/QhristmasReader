import SwiftUI
import CoreData
import SwiftPizzaSnips

@MainActor
struct StoredItemList: View {
	@MainActor
	protocol Coordinator: AnyObject {
		func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL)
		func storedItemList(_ storedItemList: StoredItemList, didAttemptDeletionOf objectID: NSManagedObjectID)
	}

	@State
	var viewModel: ScannerViewModel

	unowned let coordinator: Coordinator
	let coreDataStack: CoreDataStack

	var body: some View {
		if let snapshot = viewModel.latestSnapshot, snapshot.numberOfItems > 0 {
			List {
				ForEach(snapshot.itemIdentifiers, id: \.self) { objectID in
					let object = viewModel.fro.maybeObject(for: objectID)

					if
						let object, let id = object.imageID, case let url = ScannerViewModel.url(for: id) {
						Button(
							action: {
								coordinator.storedItemList(self, didTapItem: url)
							},
							label: {
								Text(label(for: object))
							})
					}
				}
				.onDelete { indices in
					guard
						let objectID = indices.first.map({ snapshot.itemIdentifiers[$0] })
					else { return }
					coordinator.storedItemList(self, didAttemptDeletionOf: objectID)
				}
			}
		} else {
			Text("Sync or Scan!")
				.font(.largeTitle)
				.foregroundStyle(.secondary)
				.bold()
		}
	}

	private func label(for gift: Gift) -> String {
		let label = gift.label ?? gift.imageID?.uuidString ?? "Unknown label"

		let recipients = gift.recipients.compactMap(\.name).sorted().joined(separator: ", ")

		return "\(label) (\(recipients))"
	}
}
