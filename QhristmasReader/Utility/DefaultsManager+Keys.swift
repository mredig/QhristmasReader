import SwiftPizzaSnips

extension DefaultsManager.Key where Value == String, StoredValue == Value {
	static let username = Self("multipeer.username")
}
