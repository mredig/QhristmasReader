import SwiftUI

protocol OnboardView: View {
	var gradientColors: [Color] { get }
}

extension OnboardView {
	func onboardingWrapper<T: View>(bowOnTop: Bool, onboardingView: @autoclosure () -> T) -> some View {
		onboardingWrapper(bowOnTop: bowOnTop) {
			onboardingView()
		}
	}

	func onboardingWrapper<T: View>(bowOnTop: Bool, @ViewBuilder onboardingView: () -> T) -> some View {
		ZStack(alignment: .center) {
			let screenSize = UIScreen.main.bounds.size
			RadialGradient(
				colors: gradientColors,
				center: UnitPoint(x: 0, y: 0),
				startRadius: 0,
				endRadius: screenSize.height)

			let bow = Image(.bow)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.rotationEffect(.degrees(10), anchor: .center)
				.scaledToFill()
				.frame(width: screenSize.width, height: screenSize.height)
			if bowOnTop {
				bow
					.offset(x: -50, y: -(screenSize.height / 3))
			} else {
				bow
					.offset(x: -50, y: screenSize.height / 3)
			}

			onboardingView()
		}
		.colorScheme(.dark)
		.ignoresSafeArea(.container, edges: .all)
	}

	func headingText(_ text: String, ofSize size: Double) -> some View {
		Text(text)
			.font(.system(size: size, weight: .semibold, design: .rounded))
			.multilineTextAlignment(.center)
	}

	func giftyButton(titled title: String, action: @escaping () -> Void) -> some View {
		Button(
			action: {
				action()
			},
			label: {
				Text(title)
					.padding()
					.background(Color.primary)
			})
		.cornerRadius(8)
	}
}
