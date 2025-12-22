import SwiftUI
@preconcurrency import SwiftPizzaSnips
@preconcurrency import MultipeerConnectivity

struct SyncView: View {
	@State
	var viewModel: ViewModel

	var body: some View {
		VStack {
			if let onSearch = viewModel.onSearch {
				Button(
					action: {
						onSearch()
					},
					label: {
						Text("Search for Sync Host")
					})
			}

			List(viewModel.peers, id: \.self) { peer in
				Text(peer.displayName)
			}
		}
	}

	@Observable
	@MainActor
	class ViewModel {
		var onSearch: (() -> Void)?

		var peers: [MCPeerID] = []
	}
}
