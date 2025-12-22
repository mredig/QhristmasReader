import SwiftPizzaSnips

extension Optional {
	func unwrap<E: Error>(orThrow customError: E) throws(E) -> Wrapped {
		do {
			return try unwrap()
		} catch {
			throw customError
		}
	}
}
