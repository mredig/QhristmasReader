import SwiftUI

struct GiftDetailView: View {

	@State
	var viewModel: GiftDetailViewModel

	var body: some View {
		if viewModel.gift.isArchived {
			Text("Gift deleted from database")
				.padding()
				.background(Color.red)
				.clipShape(RoundedRectangle(cornerRadius: 8, style: .circular))
		} else {
			detail
		}
	}

	@ViewBuilder
	private var detail: some View {
		Form {
			Section("Metadata") {
				if viewModel.isEditing {
					TextField("Label", text: $viewModel.editingLabel)

					Section("Recipients") {
						ForEach(viewModel.allRecipients()) { potentialRecipient in
							Button(
								action: {
									if viewModel.editingRecipients.contains(potentialRecipient) {
										viewModel.editingRecipients.remove(potentialRecipient)
									} else {
										viewModel.editingRecipients.insert(potentialRecipient)
									}
								},
								label: {
									HStack {
										let name = viewModel.editingRecipients.contains(potentialRecipient) ? "checkmark.circle" : "circle"
										Image(systemName: name)

										Text(potentialRecipient.name ?? "Some Person")
									}
								})
						}

						TextField("New Recipient", text: $viewModel.newRecipient)
					}
				} else {
					Text(viewModel.gift.label ?? "unlabeled")
					if viewModel.gift.recipients.isOccupied {
						Text(viewModel.gift.recipients.compactMap(\.name).sorted().joined(separator: ", "))
					}
				}
			}

			Image(uiImage: viewModel.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
		}
	}
}
