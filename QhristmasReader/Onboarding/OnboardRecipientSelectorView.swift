import SwiftUI

@MainActor
struct OnboardRecipientSelectorView: OnboardView {
	@MainActor
	protocol Coordinator: QhristmasReader.Coordinator {
		func onboardView(_ onboardView: OnboardRecipientSelectorView, didSelectRecipientsFromList recipients: Set<Recipient.DTO>)
	}
	unowned let coordinator: Coordinator

	let gradientColors: [Color]  = [
		Color.gradientColorLight,
		Color.gradientColorDark,
	]

	@State
	var viewModel: ViewModel

	var body: some View {
		onboardingWrapper(bowOnTop: true) {
			switch viewModel.state {
			case .error(let error):
				Text("Error loading recipient list: \(error.localizedDescription)")
			case .loading:
				Text("Loading recipient list...")
			case .loaded(let recipieints):
				recipientList(recipieints).safeAreaPadding(.top, 64)
			}

		}
	}

	@ViewBuilder
	private func recipientList(_ list: [Recipient.DTO]) -> some View {
		ScrollView {
			LazyVStack {
				headingText("Select yourself.", ofSize: 32)
					.padding(.bottom, 8)

				headingText("If you are helping itty bitty kiddies/kitties/doggies/etc,\nselect them as well.", ofSize: 14)
					.padding(.bottom, 8)

				ForEach(list, id: \.self) { recipient in
					recipientRow(recipient)
				}

				giftyButton(titled: "Next") {
					let representing = Set(list.filter({ viewModel.selection.contains($0.id) }))
					coordinator.onboardView(self, didSelectRecipientsFromList: representing)
				}
			}
		}
		.background {
			LinearGradient(
				colors: [
					Color(hue: 0, saturation: 0, brightness: 0, opacity: 0.3),
					Color(hue: 0, saturation: 0, brightness: 0, opacity: 0.0),
				],
				startPoint: .top,
				endPoint: .bottom)
		}
	}

	@ViewBuilder
	private func recipientRow(_ recipient: Recipient.DTO) -> some View {
		VStack(alignment: .leading) {
			HStack(alignment: .center) {
				let name = viewModel.selection.contains(recipient.id) ? "checkmark.circle" : "circle"
				Image(systemName: name)

				Text(recipient.name)
			}
			.onTapGesture {
				if viewModel.selection.contains(recipient.id) {
					viewModel.selection.remove(recipient.id)
				} else {
					viewModel.selection.insert(recipient.id)
				}
			}

			Rectangle()
				.foregroundStyle(.quinary)
				.frame(height: 1)
				.frame(maxWidth: .infinity)
		}
		.frame(maxWidth: .infinity)
		.frame(minHeight: 44)
		.clipShape(Rectangle())
		.padding(.horizontal)
	}

	@Observable
	@MainActor
	class ViewModel {
		enum CurrentState {
			case loading
			case loaded([Recipient.DTO])
			case error(Error)
		}

		let engine: LocalNetworkEngineClient
		var state: CurrentState = .loading

		var selection: Set<UUID> = []

		init(engine: LocalNetworkEngineClient) {
			self.engine = engine

			Task {
				await load()
			}
		}

		private func load() async {
			do {
				let list = try await engine.sendRecipientListRequest()
				state = .loaded(list)
			} catch {
				print("Error loading recipient list: \(error)")
				state = .error(error)
			}
		}
	}
}
