import Foundation

struct ListItemInfo: Codable {
	let lastUpdated: Date
	let isDeleted: Bool
	let originID: UUID
}
