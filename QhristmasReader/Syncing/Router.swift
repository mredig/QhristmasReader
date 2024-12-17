import CoreData
@preconcurrency import MultipeerConnectivity
import SwiftPizzaSnips

final class Router: Sendable {
	nonisolated(unsafe)
	let coreDataStack: CoreDataStack
	let session: MCSession

	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	init(coreDataStack: CoreDataStack, session: MCSession) {
		self.coreDataStack = coreDataStack
		self.session = session
	}

	enum Request: Codable {
		case listRecipientIDs
		case listGiftIDs
		case getRecipient(id: UUID)
		case getGift(id: UUID)
		case ping
	}

	enum Response: Codable {
		case recipientIDList(ids: [UUID: Date])
		case giftIDList(ids: [UUID: Date])
		case recipient(Recipient.DTO)
		case gift(Gift.DTO, Data)
		case pong
	}

	func send(to peer: MCPeerID.SendableDTO, request: Request) async throws {
		try await send(to: peer, request)
	}

	func send(to peers: consuming [MCPeerID.SendableDTO], request: Request) async throws {
		try await send(to: peers, request)
	}

	func send<T: Encodable>(to peer: MCPeerID.SendableDTO, _ payload: T) async throws {
		try await send(to: [peer], payload)
	}

	func send<T: Encodable>(to peers: [MCPeerID.SendableDTO], _ payload: T) async throws {
		let data = try encoder.encode(payload)

		let actualPeers = try peers.map { try MCPeerID.fromSendableData($0) }

		try session.send(data, toPeers: actualPeers, with: .reliable)
	}

	func route(data: Data, from peer: MCPeerID.SendableDTO) async throws {
		enum Which {
			case request(Request)
			case response(Response)
		}
		let which: Which
		do {
			let decodedRequest = try decoder.decode(Request.self, from: data)
			which = .request(decodedRequest)
		} catch {
			do {
				let decodedResponse = try decoder.decode(Response.self, from: data)
				which = .response(decodedResponse)
			} catch {
				throw SimpleError(message: "Neither a request or a response")
			}
		}

		switch which {
		case .request(let request):
			let responseToSend = try await route(request: request)
			try await send(to: peer, responseToSend)
		case .response(let response):
			print("Got Response! \(response)")
		}
	}

	func route(request: Router.Request) async throws -> Router.Response {
		switch request {
		case .listRecipientIDs:
			try await listAllRecipientIDs()
		case .listGiftIDs:
			try await listAllGiftIDs()
		case .getRecipient(let id):
			.pong
		case .getGift(let id):
			.pong
		case .ping:
			.pong
		}
	}

	private func listAllRecipientIDs() async throws -> Router.Response {
		let context = coreDataStack.mainContext

		let recipientsInfo = try await context.perform {
			let fr = Recipient.fetchRequest()

			let rec = try context.fetch(fr)
			return rec.reduce(into: [UUID: Date]()) {
				guard let id = $1.id else { return }
				$0[id] = $1.lastUpdated
			}
		}

		return .recipientIDList(ids: recipientsInfo)
	}

	private func listAllGiftIDs() async throws -> Router.Response {
		let context = coreDataStack.mainContext

		let giftsInfo = try await context.perform {
			let fr = Gift.fetchRequest()

			let gifts = try context.fetch(fr)
			return gifts.reduce(into: [UUID: Date]()) {
				guard let id = $1.imageID else { return }
				$0[id] = $1.lastUpdated
			}
		}

		return .giftIDList(ids: giftsInfo)
	}
}
