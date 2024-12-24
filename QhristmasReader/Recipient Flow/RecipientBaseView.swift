import SwiftUI

@MainActor
struct RecipientBaseView: OnboardView {
	@MainActor
	protocol Coordinator: QhristmasReader.Coordinator {
		func recipientBaseViewDidTapScan(_ recipientBaseView: RecipientBaseView)
	}

	let gradientColors: [Color] = [
		.gradientColorDark,
		.gradientColorDarkAlt
	]

	let selectedRecipients: [Recipient.DTO]

	unowned let coordinator: Coordinator

	var body: some View {
		onboardingWrapper(bowOnTop: true) {
			VStack(alignment: .center) {
				headingText("You are scanning for", ofSize: 18)
				
				ForEach(selectedRecipients, id: \.self) { recipient in
					headingText(recipient.name, ofSize: 24)
				}
				
				giftyButton(titled: "Start Scanning") {
					coordinator.recipientBaseViewDidTapScan(self)
				}
			}
		}
	}
}
