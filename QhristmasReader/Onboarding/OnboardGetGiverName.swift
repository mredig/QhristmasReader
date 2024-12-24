import SwiftUI
import SwiftPizzaSnips

@MainActor
struct OnboardGetGiverName: OnboardView {
	@MainActor
	protocol Coordinator: AnyObject {
		func onboardViewDidTapNextButton(_ onboardView: OnboardGetGiverName)
	}

	@ObservedObject
	var defaults = DefaultsManager.shared

	unowned let coordinator: Coordinator

	let gradientColors: [Color]  = [
		Color.gradientColorLight,
		Color.gradientColorDark,
	]

	var body: some View {
		onboardingWrapper(bowOnTop: true) {
			VStack(alignment: .center, spacing: 8) {

				headingText("Hello!", ofSize: 64)

				headingText("What is the event we are celebrating?", ofSize: 32)

				TextField("Event name", text: defaults[binding: .username])
					.textFieldStyle(.roundedBorder)
					.multilineTextAlignment(.center)
					.autocorrectionDisabled()
					.colorScheme(.light)

				Spacer()
					.frame(maxHeight: 24)

				giftyButton(titled: "Next") {
					coordinator.onboardViewDidTapNextButton(self)
				}
				.disabled(defaults[.username].isEmpty)
			}
			.padding()
		}
	}
}
