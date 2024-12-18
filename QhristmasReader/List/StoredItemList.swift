import SwiftUI
import SwiftPizzaSnips

@MainActor
struct StoredItemList: View {
	@MainActor
	protocol Coordinator: AnyObject {
		func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL)
	}

	@State
	var viewModel: ScannerViewModel

	unowned let coordinator: Coordinator
	let coreDataStack: CoreDataStack

	var body: some View {
		if let snapshot = viewModel.latestSnapshot {
			List(snapshot.itemIdentifiers, id: \.self) { objectID in
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
		} else {
			Text("Loading...")
		}
	}

	private func label(for gift: Gift) -> String {
		gift.label ?? gift.imageID?.uuidString ?? "Unknown label"
	}
}
