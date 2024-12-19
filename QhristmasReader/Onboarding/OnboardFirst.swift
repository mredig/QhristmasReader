import SwiftUI
import SwiftPizzaSnips

@MainActor
struct OnboardFirst: OnboardView {
	@MainActor
	protocol Coordinator: AnyObject {
		func onboardViewDidTapNextButton(_ onboardView: OnboardFirst)
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
				Text("Hello!")
					.font(.system(size: 64, weight: .semibold, design: .rounded))
					.multilineTextAlignment(.center)

				Text("Who are you?")
					.font(.system(size: 32, weight: .semibold, design: .rounded))
					.multilineTextAlignment(.center)

				Text("(So when giving/receiving you can be identified)")
					.font(.system(size: 14, weight: .semibold, design: .rounded))
					.multilineTextAlignment(.center)

				TextField("Your name", text: defaults[binding: .username])
					.textFieldStyle(.roundedBorder)
					.multilineTextAlignment(.center)
					.autocorrectionDisabled()
					.colorScheme(.light)

				Spacer()
					.frame(maxHeight: 24)

				Button(
					action: {
						coordinator.onboardViewDidTapNextButton(self)
					},
					label: {
						Text("Next")
							.padding()
							.background(Color.primary)
					})
				.disabled(defaults[.username].isEmpty)
				.cornerRadius(8)
			}
			.padding()
		}
	}
}
