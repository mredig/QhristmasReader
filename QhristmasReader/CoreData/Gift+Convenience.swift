import CoreData

extension Gift {
	var recipients: Set<Recipient> {
		get {
			guard let recipientsStore else {
				return []
			}
			return recipientsStore as? Set<Recipient> ?? []
		}

		set {
			recipientsStore = NSSet(set: newValue)
		}
	}

	var dto: DTO {
		guard let imageID else { fatalError("imageID missing") }
		return DTO(
			imageID: imageID,
			label: label,
			lastUpdated: lastUpdated ?? .distantPast,
			recipients: Set(recipients.compactMap(\.id)))
	}

	convenience init(imageID: UUID, label: String? = nil, context: NSManagedObjectContext) {
		self.init(context: context)

		update(imageID: .newValue(imageID), label: .newValue(label))
	}

	convenience init(from dto: DTO, context: NSManagedObjectContext) throws {
		self.init(imageID: dto.imageID, label: dto.label, context: context)

		let recipients = try context.performAndWait {
			let fr = Recipient.fetchRequest()
			fr.predicate = NSPredicate(format: "id in %@", dto.recipients as NSSet)

			let results = try context.fetch(fr)
			return Set(results)
		}
		setRecipients(recipients)
	}

	func update(imageID: Update<UUID> = .unchanged, label: Update<String?> = .unchanged) {
		if case .newValue(let t) = imageID {
			self.imageID = t
		}
		if case .newValue(let t) = label {
			self.label = t
		}

		lastUpdated = .now
	}

	func addRecipient(_ recipient: Recipient) {
		recipients.insert(recipient)
		lastUpdated = .now
	}

	func setRecipients(_ recipients: Set<Recipient>) {
		self.recipients = recipients
		lastUpdated = .now
	}

	struct DTO: Codable {
		let imageID: UUID
		let label: String?
		let lastUpdated: Date
		let recipients: Set<UUID>
	}
}
