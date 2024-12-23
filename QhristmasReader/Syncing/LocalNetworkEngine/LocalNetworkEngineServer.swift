@preconcurrency import MultipeerConnectivity
@preconcurrency import SwiftPizzaSnips

class LocalNetworkEngineServer: LocalNetworkEngine, @unchecked Sendable {
	private nonisolated let advertiser: MCNearbyServiceAdvertiser

	let coreDataStack: CoreDataStack

	@MainActor
	init(
		session: MCSession,
		advertiser: MCNearbyServiceAdvertiser,
		coreDataStack: CoreDataStack
	) async {
		self.advertiser = advertiser
		self.coreDataStack = coreDataStack
		super.init(session: session)
		advertiser.delegate = self
	}

	convenience init(username: String, coreDataStack: CoreDataStack) async {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceTypeIdentifier)

		await self.init(session: session, advertiser: advertiser, coreDataStack: coreDataStack)
	}

	func start() {
		advertiser.startAdvertisingPeer()
	}

	func stop() {
		advertiser.stopAdvertisingPeer()
	}

	override func didConnect(to peer: MCPeerID) {
		print("\(peer) is connected")
	}

	override func didStartConnecting(to peer: MCPeerID) {
		print("\(peer) is connecting")
	}

	override func didDisconnect(from peer: MCPeerID) {
		print("\(peer) disconnected")
	}
}

extension LocalNetworkEngineServer: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
		print("\(#function): - \(error)")
	}

	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("\(#function): \(peerID) - \(context as Any)")

		invitationHandler(true, session)
	}
}

extension LocalNetworkEngineServer {
	override func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		Task {
			try await handleRawRequest(data, peer: peerID)
		}
	}
}

// these methods should actually go into something like a router, but it's late
extension LocalNetworkEngineServer {
	struct RequestMeta: Codable, Sendable {
		let server: MCPeerID.SendableDTO
		let client: MCPeerID.SendableDTO
		let requestID: UUID

		let invocation: Invocation
		let headers: [String: String]
	}

	struct RequestPayload<T: Codable & Sendable>: Codable, Sendable {
		let body: T
	}

	func handleRawRequest(_ data: Data, peer: MCPeerID) async throws {
		let meta = try decoder.decode(RequestMeta.self, from: data)
		print("Processing incoming request from \(peer) for '\(meta.invocation.rawValue)'")
		let clientID = try MCPeerID.fromSendableData(meta.client)

		do {
			let response: Response
			switch meta.invocation.components.first {
			case Invocation.listRecipientIDs.rawValue:
				let baseResponse = try await handleRecipientListRequest(meta)
				response = try Response(fromRequest: meta, body: baseResponse)
			case "getRecipient":
				let baseResponse = try await handleRecipientRequest(meta)
				response = try Response(fromRequest: meta, body: baseResponse)
			case Invocation.listGiftIDs.rawValue:
				let baseResponse = try await handleGiftListRequest(meta)
				response = try Response(fromRequest: meta, body: baseResponse)
			case "getGift":
				let baseResponse = try await handleGiftRequest(meta)
				response = try Response(fromRequest: meta, body: baseResponse)
			case Invocation.listRecipients.rawValue:
				let baseResponse = try await handleRecipientListDTOsRequest(meta)
				response = try Response(fromRequest: meta, body: baseResponse)
			case Invocation.giftQuery(giftID: UUID()).components.first:
				let payload = try decoder.decode(RequestPayload<Set<UUID>>.self, from: data)
				let baseResponse = try await handleGiftQuery(meta, payload: payload.body)
				response = try Response(fromRequest: meta, body: baseResponse)
			default:
				print("Unknown invocation requested: '\(meta.invocation.rawValue)'")
				return
			}

			let responseData = try encoder.encode(response)
			try session.send(responseData, toPeers: [clientID], with: .reliable)
			print("Replied to request from \(peer) for '\(meta.invocation.rawValue)'")
		} catch {
			let errorResponse = ErrorResponse(message: "Error processing request: \(error.localizedDescription)")
			let errorData = try encoder.encode(errorResponse)
			try session.send(errorData, toPeers: [clientID], with: .reliable)
		}
	}

	func handleRecipientListDTOsRequest(_ meta: RequestMeta) async throws -> [Recipient.DTO] {
		let context = coreDataStack.mainContext

		let recipientsInfo = try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.sortDescriptors = [
				.init(keyPath: \Recipient.name, ascending: true)
			]

			return try context.fetch(fr).map(\.dto)
		}

		return recipientsInfo
	}

	func handleRecipientListRequest(_ meta: RequestMeta) async throws -> [UUID: ListItemInfo] {
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

	func handleRecipientRequest(_ meta: RequestMeta) async throws -> Recipient.DTO {
		guard
			let idStr = meta.invocation.components[optional: 1],
			let id = UUID(uuidString: idStr)
		else { throw ServerError.invalidInvocationComponent }

		let context = coreDataStack.newBackgroundContext()
		return try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "id == %@", id as NSUUID)

			let recipient = try context.fetch(fr).first.unwrap()
			return recipient.dto
		}
	}

	func handleGiftListRequest(_ meta: RequestMeta) async throws -> [UUID: ListItemInfo] {
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

	func handleGiftRequest(_ meta: RequestMeta) async throws -> Gift.DTO {
		guard
			let idStr = meta.invocation.components[optional: 1],
			let id = UUID(uuidString: idStr)
		else { throw ServerError.invalidInvocationComponent }

		async let imageData = {
			let imageURL = await Gift.url(for: id)
			return try Data(contentsOf: imageURL)
		}()

		let context = coreDataStack.newBackgroundContext()
		var dto = try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

			let gift = try context.fetch(fr).first.unwrap()
			return gift.dto
		}

		dto.imageData = try? await imageData
		return dto
	}

	struct GiftQueryResponse: Codable, Hashable, Sendable {
		let queriedIDs: Set<UUID>
		let matchingCrossover: Set<UUID>
		let allRecipients: Set<Recipient.DTO>?
		let gift: Gift.DTO?

		let message: String?
	}
	func handleGiftQuery(_ meta: RequestMeta, payload: Set<UUID>) async throws -> GiftQueryResponse {
		guard
			let idStr = meta.invocation.components[optional: 1],
			let giftID = UUID(uuidString: idStr)
		else { throw ServerError.invalidInvocationComponent }

		let context = coreDataStack.newBackgroundContext()
		let (giftDTO, recips) = try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", giftID as NSUUID)

			guard
				let gift = try? context.fetch(fr).first
			else { throw ServerError.noMatchingGift }

			let recips = gift.recipients.map(\.dto)
			return (gift.dto, recips)
		}

		return GiftQueryResponse(
			queriedIDs: payload,
			matchingCrossover: payload.intersection(recips.map(\.id)),
			allRecipients: Set(recips),
			gift: giftDTO,
			message: nil)
	}

	enum ServerError: Error {
		case invalidInvocationComponent
		case noMatchingGift
	}

	struct ErrorResponse: Codable, Sendable, Hashable {
		let message: String
	}
}




extension LocalNetworkEngine.Invocation {
	static let listRecipientIDs: Self = "listRecipientIDs"
	static let listRecipients: Self = "listRecipients"
	static let listGiftIDs: Self = "listGiftIDs"
	static func getRecipient(id: UUID) -> Self {
		"getRecipient/\(id.uuidString)"
	}
	static func getGift(id: UUID) -> Self {
		"getGift/\(id.uuidString)"
	}
	static func giftQuery(giftID: UUID) -> Self {
		"giftQuery/\(giftID.uuidString)"
	}
	static let ping: Self = "ping"
}
