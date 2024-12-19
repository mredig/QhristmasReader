import SwiftUI
import SwiftPizzaSnips

@MainActor
struct OnboardSecond: OnboardView {
	@MainActor
	protocol Coordinator: AnyObject {
		func onboardViewDidTapNextButton(_ onboardView: OnboardSecond)
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

				giftyButton(titled: "Opening", action: {})

				giftyButton(titled: "Giving", action: {})
			}
		}
	}
}
