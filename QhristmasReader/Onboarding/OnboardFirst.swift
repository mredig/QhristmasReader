import SwiftUI
import SwiftPizzaSnips

@MainActor
struct OnboardFirst: View {
	@MainActor
	protocol Coordinator: AnyObject {
		func onboardViewDidTapNextButton(_ onboardView: OnboardFirst)
	}

	@ObservedObject
	var defaults = DefaultsManager.shared

	unowned let coordinator: Coordinator

	var body: some View {
		ZStack(alignment: .center) {
			let screenSize = UIScreen.main.bounds.size
			RadialGradient(
				colors: [
					Color.gradientColorLight,
					Color.gradientColorDark,
				],
				center: UnitPoint(x: 0, y: 0),
				startRadius: 0,
				endRadius: screenSize.height)

			Image(.bow)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.rotationEffect(.degrees(10), anchor: .center)
				.scaledToFill()
				.frame(width: screenSize.width, height: screenSize.height)
				.offset(x: -50, y: -screenSize.height / 3)

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
		.colorScheme(.dark)
		.ignoresSafeArea(.container, edges: .all)
	}
}
