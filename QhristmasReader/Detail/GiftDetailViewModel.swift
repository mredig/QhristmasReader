import SwiftUI
import SwiftPizzaSnips

@Observable
@MainActor
class GiftDetailViewModel {
	let image: UIImage

	let gift: Gift

	let coreDataStack: CoreDataStack

	var editingLabel: String = ""
	var editingRecipients: Set<Recipient> = []
	var newRecipient: String = ""

	private(set) var isEditing = false
	let canEdit: Bool

	init(canEdit: Bool, imageID: UUID, coreDataStack: CoreDataStack) throws {
		let imageURL = Gift.url(for: imageID)
		let imageData = try Data(contentsOf: imageURL)
		guard
			let image = UIImage(data: imageData)
		else { throw SimpleError(message: "Image not found") }

		let context = coreDataStack.mainContext
		let gift = (try? context.performAndWait({
			let fr = Gift.fetchRequest()
			fr.predicate = NSPredicate(format: "imageID == %@", imageID as NSUUID)

			return try context.fetch(fr).first
		})) ?? Gift(imageID: imageID, context: context)

		self.canEdit = canEdit
		self.gift = gift
		self.image = image
		self.coreDataStack = coreDataStack
	}

	func toggleEditState() {
		isEditing.toggle()
		if isEditing {
			editingLabel = gift.label.nilIsEmpty
			editingRecipients = gift.recipients
			newRecipient = ""
		} else {
			gift.update(label: .newValue(editingLabel.emptyIsNil))
			gift.setRecipients(editingRecipients)

			if let newRecipientName = newRecipient.emptyIsNil {
				let newRecipient = Recipient(name: newRecipientName, context: coreDataStack.mainContext)
				gift.addRecipient(newRecipient)
			}
		}
	}

	func allRecipients() -> [Recipient] {
		let context = coreDataStack.mainContext

		let rec = try? context.performAndWait({
			let fr = Recipient.fetchRequest()
			fr.sortDescriptors = [NSSortDescriptor(keyPath: \Recipient.name, ascending: true)]

			return try context.fetch(fr)
		})
		return rec ?? []
	}

	func saveGift() {
		let context = coreDataStack.mainContext
		context.performAndWait {
			context.noThrowSave()
		}
	}
}
