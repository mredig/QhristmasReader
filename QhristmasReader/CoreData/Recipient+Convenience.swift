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
		guard let id, let name else { fatalError("Missing name or id") }
		return DTO(
			id: id,
			lastUpdated: lastUpdated ?? .distantPast,
			name: name,
			gifts: Set(gifts.compactMap(\.imageID)))
	}

	convenience init(name: String, context: NSManagedObjectContext) {
		self.init(context: context)

		self.id = UUID()
		update(name: .newValue(name))
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
		let lastUpdated: Date
		let name: String
		let gifts: Set<UUID>
	}
}