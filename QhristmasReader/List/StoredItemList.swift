import SwiftUI

struct StoredItemList: View {
	protocol Coordinator: AnyObject {
		func storedItemList(_ storedItemList: StoredItemList, didTapItem item: URL)
	}

	@State
	var viewModel: ScannerViewModel

	unowned let coordinator: Coordinator

	var body: some View {
		List(viewModel.storedItems, id: \.self) { url in
			Button(
				action: {
					coordinator.storedItemList(self, didTapItem: url)
				},
				label: {
					Text(url.lastPathComponent)
				})
		}
	}
}
