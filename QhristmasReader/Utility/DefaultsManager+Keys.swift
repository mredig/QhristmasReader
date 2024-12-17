import SwiftPizzaSnips

extension DefaultsManager.Key where Value == String, StoredValue == Value {
	nonisolated(unsafe)
	static let username = Self("multipeer.username")
}
