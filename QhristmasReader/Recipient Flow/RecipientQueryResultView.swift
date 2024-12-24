import SwiftUI

struct RecipientQueryResultView: View {

	let message: String?
	enum Result {
		case yours([Recipient.DTO])
		case others([Recipient.DTO]?)
	}
	let result: Result

	let myDTOs: Set<Recipient.DTO>

	var body: some View {
		VStack {
			switch result {
			case .yours(let array):
				Text("Yay! This one is yours!")
					.multilineTextAlignment(.center)
					.lineLimit(0)

				if Set(array) != myDTOs {
					Text("Name(s) on gift: \(array.map(\.name).joined(separator: ", "))")
						.multilineTextAlignment(.center)
						.lineLimit(0)
				}

			case .others(let array):
				Text("Aww, gotta put this one back.")

				if let array {
					Text("It's actually for \(array.map(\.name).joined(separator: ", "))")
				}
			}

			if let message {
				Text(message)
					.multilineTextAlignment(.center)
					.lineLimit(0)
			}
		}
		.padding()
		.background {
			switch result {
			case .yours:
				Color.gradientColorDark
			case .others:
				Color.gradientColorLightAlt
			}
		}
	}
}
