import CoreData

extension Recipient {
	var gifts: Set<Gift> {
		get {
			guard let giftsStore else {
				return []
			}
			return giftsStore as? Set<Gift> ?? []
		}
		set {
			giftsStore = NSSet(set: newValue)
		}
	}

	var dto: DTO {
		guard
			let id,
			let name
		else { fatalError("Missing name, id, or originID") }
		return DTO(
			id: id,
			originID: originID ?? id,
			lastUpdated: lastUpdated ?? .distantPast,
			name: name,
			gifts: Set(gifts.compactMap(\.imageID)))
	}

	convenience init(name: String, context: NSManagedObjectContext) {
		self.init(context: context)

		self.id = UUID()
		self.originID = UUID()
		update(name: .newValue(name))
	}

	convenience init(from dto: DTO, context: NSManagedObjectContext) throws {
		self.init(name: dto.name, context: context)
		self.id = dto.id
		self.originID = dto.originID

		lastUpdated = dto.lastUpdated
	}

	func update(from dto: DTO) {
		self.name = dto.name
		self.lastUpdated = dto.lastUpdated
	}

	func update(name: Update<String>) {
		if case .newValue(let t) = name {
			self.name = t
		}
		lastUpdated = .now
	}

	func addGift(_ gift: Gift) {
		gifts.insert(gift)
	}

	struct DTO: Codable {
		let id: UUID
		let originID: UUID
		let lastUpdated: Date
		let name: String
		let gifts: Set<UUID>
	}
}
