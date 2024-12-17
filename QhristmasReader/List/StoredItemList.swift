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
		List(viewModel.storedItems, id: \.self) { url in
			Button(
				action: {
					coordinator.storedItemList(self, didTapItem: url)
				},
				label: {
					Text(label(for: url))
				})
		}
	}

	private func label(for url: URL) -> String {
		let uuidStr = url.deletingPathExtension().lastPathComponent
		guard
			let uuid = UUID(uuidString: uuidStr)
		else { return uuidStr }

		do {
			let context = coreDataStack.mainContext
			let gift = try context.performAndWait {
				let fr = Gift.fetchRequest()
				fr.predicate = NSPredicate(format: "imageID == %@", uuid as NSUUID)

				return try context.fetch(fr).first
			}
			guard let gift else { return uuidStr }
			let recipients = gift.recipients.compactMap(\.name).joined(separator: ", ")
			return "\(gift.label ?? uuidStr) (\(recipients))"
		} catch {
			return uuidStr
		}
	}
}
