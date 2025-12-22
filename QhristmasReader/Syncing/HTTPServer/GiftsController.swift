import Foundation
import Hummingbird
import Logging
@preconcurrency import SwiftPizzaSnips

struct GiftsController {
	let logger: Logger

	static var giftImageIDParameter: String { "giftImageID" }
	static var giftIDParameter: String { "giftID" }

	let coreDataStack: CoreDataStack

//	listGiftIDs
//	getGift
//	giftQuery

	func addRoutes(giftsGroup: RouterGroup<BasicRequestContext>) {
		giftsGroup
			.get("id/:\(Self.giftImageIDParameter)", use: handleGiftRequest)
			.get("listChangeStates", use: handleGiftChangeStatesRequest)
			.post("query", use: handleGiftQueryRequest)
	}

	private func handleGiftChangeStatesRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
		let context = coreDataStack.mainContext

		return try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()

			let gifts = try context.fetch(fr)
			return gifts.reduce(into: [UUID: ListItemInfo]()) {
				guard let id = $1.imageID else { return }
				$0[id] = ListItemInfo(
					lastUpdated: $1.dto.lastUpdated,
					isDeleted: $1.isArchived,
					originID: $1.dto.originID)
			}
		}
	}

	// to sync gifts with other hosts
	private func handleGiftRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
		let id = try context.parameters.get(Self.giftImageIDParameter, as: UUID.self)
			.unwrap(orThrow: HTTPError(.notFound, message: "Invalid id"))

		async let imageData = {
			let imageURL = await Gift.url(for: id)
			return try Data(contentsOf: imageURL)
		}()

		let bgContext = coreDataStack.newBackgroundContext()
		var giftDTO = try await bgContext.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

			guard
				let gift = try? bgContext.fetch(fr).first
			else { throw DiscoveryServer.ServerError.noMatchingGift }

			return gift.dto
		}

		giftDTO.imageData = try? await imageData

		return giftDTO
	}

	// to provide a client an answer as to whether this is theirs or not
	private func handleGiftQueryRequest(request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {

		let query = try await request.decode(as: GiftQueryRequest.self, context: context)
		let id = query.imageID

		let bgContext = coreDataStack.newBackgroundContext()
		let (giftDTO, recips) = try await bgContext.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

			guard
				let gift = try? bgContext.fetch(fr).first
			else { throw DiscoveryServer.ServerError.noMatchingGift }

			let recips = gift.recipients.map(\.listDTO)
			return (gift.dto, recips)
		}

		return GiftQueryResponse(
			queriedIDs: query.representedRecipientIDs,
			matchingCrossover: query.representedRecipientIDs.intersection(recips.map(\.id)),
			allRecipients: Set(recips),
			gift: giftDTO,
			message: nil)
	}

	struct GiftQueryRequest: Codable, Sendable, Hashable {
		let imageID: UUID
		let representedRecipientIDs: Set<UUID>
	}

	struct GiftQueryResponse: ResponseCodable, Hashable, Sendable {
		let queriedIDs: Set<UUID>
		let matchingCrossover: Set<UUID>
		let allRecipients: Set<Recipient.ListDTO>?
		let gift: Gift.DTO?

		let message: String?
	}
}


extension Gift.DTO: ResponseCodable {}
