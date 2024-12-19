import SwiftPizzaSnips

extension DefaultsManager.KeyWithDefault where Value == String, StoredValue == Value {
	nonisolated(unsafe)
	static let username = Self("multipeer.username", defaultValue: "")
}

extension DefaultsManager.Key where Value == UserMode, StoredValue == String {
	nonisolated(unsafe)
	static let userMode = Self.init("app.usermode")
		.withTransform(
			get: {
				UserMode(rawValue: $0)
			},
			set: {
				$0.rawValue
			})

}
