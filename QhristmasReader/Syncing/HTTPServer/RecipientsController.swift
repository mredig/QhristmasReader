import Foundation
import Hummingbird
import Logging
@preconcurrency import SwiftPizzaSnips

struct RecipientsController {
	let logger: Logger

	static var recipientIDParameter: String { "recipientID" }

	let coreDataStack: CoreDataStack

//	listRecipientIDs
//	listRecipients
//	getRecipient

	func addRoutes(recipientsGroup: RouterGroup<BasicRequestContext>) {
		recipientsGroup
			.get("id/:\(Self.recipientIDParameter)", use: handleGetRecipientInfoRequest)
			.get("listChangeStates", use: handleRecipientChangeStatesRequest)
			.get("list", use: handleRecipientListRequest)
	}

	private func handleRecipientChangeStatesRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
		let context = coreDataStack.mainContext

		let recipientsInfo = try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()

			let rec = try context.fetch(fr)
			return rec.reduce(into: [UUID: ListItemInfo]()) {
				guard let id = $1.id else { return }
				$0[id] = ListItemInfo(
					lastUpdated: $1.dto.lastUpdated,
					isDeleted: false,
					originID: $1.dto.originID)
			}
		}

		return recipientsInfo
	}

	private func handleRecipientListRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
		let context = coreDataStack.mainContext

		let recipients = try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()

			return try context.fetch(fr).map(\.listDTO)
		}

		return recipients
	}

	private func handleGetRecipientInfoRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {

		let id = try context.parameters.get(Self.recipientIDParameter, as: UUID.self).unwrap("Not a UUID")

		let context = coreDataStack.newBackgroundContext()
		return try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "id == %@", id as NSUUID)

			let recipient = try context.fetch(fr).first.unwrap()
			return recipient.dto
		}
	}
}

extension Recipient.DTO: ResponseCodable {}
