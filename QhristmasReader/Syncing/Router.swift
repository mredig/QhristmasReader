import CoreData
@preconcurrency import MultipeerConnectivity
@preconcurrency import SwiftPizzaSnips

@globalActor
struct RouterActor: GlobalActor {
	actor ActorType {}

	static let shared = ActorType()
}

@RouterActor
final class Router: Sendable {


	protocol Delegate: AnyObject {
		func router(_ router: Router, didUpdateRecipientPendingCount count: Int, for peer: MCPeerID.SendableDTO)
		func router(_ router: Router, didUpdatePendingGiftCount count: Int, for peer: MCPeerID.SendableDTO)
	}

	nonisolated(unsafe)
	let coreDataStack: CoreDataStack
	let session: MCSession

	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	nonisolated(unsafe)
	weak var delegate: Delegate?

	private var pendingRecipientCounts: [MCPeerID.SendableDTO: Int] = [:]
	private var pendingGiftCounts: [MCPeerID.SendableDTO: Int] = [:]

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
		print("Sending a payload: \(payload)")
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
			print("got a request \(request)")
			let responseToSend = try await route(request: request)
			try await send(to: peer, responseToSend)
		case .response(let response):
			print("Got Response! \(response)")
			try await router(response: response, from: peer)
		}
	}

	func route(request: Router.Request) async throws -> Router.Response {
		switch request {
		case .listRecipientIDs:
			try await listAllRecipientIDs()
		case .listGiftIDs:
			try await listAllGiftIDs()
		case .getRecipient(let id):
			try await retrieveRecipient(withID: id)
		case .getGift(let id):
			try await retrieveGift(withID: id)
		case .ping:
			.pong
		}
	}

	func router(response: Response, from peer: MCPeerID.SendableDTO) async throws {
		switch response {
		case .recipientIDList(let ids):
			try await processRecipientIDs(ids, from: peer)
		case .giftIDList(let ids):
			try await processGiftIDs(ids, from: peer)
		case .recipient(let dto):
			try await processRecipient(dto: dto, from: peer)
		case .gift(let dto, let data):
			try await processGift(dto: dto, imageData: data, from: peer)
		case .pong:
			break
		}
	}

	// MARK: - Response handlers
	private func processRecipientIDs(_ ids: [UUID: Date], from peer: MCPeerID.SendableDTO) async throws {
		let needRecipientIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, date) in ids {
				group.addTask { [self] in
					let context = coreDataStack.newBackgroundContext()
					return try await context.perform {
						let fr = Recipient.fetchRequest()
						fr.fetchLimit = 1
						fr.predicate = NSPredicate(format: "id == %@", id as NSUUID)

						if let recipient = try context.fetch(fr).first {
							guard date > (recipient.lastUpdated ?? .distantPast) else { return nil }
							return recipient.id
						} else {
							return id
						}
					}
				}
			}

			var needUpdateIDs: [UUID] = []
			for try await id in group {
				guard let id else { continue }
				needUpdateIDs.append(id)
			}
			return needUpdateIDs
		}

		delegate?.router(self, didUpdateRecipientPendingCount: needRecipientIDs.count, for: peer)
		pendingRecipientCounts[peer] = needRecipientIDs.count

		for id in needRecipientIDs {
			try await send(to: peer, request: .getRecipient(id: id))
		}
	}

	private func processRecipient(dto: Recipient.DTO, from peer: MCPeerID.SendableDTO) async throws {
		let context = coreDataStack.newBackgroundContext()
		try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "id == %@", dto.id as NSUUID)

			if let recipient = try context.fetch(fr).first {
				recipient.update(from: dto)
			} else {
				_ = try Recipient(from: dto, context: context)
			}

			try context.save()
		}

		let currentCount = pendingRecipientCounts[peer, default: 0]
		let newCount = currentCount - 1
		pendingRecipientCounts[peer] = newCount
		delegate?.router(self, didUpdateRecipientPendingCount: newCount, for: peer)

		guard pendingRecipientCounts[peer] == 0 else { return }

		try await send(to: peer, request: .listGiftIDs)
	}

	private func processGiftIDs(_ ids: [UUID: Date], from peer: MCPeerID.SendableDTO) async throws {
		let needGiftIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, date) in ids {
				group.addTask { [self] in
					let context = coreDataStack.newBackgroundContext()
					return try await context.perform { @Sendable in
						let fr = Gift.fetchRequest()
						fr.fetchLimit = 1
						fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

						if let gift = try context.fetch(fr).first {
							guard date > (gift.lastUpdated ?? .distantPast) else { return nil }
							return gift.imageID
						} else {
							return id
						}
					}
				}
			}

			var needUpdateIDs: [UUID] = []
			for try await id in group {
				guard let id else { continue }
				needUpdateIDs.append(id)
			}
			return needUpdateIDs
		}

		delegate?.router(self, didUpdateRecipientPendingCount: needGiftIDs.count, for: peer)
		pendingGiftCounts[peer] = needGiftIDs.count

		for id in needGiftIDs {
			try await send(to: peer, request: .getGift(id: id))
		}
	}

	private func processGift(dto: Gift.DTO, imageData: Data, from peer: MCPeerID.SendableDTO) async throws {
		async let imageURL = ScannerViewModel.url(for: dto.imageID)

		let context = coreDataStack.newBackgroundContext()
		try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", dto.imageID as NSUUID)

			let gift = try context.fetch(fr).first
			if let gift {
				try gift.update(from: dto, context: context)
			} else {
				_ = try Gift(from: dto, context: context)
			}

			try context.save()
		}

		do {
			try await FileManager.default.createDirectory(at: ScannerViewModel.storageDirectory, withIntermediateDirectories: true)
		} catch {
			print("Error creating storage directory: \(error)")
		}
		try await imageData.write(to: imageURL)

		let currentCount = pendingGiftCounts[peer, default: 0]
		let newCount = currentCount - 1
		pendingGiftCounts[peer] = newCount
		delegate?.router(self, didUpdatePendingGiftCount: newCount, for: peer)
	}

	// MARK: - Request Handlers
	private func listAllRecipientIDs() async throws -> Router.Response {
		let context = coreDataStack.mainContext

		let recipientsInfo = try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()

			let rec = try context.fetch(fr)
			return rec.reduce(into: [UUID: Date]()) {
				guard let id = $1.id else { return }
				$0[id] = $1.lastUpdated
			}
		}

		return .recipientIDList(ids: recipientsInfo)
	}

	private func retrieveRecipient(withID id: UUID) async throws -> Response {
		let context = coreDataStack.newBackgroundContext()
		let dto = try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "id == %@", id as NSUUID)

			let recipient = try context.fetch(fr).first.unwrap()
			return recipient.dto
		}

		return .recipient(dto)
	}

	private func listAllGiftIDs() async throws -> Router.Response {
		let context = coreDataStack.mainContext

		let giftsInfo = try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()

			let gifts = try context.fetch(fr)
			return gifts.reduce(into: [UUID: Date]()) {
				guard let id = $1.imageID else { return }
				$0[id] = $1.lastUpdated
			}
		}

		return .giftIDList(ids: giftsInfo)
	}

	private func retrieveGift(withID id: UUID) async throws -> Response {
		async let imageData = {
			let imageURL = await ScannerViewModel.url(for: id)
			return try Data(contentsOf: imageURL)
		}()

		let context = coreDataStack.newBackgroundContext()
		let dto = try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

			let gift = try context.fetch(fr).first.unwrap()
			return gift.dto
		}

		return try await .gift(dto, imageData)
	}
}

extension NSManagedObjectContext: @retroactive @unchecked Sendable {}
