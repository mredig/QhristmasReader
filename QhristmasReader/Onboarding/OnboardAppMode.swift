import SwiftUI
import SwiftPizzaSnips

@MainActor
struct OnboardAppMode: OnboardView {
	@MainActor
	protocol Coordinator: AnyObject {
		func onboardViewDidTapGivingButton(_ onboardView: OnboardAppMode)
		func onboardViewDidTapOpeningButton(_ onboardView: OnboardAppMode)
	}

	unowned let coordinator: Coordinator

	@State
	var gradientColors: [Color] = [
		.gradientColorLightAlt,
		.gradientColorDarkAlt,
	]

	var body: some View {
		onboardingWrapper(bowOnTop: false) {
			VStack {
				headingText("Will you be opening or giving gifts with this app?", ofSize: 24)

				giftyButton(
					titled: "Opening",
					action: {
						coordinator.onboardViewDidTapOpeningButton(self)
					})
//				Text("Opening not yet implemented - test giving for now")

				giftyButton(
					titled: "Giving",
					action: {
						coordinator.onboardViewDidTapGivingButton(self)
					})
			}
		}
	}
}
