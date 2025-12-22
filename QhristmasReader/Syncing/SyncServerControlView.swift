import SwiftUI

struct SyncServerControlView: View {
	@State
	private var viewModel: ViewModel

	init(viewModel: ViewModel) {
		self.viewModel = viewModel
	}

	var body: some View {
		Toggle("Server is Running", isOn: $viewModel.isRunning)
	}

	@Observable
	@MainActor
	class ViewModel {
		var isRunning: Bool {
			didSet {
				if isRunning {
					server.start()
				} else {
					server.stop()
				}
			}
		}

		let server: DiscoveryServer

		init(server: DiscoveryServer) {
			self.isRunning = server.isRunning
			self.server = server
		}
	}
}
