import SwiftUI

struct GiftDetailView: View {

	@State
	var viewModel: GiftDetailViewModel

	var body: some View {
		Form {
			if viewModel.isEditing {
				TextField("Label", text: $viewModel.editingLabel)

				LazyVStack {
					ForEach(viewModel.allRecipients()) { potentialRecipient in
						Button(
							action: {
								if viewModel.editingRecipients.contains(potentialRecipient) {
									viewModel.editingRecipients.insert(potentialRecipient)
								} else {
									viewModel.editingRecipients.remove(potentialRecipient)
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
				}

			} else {
				Text(viewModel.gift.label ?? "unlabeled")
				if viewModel.gift.recipients.isOccupied {
					Text(viewModel.gift.recipients.compactMap(\.name).sorted().joined(separator: ", "))
				}
			}

			Image(uiImage: viewModel.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
		}
	}
}
