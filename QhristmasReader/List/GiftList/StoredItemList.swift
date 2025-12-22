import SwiftUI
import CoreData
import SwiftPizzaSnips

@MainActor
struct StoredItemList: View {
	@MainActor
	protocol Coordinator: AnyObject {
		func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL)
		func storedItemList(_ storedItemList: StoredItemList, didAttemptDeletionOf objectID: NSManagedObjectID)
		func storedItemList(_ storedItemList: StoredItemList, markGiftAsGiven objectID: NSManagedObjectID)
	}

	@State
	var viewModel: ScannerViewModel

	unowned let coordinator: Coordinator
	let coreDataStack: CoreDataStack

	var body: some View {
		if let snapshot = viewModel.latestSnapshot, snapshot.numberOfItems > 0 {
			VStack {
				HStack {
					Text("Show:")
					Toggle(isOn: $viewModel.includeArchived, label: { Text("Archived") })
					Toggle(isOn: $viewModel.includeGivenGifts, label: { Text("Given") })
				}
				.safeAreaPadding()

				List {
					ForEach(snapshot.itemIdentifiers, id: \.self) { objectID in
						let object = viewModel.fro.maybeObject(for: objectID)

						if
							let object, let id = object.imageID, case let url = Gift.url(for: id) {
							Button(
								action: {
									coordinator.storedItemList(self, didTapItem: url)
								},
								label: {
									HStack {
										if object.isGiven {
											Image(systemName: "envelope.open")
										}
										if object.isArchived {
											Image(systemName: "archivebox.fill")
										}

										Text(label(for: object))
									}
								})
							.swipeActions(edge: .trailing, allowsFullSwipe: false, content: {
								Button(role: .destructive) {
									coordinator.storedItemList(self, didAttemptDeletionOf: objectID)
								} label: {
									Label("Archive", systemImage: "archivebox")
								}
							})
							.swipeActions(edge: .leading, allowsFullSwipe: true, content: {
								Button(
									action: {
										coordinator.storedItemList(self, markGiftAsGiven: objectID)
									},
									label: {
										Text("Gift Given!")
									})
								.tint(.accent)
							})
						}
					}
				}
			}
		} else {
			VStack {
				Text("Sync or Scan!")
					.font(.largeTitle)
					.foregroundStyle(.secondary)
					.bold()

				Text("(Buttons at the top of the screen)")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private func label(for gift: Gift) -> String {
		let label = gift.label ?? gift.imageID?.uuidString ?? "Unknown label"

		let recipients = gift.recipients.compactMap(\.name).sorted().joined(separator: ", ")

		return "\(label) (\(recipients))"
	}
}
