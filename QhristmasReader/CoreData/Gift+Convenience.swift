import CoreData
import UIKit

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
		guard
			let imageID
		else { fatalError("imageID or originID missing") }
		return DTO(
			imageID: imageID,
			originID: originID ?? imageID,
			label: label,
			lastUpdated: lastUpdated ?? .distantPast,
			recipients: Set(recipients.compactMap(\.id)))
	}

	convenience init(imageID: UUID, label: String? = nil, context: NSManagedObjectContext) {
		self.init(context: context)
		self.originID = UUID()

		update(imageID: .newValue(imageID), label: .newValue(label))
	}

	convenience init(from dto: DTO, context: NSManagedObjectContext) throws {
		self.init(imageID: dto.imageID, label: dto.label, context: context)

		self.originID = dto.originID

		let recipients = try context.performAndWait {
			let fr = Recipient.fetchRequest()
			fr.predicate = NSPredicate(format: "id in %@", dto.recipients as NSSet)

			let results = try context.fetch(fr)
			return Set(results)
		}
		setRecipients(recipients)
		lastUpdated = dto.lastUpdated
	}

	func update(from dto: DTO, context: NSManagedObjectContext) throws {
		update(imageID: .newValue(dto.imageID), label: .newValue(dto.label))

		let recipientIDs = dto.recipients
		let recipients = try context.performAndWait {
			let fr = Recipient.fetchRequest()
			fr.predicate = NSPredicate(format: "id IN %@", recipientIDs as NSSet)

			return try context.fetch(fr)
		}

		setRecipients(Set(recipients))
		lastUpdated = dto.lastUpdated
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
		let originID: UUID
		let label: String?
		let lastUpdated: Date
		let recipients: Set<UUID>
	}

	public override func prepareForDeletion() {
		super.prepareForDeletion()

		if let imageID {
			Task { @MainActor in
				do {
					try Self.deleteImage(for: imageID)
				} catch {
					print("Error deleting image: \(error)")
				}
			}
		}
	}

	@MainActor
	static func url(for imageID: UUID) -> URL {
		ScannerViewModel
			.storageDirectory
			.appending(component: imageID.uuidString.lowercased())
			.appendingPathExtension("jpg")
	}

	@MainActor
	static func storeImage(_ image: UIImage, for id: UUID) {
		guard
			let imageData = image.jpegData(compressionQuality: 0.85)
		else { return }

		let url = Self.url(for: id)
		do {
			try FileManager.default.createDirectory(at: ScannerViewModel.storageDirectory, withIntermediateDirectories: true)
			try imageData.write(to: url)
		} catch {
			print("Cant save cuz \(error.localizedDescription)")
		}
	}

	@MainActor
	static func deleteImage(for id: UUID) throws {
		let url = Self.url(for: id)
		try FileManager.default.removeItem(at: url)
	}
}
