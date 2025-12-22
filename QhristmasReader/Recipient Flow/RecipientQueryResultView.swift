import SwiftUI

struct RecipientQueryResultView: OnboardView {

	let message: String?
	enum Result {
		case yours([Recipient.ListDTO])
		case others([Recipient.ListDTO]?)
	}
	let result: Result

	let myDTOs: Set<Recipient.ListDTO>

	let gradientColors: [Color] = []

	var body: some View {
		ZStack {
			VStack(spacing: 8) {
				switch result {
				case .yours(let array):
					headingText("Yay! This one is yours!", ofSize: 36)
					
					if Set(array) != myDTOs {
						headingText("Name(s) on gift:", ofSize: 18)
						
						Text("\(array.map(\.name).joined(separator: ", "))")
							.multilineTextAlignment(.center)
							.lineLimit(0)
					}
					
				case .others(let array):
					headingText("Aww, gotta put this one back.", ofSize: 24)
					
					if let array {
						Text("It's actually for \(array.map(\.name).joined(separator: ", "))")
							.multilineTextAlignment(.center)
							.lineLimit(0)
					}
				}
				
				if let message {
					Text(message)
						.multilineTextAlignment(.center)
						.lineLimit(0)
				}
			}
			.padding()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.background {
			switch result {
			case .yours:
				Color.gradientColorDark
			case .others:
				Color.gradientColorLightAlt
			}
		}
		.ignoresSafeArea()
	}
}
